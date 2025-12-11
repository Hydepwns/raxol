defmodule Raxol.Core.Runtime.Rendering.Scheduler do
  @moduledoc """
  Manages the rendering schedule based on frame rate.
  """

  use Raxol.Core.Behaviours.BaseManager

  alias Raxol.Core.Runtime.Rendering.Engine

  defmodule State do
    @moduledoc false

    defstruct interval_ms: 16,
              timer_id: nil,
              enabled: false,
              engine_pid: nil
  end

  # --- Public API ---

  # BaseManager provides start_link/1 and start_link/2 automatically

  def enable do
    GenServer.cast(__MODULE__, :enable)
  end

  def disable do
    GenServer.cast(__MODULE__, :disable)
  end

  def set_interval(ms) when is_integer(ms) and ms > 0 do
    GenServer.cast(__MODULE__, {:set_interval, ms})
  end

  # --- BaseManager Callbacks ---

  @impl true
  def init_manager(opts) when is_list(opts) do
    engine_pid = Keyword.get(opts, :engine_pid, Engine)
    interval_ms = Keyword.get(opts, :interval_ms, 16)
    {:ok, %State{engine_pid: engine_pid, interval_ms: interval_ms}}
  end

  def init_manager({engine_pid, interval_ms}) do
    init_manager(engine_pid: engine_pid, interval_ms: interval_ms)
  end

  @impl true
  def handle_manager_cast(
        :enable,
        %State{enabled: false, engine_pid: _pid} = state
      ) do
    new_state = schedule_render_tick(%{state | enabled: true})
    {:noreply, new_state}
  end

  # Already enabled
  @impl true
  def handle_manager_cast(:enable, state), do: {:noreply, state}

  @impl true
  def handle_manager_cast(:disable, %State{enabled: true} = state) do
    # We can't cancel the timer, but we can ignore its message
    {:noreply, %{state | enabled: false, timer_id: nil}}
  end

  # Already disabled
  @impl true
  def handle_manager_cast(:disable, state), do: {:noreply, state}

  @impl true
  def handle_manager_cast({:set_interval, ms}, state) do
    new_state = %{state | interval_ms: ms}

    updated_state =
      case state.enabled do
        true -> schedule_render_tick(new_state)
        false -> new_state
      end

    {:noreply, updated_state}
  end

  @impl true
  def handle_manager_info(:render_tick, %State{enabled: true} = state) do
    GenServer.cast(state.engine_pid, :render_frame)

    new_state = schedule_render_tick(state)
    {:noreply, new_state}
  end

  # Ignore tick if disabled
  @impl true
  def handle_manager_info(:render_tick, state), do: {:noreply, state}

  @impl true
  def handle_manager_info(
        {:render_tick, timer_id},
        %State{enabled: true, timer_id: timer_id} = state
      ) do
    GenServer.cast(state.engine_pid, :render_frame)
    new_state = schedule_render_tick(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_manager_info({:render_tick, _other_id}, state),
    do: {:noreply, state}

  # --- Private Helpers ---

  defp schedule_render_tick(%State{interval_ms: ms} = state) do
    # We can't cancel the timer, but we can ignore its message
    timer_id = System.unique_integer([:positive])
    Process.send_after(self(), {:render_tick, timer_id}, ms)
    %{state | timer_id: timer_id}
  end
end
