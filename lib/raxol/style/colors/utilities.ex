alias Raxol.Style.Colors.Color

defmodule Raxol.Style.Colors.Utilities do
  alias Raxol.Style.Colors.HSL

  @moduledoc """
  Shared color utilities for the Raxol color system.

  This module provides common color manipulation and analysis functions,
  including contrast calculations, accessibility checks, and color format
  conversions.
  """

  # WCAG 2.0 relative luminance coefficients (sRGB)
  @wcag_r 0.2126
  @wcag_g 0.7152
  @wcag_b 0.0722

  @rgb_max 255

  @doc """
  Calculates the relative luminance of a color according to WCAG 2.0.

  ## Parameters

  * `color` - A Color struct or RGB tuple

  ## Returns

  A float between 0 and 1 representing the relative luminance
  """
  def relative_luminance(%Color{} = color) do
    relative_luminance({color.r, color.g, color.b})
  end

  def relative_luminance({r, g, b})
      when is_number(r) and is_number(g) and is_number(b) do
    r = convert_to_linear(r / @rgb_max)
    g = convert_to_linear(g / @rgb_max)
    b = convert_to_linear(b / @rgb_max)

    @wcag_r * r + @wcag_g * g + @wcag_b * b
  end

  def relative_luminance(hex) when is_binary(hex) do
    # Convert hex string to Color struct and calculate luminance
    case Color.from_hex(hex) do
      %Color{} = color -> relative_luminance(color)
      _ -> 0.0
    end
  end

  def relative_luminance(nil), do: 0.0
  def relative_luminance(_), do: 0.0

  @doc """
  Calculates the contrast ratio between two colors according to WCAG 2.0.

  ## Parameters

  * `color1` - First color (Color struct or RGB tuple)
  * `color2` - Second color (Color struct or RGB tuple)

  ## Returns

  A float representing the contrast ratio (1:1 to 21:1)
  """
  def contrast_ratio(color1, color2) do
    l1 = relative_luminance(color1)
    l2 = relative_luminance(color2)

    # Ensure l1 is the lighter color
    {l1, l2} = if l1 > l2, do: {l1, l2}, else: {l2, l1}

    # Calculate contrast ratio
    (l1 + +0.05) / (l2 + +0.05)
  end

  @doc """
  Checks if two colors meet WCAG contrast requirements.

  ## Parameters

  * `color1` - First color (Color struct or RGB tuple)
  * `color2` - Second color (Color struct or RGB tuple)
  * `level` - WCAG level (:A, :AA, or :AAA)
  * `size` - Text size (:normal or :large)

  ## Returns

  `true` if the contrast meets requirements, `false` otherwise
  """
  def meets_contrast_requirements?(color1, color2, level, size) do
    ratio = contrast_ratio(color1, color2)
    required_ratio = get_required_ratio(level, size)
    ratio >= required_ratio
  end

  @doc """
  Adjusts a color to meet contrast requirements with another color.

  ## Parameters

  * `color` - The color to adjust (Color struct or RGB tuple)
  * `background` - The background color (Color struct or RGB tuple)
  * `level` - WCAG level (:A, :AA, or :AAA)
  * `size` - Text size (:normal or :large)

  ## Returns

  An adjusted Color struct that meets contrast requirements
  """
  def adjust_for_contrast(color, background, level, size) do
    required_ratio = get_required_ratio(level, size)
    current_ratio = contrast_ratio(color, background)

    adjust_color_based_on_ratio(
      current_ratio >= required_ratio,
      color,
      background,
      required_ratio
    )
  end

  defp adjust_color_based_on_ratio(true, color, _background, _required_ratio),
    do: color

  defp adjust_color_based_on_ratio(false, color, background, required_ratio) do
    # Determine if we need to lighten or darken
    color_luminance = relative_luminance(color)
    bg_luminance = relative_luminance(background)

    adjust_based_on_luminance(
      color_luminance > bg_luminance,
      color,
      background,
      required_ratio
    )
  end

  defp adjust_based_on_luminance(true, color, background, required_ratio) do
    darken_until_contrast(color, background, required_ratio)
  end

  defp adjust_based_on_luminance(false, color, background, required_ratio) do
    lighten_until_contrast(color, background, required_ratio)
  end

  @doc """
  Increases the contrast of a color by making it more extreme.

  ## Parameters

  * `color` - The color to increase contrast for (Color struct or RGB tuple)

  ## Returns

  A new Color struct with increased contrast
  """
  def increase_contrast(%Color{} = color) do
    {r, g, b} = increase_contrast({color.r, color.g, color.b})
    %{color | r: r, g: g, b: b, hex: Color.from_rgb(r, g, b).hex}
  end

  def increase_contrast({r, g, b}) do
    {
      contrast_value(r),
      contrast_value(g),
      contrast_value(b)
    }
  end

  @contrast_threshold 127
  defp contrast_value(v) when v > @contrast_threshold, do: @rgb_max
  defp contrast_value(_v), do: 0

  @doc """
  Checks if two colors have sufficient contrast according to WCAG guidelines.
  """
  def check_contrast(color1, color2, level \\ :aa, size \\ :normal) do
    ratio = contrast_ratio(color1, color2)

    min_ratio =
      case {level, size} do
        {:aaa, :normal} -> 7.0
        {:aaa, :large} -> 4.5
        {:aa, :normal} -> 4.5
        {:aa, :large} -> 3.0
      end

    validate_contrast_ratio(ratio >= min_ratio, ratio, min_ratio)
  end

  defp validate_contrast_ratio(true, ratio, _min_ratio), do: {:ok, ratio}

  defp validate_contrast_ratio(false, ratio, min_ratio) do
    {:error, {:contrast_too_low, ratio, min_ratio}}
  end

  @doc """
  Returns black or white, whichever has better contrast with the background.
  """
  def best_bw_contrast(background, min_ratio \\ 4.5) do
    black = Color.from_hex("#000000")
    white = Color.from_hex("#FFFFFF")
    ratio_black = contrast_ratio(background, black)
    ratio_white = contrast_ratio(background, white)

    select_best_contrast(ratio_white, ratio_black, min_ratio, white, black)
  end

  @doc """
  Converts RGB values to HSL.

  ## Parameters

  * `r` - Red component (0-255)
  * `g` - Green component (0-255)
  * `b` - Blue component (0-255)

  ## Returns

  A tuple {h, s, l} where:
  * h is hue (0-360)
  * s is saturation (0-1)
  * l is lightness (0-1)
  """
  def rgb_to_hsl(r, g, b)
      when is_integer(r) and is_integer(g) and is_integer(b) do
    HSL.rgb_to_hsl(r, g, b)
  end

  @doc """
  Converts HSL values to RGB.

  ## Parameters

  * `h` - Hue (0-360)
  * `s` - Saturation (0-1)
  * `l` - Lightness (0-1)

  ## Returns

  A tuple {r, g, b} where each component is in the range 0-255
  """
  def hsl_to_rgb(h, s, l) when is_number(h) and is_number(s) and is_number(l) do
    h = rem(h + 360, 360)
    s = Raxol.Core.Utils.Math.clamp(s, 0, 1)
    l = Raxol.Core.Utils.Math.clamp(l, 0, 1)
    # Ensure floats for HSL module guard
    HSL.hsl_to_rgb(h * 1.0, s * 1.0, l * 1.0)
  end

  # Private helpers

  defp convert_to_linear(value) when value <= 0.03928, do: value / 12.92
  defp convert_to_linear(value), do: :math.pow((value + 0.055) / 1.055, 2.4)

  defp get_required_ratio(level, size) do
    # Normalize to lowercase atoms for robust matching
    norm_level =
      case level do
        l when is_atom(l) ->
          String.downcase(Atom.to_string(l)) |> String.to_atom()

        l when is_binary(l) ->
          String.downcase(l) |> String.to_atom()

        _ ->
          :aa
      end

    norm_size =
      case size do
        s when is_atom(s) ->
          String.downcase(Atom.to_string(s)) |> String.to_atom()

        s when is_binary(s) ->
          String.downcase(s) |> String.to_atom()

        _ ->
          :normal
      end

    case {norm_level, norm_size} do
      {:a, :normal} -> 3.0
      {:a, :large} -> 3.0
      {:aa, :normal} -> 4.5
      {:aa, :large} -> 3.0
      {:aaa, :normal} -> 7.0
      {:aaa, :large} -> 4.5
      _ -> 4.5
    end
  end

  defp darken_until_contrast(
         color,
         background,
         required_ratio,
         step \\ 0.1,
         iter \\ 0
       ) do
    current_ratio = contrast_ratio(color, background)

    continue_darkening(
      current_ratio < required_ratio and iter < 50,
      color,
      background,
      required_ratio,
      step,
      iter
    )
  end

  defp continue_darkening(
         false,
         color,
         _background,
         _required_ratio,
         _step,
         _iter
       ),
       do: color

  defp continue_darkening(true, color, background, required_ratio, step, iter) do
    darker = darken_color(color, step)
    darken_until_contrast(darker, background, required_ratio, step, iter + 1)
  end

  defp lighten_until_contrast(
         color,
         background,
         required_ratio,
         step \\ 0.1,
         iter \\ 0
       ) do
    current_ratio = contrast_ratio(color, background)

    continue_lightening(
      current_ratio < required_ratio and iter < 50,
      color,
      background,
      required_ratio,
      step,
      iter
    )
  end

  defp continue_lightening(
         false,
         color,
         _background,
         _required_ratio,
         _step,
         _iter
       ),
       do: color

  defp continue_lightening(true, color, background, required_ratio, step, iter) do
    lighter = lighten_color(color, step)
    lighten_until_contrast(lighter, background, required_ratio, step, iter + 1)
  end

  defp darken_color(%Color{} = color, factor) do
    %{
      color
      | r: round(color.r * (1 - factor)),
        g: round(color.g * (1 - factor)),
        b: round(color.b * (1 - factor))
    }
  end

  defp lighten_color(%Color{} = color, factor) do
    %{
      color
      | r: min(@rgb_max, round(color.r + (@rgb_max - color.r) * factor)),
        g: min(@rgb_max, round(color.g + (@rgb_max - color.g) * factor)),
        b: min(@rgb_max, round(color.b + (@rgb_max - color.b) * factor))
    }
  end

  # Helper functions for pattern matching refactoring

  defp select_best_contrast(ratio_white, ratio_black, min_ratio, white, _black)
       when ratio_white >= min_ratio and ratio_white >= ratio_black,
       do: white

  defp select_best_contrast(_ratio_white, ratio_black, min_ratio, _white, black)
       when ratio_black >= min_ratio,
       do: black

  defp select_best_contrast(ratio_white, ratio_black, _min_ratio, white, _black)
       when ratio_white > ratio_black,
       do: white

  defp select_best_contrast(
         _ratio_white,
         _ratio_black,
         _min_ratio,
         _white,
         black
       ),
       do: black
end
