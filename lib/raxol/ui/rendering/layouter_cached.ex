defmodule Raxol.UI.Rendering.LayouterCached do
  @moduledoc """
  Cached version of the Layouter that uses ETSCacheManager for performance.
  """

  alias Raxol.Performance.ETSCacheManager
  alias Raxol.UI.Rendering.Layouter

  @doc """
  Layout a tree with caching.
  """
  def layout_tree(reason, tree, constraints \\ %{}) do
    cache_key = {tree, constraints}

    case ETSCacheManager.get_layout(cache_key, constraints) do
      {:ok, result} ->
        # Return cached result as-is (it already has :calculated flag)
        result

      :miss ->
        result = Layouter.layout_tree(reason, tree)
        # Add :calculated flag to indicate this was freshly calculated
        result_with_flag = Map.put(result || %{}, :calculated, true)
        ETSCacheManager.cache_layout(cache_key, constraints, result_with_flag)
        result_with_flag
    end
  end

  @doc """
  Layout a node with caching.
  """
  def layout_node(node, constraints \\ %{}) do
    cache_key = {node, constraints}

    case ETSCacheManager.get_layout(cache_key, constraints) do
      {:ok, result} ->
        # Return cached result as-is (it already has :calculated flag)
        result

      :miss ->
        # Use layout_tree for nodes as well, since layout_node doesn't exist
        result = Layouter.layout_tree(:no_change, node)
        # Add :calculated flag to indicate this was freshly calculated
        result_with_flag = Map.put(result || %{}, :calculated, true)
        ETSCacheManager.cache_layout(cache_key, constraints, result_with_flag)
        result_with_flag
    end
  end

  @doc """
  Invalidate all cached layouts.
  """
  def invalidate_cache(:all) do
    if cache_available?() do
      ETSCacheManager.clear_cache(:layout)
    end
  end

  defp cache_available? do
    Code.ensure_loaded?(Raxol.Performance.ETSCacheManager) and
      Process.whereis(Raxol.Performance.ETSCacheManager) != nil
  end
end
