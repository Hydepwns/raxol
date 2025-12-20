defmodule Raxol.Protocols.ThemeImplementations do
  @moduledoc """
  Protocol implementations for theme-related structures.

  This module provides Styleable, Renderable, and Serializable protocol
  implementations for theme and color system components.
  """

  alias Raxol.Protocols.{Renderable, Serializable, Styleable}
  alias Raxol.Utils.ColorConversion

  # Theme Protocol Implementations
  defimpl Styleable, for: Raxol.UI.Theming.Theme do
    def apply_style(theme, style) do
      # Merge style into component_styles
      current_styles = theme.component_styles || %{}
      updated_styles = deep_merge_styles(current_styles, style)
      %{theme | component_styles: updated_styles}
    end

    def get_style(theme) do
      theme.component_styles || %{}
    end

    def merge_styles(theme, new_style) do
      current_styles = get_style(theme)
      merged = deep_merge_styles(current_styles, new_style)
      %{theme | component_styles: merged}
    end

    def reset_style(theme) do
      %{theme | component_styles: %{}}
    end

    def to_ansi(theme) do
      # Convert theme's default foreground/background to ANSI
      colors = theme.colors || %{}

      codes = []

      # Extract primary colors
      codes =
        case colors[:primary] do
          color when is_binary(color) ->
            rgb = hex_to_rgb(color)
            ["38;2;#{elem(rgb, 0)};#{elem(rgb, 1)};#{elem(rgb, 2)}" | codes]

          _ ->
            codes
        end

      codes =
        case colors[:background] do
          color when is_binary(color) ->
            rgb = hex_to_rgb(color)
            ["48;2;#{elem(rgb, 0)};#{elem(rgb, 1)};#{elem(rgb, 2)}" | codes]

          _ ->
            codes
        end

      case codes do
        [] -> ""
        codes -> "\e[#{Enum.join(codes, ";")}m"
      end
    end

    defp deep_merge_styles(current, new) when is_map(current) and is_map(new) do
      Map.merge(current, new, fn _key, v1, v2 ->
        case {is_map(v1), is_map(v2)} do
          {true, true} -> deep_merge_styles(v1, v2)
          _ -> v2
        end
      end)
    end

    defp deep_merge_styles(_current, new), do: new

    defp hex_to_rgb(color), do: ColorConversion.hex_to_rgb(color)
  end

  defimpl Renderable, for: Raxol.UI.Theming.Theme do
    def render(theme, opts \\ []) do
      format = Keyword.get(opts, :format, :preview)
      width = Keyword.get(opts, :width, 60)

      case format do
        :preview -> render_theme_preview(theme, width)
        :palette -> render_color_palette(theme, width)
        :info -> render_theme_info(theme)
        _ -> render_theme_preview(theme, width)
      end
    end

    def render_metadata(theme) do
      colors = theme.colors || %{}
      components = theme.component_styles || %{}

      %{
        width: 60,
        height: 10 + map_size(colors) + map_size(components),
        colors: true,
        scrollable: true,
        interactive: false,
        component_type: :theme,
        theme_name: theme.name,
        color_count: map_size(colors),
        component_count: map_size(components)
      }
    end

    defp render_theme_preview(theme, width) do
      title = "Theme: #{theme.name || "Unnamed"}"
      separator = String.duplicate("─", width)

      [
        center_text(title, width),
        separator,
        render_basic_info(theme),
        separator,
        render_color_swatches(theme, width),
        separator,
        render_component_styles_preview(theme, width)
      ]
      |> Enum.join("\n")
    end

    defp render_color_palette(theme, width) do
      colors = theme.colors || %{}

      title = "Color Palette - #{theme.name || "Theme"}"
      separator = String.duplicate("─", width)

      color_rows =
        colors
        |> Enum.map(fn {name, value} ->
          color_preview = render_color_swatch(value)
          name_str = String.pad_trailing(to_string(name), 15)
          value_str = to_string(value)
          "#{color_preview} #{name_str} #{value_str}"
        end)

      [title, separator | color_rows]
      |> Enum.join("\n")
    end

    defp render_theme_info(theme) do
      [
        "Theme Information:",
        "  Name: #{theme.name || "Unnamed"}",
        "  Description: #{theme.description || "No description"}",
        "  Dark Mode: #{theme.dark_mode || false}",
        "  High Contrast: #{theme.high_contrast || false}",
        "  Colors: #{map_size(theme.colors || %{})}",
        "  Component Styles: #{map_size(theme.component_styles || %{})}"
      ]
      |> Enum.join("\n")
    end

    defp render_basic_info(theme) do
      dark_mode = if theme.dark_mode, do: "Yes", else: "No"
      high_contrast = if theme.high_contrast, do: "Yes", else: "No"

      "Dark Mode: #{dark_mode}  |  High Contrast: #{high_contrast}"
    end

    defp render_color_swatches(theme, width) do
      colors = theme.colors || %{}

      case map_size(colors) do
        0 ->
          "No colors defined"

        _ ->
          colors
          # Limit based on width
          |> Enum.take(div(width, 12))
          |> Enum.map_join("  ", fn {name, value} ->
            swatch = render_color_swatch(value)
            "#{swatch} #{String.slice(to_string(name), 0, 8)}"
          end)
      end
    end

    defp render_component_styles_preview(theme, _width) do
      components = theme.component_styles || %{}

      case map_size(components) do
        0 -> "No component styles defined"
        _ -> "Component Styles: #{Enum.join(Map.keys(components), ", ")}"
      end
    end

    defp render_color_swatch(color_value) do
      case color_value do
        "#" <> _hex ->
          # Create a colored block using ANSI
          rgb = hex_to_rgb(color_value)
          "\e[48;2;#{elem(rgb, 0)};#{elem(rgb, 1)};#{elem(rgb, 2)}m  \e[0m"

        color when is_atom(color) ->
          ansi_code = color_name_to_ansi(color)
          "\e[#{ansi_code}m██\e[0m"

        _ ->
          "██"
      end
    end

    defp center_text(text, width) do
      padding = max(0, div(width - String.length(text), 2))
      String.duplicate(" ", padding) <> text
    end

    defp hex_to_rgb(color), do: ColorConversion.hex_to_rgb(color)

    defp color_name_to_ansi(color) do
      case color do
        :black -> "40"
        :red -> "41"
        :green -> "42"
        :yellow -> "43"
        :blue -> "44"
        :magenta -> "45"
        :cyan -> "46"
        :white -> "47"
        _ -> "40"
      end
    end
  end

  defimpl Serializable, for: Raxol.UI.Theming.Theme do
    def serialize(theme, :json) do
      data = %{
        id: theme.id,
        name: theme.name,
        description: theme.description,
        colors: serialize_colors_for_json(theme.colors),
        component_styles: theme.component_styles,
        variants: theme.variants,
        metadata: theme.metadata,
        fonts: theme.fonts,
        ui_mappings: theme.ui_mappings,
        dark_mode: theme.dark_mode,
        high_contrast: theme.high_contrast
      }

      case Jason.encode(data) do
        {:ok, json} -> json
        {:error, reason} -> {:error, reason}
      end
    end

    def serialize(theme, :toml) do
      # Convert theme to TOML format
      # Note: This is a simplified implementation
      _data = %{
        theme: %{
          id: theme.id,
          name: theme.name,
          description: theme.description,
          dark_mode: theme.dark_mode,
          high_contrast: theme.high_contrast
        },
        colors: theme.colors || %{},
        component_styles: theme.component_styles || %{}
      }

      try do
        # This would require a TOML library
        {:error, :toml_not_available}
      rescue
        _ -> {:error, :toml_encoding_failed}
      end
    end

    def serialize(theme, :binary) do
      :erlang.term_to_binary(theme)
    end

    def serialize(_theme, format) do
      {:error, {:unsupported_format, format}}
    end

    def serializable?(_theme, format) do
      format in [:json, :toml, :binary]
    end

    @spec serialize_colors_for_json(nil) :: nil
    defp serialize_colors_for_json(nil), do: nil

    @spec serialize_colors_for_json(map()) :: map()
    defp serialize_colors_for_json(colors) when is_map(colors) do
      Enum.into(colors, %{}, fn
        {key, %Raxol.Style.Colors.Color{} = color} ->
          {key, to_string(color)}

        {key, value} ->
          {key, value}
      end)
    end

    @spec serialize_colors_for_json(any()) :: any()
    defp serialize_colors_for_json(colors), do: colors
  end

  # Color Protocol Enhancement
  defimpl Renderable, for: Raxol.Style.Colors.Color do
    def render(color, opts \\ []) do
      format = Keyword.get(opts, :format, :swatch)
      show_info = Keyword.get(opts, :info, false)

      case format do
        :swatch -> render_color_swatch(color, show_info)
        :hex -> color.hex || "#000000"
        :rgb -> "rgb(#{color.r}, #{color.g}, #{color.b})"
        :ansi -> render_ansi_preview(color)
        _ -> render_color_swatch(color, show_info)
      end
    end

    def render_metadata(color) do
      %{
        width: 20,
        height: if(color.name, do: 3, else: 2),
        colors: true,
        scrollable: false,
        interactive: false,
        component_type: :color,
        hex_value: color.hex,
        ansi_code: color.ansi_code
      }
    end

    defp render_color_swatch(color, show_info) do
      # Create colored block
      ansi_bg = "\e[48;2;#{color.r};#{color.g};#{color.b}m"
      reset = "\e[0m"
      swatch = "#{ansi_bg}    #{reset}"

      case show_info do
        true ->
          hex = color.hex || "#000000"
          name = if color.name, do: " (#{color.name})", else: ""
          "#{swatch} #{hex}#{name}"

        false ->
          swatch
      end
    end

    defp render_ansi_preview(color) do
      ansi_bg = "\e[48;2;#{color.r};#{color.g};#{color.b}m"
      ansi_fg = "\e[38;2;#{255 - color.r};#{255 - color.g};#{255 - color.b}m"
      reset = "\e[0m"

      "#{ansi_bg}#{ansi_fg} SAMPLE TEXT #{reset}"
    end
  end

  # Enhanced Styleable for Color
  defimpl Styleable, for: Raxol.Style.Colors.Color do
    def apply_style(color, style) do
      # Apply style properties to color
      Map.merge(color, style)
    end

    def get_style(color) do
      %{
        foreground: {color.r, color.g, color.b},
        hex: color.hex,
        name: color.name
      }
    end

    def merge_styles(color, new_style) do
      Map.merge(color, new_style)
    end

    def reset_style(color) do
      %{color | r: 0, g: 0, b: 0, hex: "#000000", name: nil}
    end

    def to_ansi(color) do
      "\e[38;2;#{color.r};#{color.g};#{color.b}m"
    end
  end
end
