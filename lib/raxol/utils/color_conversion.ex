defmodule Raxol.Utils.ColorConversion do
  @moduledoc """
  Utility functions for color conversions between hex and RGB formats.
  """

  @doc """
  Convert hex color to RGB tuple.

  ## Examples

      iex> Raxol.Utils.ColorConversion.hex_to_rgb("#FF0000")
      {255, 0, 0}

      iex> Raxol.Utils.ColorConversion.hex_to_rgb("#00FF00")
      {0, 255, 0}

      iex> Raxol.Utils.ColorConversion.hex_to_rgb("invalid")
      {0, 0, 0}
  """
  @spec hex_to_rgb(String.t()) ::
          {non_neg_integer(), non_neg_integer(), non_neg_integer()}
  def hex_to_rgb("#" <> hex) when byte_size(hex) == 6 do
    {r, ""} = Integer.parse(String.slice(hex, 0, 2), 16)
    {g, ""} = Integer.parse(String.slice(hex, 2, 2), 16)
    {b, ""} = Integer.parse(String.slice(hex, 4, 2), 16)
    {r, g, b}
  end

  def hex_to_rgb(_), do: {0, 0, 0}

  @doc """
  Convert RGB tuple to hex color.

  ## Examples

      iex> Raxol.Utils.ColorConversion.rgb_to_hex({255, 0, 0})
      "#ff0000"

      iex> Raxol.Utils.ColorConversion.rgb_to_hex({0, 255, 0})
      "#00ff00"
  """
  @spec rgb_to_hex({number(), number(), number()}) :: String.t()
  def rgb_to_hex({r, g, b}) do
    ("#" <>
       String.pad_leading(Integer.to_string(round(r), 16), 2, "0") <>
       String.pad_leading(Integer.to_string(round(g), 16), 2, "0") <>
       String.pad_leading(Integer.to_string(round(b), 16), 2, "0"))
    |> String.downcase()
  end

  @doc """
  Interpolate between two colors.

  ## Examples

      iex> Raxol.Utils.ColorConversion.interpolate_color("#000000", "#FFFFFF", 0.5)
      "#7f7f7f"
  """
  @spec interpolate_color(String.t(), String.t(), float()) :: String.t()
  def interpolate_color(from_color, to_color, progress)
      when progress >= 0 and progress <= 1 do
    from_rgb = hex_to_rgb(from_color)
    to_rgb = hex_to_rgb(to_color)

    interpolated_rgb = {
      interpolate(elem(from_rgb, 0), elem(to_rgb, 0), progress),
      interpolate(elem(from_rgb, 1), elem(to_rgb, 1), progress),
      interpolate(elem(from_rgb, 2), elem(to_rgb, 2), progress)
    }

    rgb_to_hex(interpolated_rgb)
  end

  # Linear interpolation
  defp interpolate(from, to, progress) do
    from + (to - from) * progress
  end
end
