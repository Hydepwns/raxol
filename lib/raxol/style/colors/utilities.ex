alias Raxol.Style.Colors.Color

defmodule Raxol.Style.Colors.Utilities do
  @moduledoc """
  Shared color utilities for the Raxol color system.

  This module provides common color manipulation and analysis functions,
  including contrast calculations, accessibility checks, and color format
  conversions.
  """

  import Raxol.Guards

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

  def relative_luminance({r, g, b}) do
    # Convert RGB to relative luminance
    r = convert_to_linear(r / 255)
    g = convert_to_linear(g / 255)
    b = convert_to_linear(b / 255)

    # Calculate relative luminance
    0.2126 * r + 0.7152 * g + 0.0722 * b
  end

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

    if current_ratio >= required_ratio do
      color
    else
      # Determine if we need to lighten or darken
      color_luminance = relative_luminance(color)
      bg_luminance = relative_luminance(background)

      if color_luminance > bg_luminance do
        darken_until_contrast(color, background, required_ratio)
      else
        lighten_until_contrast(color, background, required_ratio)
      end
    end
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
    %{color | r: r, g: g, b: b}
  end

  def increase_contrast({r, g, b}) do
    {
      if(r > 127, do: 255, else: 0),
      if(g > 127, do: 255, else: 0),
      if(b > 127, do: 255, else: 0)
    }
  end

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

    if ratio >= min_ratio do
      {:ok, ratio}
    else
      {:error, {:contrast_too_low, ratio, min_ratio}}
    end
  end

  @doc """
  Returns black or white, whichever has better contrast with the background.
  """
  def best_bw_contrast(background, min_ratio \\ 4.5) do
    black = Color.from_hex("#000000")
    white = Color.from_hex("#FFFFFF")
    ratio_black = contrast_ratio(background, black)
    ratio_white = contrast_ratio(background, white)

    cond do
      ratio_white >= min_ratio and ratio_white >= ratio_black -> white
      ratio_black >= min_ratio -> black
      true -> if ratio_white > ratio_black, do: white, else: black
    end
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
    r = r / 255
    g = g / 255
    b = b / 255

    max = Enum.max([r, g, b])
    min = Enum.min([r, g, b])
    l = (max + min) / 2

    {h, s} =
      if max == min do
        {0, 0}
      else
        d = max - min
        s = if l > 0.5, do: d / (2 - max - min), else: d / (max + min)

        h =
          cond do
            max == r -> (g - b) / d + if g < b, do: 6, else: 0
            max == g -> (b - r) / d + 2
            max == b -> (r - g) / d + 4
          end
          |> Kernel.*(60)

        {h, s}
      end

    {h, s, l}
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
  def hsl_to_rgb(h, s, l) when number?(h) and number?(s) and number?(l) do
    h = rem(h + 360, 360)
    s = max(0, min(1, s))
    l = max(0, min(1, l))

    c = (1 - abs(2 * l - 1)) * s
    x = c * (1 - abs(rem(trunc(h / 60), 2) - 1))
    m = l - c / 2

    {r1, g1, b1} =
      cond do
        h < 60 -> {c, x, 0}
        h < 120 -> {x, c, 0}
        h < 180 -> {0, c, x}
        h < 240 -> {0, x, c}
        h < 300 -> {x, 0, c}
        true -> {c, 0, x}
      end

    {
      round((r1 + m) * 255),
      round((g1 + m) * 255),
      round((b1 + m) * 255)
    }
  end

  # Private helpers

  defp convert_to_linear(value) do
    if value <= 0.03928 do
      value / 12.92
    else
      :math.pow((value + 0.055) / 1.055, 2.4)
    end
  end

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

    if current_ratio >= required_ratio or iter >= 50 do
      color
    else
      darker = darken_color(color, step)
      darken_until_contrast(darker, background, required_ratio, step, iter + 1)
    end
  end

  defp lighten_until_contrast(
         color,
         background,
         required_ratio,
         step \\ 0.1,
         iter \\ 0
       ) do
    current_ratio = contrast_ratio(color, background)

    if current_ratio >= required_ratio or iter >= 50 do
      color
    else
      lighter = lighten_color(color, step)

      lighten_until_contrast(
        lighter,
        background,
        required_ratio,
        step,
        iter + 1
      )
    end
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
      | r: min(255, round(color.r + (255 - color.r) * factor)),
        g: min(255, round(color.g + (255 - color.g) * factor)),
        b: min(255, round(color.b + (255 - color.b) * factor))
    }
  end
end
