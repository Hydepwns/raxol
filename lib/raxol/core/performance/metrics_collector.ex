defmodule Raxol.Core.Performance.MetricsCollector do
  @moduledoc """
  Enhanced performance metrics collection system for Raxol.

  This module tracks comprehensive performance metrics including:
  - Frame rate (FPS) and frame timing statistics
  - Memory usage and garbage collection statistics
  - Event processing latency and throughput
  - System resource utilization
  - Performance trends and analysis
  - Real-time telemetry integration

  ## Usage

  ```elixir
  # Create a new collector
  collector = MetricsCollector.new()

  # Record a frame
  collector = MetricsCollector.record_frame(collector, 16)

  # Record event processing
  collector = MetricsCollector.record_event_timing(collector, :keyboard, 1.5)

  # Get current FPS
  fps = MetricsCollector.get_fps(collector)

  # Get comprehensive metrics
  metrics = MetricsCollector.get_all_metrics(collector)
  ```
  """

  defstruct [
    :frame_times,
    :memory_usage,
    :gc_stats,
    :last_gc_time,
    :last_memory_usage,
    :event_timings,
    :operation_counters,
    :performance_history,
    :cpu_samples,
    :start_time,
    :telemetry_enabled
  ]

  @doc """
  Creates a new enhanced metrics collector.

  ## Options

  * `:telemetry_enabled` - Enable telemetry integration (default: true)
  * `:history_size` - Number of performance samples to keep (default: 100)

  ## Returns

  A new metrics collector struct with enhanced capabilities.

  ## Examples

      iex> MetricsCollector.new()
      %MetricsCollector{
        frame_times: [],
        memory_usage: 0,
        gc_stats: %{},
        event_timings: %{},
        operation_counters: %{},
        telemetry_enabled: true
      }
  """
  def new(opts \\ []) do
    telemetry_enabled = Keyword.get(opts, :telemetry_enabled, true)

    collector = %__MODULE__{
      frame_times: [],
      memory_usage: 0,
      gc_stats: %{},
      last_gc_time: 0,
      last_memory_usage: 0,
      event_timings: %{},
      operation_counters: %{
        frames_rendered: 0,
        events_processed: 0,
        operations_completed: 0
      },
      performance_history: [],
      cpu_samples: [],
      start_time: System.monotonic_time(:microsecond),
      telemetry_enabled: telemetry_enabled
    }

    # Send initialization telemetry
    if telemetry_enabled do
      send_telemetry(:collector_initialized, %{}, %{})
    end

    collector
  end

  @doc """
  Records a frame's timing.

  ## Parameters

  * `collector` - The metrics collector
  * `frame_time` - Time taken to render the frame in milliseconds

  ## Returns

  Updated metrics collector.

  ## Examples

      iex> collector = MetricsCollector.new()
      iex> collector = MetricsCollector.record_frame(collector, 16)
      iex> length(collector.frame_times)
      1
  """
  def record_frame(collector, frame_time) do
    # Add frame time to history (keep last 60 frames)
    frame_times =
      [frame_time | collector.frame_times]
      |> Enum.take(60)

    # Update counters
    updated_counters = %{
      collector.operation_counters
      | frames_rendered: collector.operation_counters.frames_rendered + 1
    }

    # Send telemetry
    if collector.telemetry_enabled do
      send_telemetry(:frame_rendered, %{frame_time: frame_time}, %{
        fps: if(frame_time > 0, do: 1000 / frame_time, else: 0.0)
      })
    end

    %{
      collector
      | frame_times: frame_times,
        operation_counters: updated_counters
    }
  end

  @doc """
  Gets the current frames per second.

  ## Parameters

  * `collector` - The metrics collector

  ## Returns

  Current FPS as a float.

  ## Examples

      iex> collector = MetricsCollector.new()
      iex> collector = MetricsCollector.record_frame(collector, 16)
      iex> MetricsCollector.get_fps(collector)
      62.5
  """
  def get_fps(collector) do
    case collector.frame_times do
      [] ->
        0.0

      times ->
        avg_frame_time = Enum.sum(times) / length(times)
        if avg_frame_time > 0, do: 1000 / avg_frame_time, else: 0.0
    end
  end

  @doc """
  Gets the average frame time.

  ## Parameters

  * `collector` - The metrics collector

  ## Returns

  Average frame time in milliseconds.

  ## Examples

      iex> collector = MetricsCollector.new()
      iex> collector = MetricsCollector.record_frame(collector, 16)
      iex> MetricsCollector.get_avg_frame_time(collector)
      16.0
  """
  def get_avg_frame_time(collector) do
    case collector.frame_times do
      [] -> 0.0
      times -> Enum.sum(times) / length(times)
    end
  end

  @doc """
  Updates memory usage metrics.

  ## Parameters

  * `collector` - The metrics collector

  ## Returns

  Updated metrics collector with current memory usage and GC stats.

  ## Examples

      iex> collector = MetricsCollector.new()
      iex> collector = MetricsCollector.update_memory_usage(collector)
      iex> collector.memory_usage > 0
      true
  """
  def update_memory_usage(collector) do
    # Get current memory usage
    memory_usage = :erlang.memory(:total)

    # Get GC statistics
    gc_stats = :erlang.statistics(:garbage_collection)

    %{
      collector
      | memory_usage: memory_usage,
        gc_stats: gc_stats,
        last_gc_time: System.system_time(:millisecond),
        last_memory_usage: collector.memory_usage
    }
  end

  @doc """
  Gets the memory usage trend.

  ## Parameters

  * `collector` - The metrics collector

  ## Returns

  Memory usage trend as a percentage change.

  ## Examples

      iex> collector = MetricsCollector.new()
      iex> collector = MetricsCollector.update_memory_usage(collector)
      iex> collector = MetricsCollector.update_memory_usage(collector)
      iex> MetricsCollector.get_memory_trend(collector)
      0.0
  """
  def get_memory_trend(collector) do
    case {collector.last_gc_time, collector.last_memory_usage} do
      {0, _} ->
        0.0

      {last_time, last_memory}
      when is_integer(last_memory) and last_memory > 0 ->
        current_time = System.system_time(:millisecond)
        time_diff = current_time - last_time

        if time_diff > 0 do
          # Calculate memory growth rate
          memory_growth = collector.memory_usage - last_memory
          # Convert to bytes per second
          memory_growth / time_diff * 1000
        else
          0.0
        end

      _ ->
        0.0
    end
  end

  @doc """
  Gets garbage collection statistics.

  ## Parameters

  * `collector` - The metrics collector

  ## Returns

  Map containing GC statistics:
  * `:number_of_gcs` - Total number of garbage collections
  * `:words_reclaimed` - Total words reclaimed
  * `:heap_size` - Current heap size
  * `:heap_limit` - Maximum heap size

  ## Examples

      iex> collector = MetricsCollector.new()
      iex> collector = MetricsCollector.update_memory_usage(collector)
      iex> gc_stats = MetricsCollector.get_gc_stats(collector)
      iex> Map.has_key?(gc_stats, :number_of_gcs)
      true
  """
  def get_gc_stats(collector) do
    case collector.gc_stats do
      {number_of_gcs, words_reclaimed, heap_size, heap_limit} ->
        %{
          number_of_gcs: number_of_gcs,
          words_reclaimed: words_reclaimed,
          heap_size: heap_size,
          heap_limit: heap_limit
        }

      _ ->
        %{
          number_of_gcs: 0,
          words_reclaimed: 0,
          heap_size: 0,
          heap_limit: 0
        }
    end
  end

  @doc """
  Records event processing timing.

  ## Parameters

  * `collector` - The metrics collector
  * `event_type` - Type of event (e.g., :keyboard, :mouse, :scroll)
  * `processing_time` - Time taken to process the event in milliseconds

  ## Returns

  Updated metrics collector with event timing recorded.
  """
  def record_event_timing(collector, event_type, processing_time) do
    # Update event timings (keep last 100 for each type)
    current_timings = Map.get(collector.event_timings, event_type, [])
    updated_timings = [processing_time | Enum.take(current_timings, 99)]

    new_event_timings =
      Map.put(collector.event_timings, event_type, updated_timings)

    # Update counters
    updated_counters = %{
      collector.operation_counters
      | events_processed: collector.operation_counters.events_processed + 1
    }

    # Send telemetry
    if collector.telemetry_enabled do
      send_telemetry(:event_processed, %{processing_time: processing_time}, %{
        event_type: event_type,
        average_time: get_average_event_time(updated_timings)
      })
    end

    %{
      collector
      | event_timings: new_event_timings,
        operation_counters: updated_counters
    }
  end

  @doc """
  Records operation completion.

  ## Parameters

  * `collector` - The metrics collector
  * `operation_type` - Type of operation completed
  * `duration` - Duration of the operation in microseconds

  ## Returns

  Updated metrics collector with operation recorded.
  """
  def record_operation(collector, operation_type, duration) do
    # Update counters
    updated_counters = %{
      collector.operation_counters
      | operations_completed:
          collector.operation_counters.operations_completed + 1
    }

    # Send telemetry
    if collector.telemetry_enabled do
      send_telemetry(:operation_completed, %{duration: duration}, %{
        operation_type: operation_type
      })
    end

    %{collector | operation_counters: updated_counters}
  end

  @doc """
  Updates CPU usage samples.

  ## Parameters

  * `collector` - The metrics collector

  ## Returns

  Updated metrics collector with current CPU sample.
  """
  def update_cpu_usage(collector) do
    # Simple CPU usage approximation
    run_queue = :erlang.statistics(:run_queue)
    logical_processors = :erlang.system_info(:logical_processors)
    cpu_usage = min(100.0, run_queue / logical_processors * 100.0)

    # Add to samples (keep last 60)
    cpu_samples = [cpu_usage | Enum.take(collector.cpu_samples, 59)]

    # Send telemetry
    if collector.telemetry_enabled do
      send_telemetry(:cpu_sampled, %{cpu_usage: cpu_usage}, %{
        run_queue: run_queue,
        logical_processors: logical_processors
      })
    end

    %{collector | cpu_samples: cpu_samples}
  end

  @doc """
  Gets comprehensive performance metrics.

  ## Parameters

  * `collector` - The metrics collector

  ## Returns

  Map containing all performance metrics including:
  * Frame rate and timing statistics
  * Memory usage and trends
  * Event processing statistics
  * CPU utilization
  * Operation counters
  * System uptime
  """
  def get_all_metrics(collector) do
    uptime = System.monotonic_time(:microsecond) - collector.start_time

    %{
      # Frame metrics
      fps: get_fps(collector),
      average_frame_time: get_avg_frame_time(collector),
      frame_count: collector.operation_counters.frames_rendered,

      # Memory metrics
      memory_usage: collector.memory_usage,
      memory_trend: get_memory_trend(collector),
      gc_stats: get_gc_stats(collector),

      # Event metrics
      event_timings: get_event_timing_stats(collector),
      events_processed: collector.operation_counters.events_processed,

      # CPU metrics
      cpu_usage: get_current_cpu_usage(collector),
      average_cpu_usage: get_average_cpu_usage(collector),

      # System metrics
      uptime_seconds: uptime / 1_000_000,
      operations_completed: collector.operation_counters.operations_completed,

      # Performance scores
      performance_score: calculate_performance_score(collector),

      # Collection timestamp
      timestamp: System.monotonic_time(:microsecond)
    }
  end

  @doc """
  Resets all metrics to initial state.

  ## Parameters

  * `collector` - The metrics collector

  ## Returns

  Reset metrics collector.
  """
  def reset_metrics(collector) do
    %{
      collector
      | frame_times: [],
        event_timings: %{},
        performance_history: [],
        cpu_samples: [],
        operation_counters: %{
          frames_rendered: 0,
          events_processed: 0,
          operations_completed: 0
        }
    }
  end

  # Private helper functions

  defp send_telemetry(event_name, measurements, metadata) do
    :telemetry.execute(
      [:raxol, :performance, event_name],
      measurements,
      metadata
    )
  end

  defp get_average_event_time(timings)
       when is_list(timings) and length(timings) > 0 do
    Enum.sum(timings) / length(timings)
  end

  defp get_average_event_time(_), do: 0.0

  defp get_event_timing_stats(collector) do
    Enum.map(collector.event_timings, fn {event_type, timings} ->
      {event_type,
       %{
         count: length(timings),
         average: get_average_event_time(timings),
         latest: List.first(timings, 0.0)
       }}
    end)
    |> Map.new()
  end

  defp get_current_cpu_usage(collector) do
    List.first(collector.cpu_samples, 0.0)
  end

  defp get_average_cpu_usage(collector) do
    case collector.cpu_samples do
      [] -> 0.0
      samples -> Enum.sum(samples) / length(samples)
    end
  end

  defp calculate_performance_score(collector) do
    # Calculate overall performance score (0-100)
    fps = get_fps(collector)
    cpu_usage = get_average_cpu_usage(collector)
    memory_trend = get_memory_trend(collector)

    # Weight different factors
    # Target 60 FPS
    fps_score = min(100.0, fps / 60.0 * 100.0)
    # Lower CPU usage is better
    cpu_score = max(0.0, 100.0 - cpu_usage)

    memory_score =
      if memory_trend < 0,
        do: 100.0,
        else: max(0.0, 100.0 - abs(memory_trend) / 1000.0)

    # Weighted average
    fps_score * 0.4 + cpu_score * 0.3 + memory_score * 0.3
  end
end
