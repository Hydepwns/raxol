---
title: Color Management Component
description: Documentation for the color management component in Raxol Terminal Emulator
date: 2023-04-04
author: Raxol Team
section: components
tags: [color, terminal, documentation]
---

# Color Management Component

The color management component handles color schemes, palettes, and dynamic color adjustments in the terminal emulator.

## Features

- 16-color mode support
- 256-color mode support
- True color (24-bit) support
- Color scheme management
- Dynamic theme switching
- Color palette customization
- Color space conversion
- Color interpolation
- Background/foreground color management
- Color opacity support

## Usage

```elixir
# Create a new color manager
colors = Raxol.Terminal.Colors.new()

# Set foreground color (RGB)
colors = Raxol.Terminal.Colors.set_fg(colors, {255, 0, 0})

# Set background color (Named)
colors = Raxol.Terminal.Colors.set_bg(colors, :blue)

# Load a color scheme
colors = Raxol.Terminal.Colors.load_scheme(colors, "dracula")
```

## Configuration

The color manager can be configured with the following options:

```elixir
config = %{
  color_mode: :true_color,
  default_fg: {255, 255, 255},
  default_bg: {0, 0, 0},
  palette: :solarized,
  opacity: 1.0,
  cursor_color: {255, 255, 0}
}

colors = Raxol.Terminal.Colors.new(config)
```

## Implementation Details

### Color Modes

1. **16-Color Mode**
   - Basic ANSI colors
   - Bright variants
   - System colors

2. **256-Color Mode**
   - 16 system colors
   - 216 color cube
   - 24 grayscale colors

3. **True Color Mode**
   - 24-bit RGB colors
   - Full color spectrum
   - Alpha channel support

### Color Schemes

1. **Built-in Schemes**
   - Solarized (Dark/Light)
   - Dracula
   - Nord
   - Monokai
   - One Dark

2. **Custom Schemes**
   - User-defined palettes
   - Theme inheritance
   - Dynamic updates

### Color Processing

1. **Color Space Conversion**
   - RGB to HSL
   - RGB to HSV
   - Color temperature
   - Gamma correction

2. **Color Interpolation**
   - Linear interpolation
   - Bezier curves
   - Color blending
   - Gradient generation

## API Reference

### Color Management

```elixir
# Initialize color manager
@spec new() :: t()

# Set foreground color
@spec set_fg(colors :: t(), color :: color_spec()) :: t()

# Set background color
@spec set_bg(colors :: t(), color :: color_spec()) :: t()

# Load color scheme
@spec load_scheme(colors :: t(), scheme :: String.t()) :: t()
```

### Color Manipulation

```elixir
# Convert color spaces
@spec to_rgb(colors :: t(), color :: color_spec()) :: rgb_color()

# Interpolate colors
@spec interpolate(colors :: t(), color1 :: color_spec(), color2 :: color_spec(), t :: float()) :: color_spec()

# Adjust color properties
@spec adjust(colors :: t(), color :: color_spec(), adjustments :: map()) :: color_spec()
```

### Palette Management

```elixir
# Set color in palette
@spec set_palette_color(colors :: t(), index :: integer(), color :: color_spec()) :: t()

# Get color from palette
@spec get_palette_color(colors :: t(), index :: integer()) :: color_spec()
```

## Events

The color management component emits the following events:

- `:color_changed` - When foreground or background color changes
- `:scheme_loaded` - When a new color scheme is loaded
- `:palette_updated` - When the color palette is modified
- `:mode_changed` - When color mode changes

## Example

```elixir
defmodule MyTerminal do
  alias Raxol.Terminal.Colors

  def example do
    # Create a new color manager
    colors = Colors.new()

    # Configure colors
    colors = colors
      |> Colors.load_scheme("dracula")
      |> Colors.set_fg({255, 0, 0})
      |> Colors.set_bg(:black)

    # Work with color spaces
    rgb = Colors.to_rgb(colors, :blue)
    interpolated = Colors.interpolate(colors, {255, 0, 0}, {0, 0, 255}, 0.5)

    # Manage palette
    colors = colors
      |> Colors.set_palette_color(1, {255, 0, 0})
      |> Colors.set_palette_color(2, {0, 255, 0})

    color = Colors.get_palette_color(colors, 1)
  end
end
```

## Testing

The color management component includes comprehensive tests:

```elixir
defmodule Raxol.Terminal.ColorsTest do
  use ExUnit.Case
  alias Raxol.Terminal.Colors

  test "sets colors correctly" do
    colors = Colors.new()
    colors = Colors.set_fg(colors, {255, 0, 0})
    assert Colors.get_fg(colors) == {255, 0, 0}
  end

  test "loads color schemes" do
    colors = Colors.new()
    colors = Colors.load_scheme(colors, "dracula")
    assert Colors.get_scheme(colors) == :dracula
  end

  test "manages palette colors" do
    colors = Colors.new()
    colors = Colors.set_palette_color(colors, 1, {255, 0, 0})
    assert Colors.get_palette_color(colors, 1) == {255, 0, 0}
  end

  test "converts color spaces" do
    colors = Colors.new()
    rgb = Colors.to_rgb(colors, :blue)
    assert rgb == {0, 0, 255}
  end
end
``` 