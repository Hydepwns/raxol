defmodule Raxol.AI.PerformanceOptimization do
  import Raxol.Guards

  @moduledoc """
  Runtime AI features for intelligent performance optimization.

  This module provides AI-driven performance optimizations including:

  * Predictive rendering - Intelligently determine what needs to be rendered
  * Resource allocation - Dynamically allocate system resources based on usage patterns
  * Component caching - Smart caching of frequently used components
  * Prefetching - Predict and preload content likely to be needed soon
  * Adaptive throttling - Adjust refresh rates based on current activity
  * Runtime profiling - Continuously monitor and analyze performance patterns
  """

  alias Raxol.Benchmarks.Performance, as: Benchmarks
  alias Raxol.Core.UXRefinement
  alias Raxol.Core.ComponentUtils

  # State for the optimization system
  defmodule State do
    @moduledoc false
    defstruct [
      :usage_patterns,
      :render_metrics,
      :component_usage,
      :resource_allocation,
      :prediction_models,
      :optimization_level,
      :enabled_features
    ]

    def new do
      %__MODULE__{
        usage_patterns: %{},
        render_metrics: %{},
        component_usage: %{},
        resource_allocation: %{},
        prediction_models: %{},
        optimization_level: :balanced,
        enabled_features:
          MapSet.new([
            :predictive_rendering,
            :component_caching,
            :adaptive_throttling
          ])
      }
    end
  end

  # Process dictionary key for optimizer state
  @state_key :raxol_optimizer_state

  @doc """
  Initializes the performance optimization system.

  ## Options

  * `:optimization_level` - Level of optimization to apply (:minimal, :balanced, :aggressive)
  * `:features` - List of features to enable

  ## Examples

      iex> init(optimization_level: :balanced)
      :ok
  """
  def init(opts \\ []) do
    opts = if map?(opts), do: Enum.into(opts, []), else: opts

    if UXRefinement.feature_enabled?(:ai_performance_optimization) do
      state = State.new()

      state = %{
        state
        | optimization_level: Keyword.get(opts, :optimization_level, :balanced),
          enabled_features:
            MapSet.new(
              Keyword.get(
                opts,
                :features,
                MapSet.to_list(state.enabled_features)
              )
            )
      }

      _ = Process.put(@state_key, state)

      # Start collecting initial metrics
      _ = collect_baseline_metrics()

      :ok
    else
      {:error, "AI performance optimization is not enabled"}
    end
  end

  @doc """
  Records component render time for optimization analysis.

  ## Examples

      iex> record_render_time("user_profile", 25)
      :ok
  """
  def record_render_time(component_name, time_ms) do
    _ =
      with_state(fn state ->
        render_metrics =
          Map.update(
            state.render_metrics,
            component_name,
            %{
              count: 1,
              total_time: time_ms,
              avg_time: time_ms,
              samples: [time_ms]
            },
            fn metrics ->
              samples = [time_ms | metrics.samples] |> Enum.take(10)
              count = metrics.count + 1
              total_time = metrics.total_time + time_ms

              %{
                count: count,
                total_time: total_time,
                avg_time: total_time / count,
                samples: samples
              }
            end
          )

        %{state | render_metrics: render_metrics}
      end)

    :ok
  end

  @doc """
  Records component usage for optimization analysis.

  ## Examples

      iex> record_component_usage("dropdown_menu")
      :ok
  """
  def record_component_usage(component_name) do
    _ =
      with_state(fn state ->
        component_usage =
          Map.update(
            state.component_usage,
            component_name,
            %{count: 1, last_used: System.monotonic_time()},
            fn usage ->
              %{
                usage
                | count: usage.count + 1,
                  last_used: System.monotonic_time()
              }
            end
          )

        %{state | component_usage: component_usage}
      end)

    :ok
  end

  @doc """
  Determines if a component should be rendered based on current conditions.
  Uses predictive rendering to optimize performance.

  ## Examples

      iex> should_render?("large_table", %{visible: false, scroll_position: 500})
      false
  """
  def should_render?(component_name, context \\ %{}) do
    if !UXRefinement.feature_enabled?(:ai_performance_optimization) do
      true
    else
      with_state(fn state ->
        if !feature_enabled?(:predictive_rendering, state) do
          {state, true}
        else
          metrics = Map.get(state.render_metrics, component_name)

          result =
            predictive_render_decision(metrics, component_name, context, state)

          usage_patterns =
            update_usage_patterns(
              state.usage_patterns,
              component_name,
              result,
              context
            )

          {%{state | usage_patterns: usage_patterns}, result}
        end
      end)
    end
  end

  defp predictive_render_decision(nil, _component_name, _context, _state),
    do: true

  defp predictive_render_decision(
         %{count: count},
         _component_name,
         _context,
         _state
       )
       when count < 5,
       do: true

  defp predictive_render_decision(_metrics, component_name, context, state) do
    Map.get(context, :visible, true) and
      (Map.get(context, :in_viewport, true) or
         ComponentUtils.important_component?(component_name, state))
  end

  defp update_usage_patterns(usage_patterns, component_name, result, context) do
    Map.update(
      usage_patterns,
      component_name,
      %{render_decisions: [result], context_history: [context]},
      fn patterns ->
        %{
          render_decisions:
            [result | patterns.render_decisions] |> Enum.take(20),
          context_history: [context | patterns.context_history] |> Enum.take(5)
        }
      end
    )
  end

  @doc """
  Gets the recommended refresh rate for a component based on current activity.

  ## Examples

      iex> get_refresh_rate("animated_progress")
      16  # milliseconds (approximately 60fps)
  """
  def get_refresh_rate(component_name) do
    if !UXRefinement.feature_enabled?(:ai_performance_optimization) do
      16
    else
      with_state(fn state ->
        if !feature_enabled?(:adaptive_throttling, state) do
          {state, 16}
        else
          metrics = Map.get(state.render_metrics, component_name)
          usage = Map.get(state.component_usage, component_name)
          refresh_rate = calculate_refresh_rate(metrics, usage)
          {state, refresh_rate}
        end
      end)
    end
  end

  defp calculate_refresh_rate(metrics, usage) do
    default_rates = %{
      high: 16,
      medium: 33,
      low: 100,
      idle: 250
    }

    cond do
      metrics == nil or metrics.count < 5 -> default_rates.high
      usage == :idle -> default_rates.idle
      usage == :low -> default_rates.low
      usage == :medium -> default_rates.medium
      true -> default_rates.high
    end
  end

  @doc """
  Recommends components for prefetching based on usage patterns.

  ## Examples

      iex> get_prefetch_recommendations("user_profile")
      ["user_settings", "user_activity"]
  """
  def get_prefetch_recommendations(current_component) do
    if !UXRefinement.feature_enabled?(:ai_performance_optimization) do
      []
    else
      with_state(fn state ->
        {state, build_recommendations(state.component_usage, current_component)}
      end)
    end
  end

  defp build_recommendations(component_usage, current_component) do
    component_usage
    |> Enum.filter(fn {name, _} -> name != current_component end)
    |> Enum.sort_by(fn {_, usage} -> usage.count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {name, _} -> name end)
  end

  @doc """
  Analyzes performance and suggests optimizations.

  ## Examples

      iex> analyze_performance()
      [
        %{type: :component, name: "data_table", issue: :slow_rendering, suggestion: "Consider virtual scrolling"},
        %{type: :pattern, issue: :excessive_updates, suggestion: "Implement throttling for search inputs"}
      ]
  """
  def analyze_performance do
    if !UXRefinement.feature_enabled?(:ai_performance_optimization) do
      []
    else
      with_state(fn state ->
        # Identify slow components
        slow_components =
          state.render_metrics
          |> Enum.filter(fn {_, metrics} ->
            metrics.avg_time > 50 and metrics.count > 5
          end)
          |> Enum.map(fn {name, metrics} ->
            %{
              type: :component,
              name: name,
              issue: :slow_rendering,
              avg_time: metrics.avg_time,
              suggestion: get_optimization_suggestion(name, metrics)
            }
          end)

        # Additional analyses would go here

        {state, slow_components}
      end)
    end
  end

  @doc """
  Enables or disables a specific optimization feature.

  ## Examples

      iex> toggle_feature(:predictive_rendering, true)
      :ok
  """
  def toggle_feature(feature, enabled) do
    _ =
      with_state(fn state ->
        enabled_features =
          if enabled do
            MapSet.put(state.enabled_features, feature)
          else
            MapSet.delete(state.enabled_features, feature)
          end

        %{state | enabled_features: enabled_features}
      end)

    :ok
  end

  @doc """
  Sets the optimization level for the system.

  ## Examples

      iex> set_optimization_level(:aggressive)
      :ok
  """
  def set_optimization_level(level)
      when level in [:minimal, :balanced, :aggressive] do
    with_state(fn state ->
      %{state | optimization_level: level}
    end)

    :ok
  end

  # Private helpers

  defp with_state(fun) do
    Raxol.Core.StateManager.with_state(@state_key, fn state ->
      case fun.(state) do
        {new_state, result} -> {new_state, result}
        new_state -> {new_state, nil}
      end
    end)
  end

  defp feature_enabled?(feature, state) do
    MapSet.member?(state.enabled_features, feature)
  end

  defp collect_baseline_metrics do
    # This would collect system metrics to establish a baseline
    # For now, just a placeholder
    _ = Benchmarks.run_all([])
  end

  defp get_optimization_suggestion(component_name, metrics) do
    cond do
      String.contains?(component_name, "table") or
          String.contains?(component_name, "list") ->
        "Consider implementing virtual scrolling or pagination"

      String.contains?(component_name, "image") or
          String.contains?(component_name, "avatar") ->
        "Consider implementing lazy loading and optimizing image size"

      metrics.avg_time > 100 ->
        "Consider breaking component into smaller parts or implement memoization"

      true ->
        "Review component implementation for optimization opportunities"
    end
  end
end
