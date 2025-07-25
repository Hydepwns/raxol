defmodule Raxol.UI.StyleProcessor do
  @moduledoc """
  Handles style processing, merging, inheritance, and flattening.
  """

  @doc """
  Flattens and merges styles from parent style and child element with proper theme resolution.
  """
  def flatten_merged_style(parent_style, child_element, theme) do
    # Handle case where parent_style might be an element map or a style map
    parent_style_map = case parent_style do
      %{style: style_map} when is_map(style_map) -> 
        # If parent_style is an element with a :style key, extract and merge with top-level properties
        style_map 
        |> Map.merge(Map.take(parent_style, [:foreground, :background, :fg, :bg]))
      style_map when is_map(style_map) -> 
        # If parent_style is already a flattened style map, use it as-is
        style_map
      _ -> %{}
    end
    
    child_style_map = Map.get(child_element, :style, %{})
    merged_style_map = Map.merge(parent_style_map, child_style_map)
    child_other_attrs = Map.drop(child_element, [:style])

    # Merge style map with other attributes for proper override resolution
    all_attrs = Map.merge(child_other_attrs, merged_style_map)

    # Get component styles from theme
    component_styles = Raxol.UI.ThemeResolver.get_component_styles(nil, theme)

    # Resolve colors with proper theme fallback, but allow explicit overrides
    resolved_fg = Raxol.UI.ThemeResolver.resolve_fg_color(all_attrs, component_styles, theme)
    resolved_bg = Raxol.UI.ThemeResolver.resolve_bg_color(all_attrs, component_styles, theme)

    # Use explicit values if provided, otherwise use resolved values
    final_fg = Map.get(all_attrs, :foreground) || Map.get(all_attrs, :fg) || resolved_fg
    final_bg = Map.get(all_attrs, :background) || Map.get(all_attrs, :bg) || resolved_bg

    promoted_attrs =
      all_attrs
      |> Map.put(:foreground, final_fg)
      |> Map.put(:background, final_bg)
      |> Map.put(:fg, final_fg)
      |> Map.put(:bg, final_bg)

    promoted_attrs
  end

  @doc """
  Merges parent and child styles for inheritance.
  """
  def merge_styles_for_inheritance(parent_style, child_style) do
    # Extract style maps from both parent and child
    parent_style_map = Map.get(parent_style, :style, %{})
    child_style_map = Map.get(child_style, :style, %{})

    # Merge the style maps (child overrides parent)
    merged_style_map = Map.merge(parent_style_map, child_style_map)

    # Create a complete inherited style that includes both the merged style map
    # and the promoted keys for proper inheritance
    %{}
    |> Map.put(:style, merged_style_map)
    |> maybe_put_if_not_nil(
      :foreground,
      Map.get(merged_style_map, :foreground)
    )
    |> maybe_put_if_not_nil(
      :background,
      Map.get(merged_style_map, :background)
    )
    |> maybe_put_if_not_nil(:fg, Map.get(merged_style_map, :fg))
    |> maybe_put_if_not_nil(:bg, Map.get(merged_style_map, :bg))
  end

  @doc """
  Inherits colors from parent to child style.
  """
  def inherit_colors(child_style_map, parent_element, parent_style_map) do
    %{
      fg:
        Map.get(child_style_map, :foreground) ||
          Map.get(parent_element, :foreground) ||
          Map.get(parent_style_map, :foreground),
      bg:
        Map.get(child_style_map, :background) ||
          Map.get(parent_element, :background) ||
          Map.get(parent_style_map, :background),
      fg_short:
        Map.get(child_style_map, :fg) || Map.get(parent_element, :fg) ||
          Map.get(parent_style_map, :fg),
      bg_short:
        Map.get(child_style_map, :bg) || Map.get(parent_element, :bg) ||
          Map.get(parent_style_map, :bg)
    }
  end

  @doc """
  Ensures a value is a list.
  """
  def ensure_list(value) when is_list(value), do: value
  def ensure_list(value), do: [value]

  # Helper function to put a key-value pair only if the value is not nil
  defp maybe_put_if_not_nil(map, _key, nil), do: map
  defp maybe_put_if_not_nil(map, key, value), do: Map.put(map, key, value)
end
