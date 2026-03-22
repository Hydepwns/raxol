defmodule Raxol.SSH.Session do
  @moduledoc """
  Manages a single SSH connection's TEA application lifecycle.

  Spawned per SSH connection under DynamicSupervisor. Starts a Lifecycle
  with `environment: :ssh` and routes SSH channel data through the
  IOAdapter for input parsing and output writing.
  """

  use GenServer

  require Raxol.Core.Runtime.Log

  alias Raxol.SSH.IOAdapter

  defstruct [:app_module, :lifecycle_pid, :connection_ref, :channel_id, :width, :height]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def run(app_module) do
    receive do
      {:ssh_data, _data} -> :ok
    after
      30_000 -> :ok
    end

    Raxol.Core.Runtime.Log.info(
      "[SSH.Session] Shell process for #{inspect(app_module)} exiting"
    )
  end

  @impl true
  def init(opts) do
    app_module = Keyword.fetch!(opts, :app_module)
    connection_ref = Keyword.fetch!(opts, :connection_ref)
    channel_id = Keyword.fetch!(opts, :channel_id)
    width = Keyword.get(opts, :width, 80)
    height = Keyword.get(opts, :height, 24)

    io_writer = IOAdapter.make_writer(connection_ref, channel_id)

    {:ok, lifecycle_pid} =
      Raxol.Core.Runtime.Lifecycle.start_link(app_module,
        environment: :ssh,
        io_writer: io_writer,
        width: width,
        height: height,
        name: :"ssh_session_#{inspect(self())}"
      )

    Raxol.Core.Runtime.Log.info(
      "[SSH.Session] Started for #{inspect(app_module)} (#{width}x#{height})"
    )

    {:ok,
     %__MODULE__{
       app_module: app_module,
       lifecycle_pid: lifecycle_pid,
       connection_ref: connection_ref,
       channel_id: channel_id,
       width: width,
       height: height
     }}
  end

  @impl true
  def handle_info({:ssh_data, data}, state) do
    events = IOAdapter.parse_input(data)

    dispatcher_pid = get_dispatcher(state.lifecycle_pid)

    Enum.each(events, fn event ->
      if dispatcher_pid do
        GenServer.cast(dispatcher_pid, {:dispatch, event})
      end
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info({:resize, width, height}, state) do
    if state.lifecycle_pid && Process.alive?(state.lifecycle_pid) do
      event = Raxol.Core.Events.Event.window(width, height, :resize)
      dispatcher_pid = get_dispatcher(state.lifecycle_pid)

      if dispatcher_pid do
        GenServer.cast(dispatcher_pid, {:dispatch, event})
      end
    end

    {:noreply, %{state | width: width, height: height}}
  end

  @impl true
  def handle_info(:eof, state) do
    Raxol.Core.Runtime.Log.info("[SSH.Session] EOF received, shutting down")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(:closed, state) do
    Raxol.Core.Runtime.Log.info("[SSH.Session] Channel closed")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, state) do
    if state.lifecycle_pid && Process.alive?(state.lifecycle_pid) do
      Raxol.Core.Runtime.Lifecycle.stop(state.lifecycle_pid)
    end

    :ok
  end

  defp get_dispatcher(lifecycle_pid) do
    if Process.alive?(lifecycle_pid) do
      state = GenServer.call(lifecycle_pid, :get_full_state)
      state.dispatcher_pid
    end
  rescue
    _ -> nil
  end
end
