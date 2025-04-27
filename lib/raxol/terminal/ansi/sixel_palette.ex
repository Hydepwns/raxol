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
end
