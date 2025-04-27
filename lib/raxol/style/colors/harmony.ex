defmodule Raxol.Style.Colors.Harmony do
  @moduledoc """
  Provides functions for generating color harmonies based on a base color.
  """

  alias Raxol.Style.Colors.Color
  alias Raxol.Style.Colors.HSL

  @doc """
  Generates analogous colors based on the HSL color wheel.
  Analogous colors are groups of colors that are adjacent to each other on the color wheel.

  ## Parameters

  - `color`: The base `Color{}` struct.
  - `count`: The number of analogous colors to generate (defaults to 3).
  - `angle`: The angle separation between analogous colors (defaults to 30 degrees).

  ## Returns

  A list of `Color{}` structs representing the analogous colors.
  """
  # Define head with defaults
  def analogous_colors(color, count \\ 3, angle \\ 30)

  # Remove defaults from implementation clause(s)
  def analogous_colors(%Color{} = color, count, angle) do
    hsl = Color.to_hsl(color)
    step = angle / (count - 1)
    start_angle = hsl.h - angle / 2

    Enum.map(0..(count - 1), fn i ->
      h = rem(start_angle + i * step + 360, 360)
      Color.from_hsl(%{hsl | h: h})
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
