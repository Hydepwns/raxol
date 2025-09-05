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

  alias Raxol.Core.UXRefinement, as: UXRefinement

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
    handle_init_optimizer(
      UXRefinement.feature_enabled?(:ai_performance_optimization),
      opts,
      state
    )
  end

  @impl true
  def handle_call({:should_render, component_name, context}, _from, state) do
    handle_should_render(
      UXRefinement.feature_enabled?(:ai_performance_optimization),
      component_name,
      context,
      state
    )
  end

  @impl true
  def handle_call({:get_refresh_rate, component_name}, _from, state) do
    rate =
      get_refresh_rate_for_component(
        UXRefinement.feature_enabled?(:ai_performance_optimization),
        feature_enabled?(:adaptive_throttling, state),
        component_name,
        state
      )

    {:reply, rate, state}
  end

  @impl true
  def handle_call(
        {:get_prefetch_recommendations, current_component},
        _from,
        state
      ) do
    recommendations =
      get_prefetch_recommendations_for_component(
        UXRefinement.feature_enabled?(:ai_performance_optimization),
        current_component,
        state
      )

    {:reply, recommendations, state}
  end

  @impl true
  def handle_call(:analyze_performance, _from, state) do
    slow_components =
      analyze_performance_for_components(
        UXRefinement.feature_enabled?(:ai_performance_optimization),
        state
      )

    {:reply, slow_components, state}
  end

  @impl true
  def handle_call({:toggle_feature, feature, enabled}, _from, state) do
    new_features = Map.put(state.features, feature, enabled)
    {:reply, :ok, %{state | features: new_features}}
  end

  @impl true
  def handle_call({:set_optimization_level, level}, _from, state) do
    {:reply, :ok, %{state | optimization_level: level}}
  end

  @impl true
  def handle_call(
        {:get_component_suggestions, component_name},
        _from,
        state
      ) do
    suggestions =
      get_suggestions_for_component(
        UXRefinement.feature_enabled?(:ai_performance_optimization),
        component_name,
        state
      )

    {:reply, suggestions, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
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

  # Private helper functions

  defp feature_enabled?(feature, state) do
    MapSet.member?(state.enabled_features, feature)
  end

  defp handle_init_optimizer(false, _opts, state) do
    {:reply, {:error, :ai_optimization_disabled}, state}
  end

  defp handle_init_optimizer(true, opts, state) do
    enabled_features = MapSet.union(state.enabled_features, MapSet.new(opts[:features] || []))
    optimization_level = opts[:level] || state.optimization_level
    {:reply, :ok, %{state | enabled_features: enabled_features, optimization_level: optimization_level}}
  end

  # Remove duplicated handle_call functions - they should all be grouped together above

  defp handle_should_render(false, _component_name, _context, state) do
    {:reply, true, state}
  end

  defp handle_should_render(true, component_name, context, state) do
    # Check if component should render based on performance metrics
    metrics = Map.get(state.render_metrics, component_name, %{count: 0, avg_time: 0})
    should_render = should_component_render(component_name, context, metrics, state)
    {:reply, should_render, state}
  end

  defp should_component_render(_component_name, _context, _metrics, state) do
    slow_components =
      analyze_performance_for_components(
        UXRefinement.feature_enabled?(:ai_performance_optimization),
        state
      )

    {:reply, slow_components, state}
  end

  # Private helper functions - keeping only used functions
  
  defp get_refresh_rate_for_component(false, _adaptive_enabled, _component_name, _state) do
    60  # Default refresh rate when AI optimization disabled
  end

  defp get_refresh_rate_for_component(true, _adaptive_enabled, _component_name, state) do
    # Simple rate based on optimization level
    case state.optimization_level do
      :aggressive -> 30
      :balanced -> 60  
      :minimal -> 120
    end
  end

  defp get_prefetch_recommendations_for_component(false, _current_component, _state) do
    []
  end

  defp get_prefetch_recommendations_for_component(true, _current_component, _state) do
    # Simple static recommendations
    ["preload_common_data"]
  end

  defp analyze_performance_for_components(false, _state) do
    []
  end

  defp analyze_performance_for_components(true, state) do
    state.render_metrics
    |> Enum.filter(fn {_name, metrics} -> metrics.avg_time > 50 end)
    |> Enum.map(fn {name, metrics} -> 
      %{component: name, avg_time: metrics.avg_time}
    end)
  end

  defp get_suggestions_for_component(false, _component_name, _state) do
    []
  end

  defp get_suggestions_for_component(true, _component_name, _state) do
    ["Consider performance optimization"]
  end

end
