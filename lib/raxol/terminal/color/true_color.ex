defmodule Raxol.Terminal.Color.TrueColor do
  @moduledoc """
  True color (24-bit RGB) support for Raxol terminal applications.

  This module provides comprehensive 24-bit RGB color handling with:
  - Full 16.7 million color support
  - Color space conversions (RGB, HSL, HSV, Lab)
  - Color manipulation and blending
  - Accessibility features (contrast checking, colorblind-friendly palettes)
  - Terminal capability detection
  - Graceful fallbacks to 256-color and 16-color modes
  - Color palette management and theming

  ## Usage

      # Create colors
      red = TrueColor.rgb(255, 0, 0)
      blue = TrueColor.hex("#0066CC")
      green = TrueColor.hsl(120, 100, 50)

      # Generate ANSI escape sequences
      TrueColor.to_ansi_fg(red)  # "\e[38;2;255;0;0m"
      TrueColor.to_ansi_bg(blue) # "\e[48;2;0;102;204m"

      # Color manipulation
      darker = TrueColor.darken(red, 0.2)
      lighter = TrueColor.lighten(blue, 0.3)
      mixed = TrueColor.mix(red, blue, 0.5)

      # Accessibility
      contrast = TrueColor.contrast_ratio(red, blue)
      accessible? = TrueColor.wcag_compliant?(red, blue, :aa)
  """

  require Logger

  defstruct [:r, :g, :b, :a]

  @type rgb_component :: 0..255
  @type alpha_component :: 0..255
  @type hue :: 0..360
  @type saturation :: 0..100
  @type lightness :: 0..100
  @type percentage :: float()

  @type t :: %__MODULE__{
          r: rgb_component(),
          g: rgb_component(),
          b: rgb_component(),
          a: alpha_component()
        }

  @type color_format :: :rgb | :hex | :hsl | :hsv | :lab | :ansi
  @type terminal_capability ::
          :true_color | :color_256 | :color_16 | :monochrome
  @type wcag_level :: :aa | :aaa

  # WCAG contrast ratio thresholds
  @wcag_aa_normal 4.5
  @wcag_aa_large 3.0
  @wcag_aaa_normal 7.0
  @wcag_aaa_large 4.5

  # Common color constants
  @colors %{
    black: {0, 0, 0},
    white: {255, 255, 255},
    red: {255, 0, 0},
    green: {0, 255, 0},
    blue: {0, 0, 255},
    yellow: {255, 255, 0},
    magenta: {255, 0, 255},
    cyan: {0, 255, 255},
    orange: {255, 165, 0},
    purple: {128, 0, 128},
    pink: {255, 192, 203},
    brown: {165, 42, 42},
    gray: {128, 128, 128},
    lime: {0, 255, 0},
    navy: {0, 0, 128},
    olive: {128, 128, 0},
    silver: {192, 192, 192},
    teal: {0, 128, 128}
  }

  ## Constructor Functions

  @doc """
  Creates a true color from RGB values.

  ## Examples

      iex> TrueColor.rgb(255, 0, 0)
      %TrueColor{r: 255, g: 0, b: 0, a: 255}

      iex> TrueColor.rgb(128, 128, 128, 128)
      %TrueColor{r: 128, g: 128, b: 128, a: 128}
  """
  def rgb(r, g, b, a \\ 255)
      when r in 0..255//1 and g in 0..255//1 and b in 0..255//1 and
             a in 0..255//1 do
    %__MODULE__{r: r, g: g, b: b, a: a}
  end

  @doc """
  Creates a true color from a hex string.

  ## Examples

      iex> TrueColor.hex("#FF0000")
      %TrueColor{r: 255, g: 0, b: 0, a: 255}

      iex> TrueColor.hex("0066CC")
      %TrueColor{r: 0, g: 102, b: 204, a: 255}

      iex> TrueColor.hex("#FF0000AA")
      %TrueColor{r: 255, g: 0, b: 0, a: 170}
  """
  def hex(hex_string) when is_binary(hex_string) do
    clean_hex = String.replace(hex_string, "#", "")

    case String.length(clean_hex) do
      6 -> parse_hex_6(clean_hex)
      8 -> parse_hex_8(clean_hex)
      3 -> parse_hex_3(clean_hex)
      4 -> parse_hex_4(clean_hex)
      _ -> {:error, :invalid_hex_format}
    end
  end

  @doc """
  Creates a true color from HSL values.

  ## Examples

      iex> TrueColor.hsl(0, 100, 50)    # Pure red
      %TrueColor{r: 255, g: 0, b: 0, a: 255}

      iex> TrueColor.hsl(120, 100, 50)  # Pure green
      %TrueColor{r: 0, g: 255, b: 0, a: 255}
  """
  def hsl(h, s, l, a \\ 100)
      when h in 0..360//1 and s in 0..100//1 and l in 0..100//1 and
             a in 0..100//1 do
    {r, g, b} = hsl_to_rgb(h, s / 100, l / 100)

    %__MODULE__{
      r: round(r * 255),
      g: round(g * 255),
      b: round(b * 255),
      a: round(a * 2.55)
    }
  end

  @doc """
  Creates a true color from HSV values.

  ## Examples

      iex> TrueColor.hsv(0, 100, 100)   # Pure red
      %TrueColor{r: 255, g: 0, b: 0, a: 255}
  """
  def hsv(h, s, v, a \\ 100)
      when h in 0..360//1 and s in 0..100//1 and v in 0..100//1 and
             a in 0..100//1 do
    {r, g, b} = hsv_to_rgb(h, s / 100, v / 100)

    %__MODULE__{
      r: round(r * 255),
      g: round(g * 255),
      b: round(b * 255),
      a: round(a * 2.55)
    }
  end

  @doc """
  Creates a true color from a predefined color name.

  ## Examples

      iex> TrueColor.named(:red)
      %TrueColor{r: 255, g: 0, b: 0, a: 255}

      iex> TrueColor.named("blue")
      %TrueColor{r: 0, g: 0, b: 255, a: 255}
  """
  def named(color_name) when is_atom(color_name) or is_binary(color_name) do
    name_atom = convert_to_atom(color_name)

    case Map.get(@colors, name_atom) do
      {r, g, b} -> rgb(r, g, b)
      nil -> {:error, :unknown_color_name}
    end
  end

  ## ANSI Escape Sequence Generation

  @doc """
  Converts a true color to ANSI foreground escape sequence.

  ## Examples

      iex> red = TrueColor.rgb(255, 0, 0)
      iex> TrueColor.to_ansi_fg(red)
      "\\e[38;2;255;0;0m"
  """
  def to_ansi_fg(%__MODULE__{r: r, g: g, b: b}) do
    "\e[38;2;#{r};#{g};#{b}m"
  end

  @doc """
  Converts a true color to ANSI background escape sequence.

  ## Examples

      iex> blue = TrueColor.rgb(0, 0, 255)
      iex> TrueColor.to_ansi_bg(blue)
      "\\e[48;2;0;0;255m"
  """
  def to_ansi_bg(%__MODULE__{r: r, g: g, b: b}) do
    "\e[48;2;#{r};#{g};#{b}m"
  end

  @doc """
  Converts a true color to 256-color ANSI escape sequence (fallback).
  """
  def to_ansi_256_fg(%__MODULE__{} = color) do
    ansi_code = to_256_color(color)
    "\e[38;5;#{ansi_code}m"
  end

  def to_ansi_256_bg(%__MODULE__{} = color) do
    ansi_code = to_256_color(color)
    "\e[48;5;#{ansi_code}m"
  end

  @doc """
  Converts a true color to 16-color ANSI escape sequence (fallback).
  """
  def to_ansi_16_fg(%__MODULE__{} = color) do
    ansi_code = to_16_color(color)
    "\e[#{ansi_code}m"
  end

  def to_ansi_16_bg(%__MODULE__{} = color) do
    ansi_code = to_16_color(color)
    "\e[#{ansi_code + 10}m"
  end

  ## Color Manipulation

  @doc """
  Lightens a color by the specified percentage.

  ## Examples

      iex> red = TrueColor.rgb(255, 0, 0)
      iex> TrueColor.lighten(red, 0.2)
      # Returns lighter red
  """
  def lighten(%__MODULE__{} = color, percentage)
      when percentage >= 0 and percentage <= 1 do
    {h, s, l} = to_hsl(color)
    new_l = min(100, l + percentage * 100)
    hsl(h, s, new_l, color.a)
  end

  @doc """
  Darkens a color by the specified percentage.
  """
  def darken(%__MODULE__{} = color, percentage)
      when percentage >= 0 and percentage <= 1 do
    {h, s, l} = to_hsl(color)
    new_l = max(0, l - percentage * 100)
    hsl(h, s, new_l, color.a)
  end

  @doc """
  Saturates a color by the specified percentage.
  """
  def saturate(%__MODULE__{} = color, percentage)
      when percentage >= 0 and percentage <= 1 do
    {h, s, l} = to_hsl(color)
    new_s = min(100, s + percentage * 100)
    hsl(h, new_s, l, color.a)
  end

  @doc """
  Desaturates a color by the specified percentage.
  """
  def desaturate(%__MODULE__{} = color, percentage)
      when percentage >= 0 and percentage <= 1 do
    {h, s, l} = to_hsl(color)
    new_s = max(0, s - percentage * 100)
    hsl(h, new_s, l, color.a)
  end

  @doc """
  Mixes two colors together by the specified ratio.

  ## Examples

      iex> red = TrueColor.rgb(255, 0, 0)
      iex> blue = TrueColor.rgb(0, 0, 255)
      iex> TrueColor.mix(red, blue, 0.5)
      # Returns purple (50% red, 50% blue)
  """
  def mix(%__MODULE__{} = color1, %__MODULE__{} = color2, ratio)
      when ratio >= 0 and ratio <= 1 do
    r = round(color1.r * (1 - ratio) + color2.r * ratio)
    g = round(color1.g * (1 - ratio) + color2.g * ratio)
    b = round(color1.b * (1 - ratio) + color2.b * ratio)
    a = round(color1.a * (1 - ratio) + color2.a * ratio)

    rgb(r, g, b, a)
  end

  @doc """
  Creates a complementary color (opposite on color wheel).
  """
  def complement(%__MODULE__{} = color) do
    {h, s, l} = to_hsl(color)
    new_h = rem(h + 180, 360)
    hsl(new_h, s, l, color.a)
  end

  @doc """
  Creates a triadic color scheme (3 colors evenly spaced).
  """
  def triadic(%__MODULE__{} = color) do
    {h, s, l} = to_hsl(color)
    color2 = hsl(rem(h + 120, 360), s, l, color.a)
    color3 = hsl(rem(h + 240, 360), s, l, color.a)
    [color, color2, color3]
  end

  @doc """
  Creates an analogous color scheme (adjacent colors on wheel).
  """
  def analogous(%__MODULE__{} = color, count \\ 5) when count >= 3 do
    {h, s, l} = to_hsl(color)
    step = 30

    Range.new(-div(count - 1, 2), div(count, 2))
    |> Enum.map(fn i ->
      new_h = rem(h + i * step + 360, 360)
      hsl(new_h, s, l, color.a)
    end)
  end

  ## Accessibility Functions

  @doc """
  Calculates the contrast ratio between two colors according to WCAG guidelines.

  Returns a value between 1 and 21, where 21 is maximum contrast (black/white).
  """
  def contrast_ratio(%__MODULE__{} = color1, %__MODULE__{} = color2) do
    l1 = relative_luminance(color1)
    l2 = relative_luminance(color2)

    {lighter, darker} = order_luminance(l1, l2)

    (lighter + 0.05) / (darker + 0.05)
  end

  @doc """
  Checks if two colors meet WCAG contrast requirements.

  ## Examples

      iex> black = TrueColor.rgb(0, 0, 0)
      iex> white = TrueColor.rgb(255, 255, 255)
      iex> TrueColor.wcag_compliant?(black, white, :aa)
      true
  """
  def wcag_compliant?(
        %__MODULE__{} = fg,
        %__MODULE__{} = bg,
        level,
        large_text \\ false
      ) do
    ratio = contrast_ratio(fg, bg)

    threshold =
      case {level, large_text} do
        {:aa, true} -> @wcag_aa_large
        {:aa, false} -> @wcag_aa_normal
        {:aaa, true} -> @wcag_aaa_large
        {:aaa, false} -> @wcag_aaa_normal
      end

    ratio >= threshold
  end

  @doc """
  Finds the best contrasting color (black or white) for the given background.
  """
  def best_contrast(%__MODULE__{} = bg_color) do
    black = rgb(0, 0, 0)
    white = rgb(255, 255, 255)

    black_contrast = contrast_ratio(black, bg_color)
    white_contrast = contrast_ratio(white, bg_color)

    select_best_contrast(black, white, black_contrast, white_contrast)
  end

  ## Color Space Conversions

  @doc """
  Converts a true color to HSL representation.

  Returns {hue, saturation, lightness} where:
  - hue is 0-360
  - saturation is 0-100
  - lightness is 0-100
  """
  def to_hsl(%__MODULE__{r: r, g: g, b: b}) do
    rgb_to_hsl(r / 255, g / 255, b / 255)
  end

  @doc """
  Converts a true color to HSV representation.
  """
  def to_hsv(%__MODULE__{r: r, g: g, b: b}) do
    rgb_to_hsv(r / 255, g / 255, b / 255)
  end

  @doc """
  Converts a true color to Lab color space (perceptually uniform).
  """
  def to_lab(%__MODULE__{} = color) do
    {x, y, z} = to_xyz(color)
    xyz_to_lab(x, y, z)
  end

  @doc """
  Converts a true color to hex string.

  ## Examples

      iex> red = TrueColor.rgb(255, 0, 0)
      iex> TrueColor.to_hex(red)
      "#FF0000"
  """
  def to_hex(%__MODULE__{r: r, g: g, b: b, a: a}) do
    format_hex_with_alpha(r, g, b, a)
  end

  ## Terminal Capability Detection

  @doc """
  Detects the terminal's color capability.
  """
  def detect_terminal_capability do
    case {supports_true_color?(), supports_256_color?(), supports_16_color?()} do
      {true, _, _} -> :true_color
      {_, true, _} -> :color_256
      {_, _, true} -> :color_16
      _ -> :monochrome
    end
  end

  @doc """
  Checks if the terminal supports true color (24-bit).
  """
  def supports_true_color? do
    colorterm = System.get_env("COLORTERM")
    term = System.get_env("TERM")

    check_true_color_support(colorterm, term)
  end

  @doc """
  Checks if the terminal supports 256 colors.
  """
  def supports_256_color? do
    term = System.get_env("TERM")
    check_256_color_support(term)
  end

  @doc """
  Checks if the terminal supports 16 colors.
  """
  def supports_16_color? do
    term = System.get_env("TERM")
    check_16_color_support(term)
  end

  @doc """
  Automatically selects the best ANSI escape sequence based on terminal capability.
  """
  def to_ansi_auto_fg(%__MODULE__{} = color) do
    case detect_terminal_capability() do
      :true_color -> to_ansi_fg(color)
      :color_256 -> to_ansi_256_fg(color)
      :color_16 -> to_ansi_16_fg(color)
      :monochrome -> ""
    end
  end

  def to_ansi_auto_bg(%__MODULE__{} = color) do
    case detect_terminal_capability() do
      :true_color -> to_ansi_bg(color)
      :color_256 -> to_ansi_256_bg(color)
      :color_16 -> to_ansi_16_bg(color)
      :monochrome -> ""
    end
  end

  ## Color Palette Management

  @doc """
  Generates a color palette based on a base color.
  """
  def generate_palette(%__MODULE__{} = base_color, scheme \\ :monochromatic) do
    case scheme do
      :monochromatic -> generate_monochromatic_palette(base_color)
      :analogous -> analogous(base_color)
      :triadic -> triadic(base_color)
      :complementary -> [base_color, complement(base_color)]
      :tetradic -> generate_tetradic_palette(base_color)
    end
  end

  @doc """
  Creates an accessible color palette that meets WCAG guidelines.
  """
  def accessible_palette(%__MODULE__{} = base_color, level \\ :aa) do
    bg_light = rgb(255, 255, 255)
    bg_dark = rgb(0, 0, 0)

    # Generate variations that are accessible
    variations = [
      base_color,
      darken(base_color, 0.2),
      darken(base_color, 0.4),
      lighten(base_color, 0.2),
      lighten(base_color, 0.4)
    ]

    # Filter for WCAG compliance
    accessible_on_light =
      Enum.filter(variations, &wcag_compliant?(&1, bg_light, level))

    accessible_on_dark =
      Enum.filter(variations, &wcag_compliant?(&1, bg_dark, level))

    %{
      base: base_color,
      light_background: accessible_on_light,
      dark_background: accessible_on_dark
    }
  end

  ## Private Helper Functions

  defp parse_hex_6(hex) do
    with {r, ""} <- Integer.parse(String.slice(hex, 0, 2), 16),
         {g, ""} <- Integer.parse(String.slice(hex, 2, 2), 16),
         {b, ""} <- Integer.parse(String.slice(hex, 4, 2), 16) do
      rgb(r, g, b)
    else
      _ -> {:error, :invalid_hex}
    end
  end

  defp parse_hex_8(hex) do
    with {r, ""} <- Integer.parse(String.slice(hex, 0, 2), 16),
         {g, ""} <- Integer.parse(String.slice(hex, 2, 2), 16),
         {b, ""} <- Integer.parse(String.slice(hex, 4, 2), 16),
         {a, ""} <- Integer.parse(String.slice(hex, 6, 2), 16) do
      rgb(r, g, b, a)
    else
      _ -> {:error, :invalid_hex}
    end
  end

  defp parse_hex_3(hex) do
    with {r, ""} <- Integer.parse(String.slice(hex, 0, 1), 16),
         {g, ""} <- Integer.parse(String.slice(hex, 1, 1), 16),
         {b, ""} <- Integer.parse(String.slice(hex, 2, 1), 16) do
      rgb(r * 17, g * 17, b * 17)
    else
      _ -> {:error, :invalid_hex}
    end
  end

  defp parse_hex_4(hex) do
    with {r, ""} <- Integer.parse(String.slice(hex, 0, 1), 16),
         {g, ""} <- Integer.parse(String.slice(hex, 1, 1), 16),
         {b, ""} <- Integer.parse(String.slice(hex, 2, 1), 16),
         {a, ""} <- Integer.parse(String.slice(hex, 3, 1), 16) do
      rgb(r * 17, g * 17, b * 17, a * 17)
    else
      _ -> {:error, :invalid_hex}
    end
  end

  defp pad_hex(value) do
    value
    |> Integer.to_string(16)
    |> String.pad_leading(2, "0")
    |> String.upcase()
  end

  defp hsl_to_rgb(h, s, l) do
    c = (1 - abs(2 * l - 1)) * s
    x = c * (1 - abs(rem(trunc(h / 60), 2) - 1))
    m = l - c / 2

    {r_prime, g_prime, b_prime} =
      case div(h, 60) do
        0 -> {c, x, 0}
        1 -> {x, c, 0}
        2 -> {0, c, x}
        3 -> {0, x, c}
        4 -> {x, 0, c}
        5 -> {c, 0, x}
        _ -> {0, 0, 0}
      end

    {r_prime + m, g_prime + m, b_prime + m}
  end

  defp rgb_to_hsl(r, g, b) do
    max_val = max(max(r, g), b)
    min_val = min(min(r, g), b)
    delta = max_val - min_val

    l = (max_val + min_val) / 2

    calculate_hsl_values(delta, l, max_val, min_val, r, g, b)
  end

  defp calculate_hue(max_val, delta, r, g, b) when max_val == r do
    rem(trunc((g - b) / delta + adjust_for_negative_hue(g, b)), 6)
  end

  defp calculate_hue(max_val, delta, r, g, b) when max_val == g do
    (b - r) / delta + 2
  end

  defp calculate_hue(max_val, delta, r, g, b) when max_val == b do
    (r - g) / delta + 4
  end

  defp hsv_to_rgb(h, s, v) do
    c = v * s
    x = c * (1 - abs(rem(trunc(h / 60), 2) - 1))
    m = v - c

    {r_prime, g_prime, b_prime} =
      case div(h, 60) do
        0 -> {c, x, 0}
        1 -> {x, c, 0}
        2 -> {0, c, x}
        3 -> {0, x, c}
        4 -> {x, 0, c}
        5 -> {c, 0, x}
        _ -> {0, 0, 0}
      end

    {r_prime + m, g_prime + m, b_prime + m}
  end

  defp rgb_to_hsv(r, g, b) do
    max_val = max(max(r, g), b)
    min_val = min(min(r, g), b)
    delta = max_val - min_val

    v = max_val
    s = calculate_saturation(max_val, delta)

    h = calculate_hsv_hue(delta, max_val, r, g, b)

    {round(h * 60), round(s * 100), round(v * 100)}
  end

  defp relative_luminance(%__MODULE__{r: r, g: g, b: b}) do
    [r, g, b]
    |> Enum.map(fn c ->
      s = c / 255
      calculate_linear_rgb(s)
    end)
    |> then(fn [r_l, g_l, b_l] ->
      0.2126 * r_l + 0.7152 * g_l + 0.0722 * b_l
    end)
  end

  defp to_xyz(%__MODULE__{r: r, g: g, b: b}) do
    [r, g, b]
    |> Enum.map(fn c ->
      s = c / 255
      calculate_linear_xyz(s)
    end)
    |> then(fn [r_l, g_l, b_l] ->
      x = r_l * 0.4124 + g_l * 0.3576 + b_l * 0.1805
      y = r_l * 0.2126 + g_l * 0.7152 + b_l * 0.0722
      z = r_l * 0.0193 + g_l * 0.1192 + b_l * 0.9505
      {x, y, z}
    end)
  end

  defp xyz_to_lab(x, y, z) do
    # Observer = 2°, Illuminant = D65
    x_n = 0.95047
    y_n = 1.00000
    z_n = 1.08883

    fx = lab_f(x / x_n)
    fy = lab_f(y / y_n)
    fz = lab_f(z / z_n)

    l = 116 * fy - 16
    a = 500 * (fx - fy)
    b = 200 * (fy - fz)

    {l, a, b}
  end

  defp lab_f(t) do
    threshold = :math.pow(6 / 29, 3)
    calculate_lab_f(t > threshold, t)
  end

  defp calculate_lab_f(true, t), do: :math.pow(t, 1 / 3)
  defp calculate_lab_f(false, t), do: 1 / 3 * :math.pow(29 / 6, 2) * t + 4 / 29

  defp to_256_color(%__MODULE__{r: r, g: g, b: b}) when r == g and g == b do
    # Grayscale
    232 + div(r * 23, 255)
  end

  defp to_256_color(%__MODULE__{r: r, g: g, b: b}) do
    # Color cube (6x6x6)
    r_index = div(r * 5, 255)
    g_index = div(g * 5, 255)
    b_index = div(b * 5, 255)
    16 + 36 * r_index + 6 * g_index + b_index
  end

  defp to_16_color(%__MODULE__{r: r, g: g, b: b}) do
    brightness = (r + g + b) / 3
    map_to_ansi_color(r, g, b, brightness)
  end

  # Red/Bright Red
  defp map_to_ansi_color(r, g, b, brightness)
       when r > 128 and g < 128 and b < 128 do
    select_red_ansi_code(brightness)
  end

  # Green/Bright Green
  defp map_to_ansi_color(r, g, b, brightness)
       when r < 128 and g > 128 and b < 128 do
    select_green_ansi_code(brightness)
  end

  # Blue/Bright Blue
  defp map_to_ansi_color(r, g, b, brightness)
       when r < 128 and g < 128 and b > 128 do
    select_blue_ansi_code(brightness)
  end

  # Yellow/Bright Yellow
  defp map_to_ansi_color(r, g, b, brightness)
       when r > 128 and g > 128 and b < 128 do
    select_yellow_ansi_code(brightness)
  end

  # Magenta/Bright Magenta
  defp map_to_ansi_color(r, g, b, brightness)
       when r > 128 and g < 128 and b > 128 do
    select_magenta_ansi_code(brightness)
  end

  # Cyan/Bright Cyan
  defp map_to_ansi_color(r, g, b, brightness)
       when r < 128 and g > 128 and b > 128 do
    select_cyan_ansi_code(brightness)
  end

  # Black
  defp map_to_ansi_color(_r, _g, _b, brightness) when brightness < 64, do: 30
  # White
  defp map_to_ansi_color(_r, _g, _b, brightness) when brightness > 192, do: 37
  # Default - Bright White/White based on brightness
  defp map_to_ansi_color(_r, _g, _b, brightness) do
    select_default_ansi_code(brightness)
  end

  defp generate_monochromatic_palette(%__MODULE__{} = base_color) do
    [
      darken(base_color, 0.4),
      darken(base_color, 0.2),
      base_color,
      lighten(base_color, 0.2),
      lighten(base_color, 0.4)
    ]
  end

  defp generate_tetradic_palette(%__MODULE__{} = base_color) do
    {h, s, l} = to_hsl(base_color)

    [
      base_color,
      hsl(rem(h + 90, 360), s, l, base_color.a),
      hsl(rem(h + 180, 360), s, l, base_color.a),
      hsl(rem(h + 270, 360), s, l, base_color.a)
    ]
  end

  # Helper functions using pattern matching instead of if statements

  defp convert_to_atom(color_name) when is_binary(color_name),
    do: String.to_atom(color_name)

  defp convert_to_atom(color_name) when is_atom(color_name), do: color_name

  defp order_luminance(l1, l2) when l1 > l2, do: {l1, l2}
  defp order_luminance(l1, l2), do: {l2, l1}

  defp select_best_contrast(black, _white, black_contrast, white_contrast)
       when black_contrast > white_contrast,
       do: black

  defp select_best_contrast(_black, white, _black_contrast, _white_contrast),
    do: white

  defp format_hex_with_alpha(r, g, b, a) when a < 255 do
    "##{pad_hex(r)}#{pad_hex(g)}#{pad_hex(b)}#{pad_hex(a)}"
  end

  defp format_hex_with_alpha(r, g, b, _a) do
    "##{pad_hex(r)}#{pad_hex(g)}#{pad_hex(b)}"
  end

  defp check_true_color_support(colorterm, _term)
       when colorterm in ["truecolor", "24bit"],
       do: true

  defp check_true_color_support("truecolor", term) when is_binary(term) do
    String.contains?(term, "256color")
  end

  defp check_true_color_support(_colorterm, _term), do: false

  defp check_256_color_support(nil), do: false
  defp check_256_color_support(term) when term == "xterm-kitty", do: true

  defp check_256_color_support(term) when is_binary(term) do
    String.contains?(term, "256color")
  end

  defp check_16_color_support(nil), do: false
  defp check_16_color_support(term) when term in ["dumb", "unknown"], do: false
  defp check_16_color_support(_term), do: true

  defp calculate_hsl_values(delta, l, max_val, min_val, r, g, b) do
    if delta == 0.0 do
      {0, 0, round(l * 100)}
    else
      s = calculate_hsl_saturation(l, delta, max_val, min_val)
      h = calculate_hue(max_val, delta, r, g, b)
      {round(h * 60), round(s * 100), round(l * 100)}
    end
  end

  defp calculate_hsl_saturation(l, delta, max_val, min_val) when l > 0.5 do
    delta / (2 - max_val - min_val)
  end

  defp calculate_hsl_saturation(_l, delta, max_val, min_val) do
    delta / (max_val + min_val)
  end

  defp calculate_saturation(max_val, delta) do
    if max_val == 0.0, do: 0.0, else: delta / max_val
  end

  defp calculate_hsv_hue(delta, max_val, r, g, b) do
    if delta == 0.0 do
      0
    else
      cond do
        max_val == r ->
          rem(trunc((g - b) / delta + adjust_for_negative_hue(g, b)), 6)

        max_val == g ->
          (b - r) / delta + 2

        max_val == b ->
          (r - g) / delta + 4

        true ->
          0
      end
    end
  end

  defp adjust_for_negative_hue(g, b) when g < b, do: 6
  defp adjust_for_negative_hue(_g, _b), do: 0

  defp calculate_linear_rgb(s) when s <= 0.03928, do: s / 12.92
  defp calculate_linear_rgb(s), do: :math.pow((s + 0.055) / 1.055, 2.4)

  defp calculate_linear_xyz(s) when s > 0.04045,
    do: :math.pow((s + 0.055) / 1.055, 2.4)

  defp calculate_linear_xyz(s), do: s / 12.92

  defp select_red_ansi_code(brightness) when brightness > 128, do: 91
  defp select_red_ansi_code(_brightness), do: 31

  defp select_green_ansi_code(brightness) when brightness > 128, do: 92
  defp select_green_ansi_code(_brightness), do: 32

  defp select_blue_ansi_code(brightness) when brightness > 128, do: 94
  defp select_blue_ansi_code(_brightness), do: 34

  defp select_yellow_ansi_code(brightness) when brightness > 128, do: 93
  defp select_yellow_ansi_code(_brightness), do: 33

  defp select_magenta_ansi_code(brightness) when brightness > 128, do: 95
  defp select_magenta_ansi_code(_brightness), do: 35

  defp select_cyan_ansi_code(brightness) when brightness > 128, do: 96
  defp select_cyan_ansi_code(_brightness), do: 36

  defp select_default_ansi_code(brightness) when brightness > 128, do: 97
  defp select_default_ansi_code(_brightness), do: 37
end
