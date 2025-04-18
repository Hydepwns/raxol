defmodule Raxol.Style.Colors.Accessibility do
  @moduledoc """
  Provides color accessibility features and WCAG compliance checking.

  This module helps ensure that color combinations meet WCAG guidelines
  for contrast and readability. It provides functions for:
  - Checking contrast ratios
  - Suggesting accessible color alternatives
  - Validating color combinations
  - Generating accessible color palettes
  """

  alias Raxol.Style.Colors.{Color, Utilities}

  @doc """
  Checks if a color combination meets WCAG contrast requirements.

  ## Parameters

  - `foreground` - The foreground color (typically text)
  - `background` - The background color
  - `level` - The WCAG level to check against (`:aa` or `:aaa`)
  - `size` - The text size (`:normal` or `:large`)

  ## Returns

  - `{:ok, ratio}` - If the contrast is sufficient, with the calculated ratio
  - `{:insufficient, ratio}` - If the contrast is insufficient, with the calculated ratio

  ## Examples

      iex> Accessibility.check_contrast("#000000", "#FFFFFF")
      {:ok, 21.0}

      iex> Accessibility.check_contrast("#777777", "#999999")
      {:insufficient, 1.3}
  """
  def check_contrast(foreground, background, level \\ :aa, size \\ :normal) do
    # Calculate contrast ratio
    ratio = Utilities.contrast_ratio(foreground, background)

    # Determine minimum required ratio based on level and size
    min_ratio =
      case {level, size} do
        {:aa, :normal} -> 4.5
        {:aa, :large} -> 3.0
        {:aaa, :normal} -> 7.0
        {:aaa, :large} -> 4.5
      end

    # Check if ratio is sufficient
    if ratio >= min_ratio do
      {:ok, ratio}
    else
      {:insufficient, ratio}
    end
  end

  @doc """
  Suggests an accessible color alternative for a given color.

  ## Parameters

  - `color` - The original color
  - `background` - The background color the text will appear on
  - `level` - The WCAG level to achieve (`:aa` or `:aaa`)
  - `size` - The text size (`:normal` or `:large`)

  ## Examples

      iex> Accessibility.suggest_accessible_color("#777777", "#FFFFFF")
      "#595959"
  """
  def suggest_accessible_color(color, background, level \\ :aa, size \\ :normal) do
    # Get current contrast ratio
    ratio = Utilities.contrast_ratio(color, background)

    # Determine minimum required ratio
    min_ratio =
      case {level, size} do
        {:aa, :normal} -> 4.5
        {:aa, :large} -> 3.0
        {:aaa, :normal} -> 7.0
        {:aaa, :large} -> 4.5
      end

    # If already sufficient, return original color
    if ratio >= min_ratio do
      color
    else
      # Determine if we need to lighten or darken
      bg_luminance = Utilities.relative_luminance(background)

      if bg_luminance > 0.5 do
        # Dark text on light background
        Utilities.darken_until_contrast(color, background, min_ratio)
      else
        # Light text on dark background
        Utilities.lighten_until_contrast(color, background, min_ratio)
      end
    end
  end

  @doc """
  Generates an accessible color palette from a base color.

  ## Parameters

  - `base_color` - The base color to generate the palette from
  - `background` - The background color the palette will be used on
  - `level` - The WCAG level to achieve (`:aa` or `:aaa`)
  - `size` - The text size (`:normal` or `:large`)

  ## Examples

      iex> palette = Accessibility.generate_accessible_palette("#0077CC", "#FFFFFF")
      iex> Map.keys(palette)
      [:primary, :secondary, :accent, :text]
  """
  def generate_accessible_palette(
        base_color,
        background,
        level \\ :aa,
        size \\ :normal
      ) do
    # Generate color variations
    primary = suggest_accessible_color(base_color, background, level, size)

    secondary =
      suggest_accessible_color(
        Utilities.rotate_hue(base_color, 120),
        background,
        level,
        size
      )

    accent =
      suggest_accessible_color(
        Utilities.rotate_hue(base_color, 240),
        background,
        level,
        size
      )

    # Generate text color based on background
    text =
      if Utilities.dark_color?(background) do
        suggest_accessible_color(
          Color.from_hex("#FFFFFF"),
          background,
          level,
          size
        )
      else
        suggest_accessible_color(
          Color.from_hex("#000000"),
          background,
          level,
          size
        )
      end

    %{
      primary: primary,
      secondary: secondary,
      accent: accent,
      text: text
    }
  end

  @doc """
  Validates a color combination for accessibility.

  ## Parameters

  - `colors` - Map of color names to colors
  - `background` - The background color
  - `level` - The WCAG level to check against (`:aa` or `:aaa`)
  - `size` - The text size (`:normal` or `:large`)

  ## Returns

  - `{:ok, colors}` - If all colors are accessible
  - `{:error, issues}` - If there are accessibility issues, with details

  ## Examples

      iex> colors = %{
      ...>   text: "#000000",
      ...>   link: "#0066CC"
      ...> }
      iex> Accessibility.validate_colors(colors, "#FFFFFF")
      {:ok, %{text: "#000000", link: "#0066CC"}}
  """
  def validate_colors(colors, background, level \\ :aa, size \\ :normal) do
    # Check each color against the background
    issues =
      Enum.reduce(colors, [], fn {name, color}, acc ->
        case check_contrast(color, background, level, size) do
          {:ok, _ratio} ->
            acc

          {:insufficient, ratio} ->
            [{name, ratio} | acc]
        end
      end)

    if Enum.empty?(issues) do
      {:ok, colors}
    else
      {:error, issues}
    end
  end

  @doc """
  Adjusts a color palette to be accessible.

  ## Parameters

  - `colors` - Map of color names to colors
  - `background` - The background color
  - `level` - The WCAG level to achieve (`:aa` or `:aaa`)
  - `size` - The text size (`:normal` or `:large`)

  ## Examples

      iex> colors = %{
      ...>   text: "#777777",
      ...>   link: "#999999"
      ...> }
      iex> Accessibility.adjust_palette(colors, "#FFFFFF")
      %{
        text: "#595959",
        link: "#0066CC"
      }
  """
  def adjust_palette(colors, background, level \\ :aa, size \\ :normal) do
    # Adjust each color to be accessible
    Enum.map(colors, fn {name, color} ->
      {name, suggest_accessible_color(color, background, level, size)}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Checks if a color is suitable for text on a given background.

  ## Parameters

  - `color` - The color to check
  - `background` - The background color
  - `level` - The WCAG level to check against (`:aa` or `:aaa`)
  - `size` - The text size (`:normal` or `:large`)

  ## Examples

      iex> Accessibility.suitable_for_text?("#000000", "#FFFFFF")
      true

      iex> Accessibility.suitable_for_text?("#777777", "#999999")
      false
  """
  def suitable_for_text?(color, background, level \\ :aa, size \\ :normal) do
    case check_contrast(color, background, level, size) do
      {:ok, _ratio} -> true
      {:insufficient, _ratio} -> false
    end
  end

  # For backward compatibility
  @doc false
  @deprecated "Use suitable_for_text?/4 instead"
  def is_suitable_for_text?(color, background, level \\ :aa, size \\ :normal) do
    suitable_for_text?(color, background, level, size)
  end

  @doc """
  Gets the optimal text color for a given background.

  ## Parameters

  - `background` - The background color
  - `level` - The WCAG level to achieve (`:aa` or `:aaa`)
  - `size` - The text size (`:normal` or `:large`)

  ## Examples

      iex> Accessibility.get_optimal_text_color("#FFFFFF")
      "#000000"

      iex> Accessibility.get_optimal_text_color("#000000")
      "#FFFFFF"
  """
  def get_optimal_text_color(background, level \\ :aa, size \\ :normal) do
    # Suggest text color based on background darkness
    suggested_color =
      if Utilities.dark_color?(background) do
        Color.from_hex("#FFFFFF")
      else
        Color.from_hex("#000000")
      end

    # Check if suggested color is suitable for text
    if suitable_for_text?(suggested_color, background, level, size) do
      suggested_color
    else
      # If suggested color is not suitable, adjust the background color
      if Utilities.dark_color?(background) do
        suggest_accessible_color(
          Color.from_hex("#FFFFFF"),
          background,
          level,
          size
        )
      else
        suggest_accessible_color(
          Color.from_hex("#000000"),
          background,
          level,
          size
        )
      end
    end
  end
end
