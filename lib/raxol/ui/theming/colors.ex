defmodule Raxol.UI.Theming.Colors do
  @moduledoc """
  Color management utilities for theme handling.

  This module provides functions for working with colors in the context of UI theming,
  including color format conversion, manipulation, and theme-specific operations.

  ## Features

  - Color format conversion (hex, RGB, ANSI)
  - Color manipulation (lighten, darken, blend)
  - Theme color management
  - Accessibility checks
  """

  alias Raxol.Style.Colors.{Color, Utilities}

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
  Converts a hex color string to RGB values.

  ## Examples

      iex> hex_to_rgb("#FF0000")
      {255, 0, 0}
  """
  def hex_to_rgb(hex) when is_binary(hex) do
    color = Color.from_hex(hex)
    {color.r, color.g, color.b}
  end

  @doc """
  Converts RGB values to a hex color string.

  ## Examples

      iex> rgb_to_hex(255, 0, 0)
      "#FF0000"
  """
  def rgb_to_hex(r, g, b) when r in 0..255 and g in 0..255 and b in 0..255 do
    Color.from_rgb(r, g, b).hex
  end

  @doc """
  Converts an ANSI color code to RGB values.

  ## Examples

      iex> ansi_to_rgb(1)
      {205, 0, 0}
  """
  def ansi_to_rgb(code) when code in 0..255 do
    color = Color.from_ansi(code)
    {color.r, color.g, color.b}
  end

  @doc """
  Converts RGB values to the closest ANSI color code.

  ## Examples

      iex> rgb_to_ansi(255, 0, 0)
      196
  """
  def rgb_to_ansi(r, g, b) when r in 0..255 and g in 0..255 and b in 0..255 do
    Color.from_rgb(r, g, b) |> Color.to_ansi_256()
  end

  @doc """
  Lightens a color by the specified amount.

  ## Examples

      iex> lighten("#000000", 0.5)
      "#808080"
      iex> lighten(:red, 0.5)
      "#FF8080"
  """
  def lighten(color, amount) when is_integer(amount) and amount >= 0 and amount <= 100 do
    lighten(color, amount / 100)
  end

  def lighten(color, amount) when is_float(amount) and amount >= 0 and amount <= 1 do
    hex = to_hex(color)

    case hex_to_rgb(hex) do
      {r, g, b} ->
        # Simple linear interpolation with white
        r = round(r + (255 - r) * amount)
        g = round(g + (255 - g) * amount)
        b = round(b + (255 - b) * amount)
        rgb_to_hex(r, g, b)

      {:error, _} = err ->
        err
    end
  end

  @doc """
  Darkens a color by the specified amount.

  ## Examples

      iex> darken("#FFFFFF", 0.5)
      "#808080"
      iex> darken(:red, 0.5)
      "#800000"
  """
  def darken(color, amount) when is_integer(amount) and amount >= 0 and amount <= 100 do
    darken(color, amount / 100)
  end

  def darken(color, amount) when is_float(amount) and amount >= 0 and amount <= 1 do
    hex = to_hex(color)

    case hex_to_rgb(hex) do
      {r, g, b} ->
        # Simple linear interpolation with black
        r = round(r * (1 - amount))
        g = round(g * (1 - amount))
        b = round(b * (1 - amount))
        rgb_to_hex(r, g, b)

      {:error, _} = err ->
        err
    end
  end

  @doc """
  Blends two colors with the specified alpha value.

  ## Examples

      iex> blend("#FF0000", "#0000FF", 0.5)
      "#800080"
      iex> blend(:red, :blue, 0.5)
      "#800080"
  """
  def blend(color1, color2, alpha) when alpha >= 0 and alpha <= 1 do
    hex1 = to_hex(color1)
    hex2 = to_hex(color2)

    {r1, g1, b1} = hex_to_rgb(hex1)
    {r2, g2, b2} = hex_to_rgb(hex2)

    r = round(r1 * alpha + r2 * (1 - alpha))
    g = round(g1 * alpha + g2 * (1 - alpha))
    b = round(b1 * alpha + b2 * (1 - alpha))

    rgb_to_hex(r, g, b)
  end

  @doc """
  Calculates the contrast ratio between two colors.

  ## Examples

      iex> contrast_ratio("#FFFFFF", "#000000")
      21.0
      iex> contrast_ratio(:white, :black)
      21.0
  """
  def contrast_ratio(color1, color2) do
    hex1 = to_hex(color1)
    hex2 = to_hex(color2)

    c1 = Color.from_hex(hex1)
    c2 = Color.from_hex(hex2)
    Utilities.contrast_ratio(c1, c2)
  end

  @doc """
  Checks if two colors meet WCAG contrast requirements.

  ## Examples

      iex> meets_contrast_requirements?("#FFFFFF", "#000000", :AA, :normal)
      true
  """
  def meets_contrast_requirements?(color1, color2, level, size) do
    hex1 = to_hex(color1)
    hex2 = to_hex(color2)

    c1 = Color.from_hex(hex1)
    c2 = Color.from_hex(hex2)
    Utilities.meets_contrast_requirements?(c1, c2, level, size)
  end

  @doc """
  Converts RGB values to HSL values.

  ## Examples

      iex> rgb_to_hsl(255, 0, 0)
      {0, 1.0, 0.5}
  """
  def rgb_to_hsl(r, g, b) when r in 0..255 and g in 0..255 and b in 0..255 do
    Utilities.rgb_to_hsl(r, g, b)
  end

  @doc """
  Converts HSL values to RGB values.

  ## Examples

      iex> hsl_to_rgb(0, 1.0, 0.5)
      {255, 0, 0}
  """
  def hsl_to_rgb(h, s, l)
      when h >= 0 and h <= 360 and s >= 0 and s <= 1 and l >= 0 and l <= 1 do
    Utilities.hsl_to_rgb(h, s, l)
  end

  @doc """
  Converts a color from one format to RGB values.

  ## Examples

      iex> Colors.to_rgb("#FF0000")
      {255, 0, 0}

      iex> Colors.to_rgb(:blue)
      {0, 0, 255}
  """
  def to_rgb(color) do
    case color do
      hex when is_binary(hex) -> hex_to_rgb(hex)
      name when is_atom(name) -> hex_to_rgb(@color_names[name])
      {r, g, b} when r in 0..255 and g in 0..255 and b in 0..255 -> {r, g, b}
    end
  end

  @doc """
  Converts a color to its hex representation.

  ## Examples

      iex> Colors.to_hex(:red)
      "#FF0000"

      iex> Colors.to_hex("#00FF00")
      "#00FF00"
  """
  def to_hex(color) do
    case color do
      hex when is_binary(hex) ->
        hex

      name when is_atom(name) ->
        @color_names[name]

      {r, g, b} when r in 0..255 and g in 0..255 and b in 0..255 ->
        rgb_to_hex(r, g, b)
    end
  end

  @doc """
  Converts a color to its ANSI representation.

  ## Examples

      iex> Colors.to_ansi(:red)
      196

      iex> Colors.to_ansi("#FF0000")
      196
  """
  def to_ansi(color) do
    {r, g, b} = to_rgb(color)
    rgb_to_ansi(r, g, b)
  end

  @doc """
  Converts a color to its ANSI 16-color representation.

  ## Examples

      iex> Colors.to_ansi_16(:red)
      1

      iex> Colors.to_ansi_16("#FF0000")
      1
  """
  def to_ansi_16(color) do
    {r, g, b} = to_rgb(color)
    Color.from_rgb(r, g, b) |> Color.to_ansi_16()
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

  @doc """
  Checks if two colors are accessible according to WCAG contrast requirements.

  ## Examples

      iex> accessible?("#FFFFFF", "#000000", :aa, :normal)
      true
  """
  def accessible?(color1, color2, level, size) do
    meets_contrast_requirements?(color1, color2, level, size)
  end
end
