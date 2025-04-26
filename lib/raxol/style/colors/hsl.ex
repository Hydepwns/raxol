defmodule Raxol.Style.Colors.HSL do
  @moduledoc """
  Provides functions for HSL color space conversions and adjustments.
  """

  alias Raxol.Style.Colors.Color

  @doc """
  Converts RGB values to HSL.

  ## Parameters
  - `r`, `g`, `b` - Red, Green, Blue values (0-255)

  ## Returns
  - `{h, s, l}` tuple: Hue (0-360), Saturation (0.0-1.0), Lightness (0.0-1.0)
  """
  @spec rgb_to_hsl(integer(), integer(), integer()) ::
          {float(), float(), float()}
  def rgb_to_hsl(r, g, b)
      when is_integer(r) and r >= 0 and r <= 255 and is_integer(g) and g >= 0 and
             g <= 255 and is_integer(b) and b >= 0 and b <= 255 do
    r_norm = r / 255
    g_norm = g / 255
    b_norm = b / 255

    max = Enum.max([r_norm, g_norm, b_norm])
    min = Enum.min([r_norm, g_norm, b_norm])
    delta = max - min

    h = _calculate_hue(r_norm, g_norm, b_norm, max, delta)
    l = (max + min) / 2
    s = if delta == 0.0, do: 0.0, else: delta / (1 - abs(2 * l - 1))

    {h, s, l}
  end

  defp _calculate_hue(r, g, b, max, delta) do
    hue =
      cond do
        delta == 0.0 -> 0.0 # Achromatic
        max == r -> 60.0 * rem(((g - b) / delta), 6)
        max == g -> 60.0 * (((b - r) / delta) + 2.0)
        # max == b
        true -> 60.0 * (((r - g) / delta) + 4.0)
      end
    # Ensure hue is always positive
    if hue < 0, do: hue + 360.0, else: hue
  end

  @doc """
  Converts HSL values to RGB.

  ## Parameters
  - `h`, `s`, `l` - Hue (0-360), Saturation (0.0-1.0), Lightness (0.0-1.0)

  ## Returns
  - `{r, g, b}` tuple: Red, Green, Blue values (0-255)
  """
  @spec hsl_to_rgb(number(), float(), float()) ::
          {integer(), integer(), integer()}
  def hsl_to_rgb(h, s, l)
      when is_number(h) and h >= 0 and h < 360 and is_float(s) and s >= 0.0 and
             s <= 1.0 and is_float(l) and l >= 0.0 and l <= 1.0 do

    c = (1.0 - abs(2.0 * l - 1.0)) * s
    h_prime = h / 60.0
    x = c * (1.0 - abs(rem(h_prime, 2.0) - 1.0))
    m = l - c / 2.0

    {r_prime, g_prime, b_prime} =
      cond do
        h_prime >= 0.0 and h_prime < 1.0 -> {c, x, 0.0}
        h_prime >= 1.0 and h_prime < 2.0 -> {x, c, 0.0}
        h_prime >= 2.0 and h_prime < 3.0 -> {0.0, c, x}
        h_prime >= 3.0 and h_prime < 4.0 -> {0.0, x, c}
        h_prime >= 4.0 and h_prime < 5.0 -> {x, 0.0, c}
        h_prime >= 5.0 and h_prime < 6.0 -> {c, 0.0, x}
        true -> {0.0, 0.0, 0.0} # Should not happen with valid h
      end

    r = round((r_prime + m) * 255)
    g = round((g_prime + m) * 255)
    b = round((b_prime + m) * 255)

    # Clamp values just in case of float inaccuracies
    {max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b))}
  end

  @doc """
  Rotates the hue of a color by a specified number of degrees.

  ## Parameters

  - `color` - The color to rotate (Color struct)
  - `degrees` - The number of degrees to rotate (positive or negative)

  ## Returns

  - A Color struct representing the rotated color
  """
  @spec rotate_hue(Color.t(), number()) :: Color.t()
  def rotate_hue(%Color{} = color, degrees) when is_number(degrees) do
    {h, s, l} = rgb_to_hsl(color.r, color.g, color.b)
    # Use rem for proper wrapping with negative degrees
    new_h = rem(h + degrees, 360.0)
    new_h = if new_h < 0, do: new_h + 360.0, else: new_h

    {r, g, b} = hsl_to_rgb(new_h, s, l)
    %Color{color | r: r, g: g, b: b}
  end

  @doc """
  Lightens a color by a specified amount (adjusting Lightness).

  ## Parameters

  - `color` - The color to lighten (Color struct)
  - `amount` - The amount to lighten by (0.0 to 1.0)

  ## Returns

  - A Color struct representing the lightened color
  """
  @spec lighten(Color.t(), float()) :: Color.t()
  def lighten(%Color{} = color, amount) when is_float(amount) and amount >= 0.0 do
    {h, s, l} = rgb_to_hsl(color.r, color.g, color.b)
    new_l = min(l + amount, 1.0)
    {r, g, b} = hsl_to_rgb(h, s, new_l)
    %Color{color | r: r, g: g, b: b}
  end

  @doc """
  Darkens a color by a specified amount (adjusting Lightness).

  ## Parameters

  - `color` - The color to darken (Color struct)
  - `amount` - The amount to darken by (0.0 to 1.0)

  ## Returns

  - A Color struct representing the darkened color
  """
  @spec darken(Color.t(), float()) :: Color.t()
  def darken(%Color{} = color, amount) when is_float(amount) and amount >= 0.0 do
    {h, s, l} = rgb_to_hsl(color.r, color.g, color.b)
    new_l = max(l - amount, 0.0)
    {r, g, b} = hsl_to_rgb(h, s, new_l)
    %Color{color | r: r, g: g, b: b}
  end

  @doc """
  Saturates a color by a specified amount (adjusting Saturation).

  ## Parameters

  - `color` - The color to saturate (Color struct)
  - `amount` - The amount to saturate by (0.0 to 1.0)

  ## Returns

  - A Color struct representing the saturated color
  """
  @spec saturate(Color.t(), float()) :: Color.t()
  def saturate(%Color{} = color, amount) when is_float(amount) and amount >= 0.0 do
    {h, s, l} = rgb_to_hsl(color.r, color.g, color.b)
    new_s = min(s + amount, 1.0)
    {r, g, b} = hsl_to_rgb(h, new_s, l)
    %Color{color | r: r, g: g, b: b}
  end

  @doc """
  Desaturates a color by a specified amount (adjusting Saturation).

  ## Parameters

  - `color` - The color to desaturate (Color struct)
  - `amount` - The amount to desaturate by (0.0 to 1.0)

  ## Returns

  - A Color struct representing the desaturated color
  """
  @spec desaturate(Color.t(), float()) :: Color.t()
  def desaturate(%Color{} = color, amount) when is_float(amount) and amount >= 0.0 do
    {h, s, l} = rgb_to_hsl(color.r, color.g, color.b)
    new_s = max(s - amount, 0.0)
    {r, g, b} = hsl_to_rgb(h, new_s, l)
    %Color{color | r: r, g: g, b: b}
  end
end
