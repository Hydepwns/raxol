---
title: Color System Implementation
description: Documentation for the color system implementation in Raxol Terminal Emulator
date: 2023-04-04
author: Raxol Team
section: implementation
tags: [implementation, color, system]
---

# Advanced Color System Implementation Plan

This document outlines the detailed implementation approach for Raxol's enhanced color management system, with inspiration from Prompt's color support and Charm.sh's Lip Gloss.

## Architecture Overview

The color system will be structured with the following components:

```
lib/raxol/style/colors/
├── color.ex          # Core color representation
├── palette.ex        # Color palette management
├── gradient.ex       # Gradient generation
├── theme.ex          # Theme definition and hot-swapping
├── adaptive.ex       # Terminal capability detection
└── utilities.ex      # Color manipulation utilities
```

## Core Components

### Color Representation

```elixir
defmodule Raxol.Style.Colors.Color do
  @moduledoc """
  Represents a color in various formats with conversion utilities.
  Supports ANSI 16/256 colors and True Color (24-bit).
  """

  defstruct [
    :r, :g, :b,      # RGB components (0-255)
    :ansi_code,      # ANSI color code if applicable
    :hex,            # Hex representation
    :name            # Optional name for predefined colors
  ]

  @type t :: %__MODULE__{
    r: integer(),
    g: integer(),
    b: integer(),
    ansi_code: integer() | nil,
    hex: String.t(),
    name: String.t() | nil
  }

  # Conversion functions
  def from_hex(hex_string)
  def to_hex(color)
  def from_rgb(r, g, b)
  def to_ansi_16(color)
  def to_ansi_256(color)
  def from_ansi(code)

  # Color operations
  def lighten(color, amount)
  def darken(color, amount)
  def alpha_blend(color1, color2, alpha)
  def complement(color)
  def mix(color1, color2, weight \\ 0.5)
end
```

### Color Palette

```elixir
defmodule Raxol.Style.Colors.Palette do
  @moduledoc """
  Manages collections of related colors as palettes.
  Provides standard palettes and custom palette creation.
  """

  defstruct [
    :name,
    :colors,          # Map of color names to Color structs
    :primary,         # Primary color reference
    :secondary,       # Secondary color reference
    :accent,          # Accent color references
    :background,      # Background color
    :foreground       # Foreground color
  ]

  # Standard palettes
  def standard_16()
  def ansi_256()
  def solarized()
  def nord()
  def dracula()

  # Palette generation
  def from_base_color(base_color)
  def complementary(base_color)
  def triadic(base_color)
  def analogous(base_color)
  def monochromatic(base_color, steps)

  # Palette operations
  def get_color(palette, name)
  def add_color(palette, name, color)
  def remove_color(palette, name)
  def merge_palettes(palette1, palette2)
end
```

### Color Gradients

```elixir
defmodule Raxol.Style.Colors.Gradient do
  @moduledoc """
  Creates and manages color gradients for terminal applications.
  """

  defstruct [
    :colors,          # List of color stops
    :steps,           # Number of discrete steps
    :type             # Linear, radial, etc.
  ]

  # Gradient creation
  def linear(start_color, end_color, steps)
  def multi_stop(color_stops, steps)
  def rainbow(steps)
  def heat_map(steps)

  # Gradient operations
  def at_position(gradient, position)
  def reverse(gradient)
  def to_ansi_sequence(gradient, text)
end
```

### Color Themes

```elixir
defmodule Raxol.Style.Colors.Theme do
  @moduledoc """
  Manages complete color themes with support for hot-swapping.
  """

  defstruct [
    :name,
    :palette,
    :ui_mappings,     # Map of UI element names to colors
    :dark_mode,       # Boolean indicating dark/light theme
    :high_contrast    # Boolean for high contrast mode
  ]

  # Theme management
  def apply_theme(theme)
  def switch_theme(theme_name)
  def register_theme(theme)
  def current_theme()

  # Theme creation
  def from_palette(palette, name)
  def light_variant(theme)
  def dark_variant(theme)
  def high_contrast_variant(theme)

  # Theme persistence
  def save_theme(theme, path)
  def load_theme(path)
end
```

### Terminal Capability Detection

```elixir
defmodule Raxol.Style.Colors.Adaptive do
  @moduledoc """
  Detects terminal capabilities and adapts color schemes accordingly.
  """

  # Capability detection
  def detect_color_support()
  def supports_true_color?()
  def supports_256_colors?()
  def terminal_background()
  def dark_terminal?()

  # Adaptive operations
  def adapt_color(color)
  def adapt_palette(palette)
  def adapt_theme(theme)
  def get_optimal_format()
end
```

### Color Utilities

```elixir
defmodule Raxol.Style.Colors.Utilities do
  @moduledoc """
  Provides color manipulation and accessibility utilities.
  """

  # Color analysis
  def contrast_ratio(color1, color2)
  def readable?(background, foreground, level \\ :aa)
  def brightness(color)
  def luminance(color)

  # Color suggestions
  def suggest_text_color(background)
  def suggest_contrast_color(color)
  def accessible_color_pair(base_color, level \\ :aa)

  # Color palettes
  def analogous_colors(color, count \\ 3)
  def complementary_colors(color)
  def triadic_colors(color)
end
```

## Implementation Strategy

### Phase 1: Core Color Representation

1. Implement the basic `Color` struct with RGB, hex, and ANSI representations
2. Add conversion functions between different color formats
3. Implement basic color operations (lighten, darken, mix)
4. Create tests for all color operations and conversions

### Phase 2: Color Palette Management

1. Implement the `Palette` struct and standard palettes
2. Add palette generation functions from base colors
3. Create palette manipulation functions
4. Develop tests for palette operations

### Phase 3: Gradient Implementation

1. Build the `Gradient` struct and basic linear gradients
2. Implement multi-stop gradients and presets (rainbow, heat map)
3. Add text rendering with gradient ANSI sequences
4. Create visual tests for gradient rendering

### Phase 4: Theme System

1. Implement the `Theme` struct with UI element mappings
2. Add theme switching and hot-swapping capabilities
3. Create light/dark/high-contrast variants
4. Develop theme persistence

### Phase 5: Terminal Adaptation

1. Implement terminal capability detection
2. Add color adaptation based on terminal support
3. Develop background detection and contrast adjustment
4. Create fallback strategies for limited terminals

### Phase 6: Accessibility Utilities

1. Implement contrast ratio calculation
2. Add readability checking against WCAG standards
3. Create color suggestion algorithms
4. Develop automated color enhancement for accessibility

## Integration with Other Systems

### Style System Integration

The color system will integrate with the broader style system:

```elixir
# Example usage in styles
style = Style.new()
  |> Style.foreground(Colors.rgb(255, 100, 50))
  |> Style.background(Colors.hex("#1E1E1E"))
  |> Style.border(:rounded, color: Colors.theme().accent)
```

### Component Integration

Components will use the color system through the style system:

```elixir
# Example component using colors
button(
  label: "Submit",
  style: Style.new()
    |> Style.foreground(Colors.theme().ui_mappings.button_text)
    |> Style.background(Colors.gradient(
      Colors.theme().ui_mappings.button_start,
      Colors.theme().ui_mappings.button_end,
      10
    ))
)
```

### Theme Hot-Swapping

Implement live theme switching with pub/sub:

```elixir
# Switch theme at runtime
Raxol.Style.Colors.Theme.switch_theme(:dark_mode)

# Component automatically updates with new theme
def update(msg, state) do
  case msg do
    {:theme_changed, theme} ->
      # Rerender with new theme
      {:update, %{state | theme: theme}}
    # ...
  end
end
```

## Testing Strategy

1. **Unit Tests**: Test all color conversions and manipulations
2. **Visual Tests**: Create terminal output tests showing rendered colors
3. **Integration Tests**: Test with various terminal types and capabilities
4. **Accessibility Tests**: Verify WCAG compliance for generated color combinations
5. **Performance Tests**: Ensure color operations don't impact rendering performance

## Documentation

1. Create comprehensive API documentation with examples
2. Develop a color system guide with visual examples
3. Create tutorials for theme creation and customization
4. Document accessibility best practices
5. Create example applications demonstrating the color system

## Timeline

- Week 1-2: Core color representation and operations
- Week 3-4: Palette management and generation
- Week 5-6: Gradient implementation and theme system
- Week 7-8: Terminal adaptation and accessibility utilities

## References

- Prompt color handling: https://hexdocs.pm/prompt/Prompt.html#module-basic-usage
- Lip Gloss color system: https://github.com/charmbracelet/lipgloss
- WCAG contrast guidelines: https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html
