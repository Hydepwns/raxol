defmodule Raxol.Core.ErrorPatternLearner do
  @moduledoc """
  Error Pattern Learning System - Phase 4.3 Error Experience

  Machine learning-inspired system that learns from error patterns to:
  - Predict likely errors before they occur
  - Improve fix suggestions based on success rates
  - Identify emerging error patterns in Phase 3 optimizations
  - Automatically update error templates with learned knowledge

  ## Features

  - Pattern recognition using frequency analysis
  - Success rate tracking for fix suggestions
  - Phase 3 optimization correlation analysis
  - Predictive error detection
  - Automatic template enhancement
  """

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Core.Runtime.Log
  @table_name :raxol_error_patterns
  @learning_storage "/tmp/raxol_pattern_learning"

  defstruct [
    :patterns,
    :suggestion_success_rates,
    :phase3_correlations,
    :prediction_models,
    :learning_enabled,
    :last_cleanup
  ]

  @type error_pattern :: %{
          signature: String.t(),
          frequency: integer(),
          contexts: [map()],
          successful_fixes: [String.t()],
          failure_modes: [String.t()],
          phase3_correlation: float(),
          prediction_confidence: float(),
          first_seen: DateTime.t(),
          last_seen: DateTime.t()
        }

  @type learning_state :: %__MODULE__{
          patterns: %{String.t() => error_pattern()},
          suggestion_success_rates: %{String.t() => float()},
          phase3_correlations: %{atom() => float()},
          prediction_models: map(),
          learning_enabled: boolean(),
          last_cleanup: DateTime.t()
        }

  # Public API

  @doc """
  Record a new error occurrence for learning.
  """
  def record_error(error, context \\ %{}) do
    GenServer.cast(
      __MODULE__,
      {:record_error, error, context, DateTime.utc_now()}
    )
  end

  @doc """
  Record the success or failure of a fix suggestion.
  """
  def record_fix_outcome(error_signature, fix_description, outcome)
      when outcome in [:success, :failure] do
    GenServer.cast(
      __MODULE__,
      {:record_fix_outcome, error_signature, fix_description, outcome}
    )
  end

  @doc """
  Get predictions for potential errors based on current context.
  """
  def predict_errors(context) do
    GenServer.call(__MODULE__, {:predict_errors, context})
  end

  @doc """
  Get enhanced suggestions based on learned patterns.
  """
  def enhance_suggestions(error, base_suggestions, context \\ %{}) do
    GenServer.call(
      __MODULE__,
      {:enhance_suggestions, error, base_suggestions, context}
    )
  end

  @doc """
  Get learning statistics and insights.
  """
  def get_learning_stats do
    GenServer.call(__MODULE__, :get_learning_stats)
  end

  @doc """
  Get the most common error patterns.
  """
  def get_common_patterns(limit \\ 10) do
    GenServer.call(__MODULE__, {:get_common_patterns, limit})
  end

  @doc """
  Get patterns correlated with Phase 3 optimizations.
  """
  def get_phase3_correlations do
    GenServer.call(__MODULE__, :get_phase3_correlations)
  end

  @doc """
  Export learned patterns for analysis or backup.
  """
  def export_patterns(format \\ :json) do
    GenServer.call(__MODULE__, {:export_patterns, format})
  end

  @doc """
  Import previously learned patterns.
  """
  def import_patterns(patterns_data) do
    GenServer.cast(__MODULE__, {:import_patterns, patterns_data})
  end

  # GenServer implementation

  @impl true
  def init_manager(_opts) do
    # Create ETS table for fast pattern lookups
    _ =
      :ets.new(@table_name, [
        :named_table,
        :public,
        :set,
        {:read_concurrency, true}
      ])

    # Ensure storage directory exists
    File.mkdir_p!(@learning_storage)

    # Load existing patterns
    initial_state = load_learned_patterns()

    # Schedule periodic cleanup and persistence
    schedule_cleanup()

    Log.info("Error pattern learning system started")

    {:ok, initial_state}
  end

  @impl true
  def handle_manager_cast({:record_error, error, context, timestamp}, state) do
    error_signature = generate_error_signature(error)

    # Update pattern in ETS for fast access
    update_pattern_ets(error_signature, error, context, timestamp)

    # Update state
    updated_patterns =
      update_pattern_frequency(
        state.patterns,
        error_signature,
        error,
        context,
        timestamp
      )

    updated_correlations =
      update_phase3_correlations(state.phase3_correlations, error, context)

    new_state = %{
      state
      | patterns: updated_patterns,
        phase3_correlations: updated_correlations
    }

    # Persist if significant change
    _ =
      if should_persist?(state, new_state) do
        persist_patterns_async(new_state)
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_manager_cast(
        {:record_fix_outcome, error_signature, fix_description, outcome},
        state
      ) do
    # Update suggestion success rates
    fix_key = "#{error_signature}:#{fix_description}"
    current_rate = Map.get(state.suggestion_success_rates, fix_key, 0.5)

    new_rate =
      case outcome do
        :success -> min(0.95, current_rate + 0.1)
        :failure -> max(0.05, current_rate - 0.1)
      end

    updated_rates = Map.put(state.suggestion_success_rates, fix_key, new_rate)

    # Update pattern with successful/failed fixes
    updated_patterns =
      update_pattern_fixes(
        state.patterns,
        error_signature,
        fix_description,
        outcome
      )

    new_state = %{
      state
      | suggestion_success_rates: updated_rates,
        patterns: updated_patterns
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_manager_cast({:import_patterns, patterns_data}, state) do
    imported_patterns = parse_imported_patterns(patterns_data)
    merged_patterns = Map.merge(state.patterns, imported_patterns)

    # Update ETS table
    Enum.each(merged_patterns, fn {signature, pattern} ->
      :ets.insert(@table_name, {signature, pattern})
    end)

    new_state = %{state | patterns: merged_patterns}

    Log.info("Imported #{map_size(imported_patterns)} error patterns")

    {:noreply, new_state}
  end

  @impl true
  def handle_manager_call({:predict_errors, context}, _from, state) do
    predictions = generate_predictions(state, context)
    {:reply, predictions, state}
  end

  @impl true
  def handle_manager_call(
        {:enhance_suggestions, error, base_suggestions, context},
        _from,
        state
      ) do
    enhanced =
      enhance_suggestions_with_learning(state, error, base_suggestions, context)

    {:reply, enhanced, state}
  end

  @impl true
  def handle_manager_call(:get_learning_stats, _from, state) do
    stats = %{
      total_patterns: map_size(state.patterns),
      total_error_occurrences: calculate_total_occurrences(state.patterns),
      top_patterns: get_top_patterns(state.patterns, 5),
      success_rates_tracked: map_size(state.suggestion_success_rates),
      phase3_correlations: state.phase3_correlations,
      learning_enabled: state.learning_enabled,
      last_cleanup: state.last_cleanup
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_manager_call({:get_common_patterns, limit}, _from, state) do
    common_patterns = get_top_patterns(state.patterns, limit)
    {:reply, common_patterns, state}
  end

  @impl true
  def handle_manager_call(:get_phase3_correlations, _from, state) do
    correlations = analyze_phase3_correlations(state)
    {:reply, correlations, state}
  end

  @impl true
  def handle_manager_call({:export_patterns, format}, _from, state) do
    exported_data = export_learning_data(state, format)
    {:reply, exported_data, state}
  end

  @impl true
  def handle_manager_info(:cleanup_and_persist, state) do
    # Cleanup old patterns
    cleaned_patterns = cleanup_old_patterns(state.patterns)

    # Persist current state
    persist_patterns(state)

    # Schedule next cleanup
    schedule_cleanup()

    new_state = %{
      state
      | patterns: cleaned_patterns,
        last_cleanup: DateTime.utc_now()
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_manager_info(_msg, state) do
    {:noreply, state}
  end

  # Private implementation

  defp load_learned_patterns do
    patterns_file = Path.join(@learning_storage, "patterns.json")

    patterns =
      if File.exists?(patterns_file) do
        case File.read!(patterns_file) |> Jason.decode() do
          {:ok, data} -> parse_stored_patterns(data)
          _ -> %{}
        end
      else
        %{}
      end

    %__MODULE__{
      patterns: patterns,
      suggestion_success_rates: %{},
      phase3_correlations: initialize_phase3_correlations(),
      prediction_models: %{},
      learning_enabled: true,
      last_cleanup: DateTime.utc_now()
    }
  end

  @spec generate_error_signature(any()) :: any()
  defp generate_error_signature(error) do
    error_text = inspect(error) |> String.downcase()

    # Extract key components for signature
    components =
      [
        extract_error_type(error_text),
        extract_module_path(error_text),
        extract_key_terms(error_text)
      ]
      |> Enum.filter(&(&1 != ""))
      |> Enum.join(":")

    # Generate hash for consistent signature
    :crypto.hash(:md5, components)
    |> Base.encode16(case: :lower)
    |> String.slice(0..15)
  end

  @spec extract_error_type(any()) :: any()
  defp extract_error_type(error_text) do
    cond do
      String.contains?(error_text, "timeout") -> "timeout"
      String.contains?(error_text, "memory") -> "memory"
      String.contains?(error_text, "parse") -> "parse"
      String.contains?(error_text, "render") -> "render"
      String.contains?(error_text, "component") -> "component"
      true -> "generic"
    end
  end

  @spec extract_module_path(any()) :: any()
  defp extract_module_path(error_text) do
    case Regex.run(~r/Raxol\.\w+(?:\.\w+)*/, error_text) do
      [module_path] -> module_path
      _ -> ""
    end
  end

  @spec extract_key_terms(any()) :: any()
  defp extract_key_terms(error_text) do
    # Extract significant terms for pattern matching
    error_text
    |> String.split()
    |> Enum.filter(&(String.length(&1) > 3))
    |> Enum.filter(&String.match?(&1, ~r/^[a-zA-Z_]+$/))
    |> Enum.take(3)
    |> Enum.join("_")
  end

  @spec update_pattern_ets(any(), any(), any(), any()) :: any()
  defp update_pattern_ets(signature, _error, context, timestamp) do
    pattern =
      case :ets.lookup(@table_name, signature) do
        [{^signature, existing_pattern}] ->
          %{
            existing_pattern
            | frequency: existing_pattern.frequency + 1,
              contexts: [context | existing_pattern.contexts] |> Enum.take(10),
              last_seen: timestamp
          }

        [] ->
          %{
            signature: signature,
            frequency: 1,
            contexts: [context],
            successful_fixes: [],
            failure_modes: [],
            phase3_correlation: 0.0,
            prediction_confidence: 0.5,
            first_seen: timestamp,
            last_seen: timestamp
          }
      end

    :ets.insert(@table_name, {signature, pattern})
  end

  @spec update_pattern_frequency(any(), any(), any(), any(), any()) :: any()
  defp update_pattern_frequency(patterns, signature, _error, context, timestamp) do
    pattern =
      Map.get(patterns, signature, %{
        signature: signature,
        frequency: 0,
        contexts: [],
        successful_fixes: [],
        failure_modes: [],
        phase3_correlation: 0.0,
        prediction_confidence: 0.5,
        first_seen: timestamp,
        last_seen: timestamp
      })

    updated_pattern = %{
      pattern
      | frequency: pattern.frequency + 1,
        contexts: [context | pattern.contexts] |> Enum.take(10),
        last_seen: timestamp
    }

    Map.put(patterns, signature, updated_pattern)
  end

  @spec update_phase3_correlations(any(), any(), any()) :: any()
  defp update_phase3_correlations(correlations, error, _context) do
    error_text = inspect(error) |> String.downcase()

    # Check for Phase 3 related terms
    phase3_terms = %{
      parser: ["parse", "ansi", "sequence", "3.3μs"],
      memory: ["memory", "allocation", "2.8mb", "buffer"],
      render: ["render", "batch", "damage", "frame"],
      optimization: ["optimization", "@raxol_optimized", "phase3"]
    }

    Enum.reduce(phase3_terms, correlations, fn {category, terms}, acc ->
      correlation_strength =
        Enum.count(terms, &String.contains?(error_text, &1)) / length(terms)

      current_correlation = Map.get(acc, category, 0.0)

      # Weighted average to smooth correlation over time
      new_correlation = current_correlation * 0.9 + correlation_strength * 0.1

      Map.put(acc, category, new_correlation)
    end)
  end

  @spec update_pattern_fixes(any(), any(), any(), any()) :: any()
  defp update_pattern_fixes(patterns, signature, fix_description, outcome) do
    case Map.get(patterns, signature) do
      nil ->
        patterns

      pattern ->
        updated_pattern =
          case outcome do
            :success ->
              %{
                pattern
                | successful_fixes: [fix_description | pattern.successful_fixes]
              }

            :failure ->
              %{
                pattern
                | failure_modes: [fix_description | pattern.failure_modes]
              }
          end

        Map.put(patterns, signature, updated_pattern)
    end
  end

  @spec generate_predictions(map(), any()) :: any()
  defp generate_predictions(state, context) do
    # Simple prediction based on context similarity and pattern frequency
    predictions =
      state.patterns
      |> Enum.filter(fn {_signature, pattern} ->
        pattern.frequency > 2 &&
          context_similarity(pattern.contexts, context) > 0.3
      end)
      |> Enum.map_join(fn {signature, pattern} ->
        confidence = calculate_prediction_confidence(pattern, context)

        %{
          signature: signature,
          predicted_error: pattern,
          confidence: confidence,
          prevention_suggestions: generate_prevention_suggestions(pattern)
        }
      end)
      |> Enum.sort_by(& &1.confidence, :desc)
      |> Enum.take(3)

    predictions
  end

  @spec context_similarity(any(), any()) :: any()
  defp context_similarity(pattern_contexts, current_context) do
    if pattern_contexts == [] do
      0.0
    else
      similarities =
        Enum.map(
          pattern_contexts,
          &calculate_context_overlap(&1, current_context)
        )

      Enum.sum(similarities) / length(similarities)
    end
  end

  @spec calculate_context_overlap(any(), any()) :: any()
  defp calculate_context_overlap(context1, context2) do
    common_keys =
      MapSet.intersection(
        MapSet.new(Map.keys(context1)),
        MapSet.new(Map.keys(context2))
      )

    if MapSet.size(common_keys) == 0 do
      0.0
    else
      matching_values =
        Enum.count(common_keys, fn key ->
          Map.get(context1, key) == Map.get(context2, key)
        end)

      matching_values / MapSet.size(common_keys)
    end
  end

  @spec calculate_prediction_confidence(any(), any()) :: any()
  defp calculate_prediction_confidence(pattern, context) do
    base_confidence = min(0.9, pattern.frequency / 10.0)
    context_boost = context_similarity(pattern.contexts, context) * 0.2

    min(0.95, base_confidence + context_boost)
  end

  @spec generate_prevention_suggestions(any()) :: any()
  defp generate_prevention_suggestions(pattern) do
    case pattern.successful_fixes do
      [] ->
        ["Monitor for similar error patterns"]

      fixes ->
        ["Consider preventive measures based on: #{Enum.join(fixes, ", ")}"]
    end
  end

  @spec enhance_suggestions_with_learning(map(), any(), any(), any()) :: any()
  defp enhance_suggestions_with_learning(
         state,
         error,
         base_suggestions,
         context
       ) do
    error_signature = generate_error_signature(error)

    # Get learned success rates for suggestions
    enhanced_suggestions =
      Enum.map(base_suggestions, fn suggestion ->
        fix_key = "#{error_signature}:#{suggestion.description}"

        learned_confidence =
          Map.get(
            state.suggestion_success_rates,
            fix_key,
            suggestion.confidence
          )

        # Combine original confidence with learned confidence
        final_confidence = (suggestion.confidence + learned_confidence) / 2.0

        %{suggestion | confidence: final_confidence}
      end)

    # Add learned suggestions from similar patterns
    learned_suggestions =
      get_learned_suggestions(state, error_signature, context)

    (enhanced_suggestions ++ learned_suggestions)
    |> Enum.uniq_by(& &1.description)
    |> Enum.sort_by(& &1.confidence, :desc)
  end

  @spec get_learned_suggestions(map(), any(), any()) :: any() | nil
  defp get_learned_suggestions(state, error_signature, context) do
    # Find patterns with similar signatures or contexts
    similar_patterns =
      state.patterns
      |> Enum.filter(fn {signature, pattern} ->
        signature != error_signature &&
          (String.jaro_distance(signature, error_signature) > 0.7 ||
             context_similarity(pattern.contexts, context) > 0.5)
      end)
      |> Enum.take(3)

    # Generate suggestions from successful fixes
    similar_patterns
    |> Enum.flat_map(fn {_signature, pattern} ->
      Enum.map(pattern.successful_fixes, fn fix ->
        %{
          type: :learned,
          description: "Learned suggestion: #{fix}",
          action: fix,
          confidence: 0.7,
          related_tools: [],
          phase3_context: %{
            source: "learned_pattern",
            frequency: pattern.frequency
          }
        }
      end)
    end)
    |> Enum.take(2)
  end

  defp initialize_phase3_correlations do
    %{
      parser: 0.0,
      memory: 0.0,
      render: 0.0,
      optimization: 0.0
    }
  end

  @spec analyze_phase3_correlations(map()) :: any()
  defp analyze_phase3_correlations(state) do
    %{
      correlations: state.phase3_correlations,
      insights: generate_correlation_insights(state.phase3_correlations),
      recommendations:
        generate_correlation_recommendations(state.phase3_correlations)
    }
  end

  @spec generate_correlation_insights(any()) :: any()
  defp generate_correlation_insights(correlations) do
    Enum.map(correlations, fn {category, strength} ->
      cond do
        strength > 0.7 ->
          "High correlation between errors and #{category} optimization"

        strength > 0.4 ->
          "Moderate correlation with #{category} components"

        strength > 0.2 ->
          "Some correlation detected with #{category}"

        true ->
          "Low correlation with #{category}"
      end
    end)
  end

  @spec generate_correlation_recommendations(any()) :: any()
  defp generate_correlation_recommendations(correlations) do
    correlations
    |> Enum.filter(fn {_category, strength} -> strength > 0.5 end)
    |> Enum.map(fn {category, _strength} ->
      case category do
        :parser ->
          "Review ANSI parser implementation for optimization opportunities"

        :memory ->
          "Check memory usage patterns against 2.8MB target"

        :render ->
          "Verify render batching and damage tracking are working correctly"

        :optimization ->
          "Ensure all components have proper @raxol_optimized attributes"
      end
    end)
  end

  @spec get_top_patterns(any(), any()) :: any() | nil
  defp get_top_patterns(patterns, limit) do
    patterns
    |> Enum.sort_by(fn {_signature, pattern} -> pattern.frequency end, :desc)
    |> Enum.take(limit)
    |> Enum.map(fn {signature, pattern} ->
      %{
        signature: signature,
        frequency: pattern.frequency,
        success_fixes: length(pattern.successful_fixes),
        failure_modes: length(pattern.failure_modes),
        phase3_correlation: pattern.phase3_correlation
      }
    end)
  end

  @spec calculate_total_occurrences(any()) :: any()
  defp calculate_total_occurrences(patterns) do
    patterns
    |> Enum.map(fn {_signature, pattern} -> pattern.frequency end)
    |> Enum.sum()
  end

  @spec cleanup_old_patterns(any()) :: any()
  defp cleanup_old_patterns(patterns) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -30, :day)

    Enum.filter(patterns, fn {_signature, pattern} ->
      DateTime.compare(pattern.last_seen, cutoff_date) == :gt
    end)
    |> Map.new()
  end

  @spec export_learning_data(map(), any()) :: any()
  defp export_learning_data(state, format) do
    data = %{
      patterns: state.patterns,
      suggestion_success_rates: state.suggestion_success_rates,
      phase3_correlations: state.phase3_correlations,
      export_timestamp: DateTime.utc_now()
    }

    case format do
      :json -> Jason.encode!(data, pretty: true)
      :csv -> export_to_csv(data)
      _ -> data
    end
  end

  @spec export_to_csv(any()) :: any()
  defp export_to_csv(data) do
    # Simple CSV export for patterns
    headers =
      "signature,frequency,successful_fixes,failure_modes,phase3_correlation\n"

    rows =
      data.patterns
      |> Enum.map_join("\n", fn {signature, pattern} ->
        "#{signature},#{pattern.frequency},#{length(pattern.successful_fixes)},#{length(pattern.failure_modes)},#{pattern.phase3_correlation}"
      end)

    headers <> rows
  end

  @spec parse_stored_patterns(any()) :: {:ok, any()} | {:error, any()}
  defp parse_stored_patterns(data) do
    # Convert stored data back to pattern structures
    Map.get(data, "patterns", %{})
    |> Enum.map(fn {signature, pattern_data} ->
      {signature, parse_pattern_data(pattern_data)}
    end)
    |> Map.new()
  end

  @spec parse_pattern_data(any()) :: {:ok, any()} | {:error, any()}
  defp parse_pattern_data(data) do
    %{
      signature: data["signature"],
      frequency: data["frequency"] || 0,
      contexts: data["contexts"] || [],
      successful_fixes: data["successful_fixes"] || [],
      failure_modes: data["failure_modes"] || [],
      phase3_correlation: data["phase3_correlation"] || 0.0,
      prediction_confidence: data["prediction_confidence"] || 0.5,
      first_seen: parse_datetime(data["first_seen"]),
      last_seen: parse_datetime(data["last_seen"])
    }
  end

  @spec parse_imported_patterns(any()) :: {:ok, any()} | {:error, any()}
  defp parse_imported_patterns(patterns_data) do
    case Jason.decode(patterns_data) do
      {:ok, data} -> parse_stored_patterns(data)
      _ -> %{}
    end
  end

  @spec parse_datetime(String.t()) :: {:ok, any()} | {:error, any()}
  defp parse_datetime(nil), do: DateTime.utc_now()

  @spec parse_datetime(String.t()) :: {:ok, any()} | {:error, any()}
  defp parse_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, dt, _} -> dt
      _ -> DateTime.utc_now()
    end
  end

  @spec parse_datetime(String.t()) :: {:ok, any()} | {:error, any()}
  defp parse_datetime(datetime), do: datetime

  @spec should_persist?(map(), map()) :: boolean()
  defp should_persist?(_old_state, _new_state) do
    # Simple heuristic - persist every 10th update
    :rand.uniform(10) == 1
  end

  @spec persist_patterns_async(map()) :: any()
  defp persist_patterns_async(state) do
    {:ok, _pid} = Task.start(fn -> persist_patterns(state) end)
    :ok
  end

  @spec persist_patterns(map()) :: any()
  defp persist_patterns(state) do
    patterns_file = Path.join(@learning_storage, "patterns.json")

    data = %{
      patterns: state.patterns,
      suggestion_success_rates: state.suggestion_success_rates,
      phase3_correlations: state.phase3_correlations,
      last_updated: DateTime.utc_now()
    }

    case Jason.encode(data, pretty: true) do
      {:ok, json} ->
        File.write!(patterns_file, json)
        Log.debug("Error patterns persisted successfully")

      {:error, reason} ->
        Log.error("Failed to persist error patterns: #{reason}")
    end
  end

  defp schedule_cleanup do
    # Schedule cleanup every hour
    Process.send_after(self(), :cleanup_and_persist, 60 * 60 * 1000)
  end
end
