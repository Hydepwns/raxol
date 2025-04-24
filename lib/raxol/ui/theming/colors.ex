defmodule Raxol.UI.Theming.Colors do
  @moduledoc """
  Color management utilities for theme handling.

  This module provides functions for:
  - Converting between color formats
  - Color manipulation (lighten, darken, alpha blend)
  - Calculating color contrast
  - Validating color accessibility
  """

  @type color_hex :: String.t()  # Format: "#RRGGBB" or "#RRGGBBAA"
  @type color_rgb :: {red :: 0..255, green :: 0..255, blue :: 0..255}
  @type color_rgba :: {red :: 0..255, green :: 0..255, blue :: 0..255, alpha :: 0..255}
  @type color_hsl :: {hue :: 0..360, saturation :: 0..100, lightness :: 0..100}
  @type color_name :: atom()  # Named colors like :red, :blue, etc.

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

  def to_rgb(hex_color) when is_binary(hex_color) and byte_size(hex_color) >= 7 do
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

  ## Examples

      iex> Colors.lighten("#FF0000", 20)
      "#FF6666"
  """
  @spec lighten(color_hex | color_name, percentage :: 0..100) :: color_hex
  def lighten(color, percentage) when percentage >= 0 and percentage <= 100 do
    {r, g, b} = to_rgb(color)

    # Increase each component by the percentage
    r_new = min(r + trunc((255 - r) * percentage / 100), 255)
    g_new = min(g + trunc((255 - g) * percentage / 100), 255)
    b_new = min(b + trunc((255 - b) * percentage / 100), 255)

    to_hex({r_new, g_new, b_new})
  end

  @doc """
  Darkens a color by the specified percentage.

  ## Examples

      iex> Colors.darken("#FF0000", 20)
      "#CC0000"
  """
  @spec darken(color_hex | color_name, percentage :: 0..100) :: color_hex
  def darken(color, percentage) when percentage >= 0 and percentage <= 100 do
    {r, g, b} = to_rgb(color)

    # Decrease each component by the percentage
    r_new = max(r - trunc(r * percentage / 100), 0)
    g_new = max(g - trunc(g * percentage / 100), 0)
    b_new = max(b - trunc(b * percentage / 100), 0)

    to_hex({r_new, g_new, b_new})
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
  @spec accessible?(color_hex | color_name, color_hex | color_name,
                   level :: :aa | :aaa, type :: :normal | :large) :: boolean
  def accessible?(color1, color2, level \\ :aa, type \\ :normal) do
    ratio = contrast_ratio(color1, color2)

    min_ratio = case {level, type} do
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
  @spec blend(color_hex | color_name, color_hex | color_name, alpha :: 0..1) :: color_hex
  def blend(color1, color2, alpha) when alpha >= 0 and alpha <= 1 do
    {r1, g1, b1} = to_rgb(color1)
    {r2, g2, b2} = to_rgb(color2)

    r = r1 * alpha + r2 * (1 - alpha) |> round()
    g = g1 * alpha + g2 * (1 - alpha) |> round()
    b = b1 * alpha + b2 * (1 - alpha) |> round()

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

    r_linear = if r_srgb <= 0.03928, do: r_srgb / 12.92, else: :math.pow((r_srgb + 0.055) / 1.055, 2.4)
    g_linear = if g_srgb <= 0.03928, do: g_srgb / 12.92, else: :math.pow((g_srgb + 0.055) / 1.055, 2.4)
    b_linear = if b_srgb <= 0.03928, do: b_srgb / 12.92, else: :math.pow((b_srgb + 0.055) / 1.055, 2.4)

    0.2126 * r_linear + 0.7152 * g_linear + 0.0722 * b_linear
  end
end
