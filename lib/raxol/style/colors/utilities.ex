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
  ```
  """
  
  alias Raxol.Style.Colors.Color
  
  # WCAG contrast ratio thresholds
  @contrast_aa 4.5  # AA level for normal text
  @contrast_aaa 7.0  # AAA level for normal text
  @contrast_aa_large 3.0  # AA level for large text
  @contrast_aaa_large 4.5  # AAA level for large text
  
  @doc """
  Calculates the contrast ratio between two colors according to WCAG guidelines.
  
  The ratio ranges from 1:1 (no contrast) to 21:1 (black on white).
  
  ## Parameters
  
  - `color1` - First color
  - `color2` - Second color
  
  ## Examples
  
      iex> black = Raxol.Style.Colors.Color.from_hex("#000000")
      iex> white = Raxol.Style.Colors.Color.from_hex("#FFFFFF")
      iex> Raxol.Style.Colors.Utilities.contrast_ratio(black, white)
      21.0
  """
  def contrast_ratio(%Color{} = color1, %Color{} = color2) do
    # Calculate relative luminance for both colors
    l1 = relative_luminance(color1)
    l2 = relative_luminance(color2)
    
    # Determine lighter and darker luminance
    {lighter, darker} = if l1 > l2, do: {l1, l2}, else: {l2, l1}
    
    # Calculate contrast ratio
    (lighter + 0.05) / (darker + 0.05)
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
      iex> Raxol.Style.Colors.Utilities.is_readable?(bg, fg)
      true
      
      iex> bg = Raxol.Style.Colors.Color.from_hex("#CCCCCC")
      iex> fg = Raxol.Style.Colors.Color.from_hex("#999999")
      iex> Raxol.Style.Colors.Utilities.is_readable?(bg, fg, :aaa)
      false
  """
  def is_readable?(%Color{} = background, %Color{} = foreground, level \\ :aa) do
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
      iex> Raxol.Style.Colors.Utilities.is_readable?(bg, fg)
      true
  """
  def accessible_color_pair(%Color{} = base_color, level \\ :aa) do
    # Try using the base color as background with black or white text
    black = Color.from_hex("#000000")
    white = Color.from_hex("#FFFFFF")
    
    cond do
      is_readable?(base_color, black, level) ->
        {base_color, black}
        
      is_readable?(base_color, white, level) ->
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
  
  # Private functions
  
  # Calculate relative luminance according to WCAG
  defp relative_luminance(%Color{r: r, g: g, b: b}) do
    # Normalize RGB values to 0-1
    r_srgb = r / 255
    g_srgb = g / 255
    b_srgb = b / 255
    
    # Convert to linear RGB
    r_linear = if r_srgb <= 0.03928, do: r_srgb / 12.92, else: :math.pow((r_srgb + 0.055) / 1.055, 2.4)
    g_linear = if g_srgb <= 0.03928, do: g_srgb / 12.92, else: :math.pow((g_srgb + 0.055) / 1.055, 2.4)
    b_linear = if b_srgb <= 0.03928, do: b_srgb / 12.92, else: :math.pow((b_srgb + 0.055) / 1.055, 2.4)
    
    # Calculate luminance
    0.2126 * r_linear + 0.7152 * g_linear + 0.0722 * b_linear
  end
  
  # Convert RGB to HSL
  defp rgb_to_hsl(r, g, b) do
    # Normalize RGB values to 0-1
    r_norm = r / 255
    g_norm = g / 255
    b_norm = b / 255
    
    # Find max and min values
    c_max = max(r_norm, max(g_norm, b_norm))
    c_min = min(r_norm, min(g_norm, b_norm))
    delta = c_max - c_min
    
    # Calculate hue
    h = cond do
      delta == 0 -> 0
      c_max == r_norm -> 60 * (rem(((g_norm - b_norm) / delta), 6))
      c_max == g_norm -> 60 * (((b_norm - r_norm) / delta) + 2)
      c_max == b_norm -> 60 * (((r_norm - g_norm) / delta) + 4)
    end
    
    # Ensure h is positive
    h = if h < 0, do: h + 360, else: h
    
    # Calculate lightness
    l = (c_max + c_min) / 2
    
    # Calculate saturation
    s = if delta == 0, do: 0, else: delta / (1 - abs(2 * l - 1))
    
    {round(h), s, l}
  end
  
  # Convert HSL to RGB
  defp hsl_to_rgb(h, s, l) do
    # Helper function
    hue_to_rgb = fn p, q, t ->
      t = if t < 0, do: t + 1, else: t
      t = if t > 1, do: t - 1, else: t
      
      cond do
        t < 1/6 -> p + (q - p) * 6 * t
        t < 1/2 -> q
        t < 2/3 -> p + (q - p) * (2/3 - t) * 6
        true -> p
      end
    end
    
    # Edge case for grayscale
    if s == 0 do
      # Achromatic (gray)
      gray = round(l * 255)
      {gray, gray, gray}
    else
      # Calculate temporary values
      q = if l < 0.5, do: l * (1 + s), else: l + s - l * s
      p = 2 * l - q
      
      # Normalize hue to 0-1
      h_norm = h / 360
      
      # Convert to RGB
      r = hue_to_rgb.(p, q, h_norm + 1/3)
      g = hue_to_rgb.(p, q, h_norm)
      b = hue_to_rgb.(p, q, h_norm - 1/3)
      
      # Convert to 0-255 range
      {round(r * 255), round(g * 255), round(b * 255)}
    end
  end
end 