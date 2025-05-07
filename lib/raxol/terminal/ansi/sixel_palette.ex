defmodule Raxol.Terminal.ANSI.SixelPalette do
  @moduledoc """
  Handles Sixel color palette management.

  Provides functions to initialize the default palette and potentially
  manage custom color definitions in the future.
  """

  @doc """
  Initializes the default Sixel color palette (256 colors).
  """
  @spec initialize_palette() :: map()
  def initialize_palette do
    # Standard 16 colors
    base_palette = %{
      # Black
      0 => {0, 0, 0},
      # Red
      1 => {205, 0, 0},
      # Green
      2 => {0, 205, 0},
      # Yellow
      3 => {205, 205, 0},
      # Blue
      4 => {0, 0, 238},
      # Magenta
      5 => {205, 0, 205},
      # Cyan
      6 => {0, 205, 205},
      # White
      7 => {229, 229, 229},
      # Bright Black
      8 => {127, 127, 127},
      # Bright Red
      9 => {255, 0, 0},
      # Bright Green
      10 => {0, 255, 0},
      # Bright Yellow
      11 => {255, 255, 0},
      # Bright Blue
      12 => {92, 92, 255},
      # Bright Magenta
      13 => {255, 0, 255},
      # Bright Cyan
      14 => {0, 255, 255},
      # Bright White
      15 => {255, 255, 255}
    }

    # Add 240 additional colors (16-255)
    Enum.reduce(16..255, base_palette, fn i, acc ->
      case i do
        # RGB cube (16-231)
        n when n <= 231 ->
          code = n - 16
          # Scale values from 0-5 range to 0-255 range (approximately)
          # Using 51 which is 255 / 5
          r = div(code, 36) * 51
          g = rem(div(code, 6), 6) * 51
          b = rem(code, 6) * 51
          Map.put(acc, i, {r, g, b})

        # Grayscale (232-255)
        n ->
          # Scale values from 0-23 range to 0-255 range (approximately)
          # Using 10 which is roughly 255 / 24, plus a base of 8
          value = (n - 232) * 10 + 8
          Map.put(acc, i, {value, value, value})
      end
    end)
  end

  @doc """
  Returns the maximum valid color index (typically 255 for a 256-color palette).
  """
  @spec max_colors() :: non_neg_integer()
  def max_colors(), do: 255

  # TODO: Add functions for defining custom colors via Sixel '#' command
  # e.g., define_color(palette, index, format, p1, p2, p3, p4, p5)

  # --- Color Conversion Helpers ---

  @doc """
  Converts color parameters based on the specified color space.

  Handles clamping values and delegation to specific conversion functions.
  Supports HLS (1) and RGB (2).
  """
  @spec convert_color(integer(), integer(), integer(), integer()) :: {:ok, {non_neg_integer(), non_neg_integer(), non_neg_integer()}} | {:error, atom()}
  def convert_color(color_space, px, py, pz) do
    # Clamp values to 0-100 range
    px = max(0, min(100, px))
    py = max(0, min(100, py))
    pz = max(0, min(100, pz))

    case color_space do
      # HLS (Hue: Px=H/3.6 (0-100), Lightness: Py (0-100), Saturation: Pz (0-100))
      1 ->
        # H is 0-360
        h = px * 3.6
        # L is 0-1
        l = py / 100.0
        # S is 0-1
        s = pz / 100.0
        # Clamp h to 0-360 range using fmod for floats
        h = :math.fmod(h, 360.0)
        h = if h < 0.0, do: h + 360.0, else: h
        hls_to_rgb(h, l, s)

      # RGB (R: Px, G: Py, B: Pz - all 0-100)
      2 ->
        # Scale 0-100 to 0-255
        r = round(px * 2.55)
        g = round(py * 2.55)
        b = round(pz * 2.55)
        {:ok, {r, g, b}}

      _ ->
        {:error, :unknown_color_space}
    end
  end

  @doc """
  Simplified HLS to RGB conversion (based on standard formulas).

  Input: H (0-360), L (0-1), S (0-1)
  Output: {:ok, {R, G, B}} (0-255)
  """
  @spec hls_to_rgb(float(), float(), float()) :: {:ok, {non_neg_integer(), non_neg_integer(), non_neg_integer()}}
  def hls_to_rgb(h, l, s) do
    # Clamp inputs
    h = max(0.0, min(360.0, h))
    l = max(0.0, min(1.0, l))
    s = max(0.0, min(1.0, s))

    if s == 0 do
      # Achromatic
      grey = round(l * 255)
      {:ok, {grey, grey, grey}}
    else
      c = (1.0 - abs(2.0 * l - 1.0)) * s
      h_prime = h / 60.0
      x = c * (1.0 - abs(:math.fmod(h_prime, 2.0) - 1.0))
      m = l - c / 2.0

      {r1, g1, b1} =
        cond do
          h_prime >= 0 and h_prime < 1 -> {c, x, 0.0}
          h_prime >= 1 and h_prime < 2 -> {x, c, 0.0}
          h_prime >= 2 and h_prime < 3 -> {0.0, c, x}
          h_prime >= 3 and h_prime < 4 -> {0.0, x, c}
          h_prime >= 4 and h_prime < 5 -> {x, 0.0, c}
          # Fix: Allow h_prime == 6 (Hue 360)
          h_prime >= 5 and h_prime <= 6 -> {c, 0.0, x}
          # Should not happen with clamping
          true -> {0.0, 0.0, 0.0}
        end

      r = round((r1 + m) * 255)
      g = round((g1 + m) * 255)
      b = round((b1 + m) * 255)
      # Ensure values are within 0-255 after rounding
      r = max(0, min(255, r))
      g = max(0, min(255, g))
      b = max(0, min(255, b))
      {:ok, {r, g, b}}
    end
  end
end
