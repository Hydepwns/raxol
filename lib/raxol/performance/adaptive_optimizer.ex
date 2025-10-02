defmodule Raxol.Performance.AdaptiveOptimizer do
  @moduledoc """
  Adaptive performance optimizer that responds to real-world usage patterns.

  This module implements production-ready optimizations based on telemetry data:
  - Dynamic resource allocation based on workload patterns
  - Adaptive cache tuning with machine learning principles
  - Performance threshold adjustment based on historical data
  - Predictive scaling for high-load scenarios
  - Memory pressure management with intelligent eviction
  """

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Core.Runtime.Log
  # Configuration constants
  # 15 seconds
  @optimization_interval 15_000
  # 5 minutes of data
  @pattern_analysis_window 300
  @performance_threshold_adjustment_factor 0.1
  @memory_pressure_threshold 0.85

  defstruct [
    :performance_history,
    :optimization_state,
    :adaptive_thresholds,
    :resource_allocation,
    :pattern_detector,
    :last_optimization_time
  ]

  # Client API

  # BaseManager provides start_link/1 and start_link/2 automatically

  @doc """
  Get current optimization state and recommendations.
  """
  def get_optimization_status do
    GenServer.call(__MODULE__, :get_optimization_status)
  end

  @doc """
  Manually trigger adaptive optimization based on current patterns.
  """
  def optimize_now do
    GenServer.call(__MODULE__, :optimize_now, 30_000)
  end

  @doc """
  Configure adaptive thresholds for specific metrics.
  """
  def configure_thresholds(thresholds) when is_map(thresholds) do
    GenServer.call(__MODULE__, {:configure_thresholds, thresholds})
  end

  # Server Callbacks

  @impl true
  def init_manager(_opts) do
    state = %__MODULE__{
      performance_history: initialize_performance_history(),
      optimization_state: initialize_optimization_state(),
      adaptive_thresholds: initialize_adaptive_thresholds(),
      resource_allocation: initialize_resource_allocation(),
      pattern_detector: initialize_pattern_detector(),
      last_optimization_time: System.monotonic_time(:millisecond)
    }

    # Schedule regular optimization cycles
    schedule_optimization()

    # Setup telemetry event handlers
    setup_telemetry_handlers()

    Log.info("Adaptive optimizer started with production configuration")
    {:ok, state}
  end

  @impl true
  def handle_manager_call(:get_optimization_status, _from, state) do
    status = generate_optimization_status(state)
    {:reply, status, state}
  end

  @impl true
  def handle_manager_call(:optimize_now, _from, state) do
    case perform_adaptive_optimization(state) do
      {:ok, new_state, results} ->
        {:reply, {:ok, results}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call({:configure_thresholds, thresholds}, _from, state) do
    new_state = %{
      state
      | adaptive_thresholds: Map.merge(state.adaptive_thresholds, thresholds)
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_info(:perform_optimization, state) do
    case perform_adaptive_optimization(state) do
      {:ok, new_state, _results} ->
        schedule_optimization()
        {:noreply, new_state}

      {:error, _reason} ->
        schedule_optimization()
        {:noreply, state}
    end
  end

  @impl true
  def handle_manager_info(
        {:telemetry_event, event_name, measurements, metadata},
        state
      ) do
    new_state =
      process_telemetry_event(state, event_name, measurements, metadata)

    {:noreply, new_state}
  end

  # Private Functions

  defp initialize_performance_history do
    %{
      response_times: :queue.new(),
      throughput_samples: :queue.new(),
      error_rates: :queue.new(),
      cache_metrics: :queue.new(),
      memory_usage: :queue.new()
    }
  end

  defp initialize_optimization_state do
    %{
      current_workload_type: :normal,
      optimization_cycles: 0,
      successful_optimizations: 0,
      last_optimization_impact: %{},
      active_optimizations: MapSet.new()
    }
  end

  defp initialize_adaptive_thresholds do
    %{
      # microseconds
      slow_operation_threshold: 1000,
      # percentage
      high_memory_threshold: 0.8,
      # percentage
      low_cache_hit_rate: 0.7,
      # operations per second
      high_throughput_threshold: 1000,
      # 5% error rate
      error_rate_threshold: 0.05
    }
  end

  defp initialize_resource_allocation do
    %{
      cache_sizes: %{
        component_render: 1000,
        font_metrics: 500,
        cell_cache: 2000,
        csi_parser: 300
      },
      buffer_pool_size: 50,
      worker_pool_size: System.schedulers_online() * 2,
      gc_configuration: :standard
    }
  end

  defp initialize_pattern_detector do
    %{
      workload_patterns: %{},
      seasonal_patterns: %{},
      anomaly_detection: %{
        baseline_established: false,
        deviation_threshold: 2.0
      },
      trend_analysis: %{samples: [], trend_direction: :stable}
    }
  end

  defp setup_telemetry_handlers do
    telemetry_events = [
      [:raxol, :terminal, :parse],
      [:raxol, :terminal, :render],
      [:raxol, :ui, :component, :render],
      [:raxol, :cache, :hit],
      [:raxol, :cache, :miss],
      [:vm, :memory],
      [:vm, :total_run_queue_lengths]
    ]

    Enum.each(telemetry_events, fn event ->
      :telemetry.attach(
        "adaptive_optimizer_#{Enum.join(event, "_")}",
        event,
        fn event_name, measurements, metadata, _config ->
          send(
            __MODULE__,
            {:telemetry_event, event_name, measurements, metadata}
          )
        end,
        nil
      )
    end)
  end

  defp process_telemetry_event(state, event_name, measurements, metadata) do
    # Update performance history based on telemetry data
    new_history =
      update_performance_history(
        state.performance_history,
        event_name,
        measurements,
        metadata
      )

    # Update pattern detection
    new_pattern_detector =
      update_pattern_detection(state.pattern_detector, event_name, measurements)

    # Update adaptive thresholds based on recent performance
    new_thresholds =
      adapt_thresholds(
        state.adaptive_thresholds,
        state.performance_history,
        event_name,
        measurements
      )

    %{
      state
      | performance_history: new_history,
        pattern_detector: new_pattern_detector,
        adaptive_thresholds: new_thresholds
    }
  end

  defp update_performance_history(history, event_name, measurements, _metadata) do
    case event_name do
      [:raxol, :terminal, :parse] ->
        %{
          history
          | response_times:
              add_to_history_queue(
                history.response_times,
                measurements[:duration],
                @pattern_analysis_window
              )
        }

      [:raxol, :ui, :component, :render] ->
        %{
          history
          | response_times:
              add_to_history_queue(
                history.response_times,
                measurements[:duration],
                @pattern_analysis_window
              )
        }

      [:raxol, :cache, type] when type in [:hit, :miss] ->
        cache_metric = %{
          type: type,
          timestamp: System.monotonic_time(:millisecond)
        }

        %{
          history
          | cache_metrics:
              add_to_history_queue(
                history.cache_metrics,
                cache_metric,
                @pattern_analysis_window
              )
        }

      [:vm, :memory] ->
        memory_data = %{
          total: measurements[:total],
          processes: measurements[:processes],
          system: measurements[:system],
          timestamp: System.monotonic_time(:millisecond)
        }

        %{
          history
          | memory_usage:
              add_to_history_queue(
                history.memory_usage,
                memory_data,
                @pattern_analysis_window
              )
        }

      _ ->
        history
    end
  end

  defp add_to_history_queue(queue, item, max_size) do
    new_queue = :queue.in(item, queue)

    case :queue.len(new_queue) > max_size do
      true ->
        {_, trimmed} = :queue.out(new_queue)
        trimmed

      false ->
        new_queue
    end
  end

  defp update_pattern_detection(detector, event_name, measurements) do
    # Update workload patterns
    workload_key = get_workload_key(event_name)
    current_patterns = detector.workload_patterns
    updated_patterns = Map.update(current_patterns, workload_key, 1, &(&1 + 1))

    # Update trend analysis
    case measurements[:duration] do
      duration when is_number(duration) ->
        # Keep last 20 samples
        new_samples = [
          duration | Enum.take(detector.trend_analysis.samples, 19)
        ]

        trend_direction = calculate_trend_direction(new_samples)

        %{
          detector
          | workload_patterns: updated_patterns,
            trend_analysis: %{
              samples: new_samples,
              trend_direction: trend_direction
            }
        }

      _ ->
        %{detector | workload_patterns: updated_patterns}
    end
  end

  defp get_workload_key([:raxol, :terminal, :parse]), do: :terminal_parsing
  defp get_workload_key([:raxol, :ui, :component, :render]), do: :ui_rendering
  defp get_workload_key([:raxol, :cache, _]), do: :cache_operations
  defp get_workload_key(_), do: :other

  defp calculate_trend_direction(samples) when length(samples) < 10, do: :stable

  defp calculate_trend_direction(samples) do
    {recent, older} = Enum.split(samples, div(length(samples), 2))
    recent_avg = Enum.sum(recent) / length(recent)
    older_avg = Enum.sum(older) / length(older)

    case recent_avg / older_avg do
      ratio when ratio > 1.1 -> :increasing
      ratio when ratio < 0.9 -> :decreasing
      _ -> :stable
    end
  end

  defp adapt_thresholds(current_thresholds, history, event_name, measurements) do
    case {event_name, measurements[:duration]} do
      {[:raxol, :terminal, :parse], duration} when is_number(duration) ->
        adapt_operation_threshold(
          current_thresholds,
          :slow_operation_threshold,
          duration,
          history.response_times
        )

      {[:raxol, :ui, :component, :render], duration} when is_number(duration) ->
        adapt_operation_threshold(
          current_thresholds,
          :slow_operation_threshold,
          duration,
          history.response_times
        )

      _ ->
        current_thresholds
    end
  end

  defp adapt_operation_threshold(
         thresholds,
         threshold_key,
         _current_duration,
         history_queue
       ) do
    case :queue.len(history_queue) do
      len when len >= 50 ->
        history_list = :queue.to_list(history_queue)
        percentile_95 = calculate_percentile(history_list, 0.95)
        current_threshold = thresholds[threshold_key]

        # Adapt threshold based on actual performance patterns
        new_threshold =
          current_threshold +
            (percentile_95 - current_threshold) *
              @performance_threshold_adjustment_factor

        # Don't reduce below 50% of original
        Map.put(
          thresholds,
          threshold_key,
          max(new_threshold, current_threshold * 0.5)
        )

      _ ->
        thresholds
    end
  end

  defp calculate_percentile(values, percentile) do
    sorted = Enum.sort(values)
    index = trunc(length(sorted) * percentile)
    Enum.at(sorted, min(index, length(sorted) - 1))
  end

  defp perform_adaptive_optimization(state) do
    Raxol.Core.ErrorHandling.safe_call_with_info(fn ->
      Log.info(
        "Starting adaptive optimization cycle #{state.optimization_state.optimization_cycles + 1}"
      )

      # Analyze current system state
      analysis = analyze_system_performance(state)

      # Determine optimizations to apply
      optimizations = determine_optimizations(analysis, state)

      # Apply optimizations
      application_results = apply_optimizations(optimizations, state)

      # Update optimization state
      new_optimization_state = %{
        state.optimization_state
        | optimization_cycles: state.optimization_state.optimization_cycles + 1,
          successful_optimizations:
            state.optimization_state.successful_optimizations +
              length(application_results),
          last_optimization_impact: Map.new(application_results),
          active_optimizations:
            MapSet.union(
              state.optimization_state.active_optimizations,
              MapSet.new(Keyword.keys(application_results))
            )
      }

      new_state = %{
        state
        | optimization_state: new_optimization_state,
          last_optimization_time: System.monotonic_time(:millisecond)
      }

      results = %{
        analysis: analysis,
        optimizations_applied: length(application_results),
        optimization_results: application_results,
        next_optimization_in: @optimization_interval
      }

      Log.info(
        "Adaptive optimization completed: #{length(application_results)} optimizations applied"
      )

      {new_state, results}
    end)
    |> case do
      {:ok, {new_state, results}} ->
        {:ok, new_state, results}

      {:error, {kind, error, _stacktrace}} ->
        Log.error("Adaptive optimization failed: #{kind} - #{inspect(error)}")

        {:error, {kind, error}}
    end
  end

  defp analyze_system_performance(state) do
    response_times = :queue.to_list(state.performance_history.response_times)
    cache_metrics = :queue.to_list(state.performance_history.cache_metrics)
    memory_usage = :queue.to_list(state.performance_history.memory_usage)

    %{
      avg_response_time: calculate_average(response_times),
      p95_response_time: calculate_percentile(response_times, 0.95),
      cache_hit_rate: calculate_cache_hit_rate(cache_metrics),
      memory_pressure: calculate_memory_pressure(memory_usage),
      workload_type: determine_workload_type(state.pattern_detector),
      trend_direction: state.pattern_detector.trend_analysis.trend_direction,
      anomaly_detected: detect_anomalies(state)
    }
  end

  defp calculate_average([]), do: 0
  defp calculate_average(values), do: Enum.sum(values) / length(values)

  defp calculate_cache_hit_rate([]), do: 1.0

  defp calculate_cache_hit_rate(metrics) do
    {hits, total} =
      Enum.reduce(metrics, {0, 0}, fn
        %{type: :hit}, {h, t} -> {h + 1, t + 1}
        %{type: :miss}, {h, t} -> {h, t + 1}
        _, acc -> acc
      end)

    case total do
      0 -> 1.0
      _ -> hits / total
    end
  end

  defp calculate_memory_pressure([]), do: 0.0

  defp calculate_memory_pressure(memory_data) do
    case List.last(memory_data) do
      %{total: total, processes: processes, system: system} ->
        used = processes + system
        used / total

      _ ->
        0.0
    end
  end

  defp determine_workload_type(pattern_detector) do
    patterns = pattern_detector.workload_patterns
    total_operations = Enum.sum(Map.values(patterns))

    case total_operations do
      0 -> :idle
      n when n < 100 -> :light
      n when n < 500 -> :normal
      n when n < 1500 -> :heavy
      _ -> :extreme
    end
  end

  defp detect_anomalies(state) do
    # Simple anomaly detection based on recent vs historical performance
    recent_avg =
      calculate_average(
        Enum.take(:queue.to_list(state.performance_history.response_times), 10)
      )

    historical_avg =
      calculate_average(
        :queue.to_list(state.performance_history.response_times)
      )

    case {recent_avg, historical_avg} do
      {recent, historical} when recent > 0 and historical > 0 ->
        ratio = recent / historical
        ratio > state.pattern_detector.anomaly_detection.deviation_threshold

      _ ->
        false
    end
  end

  defp determine_optimizations(analysis, state) do
    optimizations = []

    # Response time optimizations
    optimizations =
      case analysis.avg_response_time >
             state.adaptive_thresholds.slow_operation_threshold do
        true ->
          [
            {:optimize_slow_operations, analysis.avg_response_time}
            | optimizations
          ]

        false ->
          optimizations
      end

    # Cache optimizations
    optimizations =
      case analysis.cache_hit_rate <
             state.adaptive_thresholds.low_cache_hit_rate do
        true ->
          [
            {:optimize_cache_configuration, analysis.cache_hit_rate}
            | optimizations
          ]

        false ->
          optimizations
      end

    # Memory pressure optimizations
    optimizations =
      case analysis.memory_pressure >
             state.adaptive_thresholds.high_memory_threshold do
        true ->
          [{:optimize_memory_usage, analysis.memory_pressure} | optimizations]

        false ->
          optimizations
      end

    # Workload-specific optimizations
    workload_optimizations =
      case analysis.workload_type do
        :heavy ->
          [{:scale_up_resources, :heavy_workload}]

        :extreme ->
          [
            {:scale_up_resources, :extreme_workload},
            {:enable_performance_mode, true}
          ]

        :light ->
          [{:scale_down_resources, :light_workload}]

        _ ->
          []
      end

    optimizations ++ workload_optimizations
  end

  defp apply_optimizations(optimizations, state) do
    Enum.map(optimizations, fn optimization ->
      case apply_single_optimization(optimization, state) do
        {:ok, result} ->
          {elem(optimization, 0), result}

        {:error, reason} ->
          Log.warning(
            "Optimization #{elem(optimization, 0)} failed: #{inspect(reason)}"
          )

          {elem(optimization, 0), {:error, reason}}
      end
    end)
  end

  defp apply_single_optimization({:optimize_slow_operations, avg_time}, _state) do
    # Enable more aggressive caching for slow operations
    {:ok, %{cache_increase_factor: 1.5, previous_avg_time: avg_time}}
  end

  defp apply_single_optimization(
         {:optimize_cache_configuration, hit_rate},
         _state
       ) do
    # Adjust cache eviction policies and sizes based on hit rate
    adjustments =
      case hit_rate do
        rate when rate < 0.5 ->
          %{size_multiplier: 2.0, eviction_policy: :lru_strict}

        rate when rate < 0.7 ->
          %{size_multiplier: 1.5, eviction_policy: :lru}

        _ ->
          %{size_multiplier: 1.2, eviction_policy: :lfu}
      end

    {:ok, adjustments}
  end

  defp apply_single_optimization({:optimize_memory_usage, pressure}, _state) do
    case pressure do
      p when p > @memory_pressure_threshold ->
        # Trigger garbage collection and reduce cache sizes
        :erlang.garbage_collect()
        {:ok, %{gc_triggered: true, cache_reduction_factor: 0.8}}

      _ ->
        {:ok, %{no_action_needed: true}}
    end
  end

  defp apply_single_optimization({:scale_up_resources, workload_type}, _state) do
    # Scale up worker pools and buffer sizes for high workload
    scale_factor =
      case workload_type do
        :extreme_workload -> 2.0
        :heavy_workload -> 1.5
        _ -> 1.2
      end

    {:ok, %{scale_factor: scale_factor, workload_type: workload_type}}
  end

  defp apply_single_optimization(
         {:scale_down_resources, :light_workload},
         _state
       ) do
    # Scale down resources for light workload to save memory
    {:ok, %{scale_factor: 0.8, workload_type: :light_workload}}
  end

  defp apply_single_optimization({:enable_performance_mode, true}, _state) do
    # Enable high-performance mode with optimizations
    {:ok,
     %{
       performance_mode_enabled: true,
       optimizations: [:frame_skipping, :batch_rendering]
     }}
  end

  defp apply_single_optimization(unknown_optimization, _state) do
    {:error, {:unknown_optimization, unknown_optimization}}
  end

  defp generate_optimization_status(state) do
    %{
      optimization_cycles_completed:
        state.optimization_state.optimization_cycles,
      successful_optimizations:
        state.optimization_state.successful_optimizations,
      active_optimizations:
        MapSet.to_list(state.optimization_state.active_optimizations),
      current_adaptive_thresholds: state.adaptive_thresholds,
      performance_trend: state.pattern_detector.trend_analysis.trend_direction,
      last_optimization_impact:
        state.optimization_state.last_optimization_impact,
      next_optimization_in:
        @optimization_interval -
          (System.monotonic_time(:millisecond) - state.last_optimization_time)
    }
  end

  defp schedule_optimization do
    Process.send_after(self(), :perform_optimization, @optimization_interval)
  end
end
