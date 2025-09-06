defmodule Raxol.Core.Runtime.Rendering.Scheduler do
  @moduledoc """
  Manages the rendering schedule based on frame rate.
  """

  use GenServer
  alias Raxol.Core.Runtime.Rendering.Engine

  defmodule State do
    @moduledoc false

    defstruct interval_ms: 16,
              timer_id: nil,
              enabled: false,
              engine_pid: nil
  end

  # --- Public API ---

  def start_link(opts \\ []) do
    engine_pid = Keyword.get(opts, :engine_pid, Engine)
    interval_ms = Keyword.get(opts, :interval_ms, 16)

    GenServer.start_link(__MODULE__, {engine_pid, interval_ms},
      name: __MODULE__
    )
  end

  def enable do
    GenServer.cast(__MODULE__, :enable)
  end

  def disable do
    GenServer.cast(__MODULE__, :disable)
  end

  def set_interval(ms) when is_integer(ms) and ms > 0 do
    GenServer.cast(__MODULE__, {:set_interval, ms})
  end

  # --- GenServer Callbacks ---

  @impl GenServer
  def init({engine_pid, interval_ms}) do
    {:ok, %State{engine_pid: engine_pid, interval_ms: interval_ms}}
  end

  @impl GenServer
  def handle_cast(:enable, %State{enabled: false, engine_pid: _pid} = state) do
    new_state = schedule_render_tick(%{state | enabled: true})
    {:noreply, new_state}
  end

  # Already enabled
  def handle_cast(:enable, state), do: {:noreply, state}

  @impl GenServer
  def handle_cast(:disable, %State{enabled: true} = state) do
    # We can't cancel the timer, but we can ignore its message
    {:noreply, %{state | enabled: false, timer_id: nil}}
  end

  # Already disabled
  def handle_cast(:disable, state), do: {:noreply, state}

  @impl GenServer
  def handle_cast({:set_interval, ms}, state) do
    new_state = %{state | interval_ms: ms}

    updated_state =
      case state.enabled do
        true -> schedule_render_tick(new_state)
        false -> new_state
      end

    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_info(:render_tick, %State{enabled: true} = state) do
    GenServer.cast(state.engine_pid, :render_frame)

    new_state = schedule_render_tick(state)
    {:noreply, new_state}
  end

  # Ignore tick if disabled
  def handle_info(:render_tick, state), do: {:noreply, state}

  @impl GenServer
  def handle_info(
        {:render_tick, timer_id},
        %State{enabled: true, timer_id: timer_id} = state
      ) do
    GenServer.cast(state.engine_pid, :render_frame)
    new_state = schedule_render_tick(state)
    {:noreply, new_state}
  end

  def handle_info({:render_tick, _other_id}, state), do: {:noreply, state}

  # --- Private Helpers ---

  defp schedule_render_tick(%State{interval_ms: ms} = state) do
    # We can't cancel the timer, but we can ignore its message
    timer_id = System.unique_integer([:positive])
    Process.send_after(self(), {:render_tick, timer_id}, ms)
    %{state | timer_id: timer_id}
  end
end
