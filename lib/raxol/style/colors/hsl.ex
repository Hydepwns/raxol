alias Raxol.Style.Colors.Color

defmodule Raxol.Style.Colors.HSL do
  @moduledoc """
  Provides functions for HSL color space conversions and adjustments.

  This is the single source of truth for RGB<->HSL conversions.
  Other modules should delegate here instead of reimplementing.
  """

  @rgb_max 255
  @hue_max 360

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
      when is_integer(r) and r >= 0 and r <= @rgb_max and is_integer(g) and
             g >= 0 and
             g <= @rgb_max and is_integer(b) and b >= 0 and b <= @rgb_max do
    r_norm = r / @rgb_max
    g_norm = g / @rgb_max
    b_norm = b / @rgb_max

    max = Enum.max([r_norm, g_norm, b_norm])
    min = Enum.min([r_norm, g_norm, b_norm])
    delta = max - min

    h = _calculate_hue(r_norm, g_norm, b_norm, max, delta)
    l = (max + min) / 2

    s =
      case delta do
        +0.0 -> +0.0
        _ -> delta / (1 - abs(2 * l - 1))
      end

    {h, s, l}
  end

  # Helper functions for pattern matching refactoring

  defp _calculate_hue(_r, _g, _b, _max, delta) when delta == +0.0,
    do: +0.0

  defp _calculate_hue(r, g, b, max, delta) when max == r,
    do: normalize_hue(60.0 * rem(round((g - b) / delta), 6))

  defp _calculate_hue(r, g, b, max, delta) when max == g,
    do: normalize_hue(60.0 * ((b - r) / delta + 2.0))

  defp _calculate_hue(r, g, _b, _max, delta),
    do: normalize_hue(60.0 * ((r - g) / delta + 4.0))

  @doc """
  Normalizes a hue value to the range [0, 360).
  """
  def normalize_hue(hue) do
    case hue < 0 do
      true ->
        hue + @hue_max * 1.0

      false ->
        hue
        |> then(&rem(round(&1), @hue_max))
    end
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
      when is_number(h) and h >= 0 and h < @hue_max and is_float(s) and s >= 0.0 and
             s <= 1.0 and is_float(l) and l >= 0.0 and l <= 1.0 do
    c = (1.0 - abs(2.0 * l - 1.0)) * s
    h_prime = h / 60.0
    x = c * (1.0 - abs(:math.fmod(h_prime, 2.0) - 1.0))
    m = l - c / 2.0

    {r_prime, g_prime, b_prime} = calculate_rgb_prime(h_prime, c, x)

    r = round((r_prime + m) * @rgb_max)
    g = round((g_prime + m) * @rgb_max)
    b = round((b_prime + m) * @rgb_max)

    # Clamp values just in case of float inaccuracies
    clamp_rgb = &Raxol.Core.Utils.Math.clamp(&1, 0, @rgb_max)
    {clamp_rgb.(r), clamp_rgb.(g), clamp_rgb.(b)}
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
    # Ensure calculations are float, then fix rem args: use round/1
    new_h = rem(round(h + degrees + @hue_max * 1.0), @hue_max)
    {r, g, b} = hsl_to_rgb(new_h, s, l)
    %{color | r: r, g: g, b: b}
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
  def lighten(%Color{} = color, amount)
      when is_float(amount) and amount >= 0.0 do
    {h, s, l} = rgb_to_hsl(color.r, color.g, color.b)
    new_l = min(l + amount, 1.0)
    {r, g, b} = hsl_to_rgb(h, s, new_l)
    %{color | r: r, g: g, b: b}
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
  def darken(%Color{} = color, amount)
      when is_float(amount) and amount >= 0.0 do
    {h, s, l} = rgb_to_hsl(color.r, color.g, color.b)
    new_l = max(l - amount, 0.0)
    {r, g, b} = hsl_to_rgb(h, s, new_l)
    %{color | r: r, g: g, b: b}
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
  def saturate(%Color{} = color, amount)
      when is_float(amount) and amount >= 0.0 do
    {h, s, l} = rgb_to_hsl(color.r, color.g, color.b)
    new_s = min(s + amount, 1.0)
    {r, g, b} = hsl_to_rgb(h, new_s, l)
    %{color | r: r, g: g, b: b}
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
  def desaturate(%Color{} = color, amount)
      when is_float(amount) and amount >= 0.0 do
    {h, s, l} = rgb_to_hsl(color.r, color.g, color.b)
    new_s = max(s - amount, 0.0)
    {r, g, b} = hsl_to_rgb(h, new_s, l)
    %{color | r: r, g: g, b: b}
  end

  defp calculate_rgb_prime(h_prime, c, x) when h_prime >= 0.0 and h_prime < 1.0,
    do: {c, x, 0.0}

  defp calculate_rgb_prime(h_prime, c, x) when h_prime >= 1.0 and h_prime < 2.0,
    do: {x, c, 0.0}

  defp calculate_rgb_prime(h_prime, c, x) when h_prime >= 2.0 and h_prime < 3.0,
    do: {0.0, c, x}

  defp calculate_rgb_prime(h_prime, c, x) when h_prime >= 3.0 and h_prime < 4.0,
    do: {0.0, x, c}

  defp calculate_rgb_prime(h_prime, c, x) when h_prime >= 4.0 and h_prime < 5.0,
    do: {x, 0.0, c}

  defp calculate_rgb_prime(h_prime, c, x) when h_prime >= 5.0 and h_prime < 6.0,
    do: {c, 0.0, x}

  defp calculate_rgb_prime(_h_prime, _c, _x), do: {0.0, 0.0, 0.0}
end
