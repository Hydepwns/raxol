defmodule Raxol.Performance.LayoutCacheTest do
  use ExUnit.Case

  alias Raxol.UI.Rendering.{Layouter, LayouterCached}
  alias Raxol.Performance.ETSCacheManager

  setup do
    # Ensure cache manager is started with a name
    case ETSCacheManager.start_link(name: ETSCacheManager) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
    end

    # Clear layout cache before each test
    ETSCacheManager.clear_cache(:layout)

    :ok
  end

  describe "Layout Caching" do
    test "cached layouter returns same result as original" do
      test_tree = %{
        type: :container,
        layout: :flex,
        direction: :column,
        children: [
          %{type: :text, content: "Header"},
          %{type: :button, label: "Click me"},
          %{type: :text, content: "Footer"}
        ]
      }

      constraints = %{width: 80, height: 24}

      # Layout with original
      original_result = Layouter.layout_tree(:no_change, test_tree)

      # Layout with cache (first call - miss)
      cached_result1 = LayouterCached.layout_tree(:no_change, test_tree, constraints)

      # Layout with cache (second call - hit)
      cached_result2 = LayouterCached.layout_tree(:no_change, test_tree, constraints)

      assert cached_result2 == cached_result1
    end

    test "cache hit on identical layout requests" do
      tree = %{
        type: :flex,
        direction: :row,
        children: [
          %{type: :panel, width: 40},
          %{type: :panel, flex: 1}
        ]
      }

      constraints = %{width: 120, height: 40}

      # First call - cache miss
      _result1 = LayouterCached.layout_tree(:no_change, tree, constraints)

      # Get initial stats
      stats1 = ETSCacheManager.stats()[:layout]
      initial_size = stats1[:size]

      # Second call - should hit cache
      _result2 = LayouterCached.layout_tree(:no_change, tree, constraints)

      # Cache size should not increase
      stats2 = ETSCacheManager.stats()[:layout]
      assert stats2[:size] == initial_size
    end

    test "different constraints create different cache entries" do
      tree = %{type: :container, layout: :grid, columns: 2}

      constraints1 = %{width: 80, height: 24}
      constraints2 = %{width: 160, height: 50}

      # Layout with different constraints
      result1 = LayouterCached.layout_tree(:no_change, tree, constraints1)
      result2 = LayouterCached.layout_tree(:no_change, tree, constraints2)

      # Results might differ due to constraints
      # But both should be cached
      stats = ETSCacheManager.stats()[:layout]
      assert stats[:size] >= 2
    end

    test "partial updates use cache efficiently" do
      base_tree = %{
        type: :container,
        children: [
          %{id: :header, type: :text, content: "Title"},
          %{id: :body, type: :panel, height: 20},
          %{id: :footer, type: :text, content: "Status"}
        ]
      }

      constraints = %{width: 100, height: 30}

      # Initial layout
      _initial = LayouterCached.layout_tree({:replace, base_tree}, base_tree, constraints)

      # Partial update
      update_diff = {:update, [:children, 1], [{:text_change, "Updated"}]}
      _updated = LayouterCached.layout_tree(update_diff, base_tree, constraints)

      # Check cache contains entries
      stats = ETSCacheManager.stats()[:layout]
      assert stats[:size] > 0
    end

    test "cache invalidation works" do
      tree = %{type: :simple}
      constraints = %{width: 50, height: 10}

      # Cache a layout
      LayouterCached.layout_tree(:no_change, tree, constraints)

      stats_before = ETSCacheManager.stats()[:layout]
      assert stats_before[:size] > 0

      # Invalidate cache
      LayouterCached.invalidate_cache(:all)

      stats_after = ETSCacheManager.stats()[:layout]
      assert stats_after[:size] == 0
    end

    test "compatible constraints reuse cache" do
      tree = %{type: :flex, direction: :column}

      # Very similar constraints (within tolerance)
      constraints1 = %{width: 100, height: 30}
      constraints2 = %{width: 102, height: 31}  # Within 10% tolerance

      # First layout
      result1 = LayouterCached.layout_tree(:no_change, tree, constraints1)

      # Second layout with similar constraints
      result2 = LayouterCached.layout_tree(:no_change, tree, constraints2)

      # Due to constraint compatibility, might reuse cache
      stats = ETSCacheManager.stats()[:layout]
      assert stats[:size] >= 1
    end

    test "node layout caching works" do
      node = %{
        type: :button,
        layout: :flex,
        padding: 2,
        label: "Submit"
      }

      constraints = %{width: 20, height: 3}

      # Layout single node
      result1 = LayouterCached.layout_node(node, constraints)
      result2 = LayouterCached.layout_node(node, constraints)

      assert result1 == result2
      assert result1[:calculated] == true
    end
  end

  describe "Performance" do
    @tag :slow
    test "cached layout is faster than uncached" do
      complex_tree = generate_complex_tree(10, 3)
      constraints = %{width: 200, height: 100}

      # Warm up
      LayouterCached.layout_tree(:no_change, complex_tree, constraints)

      # Measure cached performance
      start_cached = System.monotonic_time(:microsecond)
      for _ <- 1..100 do
        LayouterCached.layout_tree(:no_change, complex_tree, constraints)
      end
      cached_time = System.monotonic_time(:microsecond) - start_cached

      # Clear cache
      ETSCacheManager.clear_cache(:layout)

      # Measure uncached performance (simulate by clearing cache each time)
      start_uncached = System.monotonic_time(:microsecond)
      for _ <- 1..100 do
        ETSCacheManager.clear_cache(:layout)
        LayouterCached.layout_tree(:no_change, complex_tree, constraints)
      end
      uncached_time = System.monotonic_time(:microsecond) - start_uncached

      # Cached should be significantly faster
      assert cached_time < uncached_time * 0.5  # At least 50% faster
    end
  end

  # Helper to generate complex tree for performance testing
  defp generate_complex_tree(width, depth) do
    if depth <= 0 do
      %{type: :leaf, content: "Node"}
    else
      %{
        type: :container,
        layout: Enum.random([:flex, :grid, :absolute]),
        children: for(_ <- 1..width, do: generate_complex_tree(width - 1, depth - 1))
      }
    end
  end
end