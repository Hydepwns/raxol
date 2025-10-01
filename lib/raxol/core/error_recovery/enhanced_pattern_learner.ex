defmodule Raxol.Core.ErrorRecovery.EnhancedPatternLearner do
  @moduledoc """
  Enhanced error pattern learning specifically for recovery scenarios.

  This module extends the existing ErrorPatternLearner with recovery-specific
  features like success rate tracking for different recovery strategies,
  integration with the recovery supervisor, and adaptive strategy selection.

  ## Features

  - Recovery strategy success rate tracking
  - Context-aware pattern analysis
  - Integration with RecoverySupervisor
  - Adaptive strategy recommendation
  - Performance impact correlation

  ## Usage

      # Record a recovery attempt
      EnhancedPatternLearner.record_recovery_attempt(
        error_signature,
        :circuit_break,
        :success,
        %{recovery_time_ms: 2500}
      )

      # Get recommended recovery strategy
      strategy = EnhancedPatternLearner.recommend_recovery_strategy(
        error_signature,
        %{restart_count: 3, performance_impact: :high}
      )
  """

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Core.Runtime.Log
  alias Raxol.Core.ErrorPatternLearner

  @recovery_strategies [
    :immediate_restart,
    :delayed_restart,
    :circuit_break,
    :graceful_degradation,
    :dependency_restart,
    :escalate
  ]

  @table_name :raxol_recovery_patterns
  @learning_storage "/tmp/raxol_recovery_learning"

  defstruct [
    :strategy_success_rates,
    :recovery_patterns,
    :performance_correlations,
    :context_strategies,
    :adaptive_thresholds,
    :learning_enabled
  ]

  @type recovery_strategy :: atom()
  @type recovery_outcome :: :success | :failure | :partial_success
  @type recovery_context :: map()

  @type recovery_pattern :: %{
          error_signature: String.t(),
          strategy: recovery_strategy(),
          success_rate: float(),
          avg_recovery_time_ms: float(),
          performance_impact: atom(),
          context_correlations: map(),
          last_updated: DateTime.t()
        }

  # Public API

  @doc """
  Record a recovery attempt and its outcome.
  """
  def record_recovery_attempt(
        error_signature,
        strategy,
        outcome,
        context
      ) do
    GenServer.cast(__MODULE__, {
      :record_recovery_attempt,
      error_signature,
      strategy,
      outcome,
      context,
      DateTime.utc_now()
    })
  end

  @doc """
  Get the recommended recovery strategy for an error.
  """
  def recommend_recovery_strategy(error_signature, context) do
    GenServer.call(
      __MODULE__,
      {:recommend_recovery_strategy, error_signature, context}
    )
  end

  @doc """
  Get success rates for all recovery strategies for a given error.
  """
  def get_strategy_success_rates(error_signature) do
    GenServer.call(__MODULE__, {:get_strategy_success_rates, error_signature})
  end

  @doc """
  Get recovery patterns that correlate with performance issues.
  """
  def get_performance_impact_patterns do
    GenServer.call(__MODULE__, :get_performance_impact_patterns)
  end

  @doc """
  Update adaptive thresholds based on system performance.
  """
  def update_adaptive_thresholds(performance_metrics) do
    GenServer.cast(
      __MODULE__,
      {:update_adaptive_thresholds, performance_metrics}
    )
  end

  @doc """
  Get learning statistics for recovery patterns.
  """
  def get_recovery_learning_stats do
    GenServer.call(__MODULE__, :get_recovery_learning_stats)
  end

  @doc """
  Export recovery learning data.
  """
  def export_recovery_data(format) do
    GenServer.call(__MODULE__, {:export_recovery_data, format})
  end

  # GenServer implementation

  @impl true
  def init_manager(opts) do
    # Create ETS table for fast pattern lookups
    :ets.new(@table_name, [
      :named_table,
      :public,
      :set,
      {:read_concurrency, true}
    ])

    # Ensure storage directory exists
    File.mkdir_p!(@learning_storage)

    # Load existing patterns
    initial_state = load_recovery_patterns()

    Log.module_info("Enhanced pattern learner started for recovery scenarios")

    {:ok, initial_state}
  end

  @impl true
  def handle_manager_cast(
        {
          :record_recovery_attempt,
          error_signature,
          strategy,
          outcome,
          context,
          timestamp
        },
        state
      ) do
    # Update strategy success rates
    updated_rates =
      update_strategy_success_rate(
        state.strategy_success_rates,
        error_signature,
        strategy,
        outcome
      )

    # Update recovery patterns
    updated_patterns =
      update_recovery_pattern(
        state.recovery_patterns,
        error_signature,
        strategy,
        outcome,
        context,
        timestamp
      )

    # Update performance correlations
    updated_correlations =
      update_performance_correlations(
        state.performance_correlations,
        error_signature,
        strategy,
        outcome,
        context
      )

    # Update context strategies
    updated_context_strategies =
      update_context_strategies(
        state.context_strategies,
        error_signature,
        strategy,
        outcome,
        context
      )

    # Store in ETS for fast access
    store_pattern_in_ets(error_signature, strategy, outcome, context)

    new_state = %{
      state
      | strategy_success_rates: updated_rates,
        recovery_patterns: updated_patterns,
        performance_correlations: updated_correlations,
        context_strategies: updated_context_strategies
    }

    # Persist periodically
    maybe_persist_learning_data(new_state)

    {:noreply, new_state}
  end

  @impl true
  def handle_manager_cast(
        {:update_adaptive_thresholds, performance_metrics},
        state
      ) do
    updated_thresholds =
      calculate_adaptive_thresholds(
        state.adaptive_thresholds,
        performance_metrics
      )

    new_state = %{state | adaptive_thresholds: updated_thresholds}

    {:noreply, new_state}
  end

  @impl true
  def handle_manager_call(
        {:recommend_recovery_strategy, error_signature, context},
        _from,
        state
      ) do
    strategy =
      recommend_strategy_based_on_learning(state, error_signature, context)

    {:reply, strategy, state}
  end

  @impl true
  def handle_manager_call(
        {:get_strategy_success_rates, error_signature},
        _from,
        state
      ) do
    rates = Map.get(state.strategy_success_rates, error_signature, %{})

    {:reply, rates, state}
  end

  @impl true
  def handle_manager_call(:get_performance_impact_patterns, _from, state) do
    patterns = extract_performance_impact_patterns(state)

    {:reply, patterns, state}
  end

  @impl true
  def handle_manager_call(:get_recovery_learning_stats, _from, state) do
    stats = %{
      total_patterns: map_size(state.recovery_patterns),
      strategies_tracked: length(@recovery_strategies),
      performance_correlations: map_size(state.performance_correlations),
      context_strategies: map_size(state.context_strategies),
      adaptive_thresholds: state.adaptive_thresholds,
      learning_enabled: state.learning_enabled
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_manager_call({:export_recovery_data, format}, _from, state) do
    exported_data = export_learning_data(state, format)

    {:reply, exported_data, state}
  end

  # Private implementation

  defp load_recovery_patterns do
    patterns_file = Path.join(@learning_storage, "recovery_patterns.json")

    recovery_patterns =
      if File.exists?(patterns_file) do
        case File.read!(patterns_file) |> Jason.decode() do
          {:ok, data} -> parse_stored_recovery_patterns(data)
          _ -> %{}
        end
      else
        %{}
      end

    %__MODULE__{
      strategy_success_rates: %{},
      recovery_patterns: recovery_patterns,
      performance_correlations: %{},
      context_strategies: %{},
      adaptive_thresholds: initialize_adaptive_thresholds(),
      learning_enabled: true
    }
  end

  defp update_strategy_success_rate(rates, error_signature, strategy, outcome) do
    key = {error_signature, strategy}
    current_rate = Map.get(rates, key, 0.5)

    new_rate =
      case outcome do
        :success -> min(0.95, current_rate + 0.1)
        :partial_success -> current_rate + 0.05
        :failure -> max(0.05, current_rate - 0.1)
      end

    Map.put(rates, key, new_rate)
  end

  defp update_recovery_pattern(
         patterns,
         error_signature,
         strategy,
         outcome,
         context,
         timestamp
       ) do
    key = {error_signature, strategy}

    pattern =
      Map.get(patterns, key, %{
        error_signature: error_signature,
        strategy: strategy,
        success_rate: 0.5,
        avg_recovery_time_ms: 0.0,
        performance_impact: :unknown,
        context_correlations: %{},
        last_updated: timestamp
      })

    # Update success rate
    success_value =
      case outcome do
        :success -> 1.0
        :partial_success -> 0.5
        :failure -> 0.0
      end

    new_success_rate = pattern.success_rate * 0.9 + success_value * 0.1

    # Update recovery time if provided
    recovery_time = Map.get(context, :recovery_time_ms, 0)

    new_avg_time =
      if recovery_time > 0 do
        pattern.avg_recovery_time_ms * 0.9 + recovery_time * 0.1
      else
        pattern.avg_recovery_time_ms
      end

    # Update performance impact
    performance_impact = determine_performance_impact(context)

    # Update context correlations
    updated_correlations =
      update_context_correlations(
        pattern.context_correlations,
        context,
        outcome
      )

    updated_pattern = %{
      pattern
      | success_rate: new_success_rate,
        avg_recovery_time_ms: new_avg_time,
        performance_impact: performance_impact,
        context_correlations: updated_correlations,
        last_updated: timestamp
    }

    Map.put(patterns, key, updated_pattern)
  end

  defp update_performance_correlations(
         correlations,
         error_signature,
         strategy,
         outcome,
         context
       ) do
    performance_impact = Map.get(context, :performance_impact, :unknown)

    if performance_impact != :unknown do
      key = {error_signature, performance_impact}
      strategies = Map.get(correlations, key, %{})

      updated_strategies =
        Map.update(strategies, strategy, [outcome], fn outcomes ->
          # Keep last 20 outcomes
          [outcome | outcomes] |> Enum.take(20)
        end)

      Map.put(correlations, key, updated_strategies)
    else
      correlations
    end
  end

  defp update_context_strategies(
         context_strategies,
         error_signature,
         strategy,
         outcome,
         context
       ) do
    # Extract relevant context features
    context_features = extract_context_features(context)

    Enum.reduce(context_features, context_strategies, fn {feature, value},
                                                         acc ->
      key = {error_signature, feature, value}
      strategy_outcomes = Map.get(acc, key, %{})

      updated_outcomes =
        Map.update(strategy_outcomes, strategy, [outcome], fn outcomes ->
          [outcome | outcomes] |> Enum.take(10)
        end)

      Map.put(acc, key, updated_outcomes)
    end)
  end

  defp store_pattern_in_ets(error_signature, strategy, outcome, context) do
    entry = %{
      error_signature: error_signature,
      strategy: strategy,
      outcome: outcome,
      context: context,
      timestamp: DateTime.utc_now()
    }

    :ets.insert(@table_name, {{error_signature, strategy}, entry})
  end

  defp recommend_strategy_based_on_learning(state, error_signature, context) do
    # Get success rates for this error signature
    strategy_rates =
      get_strategy_success_rates_for_error(state, error_signature)

    # Get context-specific recommendations
    context_recommendations =
      get_context_specific_recommendations(
        state,
        error_signature,
        context
      )

    # Get performance-aware recommendations
    performance_recommendations =
      get_performance_aware_recommendations(
        state,
        error_signature,
        context
      )

    # Combine all recommendations with weights
    combined_scores =
      combine_recommendation_scores(
        strategy_rates,
        context_recommendations,
        performance_recommendations,
        state.adaptive_thresholds
      )

    # Select best strategy
    select_best_strategy(combined_scores, context)
  end

  defp get_strategy_success_rates_for_error(state, error_signature) do
    @recovery_strategies
    |> Enum.map(fn strategy ->
      key = {error_signature, strategy}
      rate = Map.get(state.strategy_success_rates, key, 0.5)
      {strategy, rate}
    end)
    |> Map.new()
  end

  defp get_context_specific_recommendations(state, error_signature, context) do
    context_features = extract_context_features(context)

    Enum.reduce(context_features, %{}, fn {feature, value}, acc ->
      key = {error_signature, feature, value}

      case Map.get(state.context_strategies, key) do
        nil ->
          acc

        strategy_outcomes ->
          strategy_scores =
            calculate_strategy_scores_from_outcomes(strategy_outcomes)

          Map.merge(acc, strategy_scores, fn _k, v1, v2 -> (v1 + v2) / 2 end)
      end
    end)
  end

  defp get_performance_aware_recommendations(state, error_signature, context) do
    performance_impact = Map.get(context, :performance_impact, :unknown)

    case Map.get(
           state.performance_correlations,
           {error_signature, performance_impact}
         ) do
      nil ->
        %{}

      strategies ->
        calculate_strategy_scores_from_outcomes(strategies)
    end
  end

  defp combine_recommendation_scores(
         strategy_rates,
         context_recommendations,
         performance_recommendations,
         adaptive_thresholds
       ) do
    @recovery_strategies
    |> Enum.map(fn strategy ->
      base_score = Map.get(strategy_rates, strategy, 0.5)
      context_score = Map.get(context_recommendations, strategy, 0.5)
      performance_score = Map.get(performance_recommendations, strategy, 0.5)

      # Apply adaptive thresholds
      threshold_modifier = get_threshold_modifier(strategy, adaptive_thresholds)

      combined_score =
        (base_score * 0.4 + context_score * 0.3 + performance_score * 0.3) *
          threshold_modifier

      {strategy, combined_score}
    end)
    |> Map.new()
  end

  defp select_best_strategy(combined_scores, context) do
    # Get restart count to influence selection
    restart_count = Map.get(context, :restart_count, 0)
    performance_impact = Map.get(context, :performance_impact, :low)

    # Apply context-based filters
    filtered_strategies =
      filter_strategies_by_context(
        combined_scores,
        restart_count,
        performance_impact
      )

    # Select strategy with highest score
    case Enum.max_by(
           filtered_strategies,
           fn {_strategy, score} -> score end,
           fn -> nil end
         ) do
      {strategy, _score} -> strategy
      # Fallback
      nil -> :immediate_restart
    end
  end

  defp filter_strategies_by_context(scores, restart_count, performance_impact) do
    scores
    |> Enum.filter(fn {strategy, _score} ->
      case {strategy, restart_count, performance_impact} do
        # Don't use immediate restart if we've restarted many times
        {:immediate_restart, count, _} when count > 2 -> false
        # Prefer circuit breaking for high restart counts
        {:circuit_break, count, _} when count > 1 -> true
        # Use graceful degradation for high performance impact
        {:graceful_degradation, _, :high} -> true
        # General filtering
        _ -> true
      end
    end)
  end

  defp extract_context_features(context) do
    Map.take(context, [
      :restart_count,
      :performance_impact,
      :error_count,
      :dependency_failure,
      :system_load,
      :time_of_day
    ])
  end

  defp calculate_strategy_scores_from_outcomes(strategy_outcomes) do
    strategy_outcomes
    |> Enum.map(fn {strategy, outcomes} ->
      success_rate = calculate_success_rate_from_outcomes(outcomes)
      {strategy, success_rate}
    end)
    |> Map.new()
  end

  defp calculate_success_rate_from_outcomes(outcomes) do
    if length(outcomes) == 0 do
      0.5
    else
      success_count = Enum.count(outcomes, &(&1 == :success))
      partial_count = Enum.count(outcomes, &(&1 == :partial_success))

      (success_count + partial_count * 0.5) / length(outcomes)
    end
  end

  defp determine_performance_impact(context) do
    cond do
      Map.get(context, :recovery_time_ms, 0) > 5000 -> :high
      Map.get(context, :memory_impact_mb, 0) > 10 -> :high
      Map.get(context, :cpu_spike, false) -> :medium
      true -> :low
    end
  end

  defp update_context_correlations(correlations, context, outcome) do
    context_features = extract_context_features(context)

    Enum.reduce(context_features, correlations, fn {feature, value}, acc ->
      feature_outcomes = Map.get(acc, feature, %{})
      value_outcomes = Map.get(feature_outcomes, value, [])

      updated_outcomes = [outcome | value_outcomes] |> Enum.take(10)

      updated_feature_outcomes =
        Map.put(feature_outcomes, value, updated_outcomes)

      Map.put(acc, feature, updated_feature_outcomes)
    end)
  end

  defp initialize_adaptive_thresholds do
    %{
      immediate_restart: 1.0,
      delayed_restart: 1.0,
      circuit_break: 1.0,
      graceful_degradation: 1.0,
      dependency_restart: 1.0,
      escalate: 1.0
    }
  end

  defp calculate_adaptive_thresholds(current_thresholds, performance_metrics) do
    # Adjust thresholds based on current system performance
    performance_factor = calculate_performance_factor(performance_metrics)

    current_thresholds
    |> Enum.map(fn {strategy, threshold} ->
      adjusted_threshold =
        adjust_threshold_for_performance(
          strategy,
          threshold,
          performance_factor
        )

      {strategy, adjusted_threshold}
    end)
    |> Map.new()
  end

  defp calculate_performance_factor(metrics) do
    # Calculate overall performance factor (0.0 to 2.0)
    render_factor = if metrics[:render_avg_ms] > 20, do: 0.8, else: 1.2
    memory_factor = if metrics[:memory_mb] > 50, do: 0.9, else: 1.1
    error_factor = if metrics[:error_rate] > 2.0, do: 0.7, else: 1.3

    (render_factor + memory_factor + error_factor) / 3
  end

  defp adjust_threshold_for_performance(
         strategy,
         current_threshold,
         performance_factor
       ) do
    case strategy do
      # Favor less aggressive strategies when performance is poor
      :immediate_restart -> current_threshold * (performance_factor * 0.8)
      :circuit_break -> current_threshold * (performance_factor * 1.2)
      :graceful_degradation -> current_threshold * (performance_factor * 1.5)
      _ -> current_threshold * performance_factor
    end
    |> max(0.1)
    |> min(2.0)
  end

  defp get_threshold_modifier(strategy, thresholds) do
    Map.get(thresholds, strategy, 1.0)
  end

  defp extract_performance_impact_patterns(state) do
    state.performance_correlations
    |> Enum.group_by(fn {{_error_sig, impact}, _strategies} -> impact end)
    |> Enum.map(fn {impact, patterns} ->
      {impact, analyze_impact_patterns(patterns)}
    end)
    |> Map.new()
  end

  defp analyze_impact_patterns(patterns) do
    patterns
    |> Enum.flat_map(fn {_key, strategies} ->
      Enum.map(strategies, fn {strategy, outcomes} ->
        success_rate = calculate_success_rate_from_outcomes(outcomes)
        {strategy, success_rate}
      end)
    end)
    |> Enum.group_by(fn {strategy, _rate} -> strategy end)
    |> Enum.map(fn {strategy, rates} ->
      avg_rate =
        (rates |> Enum.map(fn {_s, r} -> r end) |> Enum.sum()) / length(rates)

      {strategy, avg_rate}
    end)
    |> Map.new()
  end

  defp export_learning_data(state, format) do
    data = %{
      strategy_success_rates: state.strategy_success_rates,
      recovery_patterns: state.recovery_patterns,
      performance_correlations: state.performance_correlations,
      context_strategies: state.context_strategies,
      adaptive_thresholds: state.adaptive_thresholds,
      export_timestamp: DateTime.utc_now()
    }

    case format do
      :json -> Jason.encode!(data, pretty: true)
      _ -> data
    end
  end

  defp parse_stored_recovery_patterns(data) do
    Map.get(data, "recovery_patterns", %{})
    |> Enum.map(fn {key, pattern_data} ->
      {key, parse_recovery_pattern_data(pattern_data)}
    end)
    |> Map.new()
  end

  defp parse_recovery_pattern_data(data) do
    %{
      error_signature: data["error_signature"],
      strategy: String.to_atom(data["strategy"]),
      success_rate: data["success_rate"] || 0.5,
      avg_recovery_time_ms: data["avg_recovery_time_ms"] || 0.0,
      performance_impact:
        String.to_atom(data["performance_impact"] || "unknown"),
      context_correlations: data["context_correlations"] || %{},
      last_updated: parse_datetime(data["last_updated"])
    }
  end

  defp parse_datetime(nil), do: DateTime.utc_now()

  defp parse_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, dt, _} -> dt
      _ -> DateTime.utc_now()
    end
  end

  defp parse_datetime(datetime), do: datetime

  defp maybe_persist_learning_data(state) do
    # Persist every 50th update to avoid too frequent I/O
    if :rand.uniform(50) == 1 do
      Task.start(fn -> persist_recovery_learning_data(state) end)
    end
  end

  defp persist_recovery_learning_data(state) do
    patterns_file = Path.join(@learning_storage, "recovery_patterns.json")

    data = %{
      recovery_patterns: state.recovery_patterns,
      strategy_success_rates: state.strategy_success_rates,
      performance_correlations: state.performance_correlations,
      context_strategies: state.context_strategies,
      adaptive_thresholds: state.adaptive_thresholds,
      last_updated: DateTime.utc_now()
    }

    case Jason.encode(data, pretty: true) do
      {:ok, json} ->
        File.write!(patterns_file, json)
        Log.module_debug("Recovery learning data persisted successfully")

      {:error, reason} ->
        Log.module_error("Failed to persist recovery learning data: #{reason}")
    end
  end
end
