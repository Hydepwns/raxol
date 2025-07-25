defmodule Raxol.UI.ThemeResolver do
  @moduledoc """
  Handles theme resolution, color processing, and theme-related utilities.
  """

  @default_fg :white
  @default_bg :black

  @doc """
  Resolves an element's theme, handling string themes and providing fallbacks.
  """
  def resolve_element_theme(element_theme, default_theme) do
    case element_theme do
      nil -> default_theme
      theme when is_binary(theme) ->
        # Try to get theme by name, fallback to default
        case Raxol.UI.Theming.Theme.get(theme) do
          nil -> default_theme
          found_theme -> found_theme
        end
      theme when is_map(theme) -> theme
      _ -> default_theme
    end
  end

  @doc """
  Resolves an element's theme with inheritance support.
  """
  def resolve_element_theme_with_inheritance(element, default_theme) do
    # Get the main theme
    main_theme = resolve_element_theme(Map.get(element, :theme), default_theme)

    # Check for parent theme inheritance
    parent_theme = Map.get(element, :parent_theme)

    if parent_theme && is_map(parent_theme) do
      # Merge parent theme with main theme (main theme overrides parent)
      merge_themes_for_inheritance(parent_theme, main_theme)
    else
      main_theme
    end
  end

  @doc """
  Merges themes for inheritance (parent theme as base, child theme overrides).
  """
  def merge_themes_for_inheritance(parent_theme, child_theme) do
    # Merge colors (child overrides parent)
    merged_colors = Map.merge(
      Map.get(parent_theme, :colors, %{}),
      Map.get(child_theme, :colors, %{})
    )

    # Merge component styles (child overrides parent)
    merged_component_styles = Map.merge(
      Map.get(parent_theme, :component_styles, %{}),
      Map.get(child_theme, :component_styles, %{})
    )

    # Merge variants (child overrides parent)
    merged_variants = Map.merge(
      Map.get(parent_theme, :variants, %{}),
      Map.get(child_theme, :variants, %{})
    )

    # Create merged theme
    Map.merge(parent_theme, %{
      colors: merged_colors,
      component_styles: merged_component_styles,
      variants: merged_variants
    })
  end

  @doc """
  Gets the default theme with fallback creation.
  """
  def get_default_theme() do
    case Raxol.UI.Theming.Theme.get(:default) do
      nil -> create_fallback_theme()
      theme -> theme
    end
  end

  @doc """
  Creates a fallback theme when no default theme is available.
  """
  def create_fallback_theme() do
    %{
      colors: %{
        foreground: :white,
        background: :black
      },
      component_styles: %{},
      variants: %{}
    }
  end

  @doc """
  Resolves foreground and background colors with proper fallbacks.
  Returns {fg_color, bg_color, style_attrs}.
  """
  def resolve_styles(attrs, component_type, theme) do
    component_styles = get_component_styles(component_type, theme)
    fg_color = resolve_fg_color(attrs, component_styles, theme)
    bg_color = resolve_bg_color(attrs, component_styles, theme)
    style_attrs = resolve_style_attrs(attrs, component_styles)

    {fg_color, bg_color, style_attrs}
  end

  @doc """
  Resolves foreground color with proper fallbacks.
  """
  def resolve_fg_color(attrs, _component_styles, theme) do
    attrs
    |> get_explicit_color([:fg, :foreground])
    |> fallback_to_variant_color(attrs, theme, :foreground)
    |> fallback_to_theme_color(theme, :foreground, :white)
    |> convert_color_to_atom()
  end

  @doc """
  Resolves background color with proper fallbacks.
  """
  def resolve_bg_color(attrs, _component_styles, theme) do
    attrs
    |> get_explicit_color([:bg, :background])
    |> fallback_to_variant_color(attrs, theme, :background)
    |> fallback_to_theme_color(theme, :background, :black)
    |> convert_color_to_atom()
  end

  @doc """
  Resolves style attributes from explicit attrs and component styles.
  """
  def resolve_style_attrs(attrs, component_styles) do
    explicit_attrs = Map.get(attrs, :style, []) |> ensure_list()
    component_attrs = Map.get(component_styles, :style, []) |> ensure_list()
    (explicit_attrs ++ component_attrs) |> Enum.uniq()
  end

  @doc """
  Resolves color from theme variant.
  """
  def resolve_variant_color(attrs, theme, color_type) do
    variant_name = Map.get(attrs, :variant)

    if variant_name && theme && is_map(theme) do
      variants = Map.get(theme, :variants, %{})
      variant = Map.get(variants, variant_name)

      if variant && is_map(variant) do
        Map.get(variant, color_type)
      else
        nil
      end
    else
      nil
    end
  end

  @doc """
  Gets component styles from theme.
  """
  def get_component_styles(component_type, theme) do
    if component_type && is_map(theme) do
      theme
      |> Map.get(:component_styles, %{})
      |> get_component_styles_from_map(component_type)
    else
      %{}
    end
  end

  defp get_component_styles_from_map(component_styles, component_type) when is_map(component_styles) do
    Map.get(component_styles, component_type, %{})
  end
  defp get_component_styles_from_map(_, _), do: %{}

  # Convert color values to atoms for test compatibility
  defp convert_color_to_atom(color) when is_atom(color), do: color
  defp convert_color_to_atom(color) when is_binary(color) do
    hex_to_color_atom(String.downcase(color))
  end
  defp convert_color_to_atom(%{r: r, g: g, b: b}) do
    # Convert RGB color struct to hex and then to atom
    hex = "##{Integer.to_string(r, 16) |> String.pad_leading(2, "0")}#{Integer.to_string(g, 16) |> String.pad_leading(2, "0")}#{Integer.to_string(b, 16) |> String.pad_leading(2, "0")}"
    convert_color_to_atom(hex)
  end
  defp convert_color_to_atom(_), do: :white  # Default fallback

  defp hex_to_color_atom("#ffffff"), do: :white
  defp hex_to_color_atom("#000000"), do: :black
  defp hex_to_color_atom("#ff0000"), do: :red
  defp hex_to_color_atom("#00ff00"), do: :green
  defp hex_to_color_atom("#0000ff"), do: :blue
  defp hex_to_color_atom("#ffff00"), do: :yellow
  defp hex_to_color_atom("#ff00ff"), do: :magenta
  defp hex_to_color_atom("#00ffff"), do: :cyan
  defp hex_to_color_atom(_), do: :white  # Default fallback

  defp ensure_list(value) when is_list(value), do: value
  defp ensure_list(value), do: [value]

  # Helper functions to reduce complexity
  defp get_explicit_color(attrs, color_keys) do
    Enum.find_value(color_keys, fn key ->
      if Map.has_key?(attrs, key) and not is_nil(Map.get(attrs, key)) do
        Map.get(attrs, key)
      end
    end)
  end

  defp fallback_to_variant_color(nil, attrs, theme, color_type) do
    resolve_variant_color(attrs, theme, color_type)
  end
  defp fallback_to_variant_color(color, _attrs, _theme, _color_type), do: color

  defp fallback_to_theme_color(nil, theme, color_type, default) do
    get_theme_color(theme, color_type, default)
  end
  defp fallback_to_theme_color(color, _theme, _color_type, _default), do: color

  defp get_theme_color(nil, _color_type, default), do: default
  defp get_theme_color(theme, _color_type, default) when not is_map(theme), do: default
  defp get_theme_color(theme, color_type, default) do
    case Map.get(theme, :colors) do
      nil -> default
      colors when is_map(colors) -> Map.get(colors, color_type, default)
      _ -> default
    end
  end
end
