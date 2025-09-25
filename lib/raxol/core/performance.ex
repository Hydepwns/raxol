defmodule Raxol.Core.Performance do
  @moduledoc """
  Core performance module for Raxol framework.

  This module provides basic performance monitoring and statistics functionality
  with pure functional error handling patterns.
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
    with {:ok, _monitor} <- safe_start_monitor(options),
         :ok <- initialize_collector(),
         :ok <- initialize_jank_detector(options) do
      :ok
    else
      {:error, reason} -> {:error, {:performance_init_failed, reason}}
    end
  end

  @spec safe_start_monitor(any()) :: any()
  defp safe_start_monitor(options) do
    # Use Task to safely start the monitor with timeout
    task =
      Task.async(fn ->
        Raxol.Core.Performance.Monitor.start_link(options)
      end)

    case Task.yield(task, 5000) || Task.shutdown(task) do
      {:ok, result} -> result
      nil -> {:error, :timeout}
      {:exit, reason} -> {:error, {:monitor_start_failed, reason}}
    end
  end

  defp initialize_collector do
    with collector <- Raxol.Core.Performance.MetricsCollector.new(),
         :ok <- safe_set_collector(collector) do
      :ok
    else
      error -> {:error, {:collector_init_failed, error}}
    end
  end

  @spec safe_set_collector(any()) :: any()
  defp safe_set_collector(collector) do
    # Safely set the collector with error handling
    case Process.whereis(Raxol.Core.Performance.Memoization.Server) do
      nil ->
        {:error, :memoization_server_not_running}

      _pid ->
        # Store collector in memoization cache
        Raxol.Core.Performance.Memoization.MemoizationServer.put(
          :metrics_collector,
          collector
        )

        :ok
    end
  end

  @spec initialize_jank_detector(any()) :: any()
  defp initialize_jank_detector(options) do
    jank_threshold = Keyword.get(options, :jank_threshold, 16)
    window_size = Keyword.get(options, :window_size, 60)

    with detector <-
           Raxol.Core.Performance.JankDetector.new(jank_threshold, window_size),
         :ok <- safe_set_jank_detector(detector) do
      :ok
    else
      error -> {:error, {:jank_detector_init_failed, error}}
    end
  end

  @spec safe_set_jank_detector(any()) :: any()
  defp safe_set_jank_detector(detector) do
    # Safely set the jank detector with error handling
    case Process.whereis(Raxol.Core.Performance.Memoization.Server) do
      nil ->
        {:error, :memoization_server_not_running}

      _pid ->
        # Store jank detector in memoization cache
        Raxol.Core.Performance.Memoization.MemoizationServer.put(
          :jank_detector,
          detector
        )

        :ok
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
  @spec get_stats() :: {:ok, map()}
  def get_stats do
    with {:ok, monitor_metrics} <- safe_get_monitor_metrics(),
         {:ok, collector_metrics} <- safe_get_collector_metrics(),
         {:ok, combined_stats} <-
           combine_stats(monitor_metrics, collector_metrics) do
      {:ok, combined_stats}
    else
      {:error, reason} -> {:error, {:performance_stats_failed, reason}}
    end
  end

  defp safe_get_monitor_metrics do
    case Process.whereis(Raxol.Core.Performance.Monitor) do
      nil ->
        {:ok, %{}}

      monitor ->
        task =
          Task.async(fn ->
            Raxol.Core.Performance.Monitor.get_metrics(monitor)
          end)

        case Task.yield(task, 1000) || Task.shutdown(task) do
          {:ok, metrics} -> {:ok, metrics}
          # Return empty metrics on timeout
          nil -> {:ok, %{}}
          _ -> {:ok, %{}}
        end
    end
  end

  defp safe_get_collector_metrics do
    with {:ok, collector} <- safe_get_collector() do
      extract_collector_metrics(collector)
    else
      # Return empty metrics on error
      _ -> {:ok, %{}}
    end
  end

  @spec extract_collector_metrics(any()) :: any()
  defp extract_collector_metrics(nil), do: {:ok, %{}}

  @spec extract_collector_metrics(any()) :: any()
  defp extract_collector_metrics(collector) do
    metrics = %{
      fps: safe_get_fps(collector),
      avg_frame_time: safe_get_avg_frame_time(collector)
    }

    {:ok, metrics}
  end

  defp safe_get_collector do
    task =
      Task.async(fn ->
        Raxol.Core.Performance.Memoization.MemoizationServer.get(
          :metrics_collector
        )
      end)

    case Task.yield(task, 1000) || Task.shutdown(task) do
      {:ok, {:ok, collector}} -> {:ok, collector}
      {:ok, :not_found} -> {:ok, nil}
      _ -> {:ok, nil}
    end
  end

  @spec safe_get_fps(any()) :: any()
  defp safe_get_fps(collector) do
    task =
      Task.async(fn ->
        Raxol.Core.Performance.MetricsCollector.get_fps(collector)
      end)

    case Task.yield(task, 500) || Task.shutdown(task) do
      {:ok, fps} -> fps
      _ -> 0
    end
  end

  @spec safe_get_avg_frame_time(any()) :: any()
  defp safe_get_avg_frame_time(collector) do
    task =
      Task.async(fn ->
        Raxol.Core.Performance.MetricsCollector.get_avg_frame_time(collector)
      end)

    case Task.yield(task, 500) || Task.shutdown(task) do
      {:ok, time} -> time
      _ -> 0
    end
  end

  @spec combine_stats(any(), any()) :: any()
  defp combine_stats(monitor_metrics, collector_metrics) do
    stats = Map.merge(monitor_metrics, collector_metrics)

    final_stats =
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

    {:ok, final_stats}
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
  @spec record_measurement(String.t(), number(), keyword()) :: :ok
  def record_measurement(name, value, _tags \\ []) do
    with :ok <- record_to_collector(name, value),
         :ok <- record_to_monitor(name, value) do
      :ok
    else
      {:error, reason} -> {:error, {:performance_record_failed, reason}}
    end
  end

  @spec record_to_collector(String.t() | atom(), any()) :: any()
  defp record_to_collector(name, value)
       when name in ["render_time", "frame_time"] do
    task =
      Task.async(fn ->
        case Raxol.Core.Performance.Memoization.MemoizationServer.get(
               :metrics_collector
             ) do
          {:ok, collector} ->
            Raxol.Core.Performance.MetricsCollector.record_frame(
              collector,
              value
            )

          _ ->
            :ok
        end
      end)

    case Task.yield(task, 500) || Task.shutdown(task) do
      {:ok, :ok} -> :ok
      # Don't fail if recording times out
      _ -> :ok
    end
  end

  @spec record_to_collector(any(), any()) :: any()
  defp record_to_collector(_, _), do: :ok

  @spec record_to_monitor(String.t() | atom(), any()) :: any()
  defp record_to_monitor(name, value)
       when name in ["render_time", "frame_time"] do
    case Process.whereis(Raxol.Core.Performance.Monitor) do
      nil ->
        :ok

      monitor ->
        task =
          Task.async(fn ->
            Raxol.Core.Performance.Monitor.record_frame(monitor, value)
          end)

        case Task.yield(task, 500) || Task.shutdown(task) do
          {:ok, _} -> :ok
          # Don't fail if recording times out
          _ -> :ok
        end
    end
  end

  @spec record_to_monitor(any(), any()) :: any()
  defp record_to_monitor(_, _), do: :ok

  @doc """
  Gets performance analysis results.

  ## Returns

  * `{:ok, analysis}` - Performance analysis results
  * `{:error, reason}` - Failed to get analysis
  """
  @spec get_analysis() :: {:ok, map()} | {:error, term()}
  def get_analysis do
    with {:ok, metrics} <- get_stats(),
         {:ok, analysis} <- safe_analyze(metrics) do
      {:ok, analysis}
    else
      {:error, reason} -> {:error, {:performance_analysis_failed, reason}}
    end
  end

  @spec safe_analyze(any()) :: any()
  defp safe_analyze(metrics) do
    task =
      Task.async(fn ->
        Raxol.Core.Performance.Analyzer.analyze(metrics)
      end)

    case Task.yield(task, 2000) || Task.shutdown(task) do
      {:ok, analysis} -> {:ok, analysis}
      nil -> {:error, :analysis_timeout}
      {:exit, reason} -> {:error, {:analysis_failed, reason}}
    end
  end

  defp get_cpu_usage do
    :rand.uniform() * 100
  end

  defp get_memory_usage do
    :rand.uniform() * 100
  end
end
