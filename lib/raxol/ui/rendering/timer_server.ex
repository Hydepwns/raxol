defmodule Raxol.UI.Rendering.TimerServer do
  @moduledoc """
  Centralized timer management for the UI rendering pipeline.

  Consolidates all rendering-related timers including:
  - Animation frame timers (60fps target)
  - Render debouncing timers
  - Adaptive frame rate timers
  - Pipeline processing timers
  - Frame rate monitoring timers

  This reduces timer process overhead and provides consistent timer handling
  across all rendering components.
  """

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Core.Utils.TimerManager
  alias Raxol.Core.Runtime.Log

  # Timer types for rendering pipeline
  @animation_frame_timer :animation_frame
  @render_debounce_timer :render_debounce
  @frame_rate_monitor_timer :frame_rate_monitor
  @adaptive_frame_timer :adaptive_frame
  @pipeline_tick_timer :pipeline_tick

  # Default intervals (milliseconds)
  # 60fps
  @default_frame_interval 16
  # 8ms debounce
  @default_debounce_interval 8
  # 1s monitoring
  @default_monitor_interval 1000
  # 2s adaptation checks
  @default_adaptive_interval 2000

  # Client API

  @doc """
  Starts an animation frame timer that sends regular frame tick messages.
  """
  @spec start_animation_timer(pid(), non_neg_integer()) :: :ok
  def start_animation_timer(target_pid, interval_ms \\ @default_frame_interval) do
    with {:ok, manager_pid} <- get_manager_pid() do
      GenServer.call(
        manager_pid,
        {:start_timer, @animation_frame_timer, target_pid, interval_ms}
      )
    end
  end

  @doc """
  Starts a render debounce timer to batch rapid render requests.
  """
  @spec start_debounce_timer(pid(), non_neg_integer()) :: :ok
  def start_debounce_timer(
        target_pid,
        interval_ms \\ @default_debounce_interval
      ) do
    with {:ok, manager_pid} <- get_manager_pid() do
      GenServer.call(
        manager_pid,
        {:start_timer, @render_debounce_timer, target_pid, interval_ms}
      )
    end
  end

  @doc """
  Starts a frame rate monitoring timer for performance tracking.
  """
  @spec start_monitor_timer(pid(), non_neg_integer()) :: :ok
  def start_monitor_timer(target_pid, interval_ms \\ @default_monitor_interval) do
    with {:ok, manager_pid} <- get_manager_pid() do
      GenServer.call(
        manager_pid,
        {:start_timer, @frame_rate_monitor_timer, target_pid, interval_ms}
      )
    end
  end

  @doc """
  Starts an adaptive frame rate timer for dynamic performance adjustment.
  """
  @spec start_adaptive_timer(pid(), non_neg_integer()) :: :ok | {:error, :not_started}
  def start_adaptive_timer(
        target_pid,
        interval_ms \\ @default_adaptive_interval
      ) do
    with {:ok, manager_pid} <- get_manager_pid() do
      GenServer.call(
        manager_pid,
        {:start_timer, @adaptive_frame_timer, target_pid, interval_ms}
      )
    end
  end

  @doc """
  Starts a pipeline processing timer for batch operations.
  """
  @spec start_pipeline_timer(pid(), non_neg_integer()) :: :ok
  def start_pipeline_timer(target_pid, interval_ms) do
    with {:ok, manager_pid} <- get_manager_pid() do
      GenServer.call(
        manager_pid,
        {:start_timer, @pipeline_tick_timer, target_pid, interval_ms}
      )
    end
  end

  @doc """
  Stops a specific timer type.
  """
  @spec stop_timer(atom()) :: :ok
  def stop_timer(timer_type) do
    with {:ok, manager_pid} <- get_manager_pid() do
      GenServer.call(manager_pid, {:stop_timer, timer_type})
    end
  end

  @doc """
  Stops all rendering timers.
  """
  @spec stop_all_timers() :: :ok
  def stop_all_timers do
    with {:ok, manager_pid} <- get_manager_pid() do
      GenServer.call(manager_pid, :stop_all_timers)
    end
  end

  @doc """
  Updates the interval for a specific timer type.
  """
  @spec update_timer_interval(atom(), non_neg_integer()) :: :ok
  def update_timer_interval(timer_type, new_interval_ms) do
    with {:ok, manager_pid} <- get_manager_pid() do
      GenServer.call(
        manager_pid,
        {:update_interval, timer_type, new_interval_ms}
      )
    end
  end

  @doc """
  Gets current timer statistics for monitoring.
  """
  @spec get_timer_stats() :: map()
  def get_timer_stats do
    case get_manager_pid() do
      {:ok, manager_pid} ->
        GenServer.call(manager_pid, :get_timer_stats)

      _ ->
        %{active_timers: 0, total_messages: 0}
    end
  end

  # BaseManager Implementation

  @impl Raxol.Core.Behaviours.BaseManager
  def init_manager(opts) do
    state = %{
      timers: %{},
      target_pids: %{},
      intervals: %{},
      stats: %{
        active_timers: 0,
        total_messages: 0,
        started_at: :os.system_time(:millisecond)
      }
    }

    Log.info("Started with options: #{inspect(opts)}")
    {:ok, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(
        {:start_timer, timer_type, target_pid, interval_ms},
        _from,
        state
      ) do
    new_state = start_timer_internal(state, timer_type, target_pid, interval_ms)
    {:reply, :ok, new_state}
  end

  def handle_manager_call({:stop_timer, timer_type}, _from, state) do
    new_state = stop_timer_internal(state, timer_type)
    {:reply, :ok, new_state}
  end

  def handle_manager_call(:stop_all_timers, _from, state) do
    new_state = stop_all_timers_internal(state)
    {:reply, :ok, new_state}
  end

  def handle_manager_call(
        {:update_interval, timer_type, new_interval_ms},
        _from,
        state
      ) do
    new_state = update_interval_internal(state, timer_type, new_interval_ms)
    {:reply, :ok, new_state}
  end

  def handle_manager_call(:get_timer_stats, _from, state) do
    {:reply, state.stats, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_info({:timer_tick, timer_type}, state) do
    new_state = handle_timer_tick(state, timer_type)
    {:noreply, new_state}
  end

  def handle_manager_info(msg, state) do
    Log.debug("Unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private functions

  defp get_manager_pid do
    case GenServer.whereis(__MODULE__) do
      nil -> {:error, :not_started}
      pid -> {:ok, pid}
    end
  end

  defp start_timer_internal(state, timer_type, target_pid, interval_ms) do
    # Stop existing timer if present
    state = stop_timer_internal(state, timer_type)

    # Start new timer
    case TimerManager.start_interval({:timer_tick, timer_type}, interval_ms) do
      {:ok, timer_ref} ->
        new_timers = Map.put(state.timers, timer_type, timer_ref)
        new_target_pids = Map.put(state.target_pids, timer_type, target_pid)
        new_intervals = Map.put(state.intervals, timer_type, interval_ms)

        new_stats = %{state.stats | active_timers: map_size(new_timers)}

        Log.debug(
          "[TimerServer] Started #{timer_type} timer (#{interval_ms}ms) for #{inspect(target_pid)}"
        )

        %{
          state
          | timers: new_timers,
            target_pids: new_target_pids,
            intervals: new_intervals,
            stats: new_stats
        }

      {:error, reason} ->
        Log.error(
          "[TimerServer] Failed to start #{timer_type} timer: #{inspect(reason)}"
        )

        state
    end
  end

  defp stop_timer_internal(state, timer_type) do
    case Map.get(state.timers, timer_type) do
      nil ->
        state

      timer_ref ->
        TimerManager.safe_cancel(timer_ref)

        new_timers = Map.delete(state.timers, timer_type)
        new_target_pids = Map.delete(state.target_pids, timer_type)
        new_intervals = Map.delete(state.intervals, timer_type)

        new_stats = %{state.stats | active_timers: map_size(new_timers)}

        Log.debug("Stopped #{timer_type} timer")

        %{
          state
          | timers: new_timers,
            target_pids: new_target_pids,
            intervals: new_intervals,
            stats: new_stats
        }
    end
  end

  defp stop_all_timers_internal(state) do
    TimerManager.cancel_all_timers(state.timers)

    new_stats = %{state.stats | active_timers: 0}

    Log.info("Stopped all timers")

    %{state | timers: %{}, target_pids: %{}, intervals: %{}, stats: new_stats}
  end

  defp update_interval_internal(state, timer_type, new_interval_ms) do
    case Map.get(state.target_pids, timer_type) do
      nil ->
        Log.warning(
          "[TimerServer] Cannot update interval for non-existent timer: #{timer_type}"
        )

        state

      target_pid ->
        # Restart timer with new interval
        start_timer_internal(state, timer_type, target_pid, new_interval_ms)
    end
  end

  defp handle_timer_tick(state, timer_type) do
    case Map.get(state.target_pids, timer_type) do
      nil ->
        Log.warning(
          "[TimerServer] Received tick for unknown timer: #{timer_type}"
        )

        state

      target_pid ->
        # Send timer message to target process
        message = build_timer_message(timer_type)
        send(target_pid, message)

        # Update stats
        new_stats = %{
          state.stats
          | total_messages: state.stats.total_messages + 1
        }

        %{state | stats: new_stats}
    end
  end

  defp build_timer_message(timer_type) do
    case timer_type do
      @animation_frame_timer -> {:animation_tick, :timer_ref}
      @render_debounce_timer -> {:render_debounce_tick}
      @frame_rate_monitor_timer -> {:frame_rate_monitor_tick}
      @adaptive_frame_timer -> {:adaptive_frame_tick}
      @pipeline_tick_timer -> {:pipeline_tick}
      _ -> {:timer_tick, timer_type}
    end
  end
end
