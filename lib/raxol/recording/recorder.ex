defmodule Raxol.Recording.Recorder do
  @moduledoc """
  GenServer that captures terminal output and input during a live Raxol session.

  Registers itself as `Raxol.Recording.Recorder` so the rendering engine
  can send output frames via `record_output/2` and the dispatcher can send
  input events via `record_input/2`. Accumulates timestamped events for
  later serialization.

  When `:auto_save` is provided, periodically flushes the session to disk
  so data is preserved if the app crashes.

  ## Usage

      {:ok, pid} = Recorder.start_link(title: "My Demo", auto_save: "demo.cast")
      # ... run app, output is captured automatically ...
      session = Recorder.stop(pid)
      Asciicast.write!(session, "demo.cast")
  """

  use GenServer

  require Logger

  alias Raxol.Recording.{Asciicast, Session}

  @flush_interval_ms 10_000

  # -- Client API --

  @doc "Starts the recorder and registers it."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Records an output frame. Called by the rendering engine."
  @spec record_output(pid() | atom(), binary()) :: :ok
  def record_output(pid \\ __MODULE__, data) when is_binary(data) do
    GenServer.cast(pid, {:output, data})
  end

  @doc "Records an input event. Called by the event dispatcher."
  @spec record_input(pid() | atom(), binary()) :: :ok
  def record_input(pid \\ __MODULE__, data) when is_binary(data) do
    GenServer.cast(pid, {:input, data})
  end

  @doc "Stops recording and returns the completed session."
  @spec stop(pid() | atom()) :: Session.t()
  def stop(pid \\ __MODULE__) do
    GenServer.call(pid, :stop)
  end

  @doc "Returns the current session (without stopping)."
  @spec get_session(pid() | atom()) :: Session.t()
  def get_session(pid \\ __MODULE__) do
    GenServer.call(pid, :get_session)
  end

  @doc "Checks if a recorder is currently active."
  @spec active?() :: boolean()
  def active? do
    Process.whereis(__MODULE__) != nil
  end

  # -- Server --

  @impl true
  def init(opts) do
    session = Session.new(opts)
    start_mono = System.monotonic_time(:microsecond)
    auto_save = Keyword.get(opts, :auto_save)

    if auto_save, do: schedule_flush()

    {:ok, %{session: session, start_mono: start_mono, auto_save: auto_save}}
  end

  @impl true
  def handle_cast({:output, data}, state) do
    {:noreply, append_event(state, :output, data)}
  end

  @impl true
  def handle_cast({:input, data}, state) do
    {:noreply, append_event(state, :input, data)}
  end

  @impl true
  def handle_call(:get_session, _from, state) do
    session = %{state.session | events: Enum.reverse(state.session.events)}
    {:reply, session, state}
  end

  @impl true
  def handle_call(:stop, _from, state) do
    session = finalize_session(state)

    if state.auto_save do
      Asciicast.write!(session, state.auto_save)
    end

    {:stop, :normal, session, state}
  end

  @impl true
  def handle_info(:flush, state) do
    if state.auto_save do
      flush_to_disk(state)
      schedule_flush()
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, state) do
    if state.auto_save do
      flush_to_disk(state)
    end
  end

  # -- Private --

  defp append_event(state, type, data) do
    elapsed = System.monotonic_time(:microsecond) - state.start_mono
    event = {elapsed, type, data}
    session = %{state.session | events: [event | state.session.events]}
    %{state | session: session}
  end

  defp finalize_session(state) do
    %{
      state.session
      | ended_at: DateTime.utc_now(),
        events: Enum.reverse(state.session.events)
    }
  end

  defp flush_to_disk(state) do
    session = %{state.session | events: Enum.reverse(state.session.events)}
    Asciicast.write!(session, state.auto_save)
  rescue
    e ->
      Logger.warning("Recorder auto-save failed: #{Exception.message(e)}")
      :ok
  end

  defp schedule_flush do
    _ref = Process.send_after(self(), :flush, @flush_interval_ms)
    :ok
  end
end
