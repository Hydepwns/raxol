defmodule Raxol.Core.Performance.Monitor do
  @moduledoc '''
  Performance monitoring system for Raxol applications.

  This module provides tools for:
  - Frame rate monitoring
  - Memory usage tracking
  - UI jank detection
  - Performance metrics collection
  - Performance visualization

  ## Usage

  ```elixir
  # Start monitoring
  {:ok, monitor} = Monitor.start_link()

  # Record frame timing
  Monitor.record_frame(monitor, 16)  # 16ms frame time

  # Check for jank
  if Monitor.detect_jank?(monitor) do
    Raxol.Core.Runtime.Log.warning_with_context("UI jank detected", %{})
  end

  # Get performance metrics
  metrics = Monitor.get_metrics(monitor)
  ```
  '''

  use GenServer

  alias Raxol.Core.Performance.{JankDetector, MetricsCollector}

  # Client API

  @doc '''
  Starts a new performance monitor.

  ## Options

  * `:jank_threshold` - Time in milliseconds above which a frame is considered janky (default: 16)
  * `:sample_size` - Number of frames to keep in the rolling window (default: 60)
  * `:memory_check_interval` - How often to check memory usage in milliseconds (default: 5000)

  ## Examples

      iex> {:ok, monitor} = Monitor.start_link()
      {:ok, #PID<0.123.0>}

      iex> {:ok, monitor} = Monitor.start_link(jank_threshold: 20)
      {:ok, #PID<0.124.0>}
  '''
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc '''
  Records a frame's timing.

  ## Parameters

  * `monitor` - The monitor process
  * `frame_time` - Time taken to render the frame in milliseconds

  ## Examples

      iex> Monitor.record_frame(monitor, 16)
      :ok
  '''
  def record_frame(monitor, frame_time) do
    GenServer.cast(monitor, {:record_frame, frame_time})
  end

  @doc '''
  Checks if jank was detected in the last frame.

  ## Parameters

  * `monitor` - The monitor process

  ## Returns

  * `true` if jank was detected
  * `false` otherwise

  ## Examples

      iex> Monitor.detect_jank?(monitor)
      false
  '''
  def detect_jank?(monitor) do
    GenServer.call(monitor, :detect_jank)
  end

  @doc '''
  Gets current performance metrics.

  ## Parameters

  * `monitor` - The monitor process

  ## Returns

  Map containing performance metrics:
  * `:fps` - Current frames per second
  * `:avg_frame_time` - Average frame time in milliseconds
  * `:jank_count` - Number of janky frames in the sample window
  * `:memory_usage` - Current memory usage in bytes
  * `:gc_stats` - Garbage collection statistics

  ## Examples

      iex> Monitor.get_metrics(monitor)
      %{
        fps: 60,
        avg_frame_time: 16.5,
        jank_count: 2,
        memory_usage: 1234567,
        gc_stats: %{...}
      }
  '''
  def get_metrics(monitor) do
    GenServer.call(monitor, :get_metrics)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    jank_threshold = Keyword.get(opts, :jank_threshold, 16)
    sample_size = Keyword.get(opts, :sample_size, 60)
    memory_check_interval = Keyword.get(opts, :memory_check_interval, 5000)

    # Initialize state
    state = %{
      jank_detector: JankDetector.new(jank_threshold, sample_size),
      metrics_collector: MetricsCollector.new(),
      memory_check_interval: memory_check_interval,
      last_memory_check: System.monotonic_time(:millisecond)
    }

    # Schedule memory check
    _memory_check_timer =
      Process.send_after(self(), :check_memory, memory_check_interval)

    {:ok, state}
  end

  @impl true
  def handle_cast({:record_frame, frame_time}, state) do
    # Update jank detector
    jank_detector = JankDetector.record_frame(state.jank_detector, frame_time)

    # Record performance metrics
    Raxol.Core.Metrics.UnifiedCollector.record_performance(
      :frame_time,
      frame_time,
      tags: [:performance, :frame]
    )

    # Record FPS
    fps = 1000 / frame_time

    Raxol.Core.Metrics.UnifiedCollector.record_performance(
      :fps,
      fps,
      tags: [:performance, :frame]
    )

    # Record jank if detected
    if JankDetector.detect_jank?(jank_detector) do
      Raxol.Core.Metrics.UnifiedCollector.record_performance(
        :jank,
        1,
        tags: [:performance, :frame, :jank]
      )
    end

    {:noreply, %{state | jank_detector: jank_detector}}
  end

  @impl true
  def handle_call(:detect_jank, _from, state) do
    jank_detected = JankDetector.detect_jank?(state.jank_detector)
    {:reply, jank_detected, state}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    # Get metrics from unified collector
    performance_metrics =
      Raxol.Core.Metrics.UnifiedCollector.get_metrics_by_type(:performance)

    resource_metrics =
      Raxol.Core.Metrics.UnifiedCollector.get_metrics_by_type(:resource)

    # Calculate metrics
    fps =
      case performance_metrics.frame_time do
        [%{value: frame_time} | _] -> 1000 / frame_time
        _ -> 0.0
      end

    avg_frame_time =
      case performance_metrics.frame_time do
        [%{value: frame_time} | _] -> frame_time
        _ -> 0.0
      end

    jank_count =
      case performance_metrics.jank do
        janks when is_list(janks) -> length(janks)
        _ -> 0
      end

    memory_usage =
      case resource_metrics.memory_usage do
        [%{value: memory} | _] -> memory
        _ -> 0
      end

    gc_stats =
      case resource_metrics.gc_stats do
        [%{value: stats} | _] -> stats
        _ -> %{}
      end

    metrics = %{
      fps: fps,
      avg_frame_time: avg_frame_time,
      jank_count: jank_count,
      memory_usage: memory_usage,
      gc_stats: gc_stats
    }

    {:reply, metrics, state}
  end

  @impl true
  def handle_info(:check_memory, state) do
    # Get memory metrics
    memory = :erlang.memory()
    total_memory = memory[:total]
    process_memory = memory[:processes]

    # Record memory metrics
    Raxol.Core.Metrics.UnifiedCollector.record_resource(
      :total_memory,
      total_memory,
      tags: [:memory, :system]
    )

    Raxol.Core.Metrics.UnifiedCollector.record_resource(
      :process_memory,
      process_memory,
      tags: [:memory, :process]
    )

    # Record memory ratio
    Raxol.Core.Metrics.UnifiedCollector.record_resource(
      :memory_usage_ratio,
      process_memory / total_memory,
      tags: [:memory, :ratio]
    )

    # Reschedule memory check
    schedule_memory_check(state.memory_check_interval)

    {:noreply, state}
  end

  # Private Helpers

  defp schedule_memory_check(interval) do
    Process.send_after(self(), :check_memory, interval)
  end
end
