# `Raxol.Terminal.Color.TrueColor`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/color/true_color.ex#L1)

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
    TrueColor.to_ansi_fg(red)  # "[38;2;255;0;0m"
    TrueColor.to_ansi_bg(blue) # "[48;2;0;102;204m"

    # Color manipulation
    darker = TrueColor.darken(red, 0.2)
    lighter = TrueColor.lighten(blue, 0.3)
    mixed = TrueColor.mix(red, blue, 0.5)

    # Accessibility
    contrast = TrueColor.contrast_ratio(red, blue)
    accessible? = TrueColor.wcag_compliant?(red, blue, :aa)

# `alpha_component`

```elixir
@type alpha_component() :: 0..255
```

# `color_format`

```elixir
@type color_format() :: :rgb | :hex | :hsl | :hsv | :lab | :ansi
```

# `hue`

```elixir
@type hue() :: 0..360
```

# `lightness`

```elixir
@type lightness() :: 0..100
```

# `percentage`

```elixir
@type percentage() :: float()
```

# `rgb_component`

```elixir
@type rgb_component() :: 0..255
```

# `saturation`

```elixir
@type saturation() :: 0..100
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.Color.TrueColor{
  a: alpha_component(),
  b: rgb_component(),
  g: rgb_component(),
  r: rgb_component()
}
```

# `terminal_capability`

```elixir
@type terminal_capability() :: :true_color | :color_256 | :color_16 | :monochrome
```

# `wcag_level`

```elixir
@type wcag_level() :: :aa | :aaa
```

# `accessible_palette`

Creates an accessible color palette that meets WCAG guidelines.

# `analogous`

Creates an analogous color scheme (adjacent colors on wheel).

# `best_contrast`

Finds the best contrasting color (black or white) for the given background.

# `complement`

Creates a complementary color (opposite on color wheel).

# `contrast_ratio`

Calculates the contrast ratio between two colors according to WCAG guidelines.

Returns a value between 1 and 21, where 21 is maximum contrast (black/white).

# `darken`

Darkens a color by the specified percentage.

# `desaturate`

Desaturates a color by the specified percentage.

# `detect_terminal_capability`

Detects the terminal's color capability.

# `generate_palette`

Generates a color palette based on a base color.

# `hex`

Creates a true color from a hex string.

## Examples

    iex> TrueColor.hex("#FF0000")
    %TrueColor{r: 255, g: 0, b: 0, a: 255}

    iex> TrueColor.hex("0066CC")
    %TrueColor{r: 0, g: 102, b: 204, a: 255}

    iex> TrueColor.hex("#FF0000AA")
    %TrueColor{r: 255, g: 0, b: 0, a: 170}

# `hsl`

Creates a true color from HSL values.

## Examples

    iex> TrueColor.hsl(0, 100, 50)    # Pure red
    %TrueColor{r: 255, g: 0, b: 0, a: 255}

    iex> TrueColor.hsl(120, 100, 50)  # Pure green
    %TrueColor{r: 0, g: 255, b: 0, a: 255}

# `hsv`

Creates a true color from HSV values.

## Examples

    iex> TrueColor.hsv(0, 100, 100)   # Pure red
    %TrueColor{r: 255, g: 0, b: 0, a: 255}

# `lighten`

Lightens a color by the specified percentage.

## Examples

    iex> red = TrueColor.rgb(255, 0, 0)
    iex> TrueColor.lighten(red, 0.2)
    # Returns lighter red

# `mix`

Mixes two colors together by the specified ratio.

## Examples

    iex> red = TrueColor.rgb(255, 0, 0)
    iex> blue = TrueColor.rgb(0, 0, 255)
    iex> TrueColor.mix(red, blue, 0.5)
    # Returns purple (50% red, 50% blue)

# `named`

Creates a true color from a predefined color name.

## Examples

    iex> TrueColor.named(:red)
    %TrueColor{r: 255, g: 0, b: 0, a: 255}

    iex> TrueColor.named("blue")
    %TrueColor{r: 0, g: 0, b: 255, a: 255}

# `rgb`

Creates a true color from RGB values.

## Examples

    iex> TrueColor.rgb(255, 0, 0)
    %TrueColor{r: 255, g: 0, b: 0, a: 255}

    iex> TrueColor.rgb(128, 128, 128, 128)
    %TrueColor{r: 128, g: 128, b: 128, a: 128}

# `saturate`

Saturates a color by the specified percentage.

# `supports_16_color?`

Checks if the terminal supports 16 colors.

# `supports_256_color?`

Checks if the terminal supports 256 colors.

# `supports_true_color?`

Checks if the terminal supports true color (24-bit).

# `to_ansi_16_bg`

# `to_ansi_16_fg`

Converts a true color to 16-color ANSI escape sequence (fallback).

# `to_ansi_256_bg`

# `to_ansi_256_fg`

Converts a true color to 256-color ANSI escape sequence (fallback).

# `to_ansi_auto_bg`

# `to_ansi_auto_fg`

Automatically selects the best ANSI escape sequence based on terminal capability.

# `to_ansi_bg`

Converts a true color to ANSI background escape sequence.

## Examples

    iex> blue = TrueColor.rgb(0, 0, 255)
    iex> TrueColor.to_ansi_bg(blue)
    "\e[48;2;0;0;255m"

# `to_ansi_fg`

Converts a true color to ANSI foreground escape sequence.

## Examples

    iex> red = TrueColor.rgb(255, 0, 0)
    iex> TrueColor.to_ansi_fg(red)
    "\e[38;2;255;0;0m"

# `to_hex`

Converts a true color to hex string.

## Examples

    iex> red = TrueColor.rgb(255, 0, 0)
    iex> TrueColor.to_hex(red)
    "#FF0000"

# `to_hsl`

Converts a true color to HSL representation.

Returns {hue, saturation, lightness} where:
- hue is 0-360
- saturation is 0-100
- lightness is 0-100

# `to_hsv`

Converts a true color to HSV representation.

# `to_lab`

Converts a true color to Lab color space (perceptually uniform).

# `triadic`

Creates a triadic color scheme (3 colors evenly spaced).

# `wcag_compliant?`

Checks if two colors meet WCAG contrast requirements.

## Examples

    iex> black = TrueColor.rgb(0, 0, 0)
    iex> white = TrueColor.rgb(255, 255, 255)
    iex> TrueColor.wcag_compliant?(black, white, :aa)
    true

---

*Consult [api-reference.md](api-reference.md) for complete listing*
