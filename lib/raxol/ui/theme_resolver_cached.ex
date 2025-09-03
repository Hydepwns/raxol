defmodule Raxol.UI.ThemeResolverCached do
  @moduledoc """
  Cached version of ThemeResolver for high-performance theme and style resolution.
  
  Caches:
  - Theme lookups and resolution
  - Style resolution (fg, bg, attrs)
  - Component style lookups
  - Variant color resolution
  - Theme merging operations
  
  Cache keys are based on:
  - Theme ID/name
  - Component type
  - Attributes hash
  - Variant names
  """
  
  alias Raxol.UI.ThemeResolver
  alias Raxol.Performance.ETSCacheManager
  
  @doc """
  Resolves styles with caching. Returns {fg_color, bg_color, style_attrs}.
  """
  def resolve_styles(attrs, component_type, theme) do
    # Generate cache key
    theme_id = get_theme_id(theme)
    attrs_hash = hash_attrs(attrs)
    
    # Check cache first
    case ETSCacheManager.get_style(theme_id, component_type, attrs_hash) do
      {:ok, cached_result} ->
        cached_result
      
      :miss ->
        # Compute and cache the result
        result = ThemeResolver.resolve_styles(attrs, component_type, theme)
        ETSCacheManager.cache_style(theme_id, component_type, attrs_hash, result)
        result
    end
  end
  
  @doc """
  Cached version of resolve_element_theme.
  """
  def resolve_element_theme(element_theme, default_theme) do
    # For string themes, cache the lookup
    case element_theme do
      theme_name when is_binary(theme_name) ->
        cache_key = {:theme_lookup, theme_name}
        case get_cached_theme(cache_key) do
          {:ok, theme} -> 
            theme
          :miss ->
            theme = ThemeResolver.resolve_element_theme(element_theme, default_theme)
            cache_theme(cache_key, theme)
            theme
        end
      
      _ ->
        # For non-string themes, use original resolver
        ThemeResolver.resolve_element_theme(element_theme, default_theme)
    end
  end
  
  @doc """
  Cached version of resolve_element_theme_with_inheritance.
  """
  def resolve_element_theme_with_inheritance(element, default_theme) do
    # Create cache key based on element's theme configuration
    cache_key = build_inheritance_cache_key(element)
    
    case get_cached_theme(cache_key) do
      {:ok, theme} ->
        theme
      
      :miss ->
        theme = ThemeResolver.resolve_element_theme_with_inheritance(element, default_theme)
        cache_theme(cache_key, theme)
        theme
    end
  end
  
  @doc """
  Cached version of merge_themes_for_inheritance.
  """
  def merge_themes_for_inheritance(parent_theme, child_theme) do
    cache_key = {:theme_merge, hash_theme(parent_theme), hash_theme(child_theme)}
    
    case get_cached_theme(cache_key) do
      {:ok, merged} ->
        merged
      
      :miss ->
        merged = ThemeResolver.merge_themes_for_inheritance(parent_theme, child_theme)
        cache_theme(cache_key, merged)
        merged
    end
  end
  
  @doc """
  Cached version of get_default_theme.
  """
  def get_default_theme() do
    cache_key = :default_theme
    
    case get_cached_theme(cache_key) do
      {:ok, theme} ->
        theme
      
      :miss ->
        theme = ThemeResolver.get_default_theme()
        cache_theme(cache_key, theme)
        theme
    end
  end
  
  @doc """
  Cached version of resolve_fg_color.
  """
  def resolve_fg_color(attrs, component_styles, theme) do
    cache_key = {:fg_color, hash_attrs(attrs), hash_attrs(component_styles), get_theme_id(theme)}
    
    case get_cached_color(cache_key) do
      {:ok, color} ->
        color
      
      :miss ->
        color = ThemeResolver.resolve_fg_color(attrs, component_styles, theme)
        cache_color(cache_key, color)
        color
    end
  end
  
  @doc """
  Cached version of resolve_bg_color.
  """
  def resolve_bg_color(attrs, component_styles, theme) do
    cache_key = {:bg_color, hash_attrs(attrs), hash_attrs(component_styles), get_theme_id(theme)}
    
    case get_cached_color(cache_key) do
      {:ok, color} ->
        color
      
      :miss ->
        color = ThemeResolver.resolve_bg_color(attrs, component_styles, theme)
        cache_color(cache_key, color)
        color
    end
  end
  
  @doc """
  Cached version of resolve_variant_color.
  """
  def resolve_variant_color(attrs, theme, color_type) do
    variant_name = Map.get(attrs, :variant)
    
    if variant_name do
      cache_key = {:variant_color, variant_name, get_theme_id(theme), color_type}
      
      case get_cached_color(cache_key) do
        {:ok, color} ->
          color
        
        :miss ->
          color = ThemeResolver.resolve_variant_color(attrs, theme, color_type)
          cache_color(cache_key, color)
          color
      end
    else
      nil
    end
  end
  
  @doc """
  Cached version of get_component_styles.
  """
  def get_component_styles(component_type, theme) do
    if component_type && is_map(theme) do
      cache_key = {:component_styles, component_type, get_theme_id(theme)}
      
      case get_cached_styles(cache_key) do
        {:ok, styles} ->
          styles
        
        :miss ->
          styles = ThemeResolver.get_component_styles(component_type, theme)
          cache_styles(cache_key, styles)
          styles
      end
    else
      %{}
    end
  end
  
  @doc """
  Clear all theme/style caches.
  """
  def clear_cache do
    ETSCacheManager.clear_cache(:style)
  end
  
  @doc """
  Invalidate cache entries for a specific theme.
  """
  def invalidate_theme(theme_id) do
    # This would require more sophisticated cache management
    # For now, clear all style cache when a theme changes
    clear_cache()
  end
  
  # Private cache helpers
  
  defp get_cached_theme(key) do
    # Use the style cache table for theme data
    ETSCacheManager.get_style(:theme_cache, nil, :erlang.phash2(key))
  end
  
  defp cache_theme(key, theme) do
    ETSCacheManager.cache_style(:theme_cache, nil, :erlang.phash2(key), theme)
  end
  
  defp get_cached_color(key) do
    ETSCacheManager.get_style(:color_cache, nil, :erlang.phash2(key))
  end
  
  defp cache_color(key, color) do
    ETSCacheManager.cache_style(:color_cache, nil, :erlang.phash2(key), color)
  end
  
  defp get_cached_styles(key) do
    ETSCacheManager.get_style(:styles_cache, nil, :erlang.phash2(key))
  end
  
  defp cache_styles(key, styles) do
    ETSCacheManager.cache_style(:styles_cache, nil, :erlang.phash2(key), styles)
  end
  
  # Cache key generation helpers
  
  defp get_theme_id(nil), do: :no_theme
  defp get_theme_id(theme) when is_atom(theme), do: theme
  defp get_theme_id(theme) when is_binary(theme), do: theme
  defp get_theme_id(theme) when is_map(theme) do
    # Use theme name if available, otherwise hash the theme
    Map.get(theme, :name, :erlang.phash2(theme))
  end
  defp get_theme_id(_), do: :unknown_theme
  
  defp hash_attrs(nil), do: 0
  defp hash_attrs(attrs) when is_map(attrs) do
    # Create a stable hash of relevant style attributes
    relevant_keys = [:fg, :foreground, :bg, :background, :variant, :style, 
                     :bold, :italic, :underline, :blink, :reverse]
    
    attrs
    |> Map.take(relevant_keys)
    |> :erlang.phash2()
  end
  defp hash_attrs(_), do: 0
  
  defp hash_theme(nil), do: 0
  defp hash_theme(theme) when is_map(theme) do
    # Hash only the parts of theme that affect style resolution
    %{
      colors: Map.get(theme, :colors, %{}),
      component_styles: Map.get(theme, :component_styles, %{}),
      variants: Map.get(theme, :variants, %{})
    }
    |> :erlang.phash2()
  end
  defp hash_theme(_), do: 0
  
  defp build_inheritance_cache_key(element) do
    element_theme = Map.get(element, :theme)
    parent_theme = Map.get(element, :parent_theme)
    
    {:inheritance, get_theme_id(element_theme), hash_theme(parent_theme)}
  end
end