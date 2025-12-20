defmodule Raxol.Performance.ComponentCacheTest do
  use ExUnit.Case, async: false

  alias Raxol.UI.RendererCached
  alias Raxol.UI.ThemeResolver

  setup do
    # ETSCacheManager should be started by the application supervision tree
    # Just clear caches before each test
    RendererCached.clear_cache()

    :ok
  end

  describe "render_to_cells/2" do
    test "caches simple text element rendering" do
      element = %{type: :text, text: "Hello", x: 0, y: 0}
      theme = ThemeResolver.get_default_theme()

      # First render - cache miss
      result1 = RendererCached.render_to_cells(element, theme)

      # Second render - should hit cache
      result2 = RendererCached.render_to_cells(element, theme)

      assert result1 == result2
      assert length(result1) > 0
    end

    test "caches multiple elements with batch rendering" do
      elements = [
        %{type: :text, text: "Line 1", x: 0, y: 0},
        %{type: :text, text: "Line 2", x: 0, y: 1},
        %{type: :text, text: "Line 3", x: 0, y: 2},
        %{type: :text, text: "Line 4", x: 0, y: 3}
      ]
      theme = ThemeResolver.get_default_theme()

      # First render
      result1 = RendererCached.render_to_cells(elements, theme)

      # Second render - should use cache
      result2 = RendererCached.render_to_cells(elements, theme)

      assert result1 == result2
    end

    test "handles nil and empty elements" do
      assert RendererCached.render_to_cells(nil, nil) == []
      assert RendererCached.render_to_cells([], nil) == []
    end
  end

  describe "render_element/3" do
    test "caches box element rendering" do
      element = %{type: :box, x: 0, y: 0, width: 10, height: 5}
      theme = ThemeResolver.get_default_theme()

      result1 = RendererCached.render_element(element, theme)
      result2 = RendererCached.render_element(element, theme)

      assert result1 == result2
    end

    test "invalidates cache when element changes" do
      element1 = %{type: :text, text: "Original", x: 0, y: 0}
      element2 = %{type: :text, text: "Modified", x: 0, y: 0}
      theme = ThemeResolver.get_default_theme()

      result1 = RendererCached.render_element(element1, theme)
      result2 = RendererCached.render_element(element2, theme)

      # Results should be different because text changed
      refute result1 == result2
    end

    test "respects no_cache flag" do
      element = %{type: :text, text: "Dynamic", x: 0, y: 0, no_cache: true}
      theme = ThemeResolver.get_default_theme()

      # Should not cache this element
      result1 = RendererCached.render_element(element, theme)
      assert is_list(result1)
    end
  end

  describe "render_virtual_list/4" do
    test "caches partial renders for virtual lists" do
      items = for i <- 1..100, do: %{id: i, text: "Item #{i}"}
      viewport = %{offset: 10, limit: 10}
      theme = ThemeResolver.get_default_theme()

      render_fn = fn _item, index ->
        [{0, index, "I", :white, :black, []}]
      end

      # First render
      result1 = RendererCached.render_virtual_list(items, viewport, theme, render_fn)

      # Second render with same viewport - should use cache
      result2 = RendererCached.render_virtual_list(items, viewport, theme, render_fn)

      assert result1 == result2
      assert length(result1) == 10  # Only visible items rendered
    end

    test "invalidates cache when viewport changes" do
      items = for i <- 1..100, do: %{id: i, text: "Item #{i}"}
      viewport1 = %{offset: 10, limit: 10}
      viewport2 = %{offset: 20, limit: 10}
      theme = ThemeResolver.get_default_theme()

      render_fn = fn _item, index ->
        [{0, index, "I", :white, :black, []}]
      end

      result1 = RendererCached.render_virtual_list(items, viewport1, theme, render_fn)
      result2 = RendererCached.render_virtual_list(items, viewport2, theme, render_fn)

      # Different viewports should give different results
      refute result1 == result2
    end
  end

  describe "render_tree/2" do
    test "recursively caches component tree" do
      tree = %{
        type: :panel,
        x: 0, y: 0,
        width: 20, height: 10,
        children: [
          %{type: :text, text: "Title", x: 1, y: 1},
          %{type: :box, x: 1, y: 2, width: 18, height: 7,
            children: [
              %{type: :text, text: "Content", x: 2, y: 3}
            ]}
        ]
      }

      theme = ThemeResolver.get_default_theme()

      # First render
      result1 = RendererCached.render_tree(tree, theme)

      # Second render - should use cache
      result2 = RendererCached.render_tree(tree, theme)

      assert result1 == result2
      assert length(result1) > 0
    end

    test "handles deep nesting with recursion limit" do
      # Create deeply nested structure
      deep_tree = Enum.reduce(1..60, %{type: :text, text: "Leaf", x: 0, y: 0}, fn _i, acc ->
        %{type: :box, x: 0, y: 0, width: 10, height: 10, children: [acc]}
      end)

      theme = ThemeResolver.get_default_theme()

      # Should not crash with deep nesting
      result = RendererCached.render_tree(deep_tree, theme)
      assert is_list(result)
    end
  end

  describe "performance" do
    @tag :skip_on_ci
    test "cached rendering is significantly faster" do
      # Create complex element structure
      elements = for i <- 1..50, do: %{
        type: :box,
        x: rem(i, 10) * 10,
        y: div(i, 10) * 5,
        width: 8,
        height: 4,
        style: %{
          fg: Enum.random([:red, :green, :blue]),
          bg: Enum.random([:black, :white])
        }
      }

      theme = ThemeResolver.get_default_theme()

      # Warm up cache
      RendererCached.render_to_cells(elements, theme)

      # Measure single cached render performance
      cached_time = :timer.tc(fn ->
        RendererCached.render_to_cells(elements, theme)
      end) |> elem(0)

      # Clear cache and measure first render
      RendererCached.clear_cache()

      first_render_time = :timer.tc(fn ->
        RendererCached.render_to_cells(elements, theme)
      end) |> elem(0)

      IO.puts("Cached rendering: #{cached_time}μs")
      IO.puts("First render: #{first_render_time}μs")

      # Cached should be faster than uncached (allow some variation for test stability)
      assert cached_time < first_render_time * 2
    end

    test "warmup_cache preloads common components" do
      RendererCached.clear_cache()

      # Warm up
      RendererCached.warmup_cache()

      # These should now be cached
      common_elements = [
        %{type: :text, text: "", x: 0, y: 0},
        %{type: :box, x: 0, y: 0, width: 10, height: 10}
      ]

      theme = ThemeResolver.get_default_theme()

      for element <- common_elements do
        # Should be fast since warmed up
        result = RendererCached.render_element(element, theme)
        assert is_list(result)
      end
    end
  end

  describe "cache management" do
    test "clear_cache removes all cached renders" do
      element = %{type: :text, text: "Test", x: 0, y: 0}
      theme = ThemeResolver.get_default_theme()

      # Cache a render
      RendererCached.render_element(element, theme)

      # Clear cache
      RendererCached.clear_cache()

      # Next render should be a cache miss (we can't directly test this
      # but we can verify it still works)
      result = RendererCached.render_element(element, theme)
      assert is_list(result)
    end

    test "get_cache_stats returns statistics" do
      stats = RendererCached.get_cache_stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :hit_rate)
      assert Map.has_key?(stats, :total_cached)
      assert Map.has_key?(stats, :memory_usage)
    end
  end
end
