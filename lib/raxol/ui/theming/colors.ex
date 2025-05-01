defmodule Raxol.UI.Theming.Colors do
  @moduledoc """
  Color management utilities for theme handling.

  This module provides functions for:
  - Converting between color formats
  - Color manipulation (lighten, darken, alpha blend)
  - Calculating color contrast
  - Validating color accessibility
  """

  alias Raxol.Style.Colors.HSL

  # Format: "#RRGGBB" or "#RRGGBBAA"
  @type color_hex :: String.t()
  @type color_rgb :: {red :: 0..255, green :: 0..255, blue :: 0..255}
  @type color_rgba ::
          {red :: 0..255, green :: 0..255, blue :: 0..255, alpha :: 0..255}
  @type color_hsl :: {hue :: 0..360, saturation :: 0..100, lightness :: 0..100}
  # Named colors like :red, :blue, etc.
  @type color_name :: atom()

  @color_names %{
    black: "#000000",
    white: "#FFFFFF",
    red: "#FF0000",
    green: "#00FF00",
    blue: "#0000FF",
    yellow: "#FFFF00",
    cyan: "#00FFFF",
    magenta: "#FF00FF",
    gray: "#808080",
    lightgray: "#D3D3D3",
    darkgray: "#A9A9A9",
    purple: "#800080",
    orange: "#FFA500",
    pink: "#FFC0CB",
    brown: "#A52A2A"
  }

  @doc """
  Converts a color from one format to RGB values.

  ## Examples

      iex> Colors.to_rgb("#FF0000")
      {255, 0, 0}

      iex> Colors.to_rgb(:blue)
      {0, 0, 255}
  """
  @spec to_rgb(color_hex | color_name) :: color_rgb
  def to_rgb(color)

  def to_rgb(hex_color)
      when is_binary(hex_color) and byte_size(hex_color) >= 7 do
    hex_color
    |> String.trim_leading("#")
    |> String.downcase()
    |> parse_hex_color()
  end

  def to_rgb(color_name) when is_atom(color_name) do
    color_name
    |> get_hex_from_name()
    |> to_rgb()
  end

  @doc """
  Converts RGB values to a hex color string.

  ## Examples

      iex> Colors.to_hex({255, 0, 0})
      "#FF0000"
  """
  @spec to_hex(color_rgb | color_rgba) :: color_hex
  def to_hex({r, g, b}) do
    "##{to_hex_component(r)}#{to_hex_component(g)}#{to_hex_component(b)}"
  end

  def to_hex({r, g, b, a}) do
    "##{to_hex_component(r)}#{to_hex_component(g)}#{to_hex_component(b)}#{to_hex_component(a)}"
  end

  @doc """
  Lightens a color by the specified percentage.

  Uses HSL color space for more perceptually uniform lightening.

  ## Examples

      iex> Colors.lighten("#FF0000", 20)
      "#FF6666"
  """
  @spec lighten(color_hex | color_name, percentage :: 0..100) :: color_hex
  def lighten(color, percentage) when percentage >= 0 and percentage <= 100 do
    {r, g, b} = to_rgb(color)
    {h, s, l} = HSL.rgb_to_hsl(r, g, b)

    # Adjust lightness, ensuring it stays within 0.0 to 1.0
    l_adjust = percentage / 100.0
    new_l = min(l + l_adjust, 1.0)

    {new_r, new_g, new_b} = HSL.hsl_to_rgb(h, s, new_l)

    # Convert back to hex
    to_hex({round(new_r), round(new_g), round(new_b)})
  end

  @doc """
  Darkens a color by the specified percentage.

  Uses HSL color space for more perceptually uniform darkening.

  ## Examples

      iex> Colors.darken("#FF0000", 20)
      "#CC0000"
  """
  @spec darken(color_hex | color_name, percentage :: 0..100) :: color_hex
  def darken(color, percentage) when percentage >= 0 and percentage <= 100 do
    {r, g, b} = to_rgb(color)
    {h, s, l} = HSL.rgb_to_hsl(r, g, b)

    # Adjust lightness, ensuring it stays within 0.0 to 1.0
    l_adjust = percentage / 100.0
    new_l = max(l - l_adjust, 0.0)

    {new_r, new_g, new_b} = HSL.hsl_to_rgb(h, s, new_l)

    # Convert back to hex
    to_hex({round(new_r), round(new_g), round(new_b)})
  end

  @doc """
  Calculates the contrast ratio between two colors.

  Returns a value between 1 and 21, with 21 being the highest contrast.

  ## Examples

      iex> Colors.contrast_ratio("#FFFFFF", "#000000")
      21.0
  """
  @spec contrast_ratio(color_hex | color_name, color_hex | color_name) :: float
  def contrast_ratio(color1, color2) do
    # Convert colors to relative luminance
    lum1 = relative_luminance(to_rgb(color1))
    lum2 = relative_luminance(to_rgb(color2))

    # Calculate contrast ratio
    {lighter, darker} = if lum1 > lum2, do: {lum1, lum2}, else: {lum2, lum1}
    (lighter + 0.05) / (darker + 0.05)
  end

  @doc """
  Checks if the contrast ratio between two colors meets accessibility standards.

  ## Parameters

  * `color1` - The first color
  * `color2` - The second color
  * `level` - The WCAG accessibility level to check for (:aa or :aaa)
  * `type` - The text type (:normal or :large)

  ## Examples

      iex> Colors.accessible?("#FFFFFF", "#000000", :aa, :normal)
      true
  """
  @spec accessible?(
          color_hex | color_name,
          color_hex | color_name,
          level :: :aa | :aaa,
          type :: :normal | :large
        ) :: boolean
  def accessible?(color1, color2, level \\ :aa, type \\ :normal) do
    ratio = contrast_ratio(color1, color2)

    min_ratio =
      case {level, type} do
        {:aa, :normal} -> 4.5
        {:aa, :large} -> 3.0
        {:aaa, :normal} -> 7.0
        {:aaa, :large} -> 4.5
      end

    ratio >= min_ratio
  end

  @doc """
  Blends two colors together with the specified alpha value.

  ## Examples

      iex> Colors.blend("#FF0000", "#0000FF", 0.5)
      "#800080"
  """
  @spec blend(color_hex | color_name, color_hex | color_name, alpha :: 0..1) ::
          color_hex
  def blend(color1, color2, alpha) when alpha >= 0 and alpha <= 1 do
    {r1, g1, b1} = to_rgb(color1)
    {r2, g2, b2} = to_rgb(color2)

    r = (r1 * alpha + r2 * (1 - alpha)) |> round()
    g = (g1 * alpha + g2 * (1 - alpha)) |> round()
    b = (b1 * alpha + b2 * (1 - alpha)) |> round()

    to_hex({r, g, b})
  end

  # Private helpers

  defp parse_hex_color(hex) when byte_size(hex) == 6 do
    # Parse RGB hex values
    {
      String.slice(hex, 0, 2) |> String.to_integer(16),
      String.slice(hex, 2, 2) |> String.to_integer(16),
      String.slice(hex, 4, 2) |> String.to_integer(16)
    }
  end

  defp parse_hex_color(hex) when byte_size(hex) == 8 do
    # Parse RGBA hex values
    {
      String.slice(hex, 0, 2) |> String.to_integer(16),
      String.slice(hex, 2, 2) |> String.to_integer(16),
      String.slice(hex, 4, 2) |> String.to_integer(16),
      String.slice(hex, 6, 2) |> String.to_integer(16)
    }
  end

  defp parse_hex_color(hex) when byte_size(hex) == 3 do
    # Handle shorthand hex (#RGB)
    r = String.at(hex, 0) |> String.duplicate(2) |> String.to_integer(16)
    g = String.at(hex, 1) |> String.duplicate(2) |> String.to_integer(16)
    b = String.at(hex, 2) |> String.duplicate(2) |> String.to_integer(16)
    {r, g, b}
  end

  defp to_hex_component(value) do
    value
    |> Integer.to_string(16)
    |> String.pad_leading(2, "0")
    |> String.upcase()
  end

  defp get_hex_from_name(color_name) do
    Map.get(@color_names, color_name, "#000000")
  end

  defp relative_luminance({r, g, b}) do
    # Convert RGB to relative luminance following WCAG formula
    r_srgb = r / 255
    g_srgb = g / 255
    b_srgb = b / 255

    r_linear =
      if r_srgb <= 0.03928,
        do: r_srgb / 12.92,
        else: :math.pow((r_srgb + 0.055) / 1.055, 2.4)

    g_linear =
      if g_srgb <= 0.03928,
        do: g_srgb / 12.92,
        else: :math.pow((g_srgb + 0.055) / 1.055, 2.4)

    b_linear =
      if b_srgb <= 0.03928,
        do: b_srgb / 12.92,
        else: :math.pow((b_srgb + 0.055) / 1.055, 2.4)

    0.2126 * r_linear + 0.7152 * g_linear + 0.0722 * b_linear
  end

  # --- ANSI Color Palette Conversion ---

  @ansi_basic_colors [
    # Standard 8 colors
    # Black
    {0, {0, 0, 0}},
    # Red
    {1, {128, 0, 0}},
    # Green
    {2, {0, 128, 0}},
    # Yellow
    {3, {128, 128, 0}},
    # Blue
    {4, {0, 0, 128}},
    # Magenta
    {5, {128, 0, 128}},
    # Cyan
    {6, {0, 128, 128}},
    # White (Light Gray)
    {7, {192, 192, 192}},
    # Bright 8 colors
    # Bright Black (Dark Gray)
    {8, {128, 128, 128}},
    # Bright Red
    {9, {255, 0, 0}},
    # Bright Green
    {10, {0, 255, 0}},
    # Bright Yellow
    {11, {255, 255, 0}},
    # Bright Blue
    {12, {0, 0, 255}},
    # Bright Magenta
    {13, {255, 0, 255}},
    # Bright Cyan
    {14, {0, 255, 255}},
    # Bright White
    {15, {255, 255, 255}}
  ]

  # Generate 216 colors (6x6x6 cube)
  @ansi_216_colors (for r <- 0..5, g <- 0..5, b <- 0..5 do
                      index = 16 + 36 * r + 6 * g + b
                      red = if r == 0, do: 0, else: 55 + r * 40
                      green = if g == 0, do: 0, else: 55 + g * 40
                      blue = if b == 0, do: 0, else: 55 + b * 40
                      {index, {red, green, blue}}
                    end)

  # Generate 24 grayscale colors
  @ansi_grayscale_colors (for i <- 0..23 do
                            index = 232 + i
                            level = 8 + i * 10
                            {index, {level, level, level}}
                          end)

  @ansi_256_colors @ansi_basic_colors ++
                     @ansi_216_colors ++ @ansi_grayscale_colors

  # --- Palette Generation --- #

  # Note: No @doc as it's private
  defp color_distance_sq({r1, g1, b1}, {r2, g2, b2}) do
    dr = r1 - r2
    dg = g1 - g2
    db = b1 - b2
    dr * dr + dg * dg + db * db
  end

  @doc """
  Finds the closest ANSI basic color index (0-15) to the given RGB color.
  """
  @spec find_closest_basic_color(color_rgb) :: 0..15
  def find_closest_basic_color(rgb) do
    @ansi_basic_colors
    |> Enum.min_by(fn {_index, ansi_rgb} ->
      color_distance_sq(rgb, ansi_rgb)
    end)
    |> elem(0)
  end

  @doc """
  Finds the closest ANSI 256-color index (0-255) to the given RGB color.
  """
  @spec find_closest_256_color(color_rgb) :: 0..255
  def find_closest_256_color(rgb) do
    @ansi_256_colors
    |> Enum.min_by(fn {_index, ansi_rgb} ->
      color_distance_sq(rgb, ansi_rgb)
    end)
    |> elem(0)
  end

  def convert_to_basic(color) when is_tuple(color),
    do: find_closest_basic_color(color)

  def convert_to_basic(theme) when is_map(theme) do
    Map.new(theme, fn {key, value} ->
      {key, convert_to_basic(value)}
    end)
  end

  # Return non-color values as is
  def convert_to_basic(value), do: value

  @doc """
  Converts a color or theme map to use a specific palette (e.g., 256 colors).
  Finds the closest color in the palette for each color in the theme.
  *Currently only supports named palettes like :xterm256*
  """
  def convert_to_palette(value, palette_name \\ :xterm256)

  def convert_to_palette(color, palette_name) when is_tuple(color) do
    find_closest_palette_color(color, palette_name)
  end

  def convert_to_palette(theme, palette_name) when is_map(theme) do
    Map.new(theme, fn {key, value} ->
      {key, convert_to_palette(value, palette_name)}
    end)
  end

  def convert_to_palette(value, _palette_name), do: value

  # Helper function
  defp find_closest_palette_color(rgb, palette_name) do
    palette =
      case palette_name do
        :xterm256 -> @ansi_256_colors
        :basic -> @ansi_basic_colors
        # TODO: Add support for other palettes or custom palettes
        # Default to 256
        _ -> @ansi_256_colors
      end

    palette
    |> Enum.min_by(fn {_index, palette_rgb} ->
      color_distance_sq(rgb, palette_rgb)
    end)
    |> elem(0)
  end

  # --- Distance Calculation --- #

  # Removed unused distance/2 function
  # defp distance(c1, c2), do: :math.sqrt(color_distance_sq(c1, c2))
end
