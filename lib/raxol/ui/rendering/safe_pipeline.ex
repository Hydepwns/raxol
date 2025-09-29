defmodule Raxol.UI.Rendering.SafePipeline do
  @moduledoc """
  Fault-tolerant rendering pipeline with error recovery and performance monitoring.

  Ensures the UI remains responsive even when rendering errors occur,
  with automatic fallback rendering and performance degradation strategies.
  """

  use Raxol.Core.Behaviours.BaseManager

@behaviour Raxol.Core.Behaviours.BaseManager
  require Logger

  import Raxol.Core.ErrorHandler
  import Raxol.Core.Performance.Profiler
  alias Raxol.Core.ErrorRecovery
  alias Raxol.UI.Rendering.Pipeline

  # Target 60 FPS
  @render_timeout 16

  defstruct [
    :pipeline,
    :error_handler,
    :performance_monitor,
    :fallback_renderer,
    :render_queue,
    :stats,
    :config
  ]

  @type performance_stats :: %{
          frames_rendered: non_neg_integer(),
          frames_dropped: non_neg_integer(),
          average_render_time: float(),
          errors_recovered: non_neg_integer(),
          performance_warnings: non_neg_integer()
        }

  @type t :: %__MODULE__{
          pipeline: pid() | nil,
          error_handler: map(),
          performance_monitor: map(),
          fallback_renderer: fun(),
          render_queue: :queue.queue(),
          stats: performance_stats(),
          config: map()
        }

  # Client API

  @doc """
  Starts the safe rendering pipeline.
  """

  @doc """
  Safely renders a frame with automatic error recovery.
  """
  def render(pid \\ __MODULE__, scene) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           GenServer.call(pid, {:render, scene}, @render_timeout * 2)
         end) do
      {:ok, result} ->
        result

      {:error, {:exit, {:timeout, _}}} ->
        Logger.warning("Render timeout, using cached frame")
        {:ok, :cached}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Schedules an animation with performance monitoring.
  """
  def animate(pid \\ __MODULE__, animation, opts \\ []) do
    GenServer.cast(pid, {:animate, animation, opts})
  end

  @doc """
  Updates rendering configuration dynamically.
  """
  def update_config(pid \\ __MODULE__, config) do
    GenServer.call(pid, {:update_config, config})
  end

  @doc """
  Gets rendering performance statistics.
  """
  def get_stats(pid \\ __MODULE__) do
    GenServer.call(pid, :get_stats)
  end

  @doc """
  Enables or disables performance mode.
  """
  def set_performance_mode(pid \\ __MODULE__, enabled) do
    GenServer.cast(pid, {:set_performance_mode, enabled})
  end

  # Server callbacks

  @impl true
  def init_manager(opts) do
    state =
      with_error_handling :init do
        # Start the underlying pipeline
        pipeline_opts = Keyword.take(opts, [:width, :height, :renderer])

        pipeline =
          case Pipeline.start_link(pipeline_opts) do
            {:ok, pid} ->
              Process.monitor(pid)
              pid

            _ ->
              nil
          end

        %__MODULE__{
          pipeline: pipeline,
          error_handler:
            ErrorRecovery.circuit_breaker_init(
              threshold: 10,
              timeout: 5_000
            ),
          performance_monitor: %{
            frame_times: :queue.new(),
            last_frame_time: System.monotonic_time(:microsecond),
            performance_mode: false
          },
          fallback_renderer: create_fallback_renderer(),
          render_queue: :queue.new(),
          stats: %{
            frames_rendered: 0,
            frames_dropped: 0,
            average_render_time: 0.0,
            errors_recovered: 0,
            performance_warnings: 0
          },
          config: %{
            enable_fallback: Keyword.get(opts, :enable_fallback, true),
            max_queue_size: Keyword.get(opts, :max_queue_size, 10),
            performance_mode_threshold:
              Keyword.get(opts, :performance_mode_threshold, 0.8),
            enable_frame_skip: Keyword.get(opts, :enable_frame_skip, true)
          }
        }
      end

    {:ok, state}
  end

  @impl true
  def handle_manager_call({:render, scene}, from, state) do
    # Profile render operation
    profile :render, metadata: %{scene_complexity: estimate_complexity(scene)} do
      case safe_render(scene, state) do
        {:ok, result, new_state} ->
          {:reply, {:ok, result}, new_state}

        {:error, reason, new_state} ->
          # Try fallback rendering
          handle_render_error(scene, reason, from, new_state)
      end
    end
  end

  @impl true
  def handle_manager_call({:update_config, config}, _from, state) do
    new_config = Map.merge(state.config, config)
    {:reply, :ok, %{state | config: new_config}}
  end

  @impl true
  def handle_manager_call(:get_stats, _from, state) do
    stats =
      Map.merge(state.stats, %{
        performance_mode: state.performance_monitor.performance_mode,
        queue_size: :queue.len(state.render_queue),
        circuit_breaker_state:
          ErrorRecovery.circuit_breaker_state(state.error_handler)
      })

    {:reply, {:ok, stats}, state}
  end

  @impl true
  def handle_manager_cast({:animate, animation, opts}, state) do
    new_state =
      with_error_handling :animate do
        safe_animate(animation, opts, state)
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_manager_cast({:set_performance_mode, enabled}, state) do
    new_monitor = Map.put(state.performance_monitor, :performance_mode, enabled)

    Logger.info("Performance mode #{get_performance_mode_status(enabled)}")

    {:noreply, %{state | performance_monitor: new_monitor}}
  end

  @impl true
  def handle_manager_info(
        {:DOWN, _ref, :process, pid, reason},
        %{pipeline: pid} = state
      ) do
    Logger.error("Rendering pipeline crashed: #{inspect(reason)}")

    # Attempt to restart pipeline
    new_state = restart_pipeline(state)

    {:noreply, new_state}
  end

  @impl true
  def handle_manager_info({:process_queue, _}, state) do
    new_state = process_render_queue(state)
    schedule_queue_processing()

    {:noreply, new_state}
  end

  # Private functions

  defp safe_render(scene, state) do
    start_time = System.monotonic_time(:microsecond)

    # Check circuit breaker
    case ErrorRecovery.with_circuit_breaker(state.error_handler, :render, fn ->
           perform_render(scene, state)
         end) do
      {:ok, result} ->
        end_time = System.monotonic_time(:microsecond)
        # Convert to ms
        render_time = (end_time - start_time) / 1000.0

        new_state =
          state
          |> update_performance_stats(render_time)
          |> check_performance_threshold(render_time)

        {:ok, result, new_state}

      {:error, :circuit_open, _message, _metadata} ->
        Logger.warning("Circuit breaker open, using fallback renderer")
        use_fallback_renderer(scene, state)

      {:error, :circuit_failure, message, _metadata} ->
        Logger.error("Render failed: #{message}")

        handle_render_error(
          message,
          scene,
          state,
          System.monotonic_time(:microsecond) - start_time
        )
    end
  end

  defp perform_render(_scene, %{pipeline: nil}) do
    {:error, :no_pipeline}
  end

  defp perform_render(scene, %{pipeline: pipeline} = state) do
    # Apply performance optimizations if needed
    optimized_scene =
      maybe_optimize_scene(state.performance_monitor.performance_mode, scene)

    case Raxol.Core.ErrorHandling.safe_call(fn ->
           GenServer.call(pipeline, {:render, optimized_scene}, @render_timeout)
         end) do
      {:ok, result} ->
        case result do
          {:ok, _} = ok_result -> ok_result
          error -> error
        end

      {:error, {:exit, {:timeout, _}}} ->
        {:error, :render_timeout}

      {:error, {:exit, {:noproc, _}}} ->
        {:error, :pipeline_dead}

      {:error, error} ->
        {:error, error}
    end
  end

  defp handle_render_error(scene, reason, from, state) do
    Logger.warning("Render error: #{inspect(reason)}")

    handle_fallback_decision(
      state.config.enable_fallback,
      scene,
      reason,
      from,
      state
    )
  end

  defp use_fallback_renderer(scene, state) do
    case Raxol.Core.ErrorHandling.safe_call_with_logging(
           fn -> state.fallback_renderer.(scene) end,
           "Fallback renderer failed"
         ) do
      {:ok, result} -> {:ok, result, state}
      {:error, _} -> {:error, :fallback_failed, state}
    end
  end

  defp safe_animate(animation, opts, state) do
    # Validate animation
    case validate_animation(animation) do
      :ok ->
        # Check if we should skip frames
        skip_frame = should_skip_frame?(state)
        handle_animation_frame(skip_frame, animation, opts, state)

      {:error, reason} ->
        Logger.error("Invalid animation: #{inspect(reason)}")
        state
    end
  end

  defp perform_animation(animation, opts, %{pipeline: pipeline} = state)
       when is_pid(pipeline) do
    case Raxol.Core.ErrorHandling.safe_call_with_logging(
           fn ->
             GenServer.cast(pipeline, {:animate, animation, opts})
             :ok
           end,
           "Animation failed"
         ) do
      {:ok, _} -> {:ok, state}
      {:error, reason} -> {:error, reason}
    end
  end

  defp perform_animation(_, _, _state), do: {:error, :no_pipeline}

  defp update_performance_stats(state, render_time) do
    # Update frame times queue (keep last 60 frames)
    frame_times =
      state.performance_monitor.frame_times
      |> :queue.in(render_time)
      |> trim_queue(60)

    # Calculate average render time
    times_list = :queue.to_list(frame_times)

    avg_time = calculate_average_time(length(times_list) > 0, times_list)

    new_monitor = %{
      state.performance_monitor
      | frame_times: frame_times,
        last_frame_time: System.monotonic_time(:microsecond)
    }

    new_stats =
      state.stats
      |> Map.update(:frames_rendered, 1, &(&1 + 1))
      |> Map.put(:average_render_time, avg_time)

    %{state | performance_monitor: new_monitor, stats: new_stats}
  end

  defp check_performance_threshold(state, render_time) do
    threshold_ms = @render_timeout * state.config.performance_mode_threshold

    threshold_exceeded =
      render_time > threshold_ms and
        not state.performance_monitor.performance_mode

    handle_performance_threshold(
      threshold_exceeded,
      state,
      render_time,
      threshold_ms
    )
  end

  defp should_skip_frame?(state) do
    should_check =
      state.config.enable_frame_skip and
        state.performance_monitor.performance_mode

    check_frame_skip(should_check, state)
  end

  defp optimize_scene(scene) do
    # Apply performance optimizations
    scene
    |> reduce_quality()
    |> disable_effects()
    |> simplify_geometry()
  end

  # Placeholder
  defp reduce_quality(scene), do: scene
  # Placeholder
  defp disable_effects(scene), do: scene
  # Placeholder
  defp simplify_geometry(scene), do: scene

  defp estimate_complexity(scene) do
    # Estimate scene complexity for profiling
    case scene do
      list when is_list(list) -> length(list)
      map when is_map(map) -> map_size(map)
      _ -> 1
    end
  end

  defp validate_animation(animation) when not is_map(animation) do
    {:error, :invalid_format}
  end

  defp validate_animation(animation)
       when not is_map_key(animation, :duration) do
    {:error, :missing_duration}
  end

  defp validate_animation(%{duration: duration}) when duration <= 0 do
    {:error, :invalid_duration}
  end

  defp validate_animation(_animation) do
    :ok
  end

  defp create_fallback_renderer do
    fn scene ->
      # Simple fallback renderer that returns a text representation
      {:ok, "Fallback render: #{inspect(scene, limit: 50)}"}
    end
  end

  defp restart_pipeline(state) do
    case Pipeline.start_link([]) do
      {:ok, new_pid} ->
        Process.monitor(new_pid)
        Logger.info("Pipeline restarted successfully")
        %{state | pipeline: new_pid}

      {:error, reason} ->
        Logger.error("Failed to restart pipeline: #{inspect(reason)}")
        state
    end
  end

  defp process_render_queue(state) do
    case :queue.out(state.render_queue) do
      {{:value, {scene, from}}, new_queue} ->
        # Try to render queued scene
        case safe_render(scene, state) do
          {:ok, result, new_state} ->
            GenServer.reply(from, {:ok, result})
            %{new_state | render_queue: new_queue}

          {:error, _reason, new_state} ->
            GenServer.reply(from, {:error, :render_failed})
            %{new_state | render_queue: new_queue}
        end

      {:empty, _} ->
        state
    end
  end

  defp schedule_queue_processing do
    _ = Process.send_after(self(), {:process_queue, :now}, 100)
  end

  defp trim_queue(queue, max_size) do
    needs_trim = :queue.len(queue) > max_size
    handle_queue_trim(needs_trim, queue, max_size)
  end

  defp get_performance_mode_status(true), do: "enabled"
  defp get_performance_mode_status(false), do: "disabled"

  defp maybe_optimize_scene(true, scene), do: optimize_scene(scene)
  defp maybe_optimize_scene(false, scene), do: scene

  defp handle_fallback_decision(false, _scene, reason, _from, state) do
    {:reply, {:error, reason}, state}
  end

  defp handle_fallback_decision(true, scene, _reason, from, state) do
    case use_fallback_renderer(scene, state) do
      {:ok, result, new_state} ->
        new_stats = Map.update(new_state.stats, :errors_recovered, 1, &(&1 + 1))
        final_state = %{new_state | stats: new_stats}
        {:reply, {:ok, result}, final_state}

      {:error, _fallback_reason, new_state} ->
        can_queue = :queue.len(state.render_queue) < state.config.max_queue_size
        handle_fallback_queue_decision(can_queue, scene, from, state, new_state)
    end
  end

  defp handle_fallback_queue_decision(true, scene, from, state, new_state) do
    new_queue = :queue.in({scene, from}, state.render_queue)
    schedule_queue_processing()
    {:noreply, %{new_state | render_queue: new_queue}}
  end

  defp handle_fallback_queue_decision(false, _scene, _from, state, new_state) do
    new_stats = Map.update(state.stats, :frames_dropped, 1, &(&1 + 1))
    {:reply, {:error, :render_failed}, %{new_state | stats: new_stats}}
  end

  defp handle_animation_frame(true, _animation, _opts, state) do
    new_stats = Map.update(state.stats, :frames_dropped, 1, &(&1 + 1))
    %{state | stats: new_stats}
  end

  defp handle_animation_frame(false, animation, opts, state) do
    case perform_animation(animation, opts, state) do
      {:ok, new_state} -> new_state
      {:error, _reason} -> state
    end
  end

  defp calculate_average_time(false, _times_list), do: 0.0

  defp calculate_average_time(true, times_list) do
    Enum.sum(times_list) / length(times_list)
  end

  defp handle_performance_threshold(false, state, _render_time, _threshold_ms),
    do: state

  defp handle_performance_threshold(true, state, render_time, threshold_ms) do
    Logger.warning(
      "Performance threshold exceeded (#{render_time}ms > #{threshold_ms}ms)"
    )

    new_stats = Map.update(state.stats, :performance_warnings, 1, &(&1 + 1))
    new_monitor = Map.put(state.performance_monitor, :performance_mode, true)

    %{state | performance_monitor: new_monitor, stats: new_stats}
  end

  defp check_frame_skip(false, _state), do: false

  defp check_frame_skip(true, state) do
    # Skip frame if we're behind schedule
    now = System.monotonic_time(:microsecond)
    time_since_last = (now - state.performance_monitor.last_frame_time) / 1000.0
    time_since_last < @render_timeout / 2
  end

  defp handle_queue_trim(false, queue, _max_size), do: queue

  defp handle_queue_trim(true, queue, max_size) do
    {_, new_queue} = :queue.out(queue)
    trim_queue(new_queue, max_size)
  end
end
