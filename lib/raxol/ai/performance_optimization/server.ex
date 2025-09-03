defmodule Raxol.AI.PerformanceOptimization.Server do
  @moduledoc """
  GenServer implementation for AI Performance Optimization.

  This server manages all AI-driven performance optimization state and operations,
  eliminating Process dictionary usage in favor of supervised state management.

  ## Features
  - Predictive rendering decisions
  - Resource allocation optimization
  - Component caching strategies
  - Content prefetching
  - Adaptive throttling
  - Runtime profiling and analysis
  """

  use GenServer
  require Logger

  alias Raxol.Benchmarks.Performance, as: Benchmarks
  alias Raxol.Core.UXRefinement, as: UXRefinement
  alias Raxol.Core.ComponentUtils
  alias Raxol.AI.ServiceAdapter

  # Client API

  @doc """
  Starts the AI Performance Optimization server.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns a child specification for this server.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  # Public API

  def init_optimizer(opts \\ []) do
    GenServer.call(__MODULE__, {:init_optimizer, opts})
  end

  def record_render_time(component_name, time_ms) do
    GenServer.cast(__MODULE__, {:record_render_time, component_name, time_ms})
  end

  def record_component_usage(component_name) do
    GenServer.cast(__MODULE__, {:record_component_usage, component_name})
  end

  def should_render?(component_name, context \\ %{}) do
    GenServer.call(__MODULE__, {:should_render, component_name, context})
  end

  def get_refresh_rate(component_name) do
    GenServer.call(__MODULE__, {:get_refresh_rate, component_name})
  end

  def get_prefetch_recommendations(current_component) do
    GenServer.call(
      __MODULE__,
      {:get_prefetch_recommendations, current_component}
    )
  end

  def analyze_performance do
    GenServer.call(__MODULE__, :analyze_performance)
  end

  def toggle_feature(feature, enabled) do
    GenServer.call(__MODULE__, {:toggle_feature, feature, enabled})
  end

  def set_optimization_level(level)
      when level in [:minimal, :balanced, :aggressive] do
    GenServer.call(__MODULE__, {:set_optimization_level, level})
  end

  def get_ai_optimization_analysis(component_name, code, metrics) do
    GenServer.call(
      __MODULE__,
      {:get_ai_analysis, component_name, code, metrics}
    )
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    state = %{
      usage_patterns: %{},
      render_metrics: %{},
      component_usage: %{},
      resource_allocation: %{},
      prediction_models: %{},
      optimization_level: Keyword.get(opts, :optimization_level, :balanced),
      enabled_features:
        MapSet.new(
          Keyword.get(opts, :features, [
            :predictive_rendering,
            :component_caching,
            :adaptive_throttling
          ])
        ),
      initialized: false
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:init_optimizer, opts}, _from, state) do
    if UXRefinement.feature_enabled?(:ai_performance_optimization) do
      opts = if is_map(opts), do: Enum.into(opts, []), else: opts

      updated_state = %{
        state
        | optimization_level:
            Keyword.get(opts, :optimization_level, state.optimization_level),
          enabled_features:
            MapSet.new(
              Keyword.get(
                opts,
                :features,
                MapSet.to_list(state.enabled_features)
              )
            ),
          initialized: true
      }

      # Start collecting baseline metrics
      spawn(fn -> Benchmarks.run_all([]) end)

      {:reply, :ok, updated_state}
    else
      {:reply, {:error, "AI performance optimization is not enabled"}, state}
    end
  end

  @impl true
  def handle_cast({:record_render_time, component_name, time_ms}, state) do
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

    {:noreply, %{state | render_metrics: render_metrics}}
  end

  @impl true
  def handle_cast({:record_component_usage, component_name}, state) do
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

    {:noreply, %{state | component_usage: component_usage}}
  end

  @impl true
  def handle_call({:should_render, component_name, context}, _from, state) do
    if UXRefinement.feature_enabled?(:ai_performance_optimization) do
      result =
        if feature_enabled?(:predictive_rendering, state) do
          metrics = Map.get(state.render_metrics, component_name)
          predictive_render_decision(metrics, component_name, context, state)
        else
          true
        end

      # Update usage patterns
      usage_patterns =
        update_usage_patterns(
          state.usage_patterns,
          component_name,
          result,
          context
        )

      {:reply, result, %{state | usage_patterns: usage_patterns}}
    else
      {:reply, true, state}
    end
  end

  @impl true
  def handle_call({:get_refresh_rate, component_name}, _from, state) do
    rate =
      if UXRefinement.feature_enabled?(:ai_performance_optimization) and
           feature_enabled?(:adaptive_throttling, state) do
        metrics = Map.get(state.render_metrics, component_name)
        usage = Map.get(state.component_usage, component_name)
        calculate_refresh_rate(metrics, usage)
      else
        # Default to 60fps
        16
      end

    {:reply, rate, state}
  end

  @impl true
  def handle_call(
        {:get_prefetch_recommendations, current_component},
        _from,
        state
      ) do
    recommendations =
      if UXRefinement.feature_enabled?(:ai_performance_optimization) do
        build_recommendations(state.component_usage, current_component)
      else
        []
      end

    {:reply, recommendations, state}
  end

  @impl true
  def handle_call(:analyze_performance, _from, state) do
    slow_components =
      if UXRefinement.feature_enabled?(:ai_performance_optimization) do
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
      else
        []
      end

    {:reply, slow_components, state}
  end

  @impl true
  def handle_call({:toggle_feature, feature, enabled}, _from, state) do
    enabled_features =
      if enabled do
        MapSet.put(state.enabled_features, feature)
      else
        MapSet.delete(state.enabled_features, feature)
      end

    {:reply, :ok, %{state | enabled_features: enabled_features}}
  end

  @impl true
  def handle_call({:set_optimization_level, level}, _from, state) do
    {:reply, :ok, %{state | optimization_level: level}}
  end

  @impl true
  def handle_call(
        {:get_ai_analysis, component_name, code, metrics},
        _from,
        state
      ) do
    result =
      if UXRefinement.feature_enabled?(:ai_performance_optimization) do
        context = %{
          component_type: infer_component_type(component_name),
          metrics: metrics,
          performance_issues: identify_performance_patterns(metrics)
        }

        ServiceAdapter.analyze_performance(code, context)
      else
        {:ok,
         [
           %{
             type: :static,
             description: "Static analysis suggestion",
             suggestion: get_optimization_suggestion(component_name, metrics)
           }
         ]}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  # Private helper functions

  defp feature_enabled?(feature, state) do
    MapSet.member?(state.enabled_features, feature)
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

  defp calculate_refresh_rate(metrics, usage) do
    default_rates = %{
      high: 16,
      medium: 33,
      low: 100,
      idle: 250
    }

    determine_rate(metrics, usage, default_rates)
  end

  defp determine_rate(nil, _usage, rates), do: rates.high

  defp determine_rate(%{count: count}, _usage, rates) when count < 5,
    do: rates.high

  defp determine_rate(_metrics, :idle, rates), do: rates.idle
  defp determine_rate(_metrics, :low, rates), do: rates.low
  defp determine_rate(_metrics, :medium, rates), do: rates.medium
  defp determine_rate(_metrics, _usage, rates), do: rates.high

  defp build_recommendations(component_usage, current_component) do
    component_usage
    |> Enum.filter(fn {name, _} -> name != current_component end)
    |> Enum.sort_by(fn {_, usage} -> usage.count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {name, _} -> name end)
  end

  defp infer_component_type(component_name) do
    Enum.find_value(
      [
        {["table", "list", "grid"], "data_display"},
        {["form", "input", "field"], "user_input"},
        {["chart", "graph", "plot"], "visualization"},
        {["modal", "dialog", "popup"], "overlay"}
      ],
      "general",
      fn {keywords, type} ->
        if String.contains?(component_name, keywords), do: type
      end
    )
  end

  defp identify_performance_patterns(metrics) do
    patterns = []

    patterns =
      if metrics.avg_time > 100 do
        ["slow_rendering" | patterns]
      else
        patterns
      end

    patterns =
      if metrics.count > 100 and metrics.avg_time > 50 do
        ["frequent_heavy_renders" | patterns]
      else
        patterns
      end

    patterns
  end

  defp get_optimization_suggestion(component_name, metrics) do
    suggest_optimization(component_name, metrics)
  end

  defp suggest_optimization(component_name, _metrics)
       when is_binary(component_name) do
    case categorize_component_for_optimization(component_name) do
      :data_list -> "Consider implementing virtual scrolling or pagination"
      :media -> "Consider implementing lazy loading and optimizing image size"
      :general -> suggest_by_metrics(component_name, _metrics)
    end
  end

  defp categorize_component_for_optimization(name) do
    Enum.find_value(
      [
        {["table", "list"], :data_list},
        {["image", "avatar"], :media}
      ],
      :general,
      fn {keywords, type} ->
        if String.contains?(name, keywords), do: type
      end
    )
  end

  defp suggest_by_metrics(_component_name, %{avg_time: avg_time})
       when avg_time > 100 do
    "Consider breaking component into smaller parts or implement memoization"
  end

  defp suggest_by_metrics(_component_name, _metrics) do
    "Review component implementation for optimization opportunities"
  end
end
