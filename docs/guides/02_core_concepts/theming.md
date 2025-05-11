---
title: Theming Guide
description: How to define, use, and customize themes in Raxol.
date: 2025-05-10
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

- **Definition:** Typically a `Raxol.UI.Theming.Theme` struct or a map matching its structure.
- **Core Attributes:**
  - `id`: Unique identifier (e.g., `:dark_theme`).
  - `name`: User-friendly name (e.g., "Dark Theme").
  - `description`: Brief description.
  - `colors`: Map of semantic color names to `Color` structs.
  - `component_styles`: Map defining styles for specific UI components.
  - `variants`: Map of theme variants (e.g., `:high_contrast`).
  - `metadata`: Additional theme information.

## 3. Color System Integration

The theming system integrates with the new centralized color system:

### Core Color Representation (`Raxol.Style.Colors.Color`)

```elixir
# Basic color operations
color = Raxol.Style.Colors.Color.from_hex("#FF0000")
lighter = Raxol.Style.Colors.Color.lighten(color, 0.2)
```

### Color System (`Raxol.Core.ColorSystem`)

```elixir
# Theme-aware color retrieval
primary_color = Raxol.Core.ColorSystem.get_color(:primary)
hover_color = Raxol.Core.ColorSystem.get_color(:primary, :hover)
```

### UI Colors (`Raxol.UI.Theming.Colors`)

```elixir
# UI-specific color operations
button_color = Raxol.UI.Theming.Colors.get_ui_color(theme, :button)
text_color = Raxol.UI.Theming.Colors.get_text_color(theme, :primary)
```

### Color Utilities (`Raxol.Style.Colors.Utilities`)

```elixir
# Accessibility checks
is_readable = Raxol.Style.Colors.Utilities.meets_contrast_requirements?(
  text_color,
  background_color,
  :AA,
  :normal
)
```

### Palette Manager (`Raxol.Style.Colors.PaletteManager`)

```elixir
# Palette operations
palette = Raxol.Style.Colors.PaletteManager.get_palette(:primary)
scale = Raxol.Style.Colors.PaletteManager.generate_scale("#0077CC", 9)
```

## 4. Using Themes

- **Defaults:** Raxol includes built-in themes (e.g., `:default`).
- **Application:** The `ColorSystem` manages the active theme state. The `Renderer` applies the active theme's styles when drawing UI elements.
- **Selection:** Configured at application startup (runtime options). User preference integration is planned.
- **Accessing Colors:** Use `Raxol.Core.ColorSystem.get_color/2` for retrieving theme colors programmatically.
  - Example: `ColorSystem.get_color(:primary)` fetches the primary color.
  - Handles high-contrast mode automatically based on system/user settings.

## 5. Customizing Themes

- **Modification:** Adjust colors or component styles within an existing theme's definition.
- **Variants:** Create custom variants by defining a new map/struct that overrides specific colors or styles of a base theme.
- **Example:**
  ```elixir
  theme = Raxol.UI.Theming.Theme.new(%{
    id: :custom_theme,
    name: "Custom Theme",
    colors: %{
      primary: Raxol.Style.Colors.Color.from_hex("#0077CC"),
      background: Raxol.Style.Colors.Color.from_hex("#FFFFFF"),
      text: Raxol.Style.Colors.Color.from_hex("#333333")
    },
    variants: %{
      high_contrast: %{
        colors: %{
          primary: Raxol.Style.Colors.Color.from_hex("#0000FF"),
          background: Raxol.Style.Colors.Color.from_hex("#000000"),
          text: Raxol.Style.Colors.Color.from_hex("#FFFFFF")
        }
      }
    }
  })
  ```

## 6. Creating New Themes

- **Definition:** Create an Elixir module returning a `Raxol.UI.Theming.Theme` struct.
- **Loading:** Make the theme available via application configuration.
- **Example:**
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
        variants: %{},
        metadata: %{
          author: "My Name",
          version: "1.0.0"
        }
      })
    end
  end
  ```

## 7. Theming and Accessibility

- **High Contrast:** Implemented as a theme variant automatically applied when high contrast mode is enabled.
- **Integration:** `Raxol.Core.Accessibility.ThemeIntegration` monitors accessibility settings and informs the `ColorSystem`.
- **Design:** Ensure sufficient color contrast ratios (WCAG AA minimum: 4.5:1 for normal text, 3:1 for large text) when defining palettes.

## 8. Advanced Topics

- **Dynamic Switching:** Update the theme state in the `ColorSystem` and trigger a re-render.
- **Inheritance:** Define full styles per theme/variant.
- **Performance:** Use the `PaletteManager` for efficient color operations and caching.

## 9. Examples

```elixir
# Example Theme Definition
theme = Raxol.UI.Theming.Theme.new(%{
  id: :dark,
  name: "Dark Theme",
  colors: %{
    primary: Raxol.Style.Colors.Color.from_hex("#0077CC"),
    secondary: Raxol.Style.Colors.Color.from_hex("#666666"),
    background: Raxol.Style.Colors.Color.from_hex("#1E1E1E"),
    text: Raxol.Style.Colors.Color.from_hex("#FFFFFF")
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
  metadata: %{
    author: "Raxol Team",
    version: "1.0.0"
  }
})
```
