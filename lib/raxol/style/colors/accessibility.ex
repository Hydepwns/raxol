defmodule Raxol.Style.Colors.Accessibility do
  @moduledoc """
  Provides utilities for color accessibility, focusing on WCAG contrast.
  """

  alias Raxol.Style.Colors.Color

  # WCAG contrast ratio thresholds
  # AA level for normal text
  @contrast_aa 4.5
  # AAA level for normal text
  @contrast_aaa 7.0
  # AA level for large text
  @contrast_aa_large 3.0
  # AAA level for large text
  @contrast_aaa_large 4.5

  @doc """
  Calculates the relative luminance of a color according to WCAG guidelines.

  ## Parameters

  - `color` - The color to calculate luminance for (hex string or Color struct)

  ## Returns

  - A float between 0 and 1 representing the relative luminance

  ## Examples

      iex> Raxol.Style.Colors.Accessibility.relative_luminance("#000000")
      0.0

      iex> Raxol.Style.Colors.Accessibility.relative_luminance("#FFFFFF")
      1.0
  """
  def relative_luminance(color) when is_binary(color) do
    # Allow hex string input for convenience
    case Color.from_hex(color) do
      %Color{} = c -> relative_luminance(c)
      _ -> 0.0 # Or handle error? Defaulting to black for invalid hex.
    end
  end

  def relative_luminance(%Color{r: r, g: g, b: b}) do
    # Convert RGB values to relative luminance
    r_lin = _channel_to_linear(r)
    g_lin = _channel_to_linear(g)
    b_lin = _channel_to_linear(b)

    0.2126 * r_lin + 0.7152 * g_lin + 0.0722 * b_lin
  end

  # WCAG formula for converting sRGB channel to linear value
  defp _channel_to_linear(channel_val) when channel_val >= 0 and channel_val <= 255 do
    v = channel_val / 255
    if v <= 0.03928, do: v / 12.92, else: :math.pow((v + 0.055) / 1.055, 2.4)
  end

  @doc """
  Calculates the contrast ratio between two colors according to WCAG guidelines.

  ## Parameters

  - `color1` - The first color (hex string or Color struct)
  - `color2` - The second color (hex string or Color struct)

  ## Returns

  - A float representing the contrast ratio (1:1 to 21:1)

  ## Examples

      iex> Raxol.Style.Colors.Accessibility.contrast_ratio("#000000", "#FFFFFF")
      21.0

      iex> Raxol.Style.Colors.Accessibility.contrast_ratio("#777777", "#999999")
      1.3
  """
  def contrast_ratio(color1, color2)
      when is_binary(color1) or is_binary(color2) do
    # Allow hex string input
    c1 = if is_binary(color1), do: Color.from_hex(color1), else: color1
    c2 = if is_binary(color2), do: Color.from_hex(color2), else: color2
    contrast_ratio(c1, c2)
  end

  def contrast_ratio(%Color{} = color1, %Color{} = color2) do
    l1 = relative_luminance(color1)
    l2 = relative_luminance(color2)

    lighter = max(l1, l2)
    darker = min(l1, l2)

    ratio = (lighter + 0.05) / (darker + 0.05)
    # Round to 2 decimal places for readability
    Float.round(ratio, 2)
  end

  @doc """
  Checks if a foreground color is readable on a background color.

  ## Parameters

  - `background` - Background color
  - `foreground` - Text color
  - `level` - Accessibility level (`:aa`, `:aaa`, `:aa_large`, `:aaa_large`)

  ## Examples

      iex> bg = Raxol.Style.Colors.Color.from_hex("#333333")
      iex> fg = Raxol.Style.Colors.Color.from_hex("#FFFFFF")
      iex> Raxol.Style.Colors.Accessibility.readable?(bg, fg)
      true

      iex> bg = Raxol.Style.Colors.Color.from_hex("#CCCCCC")
      iex> fg = Raxol.Style.Colors.Color.from_hex("#999999")
      iex> Raxol.Style.Colors.Accessibility.readable?(bg, fg, :aaa)
      false
  """
  @spec readable?(Color.t() | String.t(), Color.t() | String.t(), :aa | :aaa | :aa_large | :aaa_large) ::
          boolean()
  def readable?(background, foreground, level \\ :aa) do
    ratio = contrast_ratio(background, foreground)

    threshold =
      case level do
        :aa -> @contrast_aa
        :aaa -> @contrast_aaa
        :aa_large -> @contrast_aa_large
        :aaa_large -> @contrast_aaa_large
      end

    ratio >= threshold
  end

  @doc """
  Suggests an appropriate text color (black or white) for a given background.

  Ensures minimum AA contrast.

  ## Parameters

  - `background` - The background color (hex string or Color struct)

  ## Examples

      iex> Raxol.Style.Colors.Accessibility.suggest_text_color("#333333").hex
      "#FFFFFF"

      iex> Raxol.Style.Colors.Accessibility.suggest_text_color("#EEEEEE").hex
      "#000000"
  """
  def suggest_text_color(background) when is_binary(background) do
    case Color.from_hex(background) do
      %Color{} = c -> suggest_text_color(c)
      _ -> Color.from_hex("#000000") # Default to black for invalid bg
    end
  end

  def suggest_text_color(%Color{} = background) do
    black = Color.from_hex("#000000")
    white = Color.from_hex("#FFFFFF")

    ratio_with_white = contrast_ratio(background, white)
    ratio_with_black = contrast_ratio(background, black)

    if ratio_with_white >= ratio_with_black do
      white # Prefer white if contrast is equal or better
    else
      black
    end
  end

  @doc """
  Suggests a color with good contrast (at least AA) to the base color.

  Prioritizes complementary color, then black/white.

  ## Parameters

  - `color` - The base color (hex string or Color struct)

  ## Examples

      iex> color = Raxol.Style.Colors.Color.from_hex("#3366CC")
      iex> contrast_color = Raxol.Style.Colors.Accessibility.suggest_contrast_color(color)
      iex> Raxol.Style.Colors.Accessibility.readable?(color, contrast_color)
      true
  """
  def suggest_contrast_color(color) when is_binary(color) do
     case Color.from_hex(color) do
      %Color{} = c -> suggest_contrast_color(c)
      _ -> Color.from_hex("#000000") # Default to black for invalid base
    end
  end

  def suggest_contrast_color(%Color{} = color) do
    # Start with the complementary color
    # Need access to complement, which might move to HSL or stay in Color
    # Assuming Color.complement exists for now
    complement = Color.complement(color)

    # Check if it has enough contrast
    if readable?(color, complement, :aa) do
      complement
    else
      # If not, try black or white (whichever has better contrast)
      suggest_text_color(color) # This chooses black/white based on contrast
    end
  end

  @doc """
  Creates a pair of colors {background, foreground} that meet accessibility guidelines.

  Tries base color with black/white, then adjusts base if needed.

  ## Parameters

  - `base_color` - The base color to use (hex string or Color struct)
  - `level` - Accessibility level (`:aa`, `:aaa`, `:aa_large`, `:aaa_large`)

  ## Examples

      iex> {bg, fg} = Raxol.Style.Colors.Accessibility.accessible_color_pair("#3366CC")
      iex> Raxol.Style.Colors.Accessibility.readable?(bg, fg)
      true
  """
  def accessible_color_pair(base_color, level \\ :aa) when is_binary(base_color) do
    case Color.from_hex(base_color) do
      %Color{} = c -> accessible_color_pair(c, level)
      # Default pair for invalid base color
      _ -> {Color.from_hex("#FFFFFF"), Color.from_hex("#000000")}
    end
  end

  def accessible_color_pair(%Color{} = base_color, level \\ :aa) do
    suggested_fg = suggest_text_color(base_color)

    if readable?(base_color, suggested_fg, level) do
      {base_color, suggested_fg}
    else
      # If suggested (black/white) doesn't work, we need to adjust the base color
      # This requires lighten/darken functions, which will be in HSL module.
      # For now, return a default safe pair if adjustment is needed.
      # TODO: Integrate with HSL module later for adjustment logic.
      if relative_luminance(base_color) > 0.5 do
        # Base is light, suggest black text, try darkening base if needed
        # Placeholder: return safe pair
        {Color.from_hex("#FFFFFF"), Color.from_hex("#000000")}
      else
        # Base is dark, suggest white text, try lightening base if needed
        # Placeholder: return safe pair
        {Color.from_hex("#000000"), Color.from_hex("#FFFFFF")}
      end
    end
  end

  @doc """
  Darkens a color until it meets the specified contrast ratio with a background color.

  Requires HSL module for `darken` function.

  ## Parameters

  - `color` - The color to darken (Color struct)
  - `background` - The background color (Color struct)
  - `target_ratio` - The target contrast ratio to achieve

  ## Returns

  - A Color struct representing the darkened color
  """
  @spec darken_until_contrast(Color.t(), Color.t(), number()) :: Color.t()
  def darken_until_contrast(%Color{} = color, %Color{} = background, target_ratio) do
    if contrast_ratio(color, background) >= target_ratio do
      color
    else
      # Need Raxol.Style.Colors.HSL.darken/2
      darken_step = 0.05 # Adjust step as needed

      Stream.iterate(color, &Raxol.Style.Colors.HSL.darken(&1, darken_step))
      # Stop if color becomes black or meets contrast
      |> Stream.take_while(fn c ->
           (c.r > 0 or c.g > 0 or c.b > 0) and contrast_ratio(c, background) < target_ratio
         end)
      # Get the last element before the stream stopped, or the first if it met contrast immediately
      |> Enum.to_list()
      |> List.last()
      |> case do
           # If stream was empty (already met contrast) or we found a color
           nil -> Raxol.Style.Colors.HSL.darken(color, darken_step) # Darken at least once
           last_checked -> Raxol.Style.Colors.HSL.darken(last_checked, darken_step) # Ensure contrast met
         end
       # Final check in case the last step overshot
       |> ensure_contrast_or_limit(background, target_ratio, :darker, color)
    end
  end

  @doc """
  Lightens a color until it meets the specified contrast ratio with a background color.

  Requires HSL module for `lighten` function.

  ## Parameters

  - `color` - The color to lighten (Color struct)
  - `background` - The background color (Color struct)
  - `target_ratio` - The target contrast ratio to achieve

  ## Returns

  - A Color struct representing the lightened color
  """
  @spec lighten_until_contrast(Color.t(), Color.t(), number()) :: Color.t()
  def lighten_until_contrast(%Color{} = color, %Color{} = background, target_ratio) do
     if contrast_ratio(color, background) >= target_ratio do
      color
    else
      # Need Raxol.Style.Colors.HSL.lighten/2
      lighten_step = 0.05 # Adjust step as needed

      Stream.iterate(color, &Raxol.Style.Colors.HSL.lighten(&1, lighten_step))
      # Stop if color becomes white or meets contrast
      |> Stream.take_while(fn c ->
            (c.r < 255 or c.g < 255 or c.b < 255) and contrast_ratio(c, background) < target_ratio
         end)
      # Get the last element before the stream stopped, or the first if it met contrast immediately
      |> Enum.to_list()
      |> List.last()
      |> case do
           nil -> Raxol.Style.Colors.HSL.lighten(color, lighten_step) # Lighten at least once
           last_checked -> Raxol.Style.Colors.HSL.lighten(last_checked, lighten_step) # Ensure contrast met
         end
       # Final check in case the last step overshot
       |> ensure_contrast_or_limit(background, target_ratio, :lighter, color)
    end
  end

  # Helper to ensure contrast is met or return the limit (black/white)
  defp ensure_contrast_or_limit(adjusted_color, background, target_ratio, direction, original_color) do
    if contrast_ratio(adjusted_color, background) >= target_ratio do
      adjusted_color
    else
      # If even max adjustment doesn't meet contrast, return black/white or original?
      # Returning black/white might be safer depending on use case.
      # Returning original might preserve intent better.
      # Let's return the limit (black/white) for now.
      case direction do
        :darker -> Color.from_hex("#000000")
        :lighter -> Color.from_hex("#FFFFFF")
        _ -> original_color # Fallback
      end
    end
  end

end
