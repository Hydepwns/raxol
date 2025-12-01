defmodule Raxol.Performance.ThemeCacheTest do
  use ExUnit.Case, async: false

  alias Raxol.Performance.ETSCacheManager
  alias Raxol.UI.ThemeResolver

  setup do
    # Ensure cache manager is running with a name so GenServer.call works
    case ETSCacheManager.start_link(name: ETSCacheManager) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    # Clear cache before each test
    ETSCacheManager.clear_cache(:style)

    :ok
  end

  describe "theme/style caching" do
    test "caches style resolution" do
      theme = %{
        name: :perf_test,
        colors: %{foreground: :white, background: :black}
      }

      attrs = %{fg: :red, bg: :blue}

      # First resolution - should miss cache
      {fg1, bg1, attrs1} = ThemeResolver.resolve_styles(attrs, :button, theme)

      # Cache the result
      theme_id = :perf_test
      attrs_hash = :erlang.phash2(attrs)

      ETSCacheManager.cache_style(
        theme_id,
        :button,
        attrs_hash,
        {fg1, bg1, attrs1}
      )

      # Get from cache
      {:ok, cached} = ETSCacheManager.get_style(theme_id, :button, attrs_hash)

      assert cached == {fg1, bg1, attrs1}
      assert fg1 == :red
      assert bg1 == :blue
    end

    test "cache performance improvement" do
      theme = %{
        name: :benchmark,
        colors: %{foreground: :white, background: :black},
        variants: %{
          primary: %{foreground: :blue, background: :gray}
        }
      }

      # Use fixed data for reproducibility in CI
      attrs_list =
        for i <- 1..100 do
          fg = Enum.at([:red, :blue, :green], rem(i, 3))
          bg = Enum.at([:black, :white, :gray], rem(i, 3))
          variant = if rem(i, 2) == 0, do: :primary, else: nil
          %{fg: fg, bg: bg, variant: variant, index: i}
        end

      # First pass - populate cache and verify results are stored
      cached_results =
        for attrs <- attrs_list do
          result = ThemeResolver.resolve_styles(attrs, :test_component, theme)
          theme_id = :benchmark
          attrs_hash = :erlang.phash2(Map.drop(attrs, [:index]))

          # cache_style returns the result, not :ok
          _cached =
            ETSCacheManager.cache_style(
              theme_id,
              :test_component,
              attrs_hash,
              result
            )

          {attrs_hash, result}
        end

      # Verify cached values are retrievable and correct
      for {attrs_hash, expected_result} <- cached_results do
        {:ok, cached} =
          ETSCacheManager.get_style(:benchmark, :test_component, attrs_hash)

        assert cached == expected_result
      end

      # Verify cache has entries (functional test, not performance)
      stats = ETSCacheManager.stats()
      assert stats.style.size > 0
    end
  end

  describe "cache statistics" do
    test "tracks cache size and memory" do
      # Add some entries
      for i <- 1..10 do
        ETSCacheManager.cache_style(:test, :component, i, %{test: i})
      end

      stats = ETSCacheManager.stats()

      assert stats.style.size > 0
      assert stats.style.memory_bytes > 0
    end
  end
end
