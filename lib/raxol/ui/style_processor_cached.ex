defmodule Raxol.UI.StyleProcessorCached do
  @moduledoc """
  Cached version of StyleProcessor for high-performance style processing.

  Caches:
  - Style flattening and merging operations
  - Style inheritance chains
  - Color inheritance resolution

  Uses ETSCacheManager for consistent caching across the system.
  """

  alias Raxol.UI.StyleProcessor
  alias Raxol.UI.ThemeResolverCached
  alias Raxol.Performance.ETSCacheManager

  @doc """
  Cached version of flatten_merged_style.
  Flattens and merges styles from parent style and child element with proper theme resolution.
  """
  def flatten_merged_style(parent_style, child_element, theme) do
    # Generate cache key based on inputs
    cache_key = build_flatten_cache_key(parent_style, child_element, theme)

    # Check cache first
    case get_cached_flattened_style(cache_key) do
      {:ok, cached_style} ->
        cached_style

      :miss ->
        # Compute the flattened style using cached theme resolver
        flattened =
          compute_flattened_style_cached(parent_style, child_element, theme)

        cache_flattened_style(cache_key, flattened)
        flattened
    end
  end

  @doc """
  Cached version of merge_styles_for_inheritance.
  """
  def merge_styles_for_inheritance(parent_style, child_style) do
    cache_key =
      {:style_merge, hash_style(parent_style), hash_style(child_style)}

    case get_cached_merged_style(cache_key) do
      {:ok, merged} ->
        merged

      :miss ->
        merged =
          StyleProcessor.merge_styles_for_inheritance(parent_style, child_style)

        cache_merged_style(cache_key, merged)
        merged
    end
  end

  @doc """
  Cached version of inherit_colors.
  """
  def inherit_colors(child_style_map, parent_element, parent_style_map) do
    cache_key =
      {:color_inherit, hash_style(child_style_map), hash_style(parent_element),
       hash_style(parent_style_map)}

    case get_cached_colors(cache_key) do
      {:ok, colors} ->
        colors

      :miss ->
        colors =
          StyleProcessor.inherit_colors(
            child_style_map,
            parent_element,
            parent_style_map
          )

        cache_colors(cache_key, colors)
        colors
    end
  end

  @doc """
  Clear all style processing caches.
  """
  def clear_cache do
    ETSCacheManager.clear_cache(:style)
  end

  # Private implementation

  defp compute_flattened_style_cached(parent_style, child_element, theme) do
    # Extract parent style map
    parent_style_map =
      case parent_style do
        %{style: style_map} when is_map(style_map) ->
          style_map
          |> Map.merge(
            Map.take(parent_style, [:foreground, :background, :fg, :bg])
          )

        style_map when is_map(style_map) ->
          style_map

        _ ->
          %{}
      end

    child_style_map = Map.get(child_element, :style, %{})
    merged_style_map = Map.merge(parent_style_map, child_style_map)
    child_other_attrs = Map.drop(child_element, [:style])

    # Merge for proper override resolution
    all_attrs = Map.merge(child_other_attrs, merged_style_map)

    # Use cached theme resolver for component styles
    component_styles = ThemeResolverCached.get_component_styles(nil, theme)

    # Use cached color resolution
    resolved_fg =
      ThemeResolverCached.resolve_fg_color(all_attrs, component_styles, theme)

    resolved_bg =
      ThemeResolverCached.resolve_bg_color(all_attrs, component_styles, theme)

    # Use explicit values if provided, otherwise use resolved values
    final_fg =
      Map.get(all_attrs, :foreground) || Map.get(all_attrs, :fg) || resolved_fg

    final_bg =
      Map.get(all_attrs, :background) || Map.get(all_attrs, :bg) || resolved_bg

    # Build final promoted attributes
    all_attrs
    |> Map.put(:foreground, final_fg)
    |> Map.put(:background, final_bg)
    |> Map.put(:fg, final_fg)
    |> Map.put(:bg, final_bg)
  end

  # Cache helpers

  defp get_cached_flattened_style(key) do
    ETSCacheManager.get_style(:flatten_cache, nil, :erlang.phash2(key))
  end

  defp cache_flattened_style(key, style) do
    ETSCacheManager.cache_style(:flatten_cache, nil, :erlang.phash2(key), style)
  end

  defp get_cached_merged_style(key) do
    ETSCacheManager.get_style(:merge_cache, nil, :erlang.phash2(key))
  end

  defp cache_merged_style(key, style) do
    ETSCacheManager.cache_style(:merge_cache, nil, :erlang.phash2(key), style)
  end

  defp get_cached_colors(key) do
    ETSCacheManager.get_style(:colors_cache, nil, :erlang.phash2(key))
  end

  defp cache_colors(key, colors) do
    ETSCacheManager.cache_style(:colors_cache, nil, :erlang.phash2(key), colors)
  end

  # Cache key builders

  defp build_flatten_cache_key(parent_style, child_element, theme) do
    {:flatten, hash_style(parent_style), hash_element(child_element),
     get_theme_id(theme)}
  end

  defp hash_style(nil), do: 0

  defp hash_style(style) when is_map(style) do
    # Extract relevant style properties for hashing
    relevant_keys = [
      :style,
      :foreground,
      :background,
      :fg,
      :bg,
      :bold,
      :italic,
      :underline,
      :variant
    ]

    style
    |> Map.take(relevant_keys)
    |> :erlang.phash2()
  end

  defp hash_style(_), do: 0

  defp hash_element(nil), do: 0

  defp hash_element(element) when is_map(element) do
    # Hash the style-relevant parts of the element
    %{
      style: Map.get(element, :style, %{}),
      theme: Map.get(element, :theme),
      variant: Map.get(element, :variant),
      foreground: Map.get(element, :foreground),
      background: Map.get(element, :background),
      fg: Map.get(element, :fg),
      bg: Map.get(element, :bg)
    }
    |> :erlang.phash2()
  end

  defp hash_element(_), do: 0

  defp get_theme_id(nil), do: :no_theme
  defp get_theme_id(theme) when is_atom(theme), do: theme
  defp get_theme_id(theme) when is_binary(theme), do: theme

  defp get_theme_id(theme) when is_map(theme) do
    Map.get(theme, :name, :erlang.phash2(theme))
  end

  defp get_theme_id(_), do: :unknown_theme
end
