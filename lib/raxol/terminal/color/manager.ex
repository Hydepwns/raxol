defmodule Raxol.Terminal.Color.Manager do
  @moduledoc """
  Manages color operations for the terminal emulator.
  This module handles color palette management, color setting, and color queries.
  """

  alias Raxol.Terminal.Emulator

  @doc """
  Updates the emulator's color palette with new colors.

  ## Parameters

  * `emulator` - The emulator instance
  * `colors` - Map of color indices to color values

  ## Returns

  Updated emulator with new color palette
  """
  @spec set_colors(Emulator.t(), map()) :: Emulator.t()
  def set_colors(%Emulator{} = emulator, colors) when is_map(colors) do
    %{emulator | color_palette: colors}
  end

  @doc """
  Gets the current color palette.

  ## Parameters

  * `emulator` - The emulator instance

  ## Returns

  The current color palette map
  """
  @spec get_colors(Emulator.t()) :: map()
  def get_colors(%Emulator{} = emulator) do
    emulator.color_palette
  end

  @doc """
  Gets a specific color from the palette.

  ## Parameters

  * `emulator` - The emulator instance
  * `index` - The color index to retrieve

  ## Returns

  The color value or nil if not found
  """
  @spec get_color(Emulator.t(), non_neg_integer()) :: String.t() | nil
  def get_color(%Emulator{} = emulator, index) when is_integer(index) and index >= 0 do
    Map.get(emulator.color_palette, index)
  end

  @doc """
  Sets a specific color in the palette.

  ## Parameters

  * `emulator` - The emulator instance
  * `index` - The color index to set
  * `color` - The color value to set

  ## Returns

  Updated emulator with new color value
  """
  @spec set_color(Emulator.t(), non_neg_integer(), String.t()) :: Emulator.t()
  def set_color(%Emulator{} = emulator, index, color)
      when is_integer(index) and index >= 0 and is_binary(color) do
    new_palette = Map.put(emulator.color_palette, index, color)
    %{emulator | color_palette: new_palette}
  end

  @doc """
  Resets the color palette to default values.

  ## Parameters

  * `emulator` - The emulator instance

  ## Returns

  Updated emulator with default color palette
  """
  @spec reset_colors(Emulator.t()) :: Emulator.t()
  def reset_colors(%Emulator{} = emulator) do
    %{emulator | color_palette: default_palette()}
  end

  @doc """
  Gets the default color palette.

  ## Returns

  Map containing the default color palette
  """
  @spec default_palette() :: map()
  def default_palette do
    %{
      0 => "#000000",  # Black
      1 => "#800000",  # Red
      2 => "#008000",  # Green
      3 => "#808000",  # Yellow
      4 => "#000080",  # Blue
      5 => "#800080",  # Magenta
      6 => "#008080",  # Cyan
      7 => "#c0c0c0",  # White
      8 => "#808080",  # Bright Black
      9 => "#ff0000",  # Bright Red
      10 => "#00ff00", # Bright Green
      11 => "#ffff00", # Bright Yellow
      12 => "#0000ff", # Bright Blue
      13 => "#ff00ff", # Bright Magenta
      14 => "#00ffff", # Bright Cyan
      15 => "#ffffff"  # Bright White
    }
  end

  @doc """
  Converts a color index to an RGB value.

  ## Parameters

  * `emulator` - The emulator instance
  * `index` - The color index to convert

  ## Returns

  Tuple of {r, g, b} values or nil if color not found
  """
  @spec color_to_rgb(Emulator.t(), non_neg_integer()) :: {non_neg_integer(), non_neg_integer(), non_neg_integer()} | nil
  def color_to_rgb(%Emulator{} = emulator, index) when is_integer(index) and index >= 0 do
    case get_color(emulator, index) do
      nil -> nil
      color -> hex_to_rgb(color)
    end
  end

  # Private helper functions

  defp hex_to_rgb(hex) when is_binary(hex) do
    case String.trim(hex, "#") do
      <<r::binary-size(2), g::binary-size(2), b::binary-size(2)>> ->
        {String.to_integer(r, 16), String.to_integer(g, 16), String.to_integer(b, 16)}
      _ -> nil
    end
  end
end
