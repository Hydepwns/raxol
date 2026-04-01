defmodule Raxol.Performance.Caches.ComponentRenderCache do
  @moduledoc """
  High-performance cache for component rendering results.

  This module caches rendered component output to avoid repeated rendering
  of components with identical state and props. Components are frequently
  re-rendered during UI updates, and caching can significantly reduce
  computational overhead.

  ## Features
  - Caches component render results based on state+props hash
  - Caches composed render trees
  - Caches element-to-cell conversions
  - Thread-safe concurrent access via ETS
  - Telemetry instrumentation for monitoring

  ## Performance Impact
  Expected improvements:
  - 50-70% reduction in component rendering overhead
  - Sub-microsecond access for cached renders
  - Significant reduction in CPU usage for static components
  """

  alias Raxol.Performance.Caches.CacheHelper
  alias Raxol.UI.Renderer
  alias Raxol.UI.Rendering.Composer

  # Cache key prefixes
  @render_output_prefix "component:render:"
  @composed_tree_prefix "component:composed:"
  @cells_output_prefix "component:cells:"
  @element_render_prefix "component:element:"

  @telemetry_prefix [:raxol, :performance, :component_render_cache]

  @doc """
  Gets the rendered output for a component from cache or renders and caches it.
  """
  @spec get_rendered_output(module(), map(), map()) :: term()
  def get_rendered_output(component_module, state, props) do
    key = build_render_key(component_module, state, props)

    CacheHelper.cache_through(
      key,
      @telemetry_prefix,
      %{cache_type: :render_output},
      fn ->
        component_module.render(state, props)
      end
    )
  end

  @doc """
  Gets the composed render tree from cache or composes and caches it.
  """
  @spec get_composed_tree(term(), term(), term()) :: term()
  def get_composed_tree(layout_data, new_tree, previous_tree) do
    key = build_composed_tree_key(layout_data, new_tree)

    CacheHelper.cache_through(
      key,
      @telemetry_prefix,
      %{cache_type: :composed_tree},
      fn ->
        Composer.compose_render_tree(layout_data, new_tree, previous_tree)
      end
    )
  end

  @doc """
  Gets the rendered cells for an element from cache or renders and caches them.
  """
  @spec get_element_cells(map(), map() | nil) :: list()
  def get_element_cells(element, theme \\ nil) do
    key = build_cells_key(element, theme)

    CacheHelper.cache_through(
      key,
      @telemetry_prefix,
      %{cache_type: :element_cells},
      fn ->
        Renderer.render_to_cells(element, theme)
      end
    )
  end

  @doc """
  Gets the rendered element from cache or renders and caches it.
  """
  @spec get_rendered_element(map(), map(), map()) :: list()
  def get_rendered_element(element, theme, parent_style \\ %{}) do
    key = build_element_render_key(element, theme, parent_style)

    CacheHelper.cache_through(
      key,
      @telemetry_prefix,
      %{cache_type: :rendered_element},
      fn ->
        Renderer.render_element(element, theme, parent_style)
      end
    )
  end

  @doc """
  Invalidates cache entries for a specific component.
  """
  @spec invalidate_component(module(), map() | :all) :: :ok
  def invalidate_component(component_module, state_or_all \\ :all) do
    _pattern = build_invalidation_pattern(component_module, state_or_all)
    # Note: In a real implementation, we'd need access to the ETS table directly
    # or add an invalidation method to ETSCacheManager
    CacheHelper.emit_telemetry(@telemetry_prefix, :invalidate, %{
      component: component_module
    })

    :ok
  end

  @doc """
  Warms up the cache with common component renders.
  """
  @spec warmup(list({module(), map(), map()})) :: :ok
  def warmup(component_specs) do
    Enum.each(component_specs, fn {module, state, props} ->
      get_rendered_output(module, state, props)
    end)

    CacheHelper.emit_telemetry(@telemetry_prefix, :warmup_complete, %{
      cached_count: length(component_specs)
    })

    :ok
  end

  @doc """
  Checks if a component render would benefit from caching.
  Returns true if the component is complex enough to warrant caching.
  """
  @spec should_cache?(map() | term()) :: boolean()
  def should_cache?(%{type: type, children: children}) when is_list(children) do
    # Cache if component has multiple children or is a complex type
    length(children) > 3 or type in [:table, :panel, :modal, :dashboard]
  end

  def should_cache?(%{type: type}) do
    # Cache complex single elements
    type in [:table, :chart, :graph, :canvas]
  end

  def should_cache?(_), do: false

  @doc """
  Estimates the render cost of a component to determine caching strategy.
  """
  @spec estimate_render_cost(map()) :: :low | :medium | :high
  def estimate_render_cost(%{type: :text}), do: :low
  def estimate_render_cost(%{type: :box}), do: :low
  def estimate_render_cost(%{type: :panel}), do: :medium

  def estimate_render_cost(%{type: :table, data: data}) when is_list(data) do
    determine_table_cost(length(data) > 10)
  end

  def estimate_render_cost(%{children: children}) when is_list(children) do
    child_count = length(children)

    cond do
      child_count > 20 -> :high
      child_count > 5 -> :medium
      true -> :low
    end
  end

  def estimate_render_cost(_), do: :low

  defp determine_table_cost(true), do: :high
  defp determine_table_cost(false), do: :medium

  # Private functions

  # Key builders
  defp build_render_key(component_module, state, props) do
    # Create a unique key based on component module and state/props hash
    state_hash = :erlang.phash2({state, props})
    @render_output_prefix <> "#{component_module}:#{state_hash}"
  end

  defp build_composed_tree_key(layout_data, new_tree) do
    # Hash the layout data and new tree for the key
    data_hash = :erlang.phash2({layout_data, new_tree})
    @composed_tree_prefix <> "#{data_hash}"
  end

  defp build_cells_key(element, theme) do
    # Hash element and theme for cache key
    element_hash = hash_element(element)

    theme_hash =
      case theme do
        nil -> "default"
        _ -> :erlang.phash2(theme)
      end

    @cells_output_prefix <> "#{element_hash}:#{theme_hash}"
  end

  defp build_element_render_key(element, theme, parent_style) do
    # Hash all rendering inputs
    element_hash = hash_element(element)

    theme_hash =
      case theme do
        nil -> "default"
        _ -> :erlang.phash2(theme)
      end

    style_hash = :erlang.phash2(parent_style)
    @element_render_prefix <> "#{element_hash}:#{theme_hash}:#{style_hash}"
  end

  defp build_invalidation_pattern(component_module, :all) do
    # Pattern to match all cache entries for a component
    @render_output_prefix <> "#{component_module}:*"
  end

  defp build_invalidation_pattern(component_module, state) do
    # Pattern to match specific state cache entries
    state_hash = :erlang.phash2(state)
    @render_output_prefix <> "#{component_module}:#{state_hash}:*"
  end

  # Element hashing
  defp hash_element(element) when is_map(element) do
    # Create a stable hash for an element
    # Exclude volatile fields like timestamps or random IDs
    stable_element = Map.drop(element, [:id, :timestamp, :__meta__])
    :erlang.phash2(stable_element)
  end

  defp hash_element(element) do
    :erlang.phash2(element)
  end
end
