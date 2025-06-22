defmodule Raxol.Style.Colors.Advanced do
  @moduledoc """
  Provides advanced color handling capabilities for the terminal.

  Features:
  - Color blending and mixing
  - Custom color palettes
  - Enhanced color adaptation
  - Color space conversions
  - Color harmony generation
  """

  alias Raxol.Style.Colors.Color
  alias Raxol.Style.Colors.{Adaptive}
  require :math

  @type color :: Color.t()

  @doc """
  Blends two colors together with the given ratio.

  ## Parameters

  - `color1` - First color
  - `color2` - Second color
  - `ratio` - Blend ratio (0.0 to 1.0, where 0.0 is color1 and 1.0 is color2)

  ## Examples

      iex> color1 = Color.from_hex("#FF0000")
      iex> color2 = Color.from_hex("#0000FF")
      iex> blended = Advanced.blend_colors(color1, color2, 0.5)
      iex> blended.hex
      "#800080"  # Purple
  """
  def blend_colors(%Color{} = color1, %Color{} = color2, ratio)
      when ratio >= 0 and ratio <= 1 do
    r = round(color1.r * (1 - ratio) + color2.r * ratio)
    g = round(color1.g * (1 - ratio) + color2.g * ratio)
    b = round(color1.b * (1 - ratio) + color2.b * ratio)

    Color.from_rgb(r, g, b)
  end

  @doc """
  Creates a gradient between two colors with the specified number of steps.

  ## Parameters

  - `color1` - Start color
  - `color2` - End color
  - `steps` - Number of steps in the gradient

  ## Examples

      iex> color1 = Color.from_hex("#FF0000")
      iex> color2 = Color.from_hex("#0000FF")
      iex> gradient = Advanced.create_gradient(color1, color2, 3)
      iex> Enum.map(gradient, & &1.hex)
      ["#FF0000", "#800080", "#0000FF"]
  """
  def create_gradient(%Color{} = color1, %Color{} = color2, steps)
      when steps > 1 do
    step_size = 1.0 / (steps - 1)

    for i <- 0..(steps - 1) do
      ratio = i * step_size
      blend_colors(color1, color2, ratio)
    end
  end

  @doc """
  Converts a color to a different color space.

  ## Parameters

  - `color` - The color to convert
  - `target_space` - The target color space (:rgb, :hsl, :lab, or :xyz)

  ## Examples

      iex> color = Color.from_hex("#FF0000")
      iex> hsl = Advanced.convert_color_space(color, :hsl)
      iex> hsl
      %{h: 0, s: 100, l: 50}
  """
  def convert_color_space(%Color{} = color, target_space) do
    case target_space do
      :rgb -> color
      :hsl -> rgb_to_hsl(color)
      :lab -> rgb_to_lab(color)
      :xyz -> rgb_to_xyz(color)
    end
  end

  @doc """
  Creates a color harmony based on the input color.

  ## Parameters

  - `color` - The base color
  - `harmony_type` - Type of harmony (:complementary, :analogous, :triadic, :tetradic)

  ## Examples

      iex> color = Color.from_hex("#FF0000")
      iex> harmony = Advanced.create_harmony(color, :complementary)
      iex> Enum.map(harmony, & &1.hex)
      ["#FF0000", "#00FFFF"]
  """
  def create_harmony(color, type, opts \\ []) do
    angle = Keyword.get(opts, :angle, harmony_angle(type))
    %{h: h, s: s_orig, l: l_orig} = rgb_to_hsl(color)
    s = s_orig / 100.0
    l = l_orig / 100.0

    harmony_colors = generate_harmony_colors(h, s, l, type, angle)
    preserve_brightness = Keyword.get(opts, :preserve_brightness, false)

    if preserve_brightness do
      adjust_harmony_brightness(harmony_colors, l)
    else
      harmony_colors
    end
  end

  defp generate_harmony_colors(h, s, l, type, angle) do
    case type do
      :complementary ->
        [hsl_to_rgb({h, s, l}) | [hsl_to_rgb({normalize_hue(h + angle), s, l})]]

      :analogous ->
        [
          hsl_to_rgb({h, s, l})
          | [
              hsl_to_rgb({normalize_hue(h - angle), s, l}),
              hsl_to_rgb({normalize_hue(h + angle), s, l})
            ]
        ]

      :triadic ->
        [
          hsl_to_rgb({h, s, l})
          | [
              hsl_to_rgb({normalize_hue(h - angle), s, l}),
              hsl_to_rgb({normalize_hue(h + angle), s, l})
            ]
        ]

      :split_complementary ->
        comp_hue = normalize_hue(h + 180)
        split1 = normalize_hue(comp_hue - angle)
        split2 = normalize_hue(comp_hue + angle)

        [
          hsl_to_rgb({h, s, l})
          | [hsl_to_rgb({split1, s, l}), hsl_to_rgb({split2, s, l})]
        ]

      :tetradic ->
        hue3 = normalize_hue(h + 180)
        hue4 = normalize_hue(hue3 + angle)

        [
          hsl_to_rgb({h, s, l})
          | [
              hsl_to_rgb({normalize_hue(h + angle), s, l}),
              hsl_to_rgb({hue3, s, l}),
              hsl_to_rgb({hue4, s, l})
            ]
        ]

      :square ->
        [hsl_to_rgb({h, s, l}) | generate_square_harmony(h, s, l)]
    end
  end

  defp generate_square_harmony(h, s, l) do
    [
      hsl_to_rgb({normalize_hue(h + 90), s, l}),
      hsl_to_rgb({normalize_hue(h + 180), s, l}),
      hsl_to_rgb({normalize_hue(h + 270), s, l})
    ]
  end

  defp adjust_harmony_brightness(harmony_colors, target_l) do
    harmony_colors
    |> Enum.flat_map(fn harmony_color ->
      %{h: h_harmony, s: s_harmony} = rgb_to_hsl(harmony_color)
      angle = harmony_angle(:complementary)
      hue1 = normalize_hue(h_harmony - angle)
      hue2 = normalize_hue(h_harmony + angle)

      [
        hsl_to_rgb({hue1, s_harmony, target_l}),
        hsl_to_rgb({hue2, s_harmony, target_l})
      ]
    end)
  end

  defp harmony_angle(:complementary), do: 180
  defp harmony_angle(:analogous), do: 30
  defp harmony_angle(:triadic), do: 120
  defp harmony_angle(:split_complementary), do: 30
  defp harmony_angle(:tetradic), do: 60
  defp harmony_angle(:square), do: 90

  defp normalize_hue(hue) do
    normalized = rem(round(hue), 360)
    if normalized < 0, do: normalized + 360, else: normalized
  end

  @doc """
  Adapts a color to the current terminal capabilities with advanced options.

  ## Parameters

  - `color` - The color to adapt
  - `options` - Adaptation options
    - `:preserve_brightness` - Try to maintain perceived brightness
    - `:enhance_contrast` - Increase contrast when possible
    - `:color_blind_safe` - Ensure color blind friendly colors

  ## Examples

      iex> color = Color.from_hex("#FF0000")
      iex> adapted = Advanced.adapt_color_advanced(color, preserve_brightness: true)
      iex> adapted.hex
      "#FF0000"  # If terminal supports true color
  """
  def adapt_color_advanced(%Color{} = color, options \\ []) do
    preserve_brightness = Keyword.get(options, :preserve_brightness, false)
    enhance_contrast = Keyword.get(options, :enhance_contrast, false)
    color_blind_safe = Keyword.get(options, :color_blind_safe, false)

    # First adapt to terminal capabilities
    adapted = Adaptive.adapt_color(color)

    # Then apply additional adaptations
    adapted
    |> maybe_preserve_brightness(preserve_brightness)
    |> maybe_enhance_contrast(enhance_contrast)
    |> maybe_make_color_blind_safe(color_blind_safe)
  end

  # Private helper functions

  # Reference: https://www.rapidtables.com/convert/color/rgb-to-hsl.html
  defp rgb_to_hsl(%Color{r: r, g: g, b: b}) do
    r_prime = r / 255
    g_prime = g / 255
    b_prime = b / 255

    c_max = Enum.max([r_prime, g_prime, b_prime])
    c_min = Enum.min([r_prime, g_prime, b_prime])
    delta = c_max - c_min

    h =
      cond do
        delta == 0 -> 0
        c_max == r_prime -> 60 * ((g_prime - b_prime) / delta)
        c_max == g_prime -> 60 * ((b_prime - r_prime) / delta + 2)
        c_max == b_prime -> 60 * ((r_prime - g_prime) / delta + 4)
      end

    # Ensure hue is positive
    h = if h < 0, do: h + 360, else: h

    l = (c_max + c_min) / 2

    s =
      if delta == 0 do
        0
      else
        delta / (1 - abs(2 * l - 1))
      end

    %{h: round(h), s: round(s * 100), l: round(l * 100)}
  end

  # Reference: https://www.rapidtables.com/convert/color/hsl-to-rgb.html
  defp hsl_to_rgb({h, s, l}) do
    c = (1 - abs(2 * l - 1)) * s
    x = c * (1 - abs(:math.fmod(h / 60, 2) - 1))
    m = l - c / 2

    {r_prime, g_prime, b_prime} =
      cond do
        h >= 0 and h < 60 -> {c, x, 0}
        h >= 60 and h < 120 -> {x, c, 0}
        h >= 120 and h < 180 -> {0, c, x}
        h >= 180 and h < 240 -> {0, x, c}
        h >= 240 and h < 300 -> {x, 0, c}
        h >= 300 and h < 360 -> {c, 0, x}
        true -> {0, 0, 0}
      end

    r = round((r_prime + m) * 255)
    g = round((g_prime + m) * 255)
    b = round((b_prime + m) * 255)

    r = max(0, min(255, r))
    g = max(0, min(255, g))
    b = max(0, min(255, b))

    Color.from_rgb(r, g, b)
  end

  defp rgb_to_lab(%Color{} = color) do
    # Convert RGB to XYZ first
    xyz = rgb_to_xyz(color)

    # Then convert XYZ to Lab
    # This is a simplified conversion - a full implementation would be more complex
    x = xyz.x / 95.047
    y = xyz.y / 100.0
    z = xyz.z / 108.883

    x = if x > 0.008856, do: :math.pow(x, 1 / 3), else: 7.787 * x + 16 / 116
    y = if y > 0.008856, do: :math.pow(y, 1 / 3), else: 7.787 * y + 16 / 116
    z = if z > 0.008856, do: :math.pow(z, 1 / 3), else: 7.787 * z + 16 / 116

    l = 116 * y - 16
    a = 500 * (x - y)
    b = 200 * (y - z)

    %{l: l, a: a, b: b}
  end

  defp rgb_to_xyz(%Color{r: r, g: g, b: b}) do
    # Convert RGB to XYZ using standard conversion matrix
    x = r * 0.4124 + g * 0.3576 + b * 0.1805
    y = r * 0.2126 + g * 0.7152 + b * 0.0722
    z = r * 0.0193 + g * 0.1192 + b * 0.9505

    %{x: x, y: y, z: z}
  end

  defp xyz_to_lab(%{x: x, y: y, z: z}) do
    # Convert XYZ to Lab using standard conversion
    x = if x > +0.008856, do: :math.pow(x, 1 / 3), else: 7.787 * x + 16 / 116
    y = if y > +0.008856, do: :math.pow(y, 1 / 3), else: 7.787 * y + 16 / 116
    z = if z > +0.008856, do: :math.pow(z, 1 / 3), else: 7.787 * z + 16 / 116

    l = 116 * y - 16
    a = 500 * (x - y)
    b = 200 * (y - z)

    %{l: l, a: a, b: b}
  end

  defp maybe_preserve_brightness(color, true) do
    # Calculate perceived brightness using luminance formula
    %{l: original_l} = rgb_to_hsl(color)

    # If brightness is too low, adjust lightness while preserving hue and saturation
    if original_l < 30 do
      %{h: h, s: s} = rgb_to_hsl(color)
      hsl_to_rgb({h, s, 0.3})  # Increase lightness to 30%
    else
      color
    end
  end

  defp maybe_preserve_brightness(color, false), do: color

  defp maybe_enhance_contrast(color, true) do
    # Enhance contrast by adjusting lightness
    %{h: h, s: s, l: l} = rgb_to_hsl(color)

    # If lightness is in middle range, push towards extremes
    adjusted_l = cond do
      l > 40 and l < 60 -> l + 20  # Lighten mid-tones
      l < 40 -> l - 10              # Darken dark tones
      true -> l                     # Keep extreme values
    end

    hsl_to_rgb({h, s, adjusted_l / 100})
  end

  defp maybe_enhance_contrast(color, false), do: color

  defp maybe_make_color_blind_safe(color, true) do
    # Ensure sufficient contrast for color blind users
    %{h: h, s: s, l: l} = rgb_to_hsl(color)

    # Increase saturation for better distinction
    adjusted_s = min(100, s * 1.2)

    # Ensure minimum lightness for visibility
    adjusted_l = max(20, l)

    hsl_to_rgb({h, adjusted_s / 100, adjusted_l / 100})
  end

  defp maybe_make_color_blind_safe(color, false), do: color
end
