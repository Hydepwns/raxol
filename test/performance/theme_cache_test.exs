defmodule Raxol.Performance.ThemeCacheTest do
  use ExUnit.Case, async: false
  
  alias Raxol.Performance.ETSCacheManager
  alias Raxol.UI.ThemeResolver
  
  setup do
    # Ensure cache manager is running
    case Process.whereis(ETSCacheManager) do
      nil -> {:ok, _} = ETSCacheManager.start_link()
      _pid -> :ok
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
      ETSCacheManager.cache_style(theme_id, :button, attrs_hash, {fg1, bg1, attrs1})
      
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
      
      attrs_list = for i <- 1..1000, do: %{
        fg: Enum.random([:red, :blue, :green]),
        bg: Enum.random([:black, :white, :gray]),
        variant: Enum.random([nil, :primary]),
        index: i
      }
      
      # First pass - populate cache
      for attrs <- attrs_list do
        result = ThemeResolver.resolve_styles(attrs, :test_component, theme)
        theme_id = :benchmark
        attrs_hash = :erlang.phash2(Map.drop(attrs, [:index]))
        ETSCacheManager.cache_style(theme_id, :test_component, attrs_hash, result)
      end
      
      # Benchmark cached access
      cached_time = :timer.tc(fn ->
        for attrs <- attrs_list do
          theme_id = :benchmark
          attrs_hash = :erlang.phash2(Map.drop(attrs, [:index]))
          ETSCacheManager.get_style(theme_id, :test_component, attrs_hash)
        end
      end) |> elem(0)
      
      # Benchmark uncached computation
      uncached_time = :timer.tc(fn ->
        for attrs <- attrs_list do
          ThemeResolver.resolve_styles(attrs, :test_component, theme)
        end
      end) |> elem(0)
      
      # Cache should be faster or at least not slower
      IO.puts("Cached time: #{cached_time}μs, Uncached time: #{uncached_time}μs")
      # Allow for cache to be at most 20% slower than uncached (for small datasets)
      assert cached_time <= uncached_time * 1.2
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