defmodule Raxol.Style.Colors.Utilities do
  @moduledoc """
  Provides color manipulation and accessibility utilities.

  This module contains functions for analyzing colors, ensuring proper contrast
  for accessibility, and generating harmonious color combinations.

  ## Examples

  ```elixir
  alias Raxol.Style.Colors.{Color, Utilities}

  # Check if text is readable on a background
  bg = Color.from_hex("#333333")
  fg = Color.from_hex("#FFFFFF")
  Utilities.is_readable?(bg, fg)  # Returns true

  # Get the contrast ratio between two colors
  ratio = Utilities.contrast_ratio(bg, fg)  # Returns 12.63

  # Suggest a text color for a background
  text_color = Utilities.suggest_text_color(bg)  # Returns white for dark backgrounds

  # Generate color harmonies
  red = Color.from_hex("#FF0000")
  analogous = Utilities.analogous_colors(red)  # Returns colors adjacent to red
  complementary = Utilities.complementary_colors(red)  # Returns red and its opposite
  """

  alias Raxol.Style.Colors.Color

  # WCAG contrast ratio thresholds
  @contrast_aa 4.5  # AA level for normal text
  @contrast_aaa 7.0  # AAA level for normal text
  @contrast_aa_large 3.0  # AA level for large text
  @contrast_aaa_large 4.5  # AAA level for large text

  @doc """
  Calculates the relative luminance of a color according to WCAG guidelines.

  ## Parameters

  - `color` - The color to calculate luminance for (hex string or Color struct)

  ## Returns

  - A float between 0 and 1 representing the relative luminance

  ## Examples

      iex> Utilities.relative_luminance("#000000")
      0.0

      iex> Utilities.relative_luminance("#FFFFFF")
      1.0
  """
  def relative_luminance(color) when is_binary(color) do
    color = Color.from_hex(color)
    relative_luminance(color)
  end

  def relative_luminance(%Color{r: r, g: g, b: b}) do
    # Convert RGB values to relative luminance
    r = if r <= 10, do: r / 255 / 12.92, else: :math.pow((r / 255 + 0.055) / 1.055, 2.4)
    g = if g <= 10, do: g / 255 / 12.92, else: :math.pow((g / 255 + 0.055) / 1.055, 2.4)
    b = if b <= 10, do: b / 255 / 12.92, else: :math.pow((b / 255 + 0.055) / 1.055, 2.4)

    0.2126 * r + 0.7152 * g + 0.0722 * b
  end

  @doc """
  Calculates the contrast ratio between two colors according to WCAG guidelines.

  ## Parameters

  - `color1` - The first color (hex string or Color struct)
  - `color2` - The second color (hex string or Color struct)

  ## Returns

  - A float representing the contrast ratio (1:1 to 21:1)

  ## Examples

      iex> Utilities.contrast_ratio("#000000", "#FFFFFF")
      21.0

      iex> Utilities.contrast_ratio("#777777", "#999999")
      1.3
  """
  def contrast_ratio(color1, color2) when is_binary(color1) or is_binary(color2) do
    color1 = if is_binary(color1), do: Color.from_hex(color1), else: color1
    color2 = if is_binary(color2), do: Color.from_hex(color2), else: color2
    contrast_ratio(color1, color2)
  end

  def contrast_ratio(color1, color2) do
    l1 = relative_luminance(color1)
    l2 = relative_luminance(color2)

    lighter = max(l1, l2)
    darker = min(l1, l2)

    (lighter + 0.05) / (darker + 0.05)
  end

  @doc """
  Checks if a color is considered dark.

  ## Parameters

  - `color` - The color to check (hex string or Color struct)

  ## Returns

  - `true` if the color is dark, `false` otherwise

  ## Examples

      iex> Utilities.dark_color?("#000000")
      true

      iex> Utilities.dark_color?("#FFFFFF")
      false
  """
  def dark_color?(color) when is_binary(color) do
    color = Color.from_hex(color)
    dark_color?(color)
  end

  def dark_color?(%Color{} = color) do
    relative_luminance(color) < 0.5
  end

  @doc """
  Darkens a color until it meets the specified contrast ratio with a background color.

  ## Parameters

  - `color` - The color to darken (hex string or Color struct)
  - `background` - The background color (hex string or Color struct)
  - `target_ratio` - The target contrast ratio to achieve

  ## Returns

  - A hex string representing the darkened color

  ## Examples

      iex> Utilities.darken_until_contrast("#777777", "#FFFFFF", 4.5)
      "#595959"
  """
  def darken_until_contrast(color, background, target_ratio) when is_binary(color) or is_binary(background) do
    color = if is_binary(color), do: Color.from_hex(color), else: color
    background = if is_binary(background), do: Color.from_hex(background), else: background
    darken_until_contrast(color, background, target_ratio)
  end

  def darken_until_contrast(%Color{} = color, %Color{} = background, target_ratio) do
    # Start with the original color
    current = color

    # Keep darkening until we meet the target ratio or can't darken anymore
    Stream.iterate(current, &darken_color/1)
    |> Stream.take_while(&(&1.r > 0 or &1.g > 0 or &1.b > 0))
    |> Enum.find(fn c ->
      ratio = contrast_ratio(c, background)
      ratio >= target_ratio
    end)
    |> case do
      nil -> color  # If we couldn't find a suitable color, return the original
      result -> Color.to_hex(result)
    end
  end

  @doc """
  Lightens a color until it meets the specified contrast ratio with a background color.

  ## Parameters

  - `color` - The color to lighten (hex string or Color struct)
  - `background` - The background color (hex string or Color struct)
  - `target_ratio` - The target contrast ratio to achieve

  ## Returns

  - A hex string representing the lightened color

  ## Examples

      iex> Utilities.lighten_until_contrast("#777777", "#000000", 4.5)
      "#CCCCCC"
  """
  def lighten_until_contrast(color, background, target_ratio) when is_binary(color) or is_binary(background) do
    color = if is_binary(color), do: Color.from_hex(color), else: color
    background = if is_binary(background), do: Color.from_hex(background), else: background
    lighten_until_contrast(color, background, target_ratio)
  end

  def lighten_until_contrast(%Color{} = color, %Color{} = background, target_ratio) do
    # Start with the original color
    current = color

    # Keep lightening until we meet the target ratio or can't lighten anymore
    Stream.iterate(current, &lighten_color/1)
    |> Stream.take_while(&(&1.r < 255 or &1.g < 255 or &1.b < 255))
    |> Enum.find(fn c ->
      ratio = contrast_ratio(c, background)
      ratio >= target_ratio
    end)
    |> case do
      nil -> color  # If we couldn't find a suitable color, return the original
      result -> Color.to_hex(result)
    end
  end

  @doc """
  Rotates the hue of a color by a specified number of degrees.

  ## Parameters

  - `color` - The color to rotate (hex string or Color struct)
  - `degrees` - The number of degrees to rotate (0-360)

  ## Returns

  - A hex string representing the rotated color

  ## Examples

      iex> Utilities.rotate_hue("#FF0000", 120)
      "#00FF00"
  """
  def rotate_hue(color, degrees) when is_binary(color) do
    color = Color.from_hex(color)
    rotate_hue(color, degrees)
  end

  def rotate_hue(%Color{} = color, degrees) do
    # Convert RGB to HSL
    {h, s, l} = rgb_to_hsl(color.r, color.g, color.b)

    # Rotate hue
    new_h = rem(round(h + degrees), 360)

    # Convert back to RGB
    {r, g, b} = hsl_to_rgb(new_h, s, l)

    # Create new color and convert to hex
    %Color{r: r, g: g, b: b}
    |> Color.to_hex()
  end

  # Private helper functions

  defp darken_color(%Color{r: r, g: g, b: b}) do
    %Color{
      r: max(0, r - 10),
      g: max(0, g - 10),
      b: max(0, b - 10)
    }
  end

  defp lighten_color(%Color{r: r, g: g, b: b}) do
    %Color{
      r: min(255, r + 10),
      g: min(255, g + 10),
      b: min(255, b + 10)
    }
  end

  @doc """
  Converts RGB values to HSL.

  ## Parameters
  - `r`, `g`, `b` - Red, Green, Blue values (0-255)

  ## Returns
  - `{h, s, l}` tuple: Hue (0-360), Saturation (0.0-1.0), Lightness (0.0-1.0)
  """
  @spec rgb_to_hsl(integer(), integer(), integer()) :: {float(), float(), float()}
  def rgb_to_hsl(r, g, b) do
    r_norm = r / 255
    g_norm = g / 255
    b_norm = b / 255

    max = Enum.max([r_norm, g_norm, b_norm])
    min = Enum.min([r_norm, g_norm, b_norm])
    delta = max - min

    h = _calculate_hue(r_norm, g_norm, b_norm, max, delta)
    l = (max + min) / 2
    s = if delta == 0, do: 0, else: delta / (1 - abs(2 * l - 1))

    {h, s, l}
  end

  defp _calculate_hue(r, g, b, max, delta) do
    cond do
      delta == 0 -> 0
      max == r -> 60 * rem(round((g - b) / delta), 6)
      max == g -> 60 * ((b - r) / delta + 2)
      true -> 60 * ((r - g) / delta + 4) # max == b
    end
  end

  @doc """
  Converts HSL values to RGB.

  ## Parameters
  - `h`, `s`, `l` - Hue (0-360), Saturation (0.0-1.0), Lightness (0.0-1.0)

  ## Returns
  - `{r, g, b}` tuple: Red, Green, Blue values (0-255)
  """
  @spec hsl_to_rgb(number(), float(), float()) :: {integer(), integer(), integer()}
  def hsl_to_rgb(h, s, l) when is_number(h) and is_float(s) and is_float(l) do
    c = (1 - abs(2 * l - 1)) * s
    x = c * (1 - abs(Float.rem(h / 60, 2.0) - 1))
    m = l - c / 2

    {r_prime, g_prime, b_prime} = _calculate_rgb_segment(h, c, x)

    {
      round((r_prime + m) * 255),
      round((g_prime + m) * 255),
      round((b_prime + m) * 255)
    }
  end

  @spec _calculate_rgb_segment(number(), float(), float()) :: {float(), float(), float()}
  defp _calculate_rgb_segment(h, c, x) do
     cond do
      h < 60 -> {c, x, 0.0}
      h < 120 -> {x, c, 0.0}
      h < 180 -> {0.0, c, x}
      h < 240 -> {0.0, x, c}
      h < 300 -> {x, 0.0, c}
      true -> {c, 0.0, x} # h < 360
    end
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
      iex> Raxol.Style.Colors.Utilities.readable?(bg, fg)
      true

      iex> bg = Raxol.Style.Colors.Color.from_hex("#CCCCCC")
      iex> fg = Raxol.Style.Colors.Color.from_hex("#999999")
      iex> Raxol.Style.Colors.Utilities.readable?(bg, fg, :aaa)
      false
  """
  @spec readable?(Color.t(), Color.t(), :aa | :aaa | :aa_large | :aaa_large) :: boolean()
  def readable?(%Color{} = background, %Color{} = foreground, level \\ :aa) do
    ratio = contrast_ratio(background, foreground)

    threshold = case level do
      :aa -> @contrast_aa
      :aaa -> @contrast_aaa
      :aa_large -> @contrast_aa_large
      :aaa_large -> @contrast_aaa_large
    end

    ratio >= threshold
  end

  @doc """
  Calculates the perceived brightness of a color.

  Returns a value between 0 (darkest) and 255 (brightest).

  ## Parameters

  - `color` - The color to analyze

  ## Examples

      iex> black = Raxol.Style.Colors.Color.from_hex("#000000")
      iex> Raxol.Style.Colors.Utilities.brightness(black)
      0

      iex> white = Raxol.Style.Colors.Color.from_hex("#FFFFFF")
      iex> Raxol.Style.Colors.Utilities.brightness(white)
      255
  """
  def brightness(%Color{r: r, g: g, b: b}) do
    # Formula: (299*R + 587*G + 114*B) / 1000
    # Simplified to be in 0-255 range
    round((299 * r + 587 * g + 114 * b) / 1000)
  end

  @doc """
  Calculates the relative luminance of a color according to WCAG.

  Returns a value between 0 (darkest) and 1 (brightest).

  ## Parameters

  - `color` - The color to analyze

  ## Examples

      iex> black = Raxol.Style.Colors.Color.from_hex("#000000")
      iex> Raxol.Style.Colors.Utilities.luminance(black)
      0.0

      iex> white = Raxol.Style.Colors.Color.from_hex("#FFFFFF")
      iex> Raxol.Style.Colors.Utilities.luminance(white)
      1.0
  """
  def luminance(%Color{} = color) do
    relative_luminance(color)
  end

  @doc """
  Suggests an appropriate text color (black or white) for a given background.

  ## Parameters

  - `background` - The background color

  ## Examples

      iex> dark_bg = Raxol.Style.Colors.Color.from_hex("#333333")
      iex> Raxol.Style.Colors.Utilities.suggest_text_color(dark_bg).hex
      "#FFFFFF"

      iex> light_bg = Raxol.Style.Colors.Color.from_hex("#EEEEEE")
      iex> Raxol.Style.Colors.Utilities.suggest_text_color(light_bg).hex
      "#000000"
  """
  def suggest_text_color(%Color{} = background) do
    # Use white text for dark backgrounds, black text for light backgrounds
    # Using the YIQ formula for perceived brightness
    yiq = ((background.r * 299) + (background.g * 587) + (background.b * 114)) / 1000

    if yiq >= 128 do
      # Dark text on light background
      Color.from_hex("#000000")
    else
      # Light text on dark background
      Color.from_hex("#FFFFFF")
    end
  end

  @doc """
  Suggests a color with good contrast to the base color.

  ## Parameters

  - `color` - The base color

  ## Examples

      iex> color = Raxol.Style.Colors.Color.from_hex("#3366CC")
      iex> contrast = Raxol.Style.Colors.Utilities.suggest_contrast_color(color)
      iex> Raxol.Style.Colors.Utilities.contrast_ratio(color, contrast) > 4.5
      true
  """
  def suggest_contrast_color(%Color{} = color) do
    # Start with the complementary color
    complement = Color.complement(color)

    # Check if it has enough contrast
    if contrast_ratio(color, complement) >= @contrast_aa do
      complement
    else
      # If not, try black or white (whichever has better contrast)
      black = Color.from_hex("#000000")
      white = Color.from_hex("#FFFFFF")

      black_ratio = contrast_ratio(color, black)
      white_ratio = contrast_ratio(color, white)

      if black_ratio > white_ratio, do: black, else: white
    end
  end

  @doc """
  Creates a pair of colors that meet accessibility guidelines.

  ## Parameters

  - `base_color` - The base color to use
  - `level` - Accessibility level (`:aa`, `:aaa`, `:aa_large`, `:aaa_large`)

  ## Examples

      iex> color = Raxol.Style.Colors.Color.from_hex("#3366CC")
      iex> {bg, fg} = Raxol.Style.Colors.Utilities.accessible_color_pair(color)
      iex> Raxol.Style.Colors.Utilities.readable?(bg, fg)
      true
  """
  def accessible_color_pair(%Color{} = base_color, level \\ :aa) do
    # Try using the base color as background with black or white text
    black = Color.from_hex("#000000")
    white = Color.from_hex("#FFFFFF")

    cond do
      readable?(base_color, black, level) ->
        {base_color, black}

      readable?(base_color, white, level) ->
        {base_color, white}

      # If neither works well, adjust the base color darker or lighter
      true ->
        if brightness(base_color) > 127 do
          # Light color - make it lighter and use black text
          lighter = Color.lighten(base_color, 0.3)
          {lighter, black}
        else
          # Dark color - make it darker and use white text
          darker = Color.darken(base_color, 0.3)
          {darker, white}
        end
    end
  end

  @doc """
  Generates analogous colors (adjacent on the color wheel).

  ## Parameters

  - `color` - The base color
  - `count` - Number of colors to generate (including the base color)

  ## Examples

      iex> color = Raxol.Style.Colors.Color.from_hex("#FF0000")  # Red
      iex> colors = Raxol.Style.Colors.Utilities.analogous_colors(color)
      iex> length(colors)
      3
  """
  def analogous_colors(%Color{} = color, count \\ 3) when count >= 1 do
    # Convert to HSL to work with hue
    {h, s, l} = rgb_to_hsl(color.r, color.g, color.b)

    # Generate colors with hues spaced around the base color
    # Typically 30 degrees apart in either direction
    angle = 30
    hue_shift = div(angle * (count - 1), 2)

    -hue_shift..hue_shift
    |> Enum.map(fn shift ->
      # Calculate new hue (wrapping around 360 degrees)
      new_h = rem(h + shift + 360, 360)
      # Convert back to RGB
      {r, g, b} = hsl_to_rgb(new_h, s, l)
      Color.from_rgb(r, g, b)
    end)
  end

  @doc """
  Generates complementary colors (opposite on the color wheel).

  ## Parameters

  - `color` - The base color

  ## Examples

      iex> color = Raxol.Style.Colors.Color.from_hex("#FF0000")  # Red
      iex> [red, cyan] = Raxol.Style.Colors.Utilities.complementary_colors(color)
      iex> cyan.hex
      "#00FFFF"
  """
  def complementary_colors(%Color{} = color) do
    complement = Color.complement(color)
    [color, complement]
  end

  @doc """
  Generates triadic colors (three colors evenly spaced on the color wheel).

  ## Parameters

  - `color` - The base color

  ## Examples

      iex> color = Raxol.Style.Colors.Color.from_hex("#FF0000")  # Red
      iex> colors = Raxol.Style.Colors.Utilities.triadic_colors(color)
      iex> length(colors)
      3
  """
  def triadic_colors(%Color{} = color) do
    # Convert to HSL to work with hue
    {h, s, l} = rgb_to_hsl(color.r, color.g, color.b)

    # Generate colors 120 degrees apart
    [0, 120, 240]
    |> Enum.map(fn shift ->
      # Calculate new hue (wrapping around 360 degrees)
      new_h = rem(h + shift, 360)
      # Convert back to RGB
      {r, g, b} = hsl_to_rgb(new_h, s, l)
      Color.from_rgb(r, g, b)
    end)
  end

  @doc """
  Lightens a color by a specified amount.

  ## Parameters

  - `color` - The color to lighten (hex string or Color struct)
  - `amount` - The amount to lighten by (0.0 to 1.0)

  ## Returns

  - A hex string representing the lightened color
  """
  def lighten(color, amount) when is_binary(color) do
    color = Color.from_hex(color)
    lighten(color, amount)
  end

  def lighten(%Color{} = color, amount) do
    {h, s, l} = rgb_to_hsl(color.r, color.g, color.b)
    new_l = min(l + amount, 1.0)
    {r, g, b} = hsl_to_rgb(h, s, new_l)
    Color.to_hex(%Color{r: r, g: g, b: b})
  end

  @doc """
  Darkens a color by a specified amount.

  ## Parameters

  - `color` - The color to darken (hex string or Color struct)
  - `amount` - The amount to darken by (0.0 to 1.0)

  ## Returns

  - A hex string representing the darkened color
  """
  def darken(color, amount) when is_binary(color) do
    color = Color.from_hex(color)
    darken(color, amount)
  end

  def darken(%Color{} = color, amount) do
    {h, s, l} = rgb_to_hsl(color.r, color.g, color.b)
    new_l = max(l - amount, 0.0)
    {r, g, b} = hsl_to_rgb(h, s, new_l)
    Color.to_hex(%Color{r: r, g: g, b: b})
  end

  @doc """
  Saturates a color by a specified amount.

  ## Parameters

  - `color` - The color to saturate (hex string or Color struct)
  - `amount` - The amount to saturate by (0.0 to 1.0)

  ## Returns

  - A hex string representing the saturated color
  """
  def saturate(color, amount) when is_binary(color) do
    color = Color.from_hex(color)
    saturate(color, amount)
  end

  def saturate(%Color{} = color, amount) do
    {h, s, l} = rgb_to_hsl(color.r, color.g, color.b)
    new_s = min(s + amount, 1.0)
    {r, g, b} = hsl_to_rgb(h, new_s, l)
    Color.to_hex(%Color{r: r, g: g, b: b})
  end

  @doc """
  Desaturates a color by a specified amount.

  ## Parameters

  - `color` - The color to desaturate (hex string or Color struct)
  - `amount` - The amount to desaturate by (0.0 to 1.0)

  ## Returns

  - A hex string representing the desaturated color
  """
  def desaturate(color, amount) when is_binary(color) do
    color = Color.from_hex(color)
    desaturate(color, amount)
  end

  def desaturate(%Color{} = color, amount) do
    {h, s, l} = rgb_to_hsl(color.r, color.g, color.b)
    new_s = max(s - amount, 0.0)
    {r, g, b} = hsl_to_rgb(h, new_s, l)
    Color.to_hex(%Color{r: r, g: g, b: b})
  end

  @doc """
  Checks if a hex string is a valid hex color.

  ## Parameters

  - `hex_string` - The hex string to check

  ## Returns

  - `true` if the hex string is a valid hex color, `false` otherwise

  ## Examples

      iex> Raxol.Style.Colors.Utilities.hex_color?("#FF00AA")
      true
      iex> Raxol.Style.Colors.Utilities.hex_color?("blue")
      false
  """
  @spec hex_color?(String.t()) :: boolean()
  def hex_color?(hex_string) when is_binary(hex_string) do
    # Regex for #RGB, #RGBA, #RRGGBB, #RRGGBBAA
    ~r/^#([0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/
    |> Regex.match?(hex_string)
  end
end
