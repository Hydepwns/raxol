defmodule Raxol.UI.ThemeResolverCachedTest do
  use ExUnit.Case, async: false
  
  alias Raxol.UI.ThemeResolverCached
  alias Raxol.Performance.ETSCacheManager
  
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
  
  describe "resolve_styles/3" do
    test "caches style resolution results" do
      attrs = %{fg: :red, bg: :blue, variant: :primary}
      theme = %{
        name: :test_theme,
        colors: %{foreground: :white, background: :black},
        variants: %{primary: %{foreground: :yellow}}
      }
      
      # First call should compute and cache
      result1 = ThemeResolverCached.resolve_styles(attrs, :button, theme)
      
      # Second call should use cache
      result2 = ThemeResolverCached.resolve_styles(attrs, :button, theme)
      
      assert result1 == result2
      
      # Verify cache was used by checking stats
      stats = ETSCacheManager.stats()
      assert stats.style.size > 0
    end
    
    test "handles different component types separately" do
      attrs = %{fg: :red}
      theme = %{name: :test_theme}
      
      result1 = ThemeResolverCached.resolve_styles(attrs, :button, theme)
      result2 = ThemeResolverCached.resolve_styles(attrs, :input, theme)
      
      # Results should be cached separately
      stats = ETSCacheManager.stats()
      assert stats.style.size >= 2
    end
    
    test "handles nil theme gracefully" do
      attrs = %{fg: :red, bg: :blue}
      
      result = ThemeResolverCached.resolve_styles(attrs, :button, nil)
      {fg, bg, _attrs} = result
      
      assert fg == :red
      assert bg == :blue
    end
  end
  
  describe "resolve_element_theme/2" do
    test "caches theme lookups by name" do
      # Mock theme that would be looked up
      default_theme = %{name: :default, colors: %{foreground: :white}}
      
      # First call with string theme name
      result1 = ThemeResolverCached.resolve_element_theme("dark", default_theme)
      
      # Second call should use cache
      result2 = ThemeResolverCached.resolve_element_theme("dark", default_theme)
      
      # Should return default when theme not found, but consistently
      assert result1 == result2
      assert result1 == default_theme
    end
    
    test "passes through map themes without caching" do
      theme = %{name: :custom, colors: %{foreground: :green}}
      default_theme = %{name: :default}
      
      result = ThemeResolverCached.resolve_element_theme(theme, default_theme)
      assert result == theme
    end
    
    test "returns default for nil theme" do
      default_theme = %{name: :default}
      
      result = ThemeResolverCached.resolve_element_theme(nil, default_theme)
      assert result == default_theme
    end
  end
  
  describe "merge_themes_for_inheritance/2" do
    test "caches theme merge operations" do
      parent_theme = %{
        colors: %{foreground: :white, background: :black},
        component_styles: %{button: %{bold: true}}
      }
      
      child_theme = %{
        colors: %{foreground: :red},
        component_styles: %{input: %{italic: true}}
      }
      
      # First merge
      result1 = ThemeResolverCached.merge_themes_for_inheritance(parent_theme, child_theme)
      
      # Second merge should use cache
      result2 = ThemeResolverCached.merge_themes_for_inheritance(parent_theme, child_theme)
      
      assert result1 == result2
      assert result1.colors.foreground == :red
      assert result1.colors.background == :black
    end
  end
  
  describe "resolve_fg_color/3" do
    test "caches foreground color resolution" do
      attrs = %{variant: :primary}
      theme = %{
        name: :test,
        colors: %{foreground: :white},
        variants: %{primary: %{foreground: :blue}}
      }
      
      result1 = ThemeResolverCached.resolve_fg_color(attrs, %{}, theme)
      result2 = ThemeResolverCached.resolve_fg_color(attrs, %{}, theme)
      
      assert result1 == result2
      assert result1 == :blue
    end
    
    test "handles explicit foreground color" do
      attrs = %{fg: :green}
      theme = %{colors: %{foreground: :white}}
      
      result = ThemeResolverCached.resolve_fg_color(attrs, %{}, theme)
      assert result == :green
    end
  end
  
  describe "resolve_bg_color/3" do
    test "caches background color resolution" do
      attrs = %{variant: :primary}
      theme = %{
        name: :test,
        colors: %{background: :black},
        variants: %{primary: %{background: :gray}}
      }
      
      result1 = ThemeResolverCached.resolve_bg_color(attrs, %{}, theme)
      result2 = ThemeResolverCached.resolve_bg_color(attrs, %{}, theme)
      
      assert result1 == result2
      assert result1 == :gray
    end
  end
  
  describe "resolve_variant_color/3" do
    test "caches variant color lookups" do
      attrs = %{variant: :danger}
      theme = %{
        name: :test,
        variants: %{
          danger: %{foreground: :red, background: :white}
        }
      }
      
      result1 = ThemeResolverCached.resolve_variant_color(attrs, theme, :foreground)
      result2 = ThemeResolverCached.resolve_variant_color(attrs, theme, :foreground)
      
      assert result1 == result2
      assert result1 == :red
    end
    
    test "returns nil for missing variant" do
      attrs = %{variant: :nonexistent}
      theme = %{name: :test, variants: %{}}
      
      result = ThemeResolverCached.resolve_variant_color(attrs, theme, :foreground)
      assert result == nil
    end
    
    test "returns nil when no variant specified" do
      attrs = %{}
      theme = %{name: :test}
      
      result = ThemeResolverCached.resolve_variant_color(attrs, theme, :foreground)
      assert result == nil
    end
  end
  
  describe "get_component_styles/2" do
    test "caches component style lookups" do
      theme = %{
        name: :test,
        component_styles: %{
          button: %{bold: true, padding: 2},
          input: %{italic: true}
        }
      }
      
      result1 = ThemeResolverCached.get_component_styles(:button, theme)
      result2 = ThemeResolverCached.get_component_styles(:button, theme)
      
      assert result1 == result2
      assert result1 == %{bold: true, padding: 2}
    end
    
    test "returns empty map for missing component" do
      theme = %{name: :test, component_styles: %{}}
      
      result = ThemeResolverCached.get_component_styles(:nonexistent, theme)
      assert result == %{}
    end
  end
  
  describe "cache invalidation" do
    test "clear_cache removes all cached entries" do
      attrs = %{fg: :red}
      theme = %{name: :test}
      
      # Populate cache
      ThemeResolverCached.resolve_styles(attrs, :button, theme)
      
      # Verify cache has entries
      stats_before = ETSCacheManager.stats()
      assert stats_before.style.size > 0
      
      # Clear cache
      ThemeResolverCached.clear_cache()
      
      # Verify cache is empty
      stats_after = ETSCacheManager.stats()
      assert stats_after.style.size == 0
    end
  end
  
  describe "performance" do
    test "cached lookups are significantly faster than uncached" do
      attrs = %{
        fg: :red, 
        bg: :blue, 
        variant: :primary,
        bold: true,
        italic: true
      }
      
      theme = %{
        name: :perf_test,
        colors: %{foreground: :white, background: :black},
        variants: %{
          primary: %{foreground: :yellow, background: :gray},
          secondary: %{foreground: :green}
        },
        component_styles: %{
          button: %{padding: 2, margin: 1}
        }
      }
      
      # Warm up cache
      ThemeResolverCached.resolve_styles(attrs, :button, theme)
      
      # Measure cached performance
      cached_time = :timer.tc(fn ->
        for _ <- 1..1000 do
          ThemeResolverCached.resolve_styles(attrs, :button, theme)
        end
      end) |> elem(0)
      
      # Clear cache
      ThemeResolverCached.clear_cache()
      
      # Measure uncached performance (first lookup only)
      uncached_time = :timer.tc(fn ->
        ThemeResolverCached.resolve_styles(attrs, :button, theme)
      end) |> elem(0)
      
      # Cached should be at least 10x faster for repeated lookups
      assert cached_time < uncached_time * 100
    end
  end
end