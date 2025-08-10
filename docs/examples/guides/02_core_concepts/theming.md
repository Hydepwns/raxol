---
title: Theming Guide
description: How to define, use, and customize themes in Raxol.
date: 2025-06-18
author: Raxol Team
section: guides
tags: [theming, themes, styling, guides]
---

# Raxol Theming Guide

This guide explains how to work with themes in the Raxol Terminal Emulator, including understanding the theme structure, selecting themes, customizing existing themes, and creating new ones.

## 1. Introduction to Theming

- **Purpose:** Defines the visual appearance (colors, styles) of Raxol UI elements.
- **Benefits:** Ensures visual consistency, aids accessibility (e.g., high contrast), allows user personalization.
- **Core Module:** `Raxol.UI.Theming.Theme` holds theme definitions.

## 2. Theme Structure

- **Definition:** A `Raxol.UI.Theming.Theme` struct with the following attributes:
  - `id`: Unique identifier (e.g., `:dark_theme`)
  - `name`: User-friendly name (e.g., "Dark Theme")
  - `description`: Brief description
  - `colors`: Map of semantic color names to `Color` structs
  - `component_styles`: Map defining styles for specific UI components
  - `variants`: Map of theme variants (e.g., `:high_contrast`)
  - `metadata`: Additional theme information
  - `fonts`: Font definitions for the theme
  - `ui_mappings`: Maps UI roles to semantic color names

## 3. Color System Integration

The theming system integrates with the centralized color system:

### Core Color Representation (`Raxol.Style.Colors.Color`)

```elixir
# Basic color operations
color = Raxol.Style.Colors.Color.from_hex("#FF0000")
lighter = Raxol.Style.Colors.Color.lighten(color, 0.2)
darker = Raxol.Style.Colors.Color.darken(color, 0.2)
```

### Color System (`Raxol.Core.ColorSystem`)

```elixir
# Initialize the color system
Raxol.Core.ColorSystem.init()

# Get a semantic color (respects accessibility settings)
color = Raxol.Core.ColorSystem.get_color(:primary)

# Get a specific color variation
hover_color = Raxol.Core.ColorSystem.get_color(:primary, :hover)

# Get UI-specific colors
button_color = Raxol.Core.ColorSystem.get_ui_color(:primary_button)
```

### Color Utilities (`Raxol.Style.Colors.Utilities`)

```elixir
# Accessibility checks
readable = Raxol.Style.Colors.Utilities.meets_contrast_requirements?(
  text_color,
  background_color,
  :AA,
  :normal
)

# Color manipulation
adjusted_color = Raxol.Style.Colors.Utilities.adjust_for_contrast(
  text_color,
  background_color,
  :AA,
  :normal
)
```

## 4. Using Themes

### Default Themes

Raxol includes several built-in themes:

```elixir
# Get the default theme
default_theme = Raxol.UI.Theming.Theme.default_theme()

# Get the dark theme
dark_theme = Raxol.UI.Theming.Theme.dark_theme()

# Get a theme by ID
theme = Raxol.UI.Theming.Theme.get(:custom_theme)
```

### Applying Themes

```elixir
# Apply a theme
Raxol.Core.ColorSystem.apply_theme(:dark)

# Apply with high contrast
Raxol.Core.ColorSystem.apply_theme(:dark, high_contrast: true)
```

### Accessing Theme Colors

```elixir
# Get a color from the current theme
color = Raxol.Core.ColorSystem.get_color(:primary)

# Get a UI-specific color
button_color = Raxol.Core.ColorSystem.get_ui_color(:primary_button)

# Get all UI colors
all_colors = Raxol.Core.ColorSystem.get_all_ui_colors()
```

## 5. Customizing Themes

### Creating a Custom Theme

```elixir
defmodule MyApp.Themes.CustomTheme do
  def theme do
    Raxol.UI.Theming.Theme.new(%{
      id: :custom,
      name: "Custom Theme",
      description: "A custom theme for my application",
      colors: %{
        primary: Raxol.Style.Colors.Color.from_hex("#0077CC"),
        secondary: Raxol.Style.Colors.Color.from_hex("#666666"),
        background: Raxol.Style.Colors.Color.from_hex("#FFFFFF"),
        text: Raxol.Style.Colors.Color.from_hex("#333333")
      },
      component_styles: %{
        panel: %{
          border: :single,
          padding: 1
        },
        button: %{
          padding: {0, 1},
          text_style: [:bold]
        }
      },
      variants: %{
        high_contrast: %{
          colors: %{
            primary: Raxol.Style.Colors.Color.from_hex("#0000FF"),
            background: Raxol.Style.Colors.Color.from_hex("#000000"),
            text: Raxol.Style.Colors.Color.from_hex("#FFFFFF")
          }
        }
      },
      ui_mappings: %{
        app_background: :background,
        surface_background: :surface,
        primary_button: :primary,
        secondary_button: :secondary,
        text: :text
      },
      metadata: %{
        author: "My Name",
        version: "1.0.0"
      }
    })
  end
end
```

### Registering a Custom Theme

```elixir
# Register a theme
Raxol.Core.ColorSystem.register_theme(%{
  primary: "#0077CC",
  secondary: "#00AAFF",
  background: "#001133",
  foreground: "#FFFFFF",
  accent: "#FF9900"
})
```

## 6. Theming and Accessibility

### High Contrast Mode

```elixir
# Create a high contrast variant
high_contrast_theme = Raxol.UI.Theming.Theme.create_high_contrast_variant(theme)

# Apply high contrast mode
Raxol.Core.ColorSystem.apply_theme(:dark, high_contrast: true)
```

### Accessibility Integration

The color system automatically integrates with the accessibility system:

- Monitors system accessibility settings
- Applies high contrast mode when enabled
- Ensures sufficient color contrast ratios
- Provides alternative color schemes for color blindness

## 7. Component-Specific Styling

```elixir
# Define component styles in a theme
component_styles: %{
  panel: %{
    border: :single,
    padding: 1,
    background: :surface,
    foreground: :text
  },
  button: %{
    padding: {0, 1},
    text_style: [:bold],
    background: :primary,
    foreground: :white
  },
  text_field: %{
    border: :single,
    padding: {0, 1},
    background: :surface,
    foreground: :text
  }
}
```

## 8. Best Practices

1. **Semantic Colors**: Use semantic color names (e.g., `:primary`, `:secondary`) instead of specific colors
2. **Accessibility**: Always provide high contrast variants and ensure sufficient contrast ratios
3. **Component Styles**: Define styles for all UI components in your theme
4. **UI Mappings**: Use `ui_mappings` to map UI roles to semantic colors
5. **Theme Variants**: Create variants for different use cases (e.g., dark mode, high contrast)
6. **Color System**: Use the color system for all color operations to ensure consistency
7. **Testing**: Test themes with different accessibility settings and color schemes

## 9. Example: Complete Theme Definition

```elixir
theme = Raxol.UI.Theming.Theme.new(%{
  id: :dark,
  name: "Dark Theme",
  description: "A dark theme for Raxol applications",
  colors: %{
    primary: Raxol.Style.Colors.Color.from_hex("#0077CC"),
    secondary: Raxol.Style.Colors.Color.from_hex("#666666"),
    background: Raxol.Style.Colors.Color.from_hex("#1E1E1E"),
    surface: Raxol.Style.Colors.Color.from_hex("#2D2D2D"),
    text: Raxol.Style.Colors.Color.from_hex("#FFFFFF"),
    error: Raxol.Style.Colors.Color.from_hex("#FF5555"),
    warning: Raxol.Style.Colors.Color.from_hex("#FFB86C"),
    success: Raxol.Style.Colors.Color.from_hex("#50FA7B")
  },
  component_styles: %{
    panel: %{
      border: :single,
      padding: 1,
      background: :surface,
      foreground: :text
    },
    button: %{
      padding: {0, 1},
      text_style: [:bold],
      background: :primary,
      foreground: :white
    },
    text_field: %{
      border: :single,
      padding: {0, 1},
      background: :surface,
      foreground: :text
    }
  },
  variants: %{
    high_contrast: %{
      colors: %{
        primary: Raxol.Style.Colors.Color.from_hex("#0000FF"),
        background: Raxol.Style.Colors.Color.from_hex("#000000"),
        text: Raxol.Style.Colors.Color.from_hex("#FFFFFF")
      }
    }
  },
  ui_mappings: %{
    app_background: :background,
    surface_background: :surface,
    primary_button: :primary,
    secondary_button: :secondary,
    text: :text,
    error_text: :error,
    warning_text: :warning,
    success_text: :success
  },
  metadata: %{
    author: "Raxol Team",
    version: "1.0.0"
  }
})
```
