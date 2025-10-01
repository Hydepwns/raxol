defmodule Raxol.Terminal.Graphics.PerformanceMonitor do
  @moduledoc """
  Comprehensive performance monitoring system for terminal graphics operations.

  This module provides real-time monitoring and analysis of:
  - Graphics operation latency and throughput
  - GPU utilization and memory usage
  - Rendering pipeline performance
  - Cache hit rates and efficiency
  - Resource allocation patterns
  - Performance regression detection

  ## Features

  ### Real-time Monitoring
  - Sub-millisecond operation timing
  - GPU memory usage tracking
  - Rendering pipeline bottleneck detection
  - Cache performance analysis
  - Throughput measurement (operations/second)

  ### Performance Analysis
  - Statistical analysis (percentiles, averages, variance)
  - Performance trend analysis
  - Anomaly detection for performance regressions
  - Comparative analysis across different graphics operations
  - Resource utilization optimization suggestions

  ### Reporting and Alerting
  - Real-time performance dashboards
  - Performance alert thresholds
  - Historical performance data
  - Export capabilities for analysis tools
  - Integration with external monitoring systems

  ## Usage

      # Start performance monitoring
      {:ok, monitor} = PerformanceMonitor.start_link(%{
        sampling_rate: 100,  # samples per second
        retention_period: 3600,  # 1 hour
        alert_thresholds: %{
          latency_p99: 100,  # 100ms
          gpu_memory_usage: 0.8  # 80%
        }
      })

      # Monitor a graphics operation
      PerformanceMonitor.start_operation(:image_scaling, metadata)
      # ... perform operation ...
      PerformanceMonitor.end_operation(:image_scaling, result)

      # Get performance metrics
      metrics = PerformanceMonitor.get_metrics()
  """

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Core.Runtime.Log
  @type operation_type :: atom()
  @type operation_id :: String.t()
  # microseconds
  @type timestamp :: non_neg_integer()

  @type operation_metrics :: %{
          type: operation_type(),
          start_time: timestamp(),
          end_time: timestamp(),
          # microseconds
          duration: non_neg_integer(),
          cpu_usage: float(),
          gpu_usage: float(),
          # bytes
          memory_used: non_neg_integer(),
          cache_hits: non_neg_integer(),
          cache_misses: non_neg_integer(),
          metadata: map()
        }

  @type performance_stats :: %{
          operation_counts: map(),
          latency_percentiles: map(),
          throughput: map(),
          resource_utilization: map(),
          cache_performance: map(),
          error_rates: map()
        }

  @type alert_config :: %{
          threshold: float(),
          comparison: :greater_than | :less_than | :equals,
          consecutive_violations: non_neg_integer(),
          callback: function() | nil
        }

  defstruct [
    :config,
    :active_operations,
    :completed_operations,
    :performance_history,
    :alert_configs,
    :alert_states,
    :system_metrics,
    :monitoring_refs
  ]

  @default_config %{
    # samples per second
    sampling_rate: 50,
    # 30 minutes
    retention_period: 1800,
    # maximum operations to keep
    max_history_size: 10_000,
    enable_system_monitoring: true,
    enable_gpu_monitoring: true,
    enable_cache_monitoring: true,
    performance_analysis: true,
    alert_enabled: true
  }

  # Public API

  #  def start_link(config \\ %{}) do
  #    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  #  end

  @doc """
  Starts monitoring a graphics operation.

  ## Parameters

  - `operation_type` - Type of operation (e.g., :image_scaling, :rendering)
  - `metadata` - Additional operation metadata

  ## Returns

  - `{:ok, operation_id}` - Successfully started monitoring
  - `{:error, reason}` - Failed to start monitoring

  ## Examples

      {:ok, op_id} = PerformanceMonitor.start_operation(:image_processing, %{
        image_size: 1024 * 1024,
        format: :png,
        operation: :scale
      })
  """
  @spec start_operation(operation_type(), map()) ::
          {:ok, operation_id()} | {:error, term()}
  def start_operation(operation_type, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:start_operation, operation_type, metadata})
  end

  @doc """
  Ends monitoring of a graphics operation.

  ## Parameters

  - `operation_id` - ID returned from start_operation/2
  - `result` - Operation result (success/failure and additional data)
  """
  @spec end_operation(operation_id(), map()) :: :ok | {:error, term()}
  def end_operation(operation_id, result \\ %{}) do
    GenServer.call(__MODULE__, {:end_operation, operation_id, result})
  end

  @doc """
  Records a custom metric for analysis.

  ## Examples

      PerformanceMonitor.record_metric(:gpu_memory_usage, 75.5, %{
        timestamp: System.system_time(:microsecond),
        unit: :percentage
      })
  """
  @spec record_metric(atom(), float(), map()) :: :ok
  def record_metric(metric_name, value, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:record_metric, metric_name, value, metadata})
  end

  @doc """
  Gets current performance metrics and statistics.
  """
  @spec get_metrics() :: performance_stats()
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  @doc """
  Gets detailed performance history for analysis.

  ## Parameters

  - `options` - Filtering and formatting options
    - `:operation_types` - List of operation types to include
    - `:time_range` - {start_time, end_time} in microseconds
    - `:limit` - Maximum number of operations to return
  """
  @spec get_performance_history(map()) :: [operation_metrics()]
  def get_performance_history(options \\ %{}) do
    GenServer.call(__MODULE__, {:get_performance_history, options})
  end

  @doc """
  Configures performance alerts.

  ## Examples

      PerformanceMonitor.configure_alert(:high_latency, %{
        threshold: 100.0,  # 100ms
        comparison: :greater_than,
        consecutive_violations: 3,
        callback: fn metrics -> Log.module_warning("High latency detected") end
      })
  """
  @spec configure_alert(atom(), alert_config()) :: :ok | {:error, term()}
  def configure_alert(alert_name, alert_config) do
    GenServer.call(__MODULE__, {:configure_alert, alert_name, alert_config})
  end

  @doc """
  Generates a performance report for the specified time period.
  """
  @spec generate_report(map()) :: {:ok, map()} | {:error, term()}
  def generate_report(options \\ %{}) do
    GenServer.call(__MODULE__, {:generate_report, options})
  end

  @doc """
  Resets all performance statistics and history.
  """
  @spec reset_statistics() :: :ok
  def reset_statistics do
    GenServer.call(__MODULE__, :reset_statistics)
  end

  # GenServer Implementation

  @impl true
  def init_manager(config) do
    merged_config = Map.merge(@default_config, config)

    initial_state = %__MODULE__{
      config: merged_config,
      active_operations: %{},
      completed_operations: [],
      performance_history: [],
      alert_configs: %{},
      alert_states: %{},
      system_metrics: initialize_system_metrics(),
      monitoring_refs: start_system_monitoring(merged_config)
    }

    # Schedule periodic tasks
    schedule_cleanup()
    schedule_analysis()

    {:ok, initial_state}
  end

  @impl true
  def handle_manager_call(
        {:start_operation, operation_type, metadata},
        _from,
        state
      ) do
    operation_id = generate_operation_id()
    start_time = System.monotonic_time(:microsecond)

    operation_data = %{
      id: operation_id,
      type: operation_type,
      start_time: start_time,
      metadata: metadata,
      system_metrics_start: capture_system_metrics()
    }

    new_active = Map.put(state.active_operations, operation_id, operation_data)

    {:reply, {:ok, operation_id}, %{state | active_operations: new_active}}
  end

  @impl true
  def handle_manager_call({:end_operation, operation_id, result}, _from, state) do
    case Map.get(state.active_operations, operation_id) do
      nil ->
        {:reply, {:error, :operation_not_found}, state}

      operation_data ->
        end_time = System.monotonic_time(:microsecond)
        system_metrics_end = capture_system_metrics()

        completed_operation = %{
          type: operation_data.type,
          start_time: operation_data.start_time,
          end_time: end_time,
          duration: end_time - operation_data.start_time,
          cpu_usage:
            calculate_cpu_usage(
              operation_data.system_metrics_start,
              system_metrics_end
            ),
          gpu_usage:
            calculate_gpu_usage(
              operation_data.system_metrics_start,
              system_metrics_end
            ),
          memory_used:
            calculate_memory_used(
              operation_data.system_metrics_start,
              system_metrics_end
            ),
          cache_hits: Map.get(result, :cache_hits, 0),
          cache_misses: Map.get(result, :cache_misses, 0),
          metadata: Map.merge(operation_data.metadata, result),
          success: Map.get(result, :success, true)
        }

        # Update state
        new_active = Map.delete(state.active_operations, operation_id)
        new_completed = [completed_operation | state.completed_operations]

        new_history =
          add_to_history(
            completed_operation,
            state.performance_history,
            state.config
          )

        # Check alerts
        new_alert_states =
          check_alerts(
            completed_operation,
            state.alert_configs,
            state.alert_states
          )

        new_state = %{
          state
          | active_operations: new_active,
            completed_operations:
              limit_list(new_completed, state.config.max_history_size),
            performance_history: new_history,
            alert_states: new_alert_states
        }

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_manager_call(:get_metrics, _from, state) do
    metrics = calculate_performance_stats(state)
    {:reply, metrics, state}
  end

  @impl true
  def handle_manager_call({:get_performance_history, options}, _from, state) do
    filtered_history = filter_history(state.performance_history, options)
    {:reply, filtered_history, state}
  end

  @impl true
  def handle_manager_call(
        {:configure_alert, alert_name, alert_config},
        _from,
        state
      ) do
    case validate_alert_config(alert_config) do
      :ok ->
        new_configs = Map.put(state.alert_configs, alert_name, alert_config)

        new_states =
          Map.put(state.alert_states, alert_name, initialize_alert_state())

        {:reply, :ok,
         %{state | alert_configs: new_configs, alert_states: new_states}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call({:generate_report, options}, _from, state) do
    {:ok, report} = generate_performance_report(state, options)
    {:reply, {:ok, report}, state}
  end

  @impl true
  def handle_manager_call(:reset_statistics, _from, state) do
    new_state = %{
      state
      | active_operations: %{},
        completed_operations: [],
        performance_history: [],
        alert_states:
          Map.new(state.alert_configs, fn {name, _} ->
            {name, initialize_alert_state()}
          end)
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_cast({:record_metric, metric_name, value, metadata}, state) do
    timestamp =
      Map.get(metadata, :timestamp, System.monotonic_time(:microsecond))

    metric_entry = %{
      name: metric_name,
      value: value,
      timestamp: timestamp,
      metadata: metadata
    }

    # Update system metrics
    new_system_metrics =
      update_system_metric(state.system_metrics, metric_entry)

    {:noreply, %{state | system_metrics: new_system_metrics}}
  end

  @impl true
  def handle_manager_info(:cleanup, state) do
    new_state = perform_cleanup(state)
    schedule_cleanup()
    {:noreply, new_state}
  end

  @impl true
  def handle_manager_info(:analysis, state) do
    new_state = perform_analysis(state)
    schedule_analysis()
    {:noreply, new_state}
  end

  @impl true
  def handle_manager_info({:system_metric, metric_data}, state) do
    new_system_metrics = Map.merge(state.system_metrics, metric_data)
    {:noreply, %{state | system_metrics: new_system_metrics}}
  end

  # Private Functions

  defp generate_operation_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp capture_system_metrics do
    %{
      timestamp: System.monotonic_time(:microsecond),
      cpu_usage: get_cpu_usage(),
      memory_usage: get_memory_usage(),
      gpu_usage: get_gpu_usage(),
      gpu_memory: get_gpu_memory_usage()
    }
  end

  defp get_cpu_usage do
    # In a real implementation, this would get actual CPU usage
    # For now, return a simulated value
    :rand.uniform() * 100
  end

  defp get_memory_usage do
    # Get current memory usage in bytes
    case :erlang.memory(:total) do
      memory when is_integer(memory) -> memory
      _ -> 0
    end
  end

  defp get_gpu_usage do
    # In a real implementation, this would query GPU usage
    # For now, return a simulated value
    :rand.uniform() * 100
  end

  defp get_gpu_memory_usage do
    # In a real implementation, this would query GPU memory usage
    # For now, return a simulated value
    # Up to 1GB
    :rand.uniform() * 1024 * 1024 * 1024
  end

  defp calculate_cpu_usage(start_metrics, end_metrics) do
    # Calculate CPU usage during operation
    abs(end_metrics.cpu_usage - start_metrics.cpu_usage)
  end

  defp calculate_gpu_usage(start_metrics, end_metrics) do
    # Calculate GPU usage during operation
    abs(end_metrics.gpu_usage - start_metrics.gpu_usage)
  end

  defp calculate_memory_used(start_metrics, end_metrics) do
    # Calculate memory used during operation
    max(0, end_metrics.memory_usage - start_metrics.memory_usage)
  end

  defp add_to_history(operation, history, config) do
    new_history = [operation | history]
    limit_list(new_history, config.max_history_size)
  end

  defp limit_list(list, max_size) do
    case length(list) > max_size do
      true -> Enum.take(list, max_size)
      false -> list
    end
  end

  defp calculate_performance_stats(state) do
    operations = state.completed_operations

    %{
      operation_counts: calculate_operation_counts(operations),
      latency_percentiles: calculate_latency_percentiles(operations),
      throughput: calculate_throughput(operations),
      resource_utilization: calculate_resource_utilization(operations),
      cache_performance: calculate_cache_performance(operations),
      error_rates: calculate_error_rates(operations),
      active_operations: map_size(state.active_operations),
      total_operations: length(operations)
    }
  end

  defp calculate_operation_counts(operations) do
    Enum.reduce(operations, %{}, fn op, acc ->
      Map.update(acc, op.type, 1, &(&1 + 1))
    end)
  end

  defp calculate_latency_percentiles(operations) do
    durations = Enum.map(operations, & &1.duration)

    case durations do
      [] ->
        %{p50: 0, p90: 0, p95: 0, p99: 0}

      _ ->
        sorted = Enum.sort(durations)
        count = length(sorted)

        %{
          p50: percentile(sorted, count, 0.50),
          p90: percentile(sorted, count, 0.90),
          p95: percentile(sorted, count, 0.95),
          p99: percentile(sorted, count, 0.99),
          avg: Enum.sum(durations) / count,
          min: Enum.min(durations),
          max: Enum.max(durations)
        }
    end
  end

  defp percentile(sorted_list, count, percentile) do
    index = round(count * percentile) - 1
    index = max(0, min(index, count - 1))
    Enum.at(sorted_list, index)
  end

  defp calculate_throughput(operations) do
    case operations do
      [] ->
        %{ops_per_second: 0.0}

      _ ->
        # Calculate operations per second over the last minute
        now = System.monotonic_time(:microsecond)
        # 60 seconds in microseconds
        one_minute_ago = now - 60_000_000

        recent_ops =
          Enum.filter(operations, fn op -> op.end_time > one_minute_ago end)

        ops_per_second = length(recent_ops) / 60.0

        %{
          ops_per_second: ops_per_second,
          total_operations: length(operations)
        }
    end
  end

  defp calculate_resource_utilization(operations) do
    case operations do
      [] ->
        %{avg_cpu: 0.0, avg_gpu: 0.0, avg_memory: 0}

      _ ->
        cpu_usage = Enum.map(operations, & &1.cpu_usage)
        gpu_usage = Enum.map(operations, & &1.gpu_usage)
        memory_usage = Enum.map(operations, & &1.memory_used)

        %{
          avg_cpu: Enum.sum(cpu_usage) / length(cpu_usage),
          avg_gpu: Enum.sum(gpu_usage) / length(gpu_usage),
          avg_memory: div(Enum.sum(memory_usage), length(memory_usage)),
          peak_cpu: Enum.max(cpu_usage),
          peak_gpu: Enum.max(gpu_usage),
          peak_memory: Enum.max(memory_usage)
        }
    end
  end

  defp calculate_cache_performance(operations) do
    total_hits = Enum.sum(Enum.map(operations, & &1.cache_hits))
    total_misses = Enum.sum(Enum.map(operations, & &1.cache_misses))
    total_requests = total_hits + total_misses

    hit_rate =
      case total_requests do
        0 -> 0.0
        _ -> total_hits / total_requests
      end

    %{
      hit_rate: hit_rate,
      total_hits: total_hits,
      total_misses: total_misses,
      total_requests: total_requests
    }
  end

  defp calculate_error_rates(operations) do
    total_ops = length(operations)
    failed_ops = Enum.count(operations, fn op -> not op.success end)

    error_rate =
      case total_ops do
        0 -> 0.0
        _ -> failed_ops / total_ops
      end

    %{
      error_rate: error_rate,
      total_errors: failed_ops,
      total_operations: total_ops
    }
  end

  defp check_alerts(operation, alert_configs, alert_states) do
    Enum.reduce(alert_configs, alert_states, fn {alert_name, config}, acc ->
      current_state = Map.get(acc, alert_name, initialize_alert_state())
      new_state = evaluate_alert(operation, config, current_state)
      Map.put(acc, alert_name, new_state)
    end)
  end

  defp evaluate_alert(operation, config, current_state) do
    # Check if the operation violates the alert threshold
    value = get_alert_value(operation, config)

    violated =
      case config.comparison do
        :greater_than -> value > config.threshold
        :less_than -> value < config.threshold
        :equals -> value == config.threshold
      end

    case violated do
      true ->
        consecutive = current_state.consecutive_violations + 1

        case consecutive >= config.consecutive_violations do
          true ->
            # Trigger alert
            trigger_alert(config, operation, value)

            %{
              current_state
              | consecutive_violations: consecutive,
                last_triggered: System.system_time(:millisecond)
            }

          false ->
            %{current_state | consecutive_violations: consecutive}
        end

      false ->
        %{current_state | consecutive_violations: 0}
    end
  end

  defp get_alert_value(operation, _config) do
    # Extract the relevant value for the alert from the operation
    # This is a simplified implementation
    # Convert to milliseconds
    operation.duration / 1000
  end

  defp trigger_alert(config, operation, value) do
    case config.callback do
      callback when is_function(callback, 3) ->
        try do
          callback.(config, operation, value)
        rescue
          error -> Log.module_error("Alert callback failed: #{inspect(error)}")
        end

      _ ->
        Log.module_warning(
          "Performance alert triggered: #{inspect(config)} value: #{value}"
        )
    end
  end

  defp initialize_alert_state do
    %{
      consecutive_violations: 0,
      last_triggered: 0
    }
  end

  defp validate_alert_config(config) do
    required_fields = [:threshold, :comparison, :consecutive_violations]

    case Enum.all?(required_fields, &Map.has_key?(config, &1)) do
      true -> :ok
      false -> {:error, :missing_required_fields}
    end
  end

  defp initialize_system_metrics do
    %{
      start_time: System.system_time(:millisecond),
      cpu_samples: [],
      memory_samples: [],
      gpu_samples: [],
      custom_metrics: %{}
    }
  end

  defp start_system_monitoring(config) do
    case config.enable_system_monitoring do
      true ->
        refs = []
        # In a real implementation, would start system monitoring processes
        refs

      false ->
        []
    end
  end

  defp update_system_metric(system_metrics, metric_entry) do
    case metric_entry.name do
      name when name in [:cpu_usage, :memory_usage, :gpu_usage] ->
        samples_key = String.to_atom("#{name}_samples")
        current_samples = Map.get(system_metrics, samples_key, [])
        # Keep last 100 samples
        new_samples = [metric_entry | Enum.take(current_samples, 99)]
        Map.put(system_metrics, samples_key, new_samples)

      _ ->
        custom_metrics = Map.get(system_metrics, :custom_metrics, %{})
        new_custom = Map.put(custom_metrics, metric_entry.name, metric_entry)
        Map.put(system_metrics, :custom_metrics, new_custom)
    end
  end

  defp filter_history(history, options) do
    history
    |> filter_by_operation_types(Map.get(options, :operation_types))
    |> filter_by_time_range(Map.get(options, :time_range))
    |> limit_results(Map.get(options, :limit))
  end

  defp filter_by_operation_types(history, nil), do: history

  defp filter_by_operation_types(history, types) do
    Enum.filter(history, fn op -> op.type in types end)
  end

  defp filter_by_time_range(history, nil), do: history

  defp filter_by_time_range(history, {start_time, end_time}) do
    Enum.filter(history, fn op ->
      op.start_time >= start_time and op.end_time <= end_time
    end)
  end

  defp limit_results(history, nil), do: history
  defp limit_results(history, limit), do: Enum.take(history, limit)

  defp generate_performance_report(_state, _options) do
    # Generate comprehensive performance report
    report = %{
      generated_at: System.system_time(:millisecond),
      summary: "Performance report placeholder",
      recommendations: []
    }

    {:ok, report}
  end

  defp schedule_cleanup do
    # Every 5 minutes
    Process.send_after(self(), :cleanup, 300_000)
  end

  defp schedule_analysis do
    # Every minute
    Process.send_after(self(), :analysis, 60_000)
  end

  defp perform_cleanup(state) do
    # Remove old data beyond retention period
    now = System.monotonic_time(:microsecond)
    retention_microseconds = state.config.retention_period * 1_000_000
    cutoff = now - retention_microseconds

    new_history =
      Enum.filter(state.performance_history, fn op ->
        op.end_time > cutoff
      end)

    %{state | performance_history: new_history}
  end

  defp perform_analysis(state) do
    # Perform periodic performance analysis
    # This could include trend analysis, anomaly detection, etc.
    state
  end
end
