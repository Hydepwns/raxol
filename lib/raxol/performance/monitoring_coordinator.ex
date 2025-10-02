defmodule Raxol.Performance.MonitoringCoordinator do
  @moduledoc """
  Central coordinator for automated performance monitoring in Raxol.

  This module orchestrates all performance monitoring components:
  - AutomatedMonitor for continuous metrics collection
  - AlertManager for intelligent alerting
  - AdaptiveOptimizer for automatic performance improvements
  - TelemetryInstrumentation for data collection
  - Performance regression detection and baseline management

  The coordinator ensures all components work together seamlessly and provides
  a unified interface for starting/stopping monitoring across the system.
  """

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Performance.AutomatedMonitor
  alias Raxol.Performance.AlertManager
  alias Raxol.Performance.AdaptiveOptimizer
  alias Raxol.Core.Runtime.Log

  defstruct [
    :monitoring_config,
    :component_status,
    :baseline_data,
    :regression_detector,
    :auto_optimization_enabled,
    :monitoring_enabled
  ]

  ## Client API

  @doc """
  Start comprehensive performance monitoring with all components.
  """
  def start_monitoring(config \\ []) do
    GenServer.call(__MODULE__, {:start_monitoring, config}, 30_000)
  end

  @doc """
  Stop all performance monitoring components.
  """
  def stop_monitoring do
    GenServer.call(__MODULE__, :stop_monitoring)
  end

  @doc """
  Get comprehensive monitoring status across all components.
  """
  def get_monitoring_status do
    GenServer.call(__MODULE__, :get_monitoring_status)
  end

  @doc """
  Enable or disable automatic optimization based on performance data.
  """
  def set_auto_optimization(enabled) do
    GenServer.call(__MODULE__, {:set_auto_optimization, enabled})
  end

  @doc """
  Manually trigger performance optimization across all components.
  """
  def optimize_performance do
    GenServer.call(__MODULE__, :optimize_performance, 60_000)
  end

  @doc """
  Update monitoring configuration for all components.
  """
  def update_config(new_config) do
    GenServer.call(__MODULE__, {:update_config, new_config})
  end

  @doc """
  Get comprehensive performance dashboard data.
  """
  def get_dashboard_data do
    GenServer.call(__MODULE__, :get_dashboard_data, 10_000)
  end

  @doc """
  Perform comprehensive regression analysis across all metrics.
  """
  def analyze_regressions(time_range \\ :last_hour) do
    GenServer.call(__MODULE__, {:analyze_regressions, time_range}, 30_000)
  end

  ## BaseManager Implementation

  @impl true
  def init_manager(opts) do
    config = build_monitoring_config(opts)

    state = %__MODULE__{
      monitoring_config: config,
      component_status: %{
        automated_monitor: :stopped,
        alert_manager: :stopped,
        adaptive_optimizer: :stopped
      },
      baseline_data: %{},
      regression_detector: initialize_regression_detector(),
      auto_optimization_enabled: Keyword.get(opts, :auto_optimization, true),
      monitoring_enabled: false
    }

    # Start AlertManager (always available)
    {:ok, _} = AlertManager.start_link(config.alert_manager)

    Log.module_info("Performance MonitoringCoordinator initialized", %{
      auto_optimization: state.auto_optimization_enabled,
      config: config
    })

    {:ok, state}
  end

  @impl true
  def handle_manager_call({:start_monitoring, user_config}, _from, state) do
    case state.monitoring_enabled do
      true ->
        {:reply, {:already_running, get_current_status(state)}, state}

      false ->
        config = merge_user_config(state.monitoring_config, user_config)

        case start_all_components(config) do
          {:ok, component_statuses} ->
            # Collect initial baseline
            baseline = collect_initial_baseline()

            new_state = %{
              state
              | monitoring_enabled: true,
                component_status: component_statuses,
                baseline_data: baseline,
                monitoring_config: config
            }

            Log.module_info("Comprehensive performance monitoring started", %{
              components: Map.keys(component_statuses),
              baseline_metrics: Map.keys(baseline)
            })

            {:reply, :ok, new_state}

          {:error, reason} ->
            Log.module_error("Failed to start performance monitoring", %{
              reason: reason
            })

            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_manager_call(:stop_monitoring, _from, state) do
    case stop_all_components() do
      :ok ->
        new_state = %{
          state
          | monitoring_enabled: false,
            component_status: %{
              automated_monitor: :stopped,
              # AlertManager stays running
              alert_manager: :running,
              adaptive_optimizer: :stopped
            }
        }

        Log.module_info("Performance monitoring stopped")
        {:reply, :ok, new_state}

      {:error, reason} ->
        Log.module_error("Failed to stop performance monitoring", %{
          reason: reason
        })

        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call(:get_monitoring_status, _from, state) do
    status = get_comprehensive_status(state)
    {:reply, status, state}
  end

  @impl true
  def handle_manager_call({:set_auto_optimization, enabled}, _from, state) do
    new_state = %{state | auto_optimization_enabled: enabled}

    if enabled and state.monitoring_enabled do
      # Configure automatic optimization triggers
      configure_optimization_triggers()
    end

    Log.module_info(
      "Auto-optimization #{if enabled, do: "enabled", else: "disabled"}"
    )

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_call(:optimize_performance, _from, state) do
    case perform_comprehensive_optimization(state) do
      {:ok, optimization_results} ->
        Log.module_info("Manual performance optimization completed", %{
          results: optimization_results
        })

        {:reply, {:ok, optimization_results}, state}

      {:error, reason} ->
        Log.module_error("Performance optimization failed", %{reason: reason})
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call({:update_config, new_config}, _from, state) do
    merged_config = merge_user_config(state.monitoring_config, new_config)

    # Update running components with new config
    update_results =
      update_component_configs(merged_config, state.component_status)

    new_state = %{state | monitoring_config: merged_config}

    Log.module_info("Monitoring configuration updated", %{
      components_updated: Map.keys(update_results)
    })

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_call(:get_dashboard_data, _from, state) do
    dashboard_data = collect_dashboard_data(state)
    {:reply, dashboard_data, state}
  end

  @impl true
  def handle_manager_call({:analyze_regressions, time_range}, _from, state) do
    case perform_regression_analysis(time_range, state) do
      {:ok, analysis} ->
        # Store regression data for trend analysis
        updated_detector =
          update_regression_data(state.regression_detector, analysis)

        new_state = %{state | regression_detector: updated_detector}

        {:reply, {:ok, analysis}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  ## Private Implementation

  defp build_monitoring_config(opts) do
    %{
      automated_monitor: %{
        thresholds: Keyword.get(opts, :thresholds, %{}),
        collection_interval: Keyword.get(opts, :collection_interval, 30_000),
        health_check_interval: Keyword.get(opts, :health_check_interval, 60_000)
      },
      alert_manager: %{
        channels: Keyword.get(opts, :alert_channels, %{}),
        escalation_rules: Keyword.get(opts, :escalation_rules, %{}),
        rate_limits: Keyword.get(opts, :rate_limits, %{})
      },
      adaptive_optimizer: %{
        optimization_interval:
          Keyword.get(opts, :optimization_interval, 300_000),
        auto_trigger: Keyword.get(opts, :auto_optimization, true)
      },
      regression_detection: %{
        # 1 hour
        baseline_window: Keyword.get(opts, :baseline_window, 3600_000),
        # 15%
        regression_threshold: Keyword.get(opts, :regression_threshold, 0.15),
        confidence_level: Keyword.get(opts, :confidence_level, 0.95)
      }
    }
  end

  defp merge_user_config(base_config, user_config) do
    # Deep merge user config with base config
    DeepMerge.deep_merge(base_config, user_config)
  end

  defp start_all_components(config) do
    results = %{}

    # Start AutomatedMonitor
    monitor_result =
      case AutomatedMonitor.start_monitoring(config.automated_monitor) do
        :ok -> {:ok, :running}
        {:already_running, _} -> {:ok, :running}
        error -> error
      end

    results = Map.put(results, :automated_monitor, monitor_result)

    # AlertManager is already running
    results = Map.put(results, :alert_manager, {:ok, :running})

    # Start AdaptiveOptimizer if auto-optimization is enabled
    optimizer_result =
      if config.adaptive_optimizer.auto_trigger do
        case AdaptiveOptimizer.start_link(config.adaptive_optimizer) do
          {:ok, _} -> {:ok, :running}
          {:error, {:already_started, _}} -> {:ok, :running}
          error -> error
        end
      else
        {:ok, :disabled}
      end

    results = Map.put(results, :adaptive_optimizer, optimizer_result)

    # Check if all components started successfully
    case Enum.all?(results, fn {_component, result} ->
           match?({:ok, _}, result)
         end) do
      true ->
        status_map =
          Enum.into(results, %{}, fn {component, {:ok, status}} ->
            {component, status}
          end)

        {:ok, status_map}

      false ->
        failed_components =
          Enum.filter(results, fn {_component, result} ->
            not match?({:ok, _}, result)
          end)

        {:error, {:component_start_failed, failed_components}}
    end
  end

  defp stop_all_components do
    results = []

    # Stop AutomatedMonitor
    monitor_result =
      case AutomatedMonitor.stop_monitoring() do
        :ok -> :ok
        error -> error
      end

    results = [monitor_result | results]

    # Stop AdaptiveOptimizer (if running)
    optimizer_result =
      case GenServer.stop(AdaptiveOptimizer, :normal, 5000) do
        :ok -> :ok
        # Already stopped
        {:error, :noproc} -> :ok
        error -> error
      end

    results = [optimizer_result | results]

    # Check if all stops were successful
    case Enum.all?(results, &(&1 == :ok)) do
      true -> :ok
      false -> {:error, :component_stop_failed}
    end
  end

  defp collect_initial_baseline do
    # Wait a moment for components to start collecting data
    :timer.sleep(5000)

    case AutomatedMonitor.get_status() do
      %{current_metrics: metrics} when map_size(metrics) > 0 ->
        metrics

      _ ->
        %{}
    end
  end

  defp get_current_status(state) do
    %{
      monitoring_enabled: state.monitoring_enabled,
      components: state.component_status,
      auto_optimization: state.auto_optimization_enabled
    }
  end

  defp get_comprehensive_status(state) do
    base_status = get_current_status(state)

    # Add detailed component status
    detailed_status = %{
      automated_monitor: get_automated_monitor_status(),
      alert_manager: get_alert_manager_status(),
      adaptive_optimizer: get_adaptive_optimizer_status()
    }

    Map.put(base_status, :component_details, detailed_status)
  end

  defp get_automated_monitor_status do
    case AutomatedMonitor.get_status() do
      status when is_map(status) -> status
      _ -> %{status: :unavailable}
    end
  end

  defp get_alert_manager_status do
    case AlertManager.get_alert_stats() do
      stats when is_map(stats) -> stats
      _ -> %{status: :unavailable}
    end
  end

  defp get_adaptive_optimizer_status do
    case AdaptiveOptimizer.get_optimization_status() do
      status when is_map(status) -> status
      _ -> %{status: :unavailable}
    end
  end

  defp configure_optimization_triggers do
    # Configure telemetry handlers for automatic optimization triggers
    events = [
      [:raxol, :performance, :regression_detected],
      [:raxol, :performance, :threshold_exceeded],
      [:raxol, :performance, :memory_pressure]
    ]

    Enum.each(events, fn event ->
      :telemetry.attach(
        "auto_optimization_#{Enum.join(event, "_")}",
        event,
        &handle_optimization_trigger/4,
        %{}
      )
    end)
  end

  defp handle_optimization_trigger(event, measurements, metadata, _config) do
    Log.module_info("Automatic optimization triggered", %{
      event: event,
      measurements: measurements,
      metadata: metadata
    })

    # Trigger optimization asynchronously
    Task.start(fn ->
      case AdaptiveOptimizer.optimize_now() do
        {:ok, _} ->
          Log.module_info("Automatic optimization completed successfully")

        {:error, reason} ->
          Log.module_error("Automatic optimization failed", %{reason: reason})
      end
    end)
  end

  defp perform_comprehensive_optimization(_state) do
    optimization_tasks = [
      {:adaptive_optimizer, fn -> AdaptiveOptimizer.optimize_now() end},
      {:memory_optimization, fn -> perform_memory_optimization() end},
      {:cache_optimization, fn -> perform_cache_optimization() end}
    ]

    results =
      Enum.map(optimization_tasks, fn {task_name, task_func} ->
        try do
          result = task_func.()
          {task_name, result}
        rescue
          error ->
            {task_name, {:error, error}}
        end
      end)

    successful_optimizations =
      Enum.filter(results, fn {_name, result} ->
        match?({:ok, _}, result)
      end)

    case length(successful_optimizations) do
      0 -> {:error, :all_optimizations_failed}
      _ -> {:ok, results}
    end
  end

  defp perform_memory_optimization do
    # Trigger garbage collection and memory cleanup
    :erlang.garbage_collect()
    {:ok, :memory_cleaned}
  end

  defp perform_cache_optimization do
    # Clear old cache entries and optimize cache sizes
    # This would integrate with existing cache systems
    {:ok, :caches_optimized}
  end

  defp update_component_configs(new_config, component_status) do
    updates = %{}

    # Update AutomatedMonitor config
    updates =
      if component_status.automated_monitor == :running do
        monitor_update =
          AutomatedMonitor.update_thresholds(
            new_config.automated_monitor.thresholds
          )

        Map.put(updates, :automated_monitor, monitor_update)
      else
        updates
      end

    # Update AlertManager config
    updates =
      if component_status.alert_manager == :running do
        alert_update =
          AlertManager.configure_channels(new_config.alert_manager.channels)

        Map.put(updates, :alert_manager, alert_update)
      else
        updates
      end

    updates
  end

  defp collect_dashboard_data(state) do
    %{
      monitoring_status: get_comprehensive_status(state),
      current_metrics: get_automated_monitor_status(),
      alert_summary: get_alert_manager_status(),
      optimization_status: get_adaptive_optimizer_status(),
      baseline_comparison: compare_with_baseline(state),
      system_health: assess_system_health(),
      regression_trends: analyze_regression_trends(state.regression_detector)
    }
  end

  defp compare_with_baseline(state) do
    case {state.baseline_data, get_automated_monitor_status()} do
      {baseline, %{current_metrics: current}} when map_size(baseline) > 0 ->
        calculate_baseline_deltas(baseline, current)

      _ ->
        %{status: :insufficient_data}
    end
  end

  defp calculate_baseline_deltas(baseline, current) do
    %{
      render_performance_delta:
        calculate_percentage_change(
          baseline.render_performance.avg_ms,
          current.render_performance.avg_ms
        ),
      memory_usage_delta:
        calculate_percentage_change(
          baseline.memory_usage.total_mb,
          current.memory_usage.total_mb
        ),
      parse_performance_delta:
        calculate_percentage_change(
          baseline.parse_performance.avg_us,
          current.parse_performance.avg_us
        )
    }
  end

  defp calculate_percentage_change(baseline, current) do
    (current - baseline) / baseline * 100
  end

  defp assess_system_health do
    memory_info = :erlang.memory()
    process_count = :erlang.system_info(:process_count)
    process_limit = :erlang.system_info(:process_limit)

    %{
      memory_usage_percent:
        memory_info[:total] / (memory_info[:total] + memory_info[:system]) * 100,
      process_usage_percent: process_count / process_limit * 100,
      schedulers_online: :erlang.system_info(:schedulers_online),
      uptime_ms: :erlang.statistics(:wall_clock) |> elem(0)
    }
  end

  defp initialize_regression_detector do
    %{
      # 1 hour
      baseline_window_ms: 3600_000,
      # 15%
      regression_threshold: 0.15,
      confidence_level: 0.95,
      historical_data: [],
      trend_analysis: %{}
    }
  end

  defp perform_regression_analysis(time_range, state) do
    case AutomatedMonitor.check_regressions() do
      {:ok, regressions} ->
        enhanced_analysis =
          enhance_regression_analysis(regressions, time_range, state)

        {:ok, enhanced_analysis}

      error ->
        error
    end
  end

  defp enhance_regression_analysis(regressions, _time_range, state) do
    %{
      detected_regressions: regressions,
      regression_count: length(regressions),
      severity_distribution: calculate_severity_distribution(regressions),
      trend_analysis: analyze_regression_trends(state.regression_detector),
      recommended_actions: generate_regression_recommendations(regressions),
      confidence_score:
        calculate_regression_confidence(regressions, state.regression_detector)
    }
  end

  defp calculate_severity_distribution(regressions) do
    regressions
    |> Enum.group_by(fn regression ->
      cond do
        regression.regression_percent > 50 -> :critical
        regression.regression_percent > 25 -> :high
        regression.regression_percent > 15 -> :medium
        true -> :low
      end
    end)
    |> Enum.into(%{}, fn {severity, group} -> {severity, length(group)} end)
  end

  defp analyze_regression_trends(detector) do
    # Analyze historical regression data for patterns
    %{
      frequent_regression_types: get_frequent_regression_types(detector),
      regression_frequency: calculate_regression_frequency(detector),
      seasonal_patterns: detect_seasonal_patterns(detector)
    }
  end

  defp get_frequent_regression_types(detector) do
    detector.historical_data
    |> Enum.group_by(& &1.type)
    |> Enum.map(fn {type, instances} -> {type, length(instances)} end)
    |> Enum.sort_by(fn {_type, count} -> count end, :desc)
    |> Enum.take(3)
  end

  defp calculate_regression_frequency(detector) do
    case detector.historical_data do
      [] ->
        0

      data ->
        time_span = List.last(data).timestamp - List.first(data).timestamp
        # regressions per day
        length(data) / (time_span / 86_400_000)
    end
  end

  defp detect_seasonal_patterns(_detector) do
    # Placeholder for seasonal pattern detection
    %{
      patterns_detected: false,
      analysis: "Insufficient data for pattern detection"
    }
  end

  defp generate_regression_recommendations(regressions) do
    regressions
    |> Enum.map(fn regression ->
      case regression.type do
        :render_performance ->
          "Consider optimizing render pipeline or reducing component complexity"

        :parse_performance ->
          "Review ANSI parsing efficiency or increase buffer sizes"

        :memory_usage ->
          "Investigate memory leaks or enable more aggressive garbage collection"

        _ ->
          "General performance review recommended"
      end
    end)
    |> Enum.uniq()
  end

  defp calculate_regression_confidence(regressions, detector) do
    # Calculate confidence based on data quality and consistency
    base_confidence = detector.confidence_level

    # Adjust based on data consistency
    case length(regressions) do
      0 -> 1.0
      # Too many regressions might indicate noise
      count when count > 5 -> base_confidence * 0.8
      _ -> base_confidence
    end
  end

  defp update_regression_data(detector, analysis) do
    new_data_point = %{
      timestamp: System.system_time(:millisecond),
      regressions: analysis.detected_regressions,
      regression_count: analysis.regression_count
    }

    updated_history =
      [new_data_point | detector.historical_data]
      # Keep last 100 data points
      |> Enum.take(100)

    %{detector | historical_data: updated_history}
  end
end
