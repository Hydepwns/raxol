defmodule Raxol.Style.Colors.Utilities do
  @moduledoc """
  Shared color utilities for the Raxol color system.

  This module provides common color manipulation and analysis functions,
  including contrast calculations, accessibility checks, and color format
  conversions.
  """

  alias Raxol.Style.Colors.Color

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
    (l1 + 0.05) / (l2 + 0.05)
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

  # Private helpers

  defp convert_to_linear(value) do
    if value <= 0.03928 do
      value / 12.92
    else
      :math.pow((value + 0.055) / 1.055, 2.4)
    end
  end

  defp get_required_ratio(level, size) do
    case {level, size} do
      {:A, :normal} -> 3.0
      {:A, :large} -> 3.0
      {:AA, :normal} -> 4.5
      {:AA, :large} -> 3.0
      {:AAA, :normal} -> 7.0
      {:AAA, :large} -> 4.5
    end
  end

  defp darken_until_contrast(color, background, required_ratio, step \\ 0.1) do
    current_ratio = contrast_ratio(color, background)

    if current_ratio >= required_ratio do
      color
    else
      darker = darken_color(color, step)
      darken_until_contrast(darker, background, required_ratio, step)
    end
  end

  defp lighten_until_contrast(color, background, required_ratio, step \\ 0.1) do
    current_ratio = contrast_ratio(color, background)

    if current_ratio >= required_ratio do
      color
    else
      lighter = lighten_color(color, step)
      lighten_until_contrast(lighter, background, required_ratio, step)
    end
  end

  defp darken_color(%Color{} = color, factor) do
    %{color |
      r: round(color.r * (1 - factor)),
      g: round(color.g * (1 - factor)),
      b: round(color.b * (1 - factor))
    }
  end

  defp lighten_color(%Color{} = color, factor) do
    %{color |
      r: min(255, round(color.r + (255 - color.r) * factor)),
      g: min(255, round(color.g + (255 - color.g) * factor)),
      b: min(255, round(color.b + (255 - color.b) * factor))
    }
  end
end
