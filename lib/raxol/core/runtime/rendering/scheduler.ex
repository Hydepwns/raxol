defmodule Raxol.Core.Runtime.Rendering.Scheduler do
  @moduledoc """
  Manages the rendering schedule based on frame rate.
  """

  use GenServer

  alias Raxol.Core.Runtime.Rendering.Engine

  defmodule State do
    @moduledoc false
    defstruct interval_ms: 16, # Default ~60 FPS
              timer_ref: nil,
              enabled: false,
              # Keep track of the engine PID
              engine_pid: nil
  end

  # --- Public API ---

  def start_link(opts \\ []) do
    engine_pid = Keyword.get(opts, :engine_pid, Engine)
    interval_ms = Keyword.get(opts, :interval_ms, 16)
    GenServer.start_link(__MODULE__, {engine_pid, interval_ms}, name: __MODULE__)
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

  @impl true
  def init({engine_pid, interval_ms}) do
    {:ok, %State{engine_pid: engine_pid, interval_ms: interval_ms}}
  end

  @impl true
  def handle_cast(:enable, %State{enabled: false, engine_pid: _pid} = state) do
    new_state = schedule_render_tick(%{state | enabled: true})
    {:noreply, new_state}
  end

  def handle_cast(:enable, state), do: {:noreply, state} # Already enabled

  @impl true
  def handle_cast(:disable, %State{enabled: true, timer_ref: ref} = state) do
    if ref, do: Process.cancel_timer(ref)
    {:noreply, %{state | enabled: false, timer_ref: nil}}
  end

  def handle_cast(:disable, state), do: {:noreply, state} # Already disabled

  @impl true
  def handle_cast({:set_interval, ms}, state) do
    new_state = %{state | interval_ms: ms}
    # If enabled, reschedule with new interval
    updated_state = if state.enabled, do: schedule_render_tick(new_state), else: new_state
    {:noreply, updated_state}
  end

  @impl true
  def handle_info(:render_tick, %State{enabled: true} = state) do
    # Trigger the rendering engine via async cast
    GenServer.cast(state.engine_pid, :render_frame)

    # Reschedule the next tick
    new_state = schedule_render_tick(state)
    {:noreply, new_state}
  end

  # Ignore tick if disabled
  def handle_info(:render_tick, state), do: {:noreply, state}

  # --- Private Helpers ---

  defp schedule_render_tick(%State{timer_ref: ref, interval_ms: ms} = state) do
    # Cancel previous timer if exists
    if ref, do: Process.cancel_timer(ref)
    # Schedule new timer
    new_timer_ref = Process.send_after(self(), :render_tick, ms)
    %{state | timer_ref: new_timer_ref}
  end
end
