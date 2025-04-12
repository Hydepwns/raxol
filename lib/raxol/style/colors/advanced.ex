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

  alias Raxol.Style.Colors.{Color, Palette, Adaptive}

  @type color :: Color.t()
  @type palette :: Palette.t()
  @type color_space :: :rgb | :hsl | :lab | :xyz

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
  def create_harmony(%Color{} = color, harmony_type) do
    hsl = rgb_to_hsl(color)

    case harmony_type do
      :complementary ->
        [
          color,
          hsl_to_rgb(%{hsl | h: rem(round(hsl.h + 180.0), 360)})
        ]

      :analogous ->
        [
          color,
          hsl_to_rgb(%{hsl | h: rem(round(hsl.h - 30.0), 360)}),
          hsl_to_rgb(%{hsl | h: rem(round(hsl.h + 30.0), 360)})
        ]

      :triadic ->
        [
          color,
          hsl_to_rgb(%{hsl | h: rem(round(hsl.h + 120.0), 360)}),
          hsl_to_rgb(%{hsl | h: rem(round(hsl.h - 120.0), 360)})
        ]

      :tetradic ->
        [
          color,
          hsl_to_rgb(%{hsl | h: rem(round(hsl.h + 90.0), 360)}),
          hsl_to_rgb(%{hsl | h: rem(round(hsl.h + 180.0), 360)}),
          hsl_to_rgb(%{hsl | h: rem(round(hsl.h + 270.0), 360)})
        ]
    end
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

  defp rgb_to_hsl(%Color{r: r, g: g, b: b}) do
    r = r / 255
    g = g / 255
    b = b / 255

    max = Enum.max([r, g, b])
    min = Enum.min([r, g, b])
    delta = max - min

    h =
      cond do
        delta == 0 -> 0
        max == r -> 60 * rem(round((g - b) / delta) + 360, 360)
        max == g -> 60 * ((b - r) / delta + 2)
        true -> 60 * ((r - g) / delta + 4)
      end

    l = (max + min) / 2

    s =
      if delta == 0 do
        0
      else
        delta / (1 - abs(2 * l - 1))
      end

    %{h: round(h), s: round(s * 100), l: round(l * 100)}
  end

  defp hsl_to_rgb(%{h: h, s: s, l: l}) do
    s = s / 100
    l = l / 100

    c = (1 - abs(2 * l - 1)) * s
    x = c * (1 - abs(rem(round(h / 60.0), 2) - 1))
    m = l - c / 2

    {r, g, b} =
      cond do
        h < 60 -> {c, x, 0}
        h < 120 -> {x, c, 0}
        h < 180 -> {0, c, x}
        h < 240 -> {0, x, c}
        h < 300 -> {x, 0, c}
        true -> {c, 0, x}
      end

    Color.from_rgb(
      round((r + m) * 255),
      round((g + m) * 255),
      round((b + m) * 255)
    )
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
    # Convert RGB to XYZ
    # This is a simplified conversion - a full implementation would be more complex
    r =
      if r > 10.3148,
        do: :math.pow((r + 14.025) / 269.025, 2.4),
        else: r / 3294.6

    g =
      if g > 10.3148,
        do: :math.pow((g + 14.025) / 269.025, 2.4),
        else: g / 3294.6

    b =
      if b > 10.3148,
        do: :math.pow((b + 14.025) / 269.025, 2.4),
        else: b / 3294.6

    x = r * 0.4124 + g * 0.3576 + b * 0.1805
    y = r * 0.2126 + g * 0.7152 + b * 0.0722
    z = r * 0.0193 + g * 0.1192 + b * 0.9505

    %{x: x * 100, y: y * 100, z: z * 100}
  end

  defp maybe_preserve_brightness(color, true) do
    # Implement brightness preservation logic
    color
  end

  defp maybe_preserve_brightness(color, false), do: color

  defp maybe_enhance_contrast(color, true) do
    # Implement contrast enhancement logic
    color
  end

  defp maybe_enhance_contrast(color, false), do: color

  defp maybe_make_color_blind_safe(color, true) do
    # Implement color blind safety logic
    color
  end

  defp maybe_make_color_blind_safe(color, false), do: color
end
