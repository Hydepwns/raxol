defmodule Raxol.Core.Performance do
  @moduledoc """
  Core performance module for Raxol framework.

  This module provides basic performance monitoring and statistics functionality.
  It serves as the main entry point for performance operations.
  """

  @doc """
  Initializes the performance monitoring system.

  ## Parameters

  * `options` - Configuration options for performance monitoring (optional)

  ## Returns

  * `:ok` - Performance system initialized successfully
  * `{:error, reason}` - Failed to initialize performance system
  """
  @spec init(keyword()) :: :ok | {:error, term()}
  def init(options \\ []) do
    # Initialize performance subsystems
    try do
      # Start monitor
      {:ok, _monitor} = Raxol.Core.Performance.Monitor.start_link(options)

      # Create metrics collector
      collector = Raxol.Core.Performance.MetricsCollector.new()
      Process.put(:performance_collector, collector)

      # Create jank detector
      jank_threshold = Keyword.get(options, :jank_threshold, 16)
      window_size = Keyword.get(options, :window_size, 60)

      detector =
        Raxol.Core.Performance.JankDetector.new(jank_threshold, window_size)

      Process.put(:jank_detector, detector)

      :ok
    rescue
      e ->
        {:error, {:performance_init_failed, e}}
    end
  end

  @doc """
  Gets current performance statistics.

  ## Returns

  * `{:ok, stats}` - Performance statistics map
  * `{:error, reason}` - Failed to get performance stats

  ## Example

  ```elixir
  {:ok, stats} = Raxol.Core.Performance.get_stats()
  # Returns: {:ok, %{cpu_usage: 15.2, memory_usage: 45.8, render_time: 120}}
  ```
  """
  @spec get_stats() :: {:ok, map()} | {:error, term()}
  def get_stats do
    try do
      # Get monitor metrics if available
      monitor_metrics =
        case Process.whereis(Raxol.Core.Performance.Monitor) do
          nil -> %{}
          monitor -> Raxol.Core.Performance.Monitor.get_metrics(monitor)
        end

      # Get collector metrics if available
      collector = Process.get(:performance_collector)

      collector_metrics =
        if collector do
          %{
            fps: Raxol.Core.Performance.MetricsCollector.get_fps(collector),
            avg_frame_time:
              Raxol.Core.Performance.MetricsCollector.get_avg_frame_time(
                collector
              )
          }
        else
          %{}
        end

      # Combine metrics
      stats = Map.merge(monitor_metrics, collector_metrics)

      # Add basic system stats if not available
      stats =
        Map.merge(
          stats,
          %{
            cpu_usage: get_cpu_usage(),
            memory_usage: get_memory_usage(),
            render_time: Map.get(stats, :avg_frame_time, 0),
            frame_rate: Map.get(stats, :fps, 0),
            jank_events: Map.get(stats, :jank_count, 0)
          },
          fn _key, _v1, v2 -> v2 end
        )

      {:ok, stats}
    rescue
      e ->
        {:error, {:performance_stats_failed, e}}
    end
  end

  @doc """
  Records a performance measurement.

  ## Parameters

  * `name` - Measurement name
  * `value` - Measurement value (typically time in milliseconds)
  * `tags` - Optional tags as keyword list

  ## Returns

  * `:ok` - Measurement recorded successfully
  * `{:error, reason}` - Failed to record measurement
  """
  @spec record_measurement(String.t(), number(), keyword()) ::
          :ok | {:error, term()}
  def record_measurement(name, value, _tags \\ []) do
    try do
      # Record in metrics collector if it's a frame time
      if name == "render_time" or name == "frame_time" do
        collector = Process.get(:performance_collector)

        if collector do
          Raxol.Core.Performance.MetricsCollector.record_frame(collector, value)
        end
      end

      # Record in monitor if available
      monitor = Process.whereis(Raxol.Core.Performance.Monitor)

      if monitor and (name == "render_time" or name == "frame_time") do
        Raxol.Core.Performance.Monitor.record_frame(monitor, value)
      end

      :ok
    rescue
      e ->
        {:error, {:performance_record_failed, e}}
    end
  end

  @doc """
  Gets performance analysis results.

  ## Returns

  * `{:ok, analysis}` - Performance analysis results
  * `{:error, reason}` - Failed to get analysis
  """
  @spec get_analysis() :: {:ok, map()} | {:error, term()}
  def get_analysis do
    try do
      # Get current metrics for analysis
      {:ok, metrics} = get_stats()

      # Analyze the metrics
      analysis = Raxol.Core.Performance.Analyzer.analyze(metrics)
      {:ok, analysis}
    rescue
      e ->
        {:error, {:performance_analysis_failed, e}}
    end
  end

  # Private helper functions

  defp get_cpu_usage do
    # Simple CPU usage estimation
    # In a real implementation, this would use :os.cmd or similar
    :rand.uniform() * 100
  end

  defp get_memory_usage do
    # Simple memory usage estimation
    # In a real implementation, this would use :erlang.memory()
    :rand.uniform() * 100
  end
end
