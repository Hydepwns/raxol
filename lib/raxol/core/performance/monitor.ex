defmodule Raxol.Core.Performance.Monitor do
  @moduledoc """
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
    Logger.warning("UI jank detected")
  end
  
  # Get performance metrics
  metrics = Monitor.get_metrics(monitor)
  ```
  """
  
  use GenServer
  
  alias Raxol.Core.Performance.{JankDetector, MetricsCollector}
  
  # Client API
  
  @doc """
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
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end
  
  @doc """
  Records a frame's timing.
  
  ## Parameters
  
  * `monitor` - The monitor process
  * `frame_time` - Time taken to render the frame in milliseconds
  
  ## Examples
  
      iex> Monitor.record_frame(monitor, 16)
      :ok
  """
  def record_frame(monitor, frame_time) do
    GenServer.cast(monitor, {:record_frame, frame_time})
  end
  
  @doc """
  Checks if jank was detected in the last frame.
  
  ## Parameters
  
  * `monitor` - The monitor process
  
  ## Returns
  
  * `true` if jank was detected
  * `false` otherwise
  
  ## Examples
  
      iex> Monitor.detect_jank?(monitor)
      false
  """
  def detect_jank?(monitor) do
    GenServer.call(monitor, :detect_jank)
  end
  
  @doc """
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
  """
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
    schedule_memory_check(memory_check_interval)
    
    {:ok, state}
  end
  
  @impl true
  def handle_cast({:record_frame, frame_time}, state) do
    # Update jank detector
    jank_detector = JankDetector.record_frame(state.jank_detector, frame_time)
    
    # Update metrics
    metrics_collector = MetricsCollector.record_frame(state.metrics_collector, frame_time)
    
    {:noreply, %{state |
      jank_detector: jank_detector,
      metrics_collector: metrics_collector
    }}
  end
  
  @impl true
  def handle_call(:detect_jank, _from, state) do
    jank_detected = JankDetector.detect_jank?(state.jank_detector)
    {:reply, jank_detected, state}
  end
  
  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics = %{
      fps: MetricsCollector.get_fps(state.metrics_collector),
      avg_frame_time: MetricsCollector.get_avg_frame_time(state.metrics_collector),
      jank_count: JankDetector.get_jank_count(state.jank_detector),
      memory_usage: state.metrics_collector.memory_usage,
      gc_stats: state.metrics_collector.gc_stats
    }
    
    {:reply, metrics, state}
  end
  
  @impl true
  def handle_info(:check_memory, state) do
    # Update memory metrics
    metrics_collector = MetricsCollector.update_memory_usage(state.metrics_collector)
    
    # Reschedule memory check
    schedule_memory_check(state.memory_check_interval)
    
    {:noreply, %{state |
      metrics_collector: metrics_collector,
      last_memory_check: System.monotonic_time(:millisecond)
    }}
  end
  
  # Private Helpers
  
  defp schedule_memory_check(interval) do
    Process.send_after(self(), :check_memory, interval)
  end
end 