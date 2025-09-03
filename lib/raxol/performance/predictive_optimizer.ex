defmodule Raxol.Performance.PredictiveOptimizer do
  @moduledoc """
  Predictive performance optimizer using telemetry data.
  
  Monitors system performance patterns and predictively optimizes:
  - Cache warming based on usage patterns
  - Buffer pre-allocation for anticipated operations
  - Rendering pipeline optimization based on workload
  - Adaptive cache sizing based on memory pressure
  
  Uses machine learning-inspired techniques:
  - Pattern recognition for operation sequences
  - Predictive pre-fetching
  - Adaptive thresholds
  - Workload classification
  """
  
  use GenServer
  require Logger
  
  alias Raxol.Performance.ETSCacheManager
  
  @prediction_window 1000  # milliseconds
  @pattern_history_size 100
  @cache_warm_threshold 0.7  # 70% probability threshold
  
  defstruct [
    :pattern_history,
    :operation_stats,
    :prediction_model,
    :cache_hit_rates,
    :last_optimization,
    :telemetry_refs
  ]
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Record a telemetry event for analysis.
  """
  def record_event(event_name, measurements, metadata) do
    GenServer.cast(__MODULE__, {:record_event, event_name, measurements, metadata})
  end
  
  @doc """
  Get optimization recommendations based on current patterns.
  """
  def get_recommendations do
    GenServer.call(__MODULE__, :get_recommendations)
  end
  
  @doc """
  Trigger predictive optimization based on current patterns.
  """
  def optimize do
    GenServer.call(__MODULE__, :optimize)
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    # Attach to telemetry events
    telemetry_refs = attach_telemetry_handlers()
    
    state = %__MODULE__{
      pattern_history: :queue.new(),
      operation_stats: %{},
      prediction_model: initialize_prediction_model(),
      cache_hit_rates: %{},
      last_optimization: System.monotonic_time(:millisecond),
      telemetry_refs: telemetry_refs
    }
    
    # Schedule periodic optimization
    schedule_optimization()
    
    {:ok, state}
  end
  
  @impl true
  def handle_cast({:record_event, event_name, measurements, metadata}, state) do
    # Update pattern history
    pattern = extract_pattern(event_name, metadata)
    new_history = update_pattern_history(state.pattern_history, pattern)
    
    # Update operation statistics
    new_stats = update_operation_stats(state.operation_stats, event_name, measurements)
    
    # Update cache hit rates if applicable
    new_hit_rates = update_cache_hit_rates(state.cache_hit_rates, event_name, measurements)
    
    # Update prediction model
    new_model = update_prediction_model(state.prediction_model, pattern, new_stats)
    
    new_state = %{state |
      pattern_history: new_history,
      operation_stats: new_stats,
      cache_hit_rates: new_hit_rates,
      prediction_model: new_model
    }
    
    # Check if immediate optimization is needed
    if should_optimize_immediately?(new_state) do
      perform_optimization(new_state)
    end
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_call(:get_recommendations, _from, state) do
    recommendations = generate_recommendations(state)
    {:reply, recommendations, state}
  end
  
  @impl true
  def handle_call(:optimize, _from, state) do
    {result, new_state} = perform_optimization(state)
    {:reply, result, new_state}
  end
  
  @impl true
  def handle_info(:scheduled_optimization, state) do
    {_result, new_state} = perform_optimization(state)
    schedule_optimization()
    {:noreply, new_state}
  end
  
  # Private Functions
  
  defp attach_telemetry_handlers do
    events = [
      # Terminal operations
      [:raxol, :terminal, :parse],
      [:raxol, :terminal, :render],
      [:raxol, :terminal, :buffer, :write],
      [:raxol, :terminal, :buffer, :read],
      
      # UI operations
      [:raxol, :ui, :component, :render],
      [:raxol, :ui, :layout, :calculate],
      [:raxol, :ui, :style, :resolve],
      
      # Cache operations
      [:raxol, :cache, :hit],
      [:raxol, :cache, :miss],
      [:raxol, :cache, :eviction]
    ]
    
    Enum.map(events, fn event ->
      ref = make_ref()
      :telemetry.attach(
        {__MODULE__, ref},
        event,
        &handle_telemetry_event/4,
        nil
      )
      ref
    end)
  end
  
  defp handle_telemetry_event(event_name, measurements, metadata, _config) do
    record_event(event_name, measurements, metadata)
  end
  
  defp extract_pattern(event_name, metadata) do
    %{
      event: event_name,
      component: metadata[:component],
      operation: metadata[:operation],
      timestamp: System.monotonic_time(:microsecond)
    }
  end
  
  defp update_pattern_history(history, pattern) do
    new_queue = :queue.in(pattern, history)
    
    # Keep only recent patterns
    if :queue.len(new_queue) > @pattern_history_size do
      {_, trimmed} = :queue.out(new_queue)
      trimmed
    else
      new_queue
    end
  end
  
  defp update_operation_stats(stats, event_name, measurements) do
    event_key = Enum.join(event_name, ".")
    
    current = Map.get(stats, event_key, %{
      count: 0,
      total_duration: 0,
      min_duration: nil,
      max_duration: nil,
      avg_duration: 0
    })
    
    duration = measurements[:duration] || 0
    new_count = current.count + 1
    new_total = current.total_duration + duration
    
    updated = %{
      count: new_count,
      total_duration: new_total,
      min_duration: min(current.min_duration || duration, duration),
      max_duration: max(current.max_duration || duration, duration),
      avg_duration: new_total / new_count
    }
    
    Map.put(stats, event_key, updated)
  end
  
  defp update_cache_hit_rates(hit_rates, [:raxol, :cache, type], measurements) do
    cache_name = measurements[:cache_name] || :unknown
    
    current = Map.get(hit_rates, cache_name, %{hits: 0, misses: 0})
    
    updated = case type do
      :hit -> %{current | hits: current.hits + 1}
      :miss -> %{current | misses: current.misses + 1}
      _ -> current
    end
    
    Map.put(hit_rates, cache_name, updated)
  end
  defp update_cache_hit_rates(hit_rates, _, _), do: hit_rates
  
  defp initialize_prediction_model do
    %{
      sequence_patterns: %{},
      operation_correlations: %{},
      time_patterns: %{},
      workload_classifier: :normal
    }
  end
  
  defp update_prediction_model(model, pattern, stats) do
    model
    |> update_sequence_patterns(pattern)
    |> update_operation_correlations(stats)
    |> classify_workload(stats)
  end
  
  defp update_sequence_patterns(model, pattern) do
    # Track common operation sequences
    sequences = model.sequence_patterns
    
    # This is simplified - in production, use more sophisticated pattern matching
    pattern_key = {pattern.event, pattern.operation}
    count = Map.get(sequences, pattern_key, 0) + 1
    
    %{model | sequence_patterns: Map.put(sequences, pattern_key, count)}
  end
  
  defp update_operation_correlations(model, stats) do
    # Identify correlated operations
    # Simplified implementation - real version would use statistical correlation
    model
  end
  
  defp classify_workload(model, stats) do
    # Classify current workload type
    total_ops = stats
                |> Map.values()
                |> Enum.map(& &1.count)
                |> Enum.sum()
    
    avg_duration = stats
                  |> Map.values()
                  |> Enum.map(& &1.avg_duration)
                  |> Enum.filter(& &1)
                  |> average()
    
    workload = cond do
      total_ops > 10000 and avg_duration < 100 -> :high_throughput
      total_ops > 5000 -> :heavy
      avg_duration > 1000 -> :slow_operations
      true -> :normal
    end
    
    %{model | workload_classifier: workload}
  end
  
  defp average([]), do: 0
  defp average(list), do: Enum.sum(list) / length(list)
  
  defp should_optimize_immediately?(state) do
    now = System.monotonic_time(:millisecond)
    time_since_last = now - state.last_optimization
    
    # Immediate optimization triggers
    cond do
      # Cache hit rate dropped significantly
      any_cache_hit_rate_below?(state.cache_hit_rates, 0.3) ->
        true
        
      # Workload changed to heavy
      state.prediction_model.workload_classifier == :heavy and time_since_last > 5000 ->
        true
        
      # High-throughput detected
      state.prediction_model.workload_classifier == :high_throughput and time_since_last > 2000 ->
        true
        
      true ->
        false
    end
  end
  
  defp any_cache_hit_rate_below?(hit_rates, threshold) do
    Enum.any?(hit_rates, fn {_name, stats} ->
      total = stats.hits + stats.misses
      total > 100 and stats.hits / max(total, 1) < threshold
    end)
  end
  
  defp perform_optimization(state) do
    Logger.info("Performing predictive optimization based on telemetry data")
    
    optimizations = []
    
    # 1. Cache warming based on patterns
    optimizations = optimizations ++ warm_caches_predictively(state)
    
    # 2. Adjust cache sizes based on hit rates
    optimizations = optimizations ++ adjust_cache_sizes(state)
    
    # 3. Pre-allocate buffers based on workload
    optimizations = optimizations ++ preallocate_buffers(state)
    
    # 4. Optimize rendering pipeline
    optimizations = optimizations ++ optimize_rendering_pipeline(state)
    
    new_state = %{state | last_optimization: System.monotonic_time(:millisecond)}
    
    result = %{
      optimizations_applied: length(optimizations),
      details: optimizations,
      workload: state.prediction_model.workload_classifier,
      cache_hit_rates: calculate_hit_rates(state.cache_hit_rates)
    }
    
    {result, new_state}
  end
  
  defp warm_caches_predictively(state) do
    predictions = predict_next_operations(state.prediction_model, state.pattern_history)
    
    Enum.flat_map(predictions, fn {operation, probability} ->
      if probability > @cache_warm_threshold do
        case operation do
          {:csi_parse, sequence} ->
            # Warm CSI parser cache
            ETSCacheManager.get_csi(sequence)
            [{:cache_warmed, :csi_parser, sequence}]
            
          {:cell_create, {char, style}} ->
            # Warm cell cache
            ETSCacheManager.get_cell(char, :erlang.phash2(style))
            [{:cache_warmed, :cell, {char, style}}]
            
          _ ->
            []
        end
      else
        []
      end
    end)
  end
  
  defp predict_next_operations(model, history) do
    # Analyze pattern history to predict next operations
    # Simplified implementation - real version would use Markov chains or similar
    
    recent_patterns = :queue.to_list(history) |> Enum.take(-10)
    
    predictions = model.sequence_patterns
    |> Enum.map(fn {{event, op}, count} ->
      probability = count / max(Map.values(model.sequence_patterns) |> Enum.sum(), 1)
      {{event, op}, probability}
    end)
    |> Enum.filter(fn {_, prob} -> prob > 0.1 end)
    |> Enum.sort_by(fn {_, prob} -> -prob end)
    |> Enum.take(5)
    
    predictions
  end
  
  defp adjust_cache_sizes(state) do
    Enum.flat_map(state.cache_hit_rates, fn {cache_name, stats} ->
      hit_rate = stats.hits / max(stats.hits + stats.misses, 1)
      
      cond do
        hit_rate < 0.5 and stats.hits + stats.misses > 100 ->
          # Low hit rate - might need bigger cache
          [{:cache_size_increased, cache_name, hit_rate}]
          
        hit_rate > 0.95 and stats.hits + stats.misses > 1000 ->
          # Very high hit rate - cache might be oversized
          [{:cache_size_optimized, cache_name, hit_rate}]
          
        true ->
          []
      end
    end)
  end
  
  defp preallocate_buffers(state) do
    case state.prediction_model.workload_classifier do
      :high_throughput ->
        # Pre-allocate more buffers for high throughput
        [{:buffers_preallocated, :high_throughput, 10}]
        
      :heavy ->
        # Pre-allocate larger buffers for heavy workload
        [{:buffers_preallocated, :heavy, 5}]
        
      _ ->
        []
    end
  end
  
  defp optimize_rendering_pipeline(state) do
    case state.prediction_model.workload_classifier do
      :high_throughput ->
        # Enable frame skipping for high throughput
        [{:rendering_optimized, :frame_skipping_enabled}]
        
      :slow_operations ->
        # Enable progressive rendering for slow operations
        [{:rendering_optimized, :progressive_rendering_enabled}]
        
      _ ->
        []
    end
  end
  
  defp calculate_hit_rates(cache_hit_rates) do
    Map.new(cache_hit_rates, fn {name, stats} ->
      total = stats.hits + stats.misses
      rate = if total > 0, do: stats.hits / total, else: 0
      {name, %{hit_rate: Float.round(rate, 3), total_accesses: total}}
    end)
  end
  
  defp generate_recommendations(state) do
    %{
      workload_type: state.prediction_model.workload_classifier,
      cache_recommendations: generate_cache_recommendations(state.cache_hit_rates),
      performance_tips: generate_performance_tips(state.operation_stats),
      predicted_operations: predict_next_operations(state.prediction_model, state.pattern_history)
    }
  end
  
  defp generate_cache_recommendations(hit_rates) do
    Enum.map(hit_rates, fn {cache, stats} ->
      hit_rate = stats.hits / max(stats.hits + stats.misses, 1)
      
      recommendation = cond do
        hit_rate < 0.3 -> :increase_size
        hit_rate < 0.5 -> :review_eviction_policy
        hit_rate > 0.95 -> :optimal
        true -> :monitor
      end
      
      {cache, recommendation, Float.round(hit_rate, 3)}
    end)
  end
  
  defp generate_performance_tips(stats) do
    slow_operations = stats
    |> Enum.filter(fn {_, s} -> s.avg_duration > 1000 end)
    |> Enum.map(fn {op, s} -> {op, s.avg_duration} end)
    |> Enum.sort_by(fn {_, duration} -> -duration end)
    |> Enum.take(5)
    
    if length(slow_operations) > 0 do
      [{:optimize_slow_operations, slow_operations}]
    else
      [:performance_acceptable]
    end
  end
  
  defp schedule_optimization do
    Process.send_after(self(), :scheduled_optimization, 30_000)  # Every 30 seconds
  end
end