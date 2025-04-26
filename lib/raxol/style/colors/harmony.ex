defmodule Raxol.Style.Colors.Harmony do
  @moduledoc """
  Provides functions for generating color harmonies based on a base color.
  """

  alias Raxol.Style.Colors.Color
  alias Raxol.Style.Colors.HSL

  @doc """
  Generates analogous colors (adjacent on the color wheel).

  Typically uses a 30 degree separation.

  ## Parameters

  - `color` - The base color (Color struct or hex string)
  - `count` - Number of colors to generate (including the base color)
  - `angle` - Angle separation between colors (degrees)

  ## Returns

  - A list of Color structs

  ## Examples

      iex> red = Raxol.Style.Colors.Color.from_hex("#FF0000")
      iex> colors = Raxol.Style.Colors.Harmony.analogous_colors(red)
      iex> length(colors)
      3
      # Colors will be roughly red-orange, red, red-violet
  """
  def analogous_colors(color, count \\ 3, angle \\ 30) when is_binary(color) do
    case Color.from_hex(color) do
      %Color{} = c -> analogous_colors(c, count, angle)
      _ -> [] # Return empty list for invalid base color
    end
  end

  def analogous_colors(%Color{} = color, count \\ 3, angle \\ 30)
      when is_integer(count) and count >= 1 and is_number(angle) do

    {h, s, l} = HSL.rgb_to_hsl(color.r, color.g, color.b)

    # Calculate the starting hue shift to center the results around the base color
    start_shift = - (angle * (count - 1)) / 2.0

    # Generate the list of hue shifts
    shifts = for i <- 0..(count - 1), do: start_shift + i * angle

    # Apply each shift to create a new color
    Enum.map(shifts, fn shift ->
      # Calculate new hue (wrapping around 360 degrees)
      new_h = rem(h + shift, 360.0)
      new_h = if new_h < 0, do: new_h + 360.0, else: new_h

      {r, g, b} = HSL.hsl_to_rgb(new_h, s, l)
      %Color{color | r: r, g: g, b: b, hex: Color.rgb_to_hex(r, g, b)}
    end)
  end

  @doc """
  Generates complementary colors (opposite on the color wheel).

  Returns a list containing the base color and its complement.

  ## Parameters

  - `color` - The base color (Color struct or hex string)

  ## Returns

  - A list of two Color structs: `[base_color, complement]`

  ## Examples

      iex> red = Raxol.Style.Colors.Color.from_hex("#FF0000")
      iex> [red_struct, cyan_struct] = Raxol.Style.Colors.Harmony.complementary_colors(red)
      iex> cyan_struct.hex
      "#00FFFF"
  """
  def complementary_colors(color) when is_binary(color) do
    case Color.from_hex(color) do
      %Color{} = c -> complementary_colors(c)
      _ -> []
    end
  end

  def complementary_colors(%Color{} = color) do
    # Complement is 180 degrees rotation
    complement = HSL.rotate_hue(color, 180.0)
    [color, complement]
  end

  @doc """
  Generates triadic colors (three colors evenly spaced on the color wheel).

  ## Parameters

  - `color` - The base color (Color struct or hex string)

  ## Returns

  - A list of three Color structs

  ## Examples

      iex> red = Raxol.Style.Colors.Color.from_hex("#FF0000")
      iex> colors = Raxol.Style.Colors.Harmony.triadic_colors(red)
      iex> length(colors)
      3
      # Colors will be red, green, blue (approximately)
  """
  def triadic_colors(color) when is_binary(color) do
     case Color.from_hex(color) do
      %Color{} = c -> triadic_colors(c)
      _ -> []
    end
  end

  def triadic_colors(%Color{} = color) do
    # Generate colors 120 degrees apart
    [0.0, 120.0, 240.0]
    |> Enum.map(&HSL.rotate_hue(color, &1))
  end

end
