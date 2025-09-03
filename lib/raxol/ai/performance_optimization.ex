defmodule Raxol.AI.PerformanceOptimization do
  @moduledoc """
  Refactored AI Performance Optimization module with GenServer-based state management.

  This module provides backward compatibility while eliminating Process dictionary usage.
  All state is now managed through the AI.PerformanceOptimization.Server GenServer.

  ## Migration Notes

  This module replaces direct Process dictionary usage with supervised GenServer state.
  The API remains the same, but the implementation is now OTP-compliant and more robust.
  """

  alias Raxol.AI.PerformanceOptimization.Server

  @deprecated "Use Raxol.AI.PerformanceOptimization instead of Raxol.AI.PerformanceOptimization"

  # State module for backward compatibility
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

  # Ensure server is started
  defp ensure_server_started do
    case Process.whereis(Server) do
      nil ->
        {:ok, _pid} = Server.start_link()
        :ok

      _pid ->
        :ok
    end
  end

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
    ensure_server_started()
    Server.init_optimizer(opts)
  end

  @doc """
  Records component render time for optimization analysis.

  ## Examples

      iex> record_render_time("user_profile", 25)
      :ok
  """
  def record_render_time(component_name, time_ms) do
    ensure_server_started()
    Server.record_render_time(component_name, time_ms)
    :ok
  end

  @doc """
  Records component usage for optimization analysis.

  ## Examples

      iex> record_component_usage("dropdown_menu")
      :ok
  """
  def record_component_usage(component_name) do
    ensure_server_started()
    Server.record_component_usage(component_name)
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
    ensure_server_started()
    Server.should_render?(component_name, context)
  end

  @doc """
  Gets the recommended refresh rate for a component based on current activity.

  ## Examples

      iex> get_refresh_rate("animated_progress")
      16  # milliseconds (approximately 60fps)
  """
  def get_refresh_rate(component_name) do
    ensure_server_started()
    Server.get_refresh_rate(component_name)
  end

  @doc """
  Recommends components for prefetching based on usage patterns.

  ## Examples

      iex> get_prefetch_recommendations("user_profile")
      ["user_settings", "user_activity"]
  """
  def get_prefetch_recommendations(current_component) do
    ensure_server_started()
    Server.get_prefetch_recommendations(current_component)
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
    ensure_server_started()
    Server.analyze_performance()
  end

  @doc """
  Enables or disables a specific optimization feature.

  ## Examples

      iex> toggle_feature(:predictive_rendering, true)
      :ok
  """
  def toggle_feature(feature, enabled) do
    ensure_server_started()
    Server.toggle_feature(feature, enabled)
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
    ensure_server_started()
    Server.set_optimization_level(level)
    :ok
  end

  @doc """
  Gets AI-powered optimization analysis for a component.

  ## Examples

      iex> get_ai_optimization_analysis("MyComponent", "defmodule MyComponent do...", %{avg_time: 150})
      {:ok, [%{type: :performance, description: "...", suggestion: "..."}]}
  """
  def get_ai_optimization_analysis(component_name, code, metrics) do
    ensure_server_started()
    Server.get_ai_optimization_analysis(component_name, code, metrics)
  end
end
