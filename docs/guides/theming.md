---
title: Theming Guide
description: How to define, use, and customize themes in Raxol.
date: 2025-04-27
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
  - `variant`: The specific variant (e.g., `:default`, `:light`, `:high_contrast`).
- **Color Palettes:** A map defining semantic color groups.
  - Keys: `:primary`, `:secondary`, `:accent`, `:neutral`, `:status` (info, success, warning, error).
  - Values: `%{fg: color, bg: color, emphasis: color}` maps.
  - Colors: `{r, g, b}` tuples (0-255) or ANSI integer codes.
- **Component Styles (`component_styles`):** Map defining styles for specific UI components.
  - Keys: Component types (e.g., `:button`, `:panel`, `:text_input`, `:border`).
  - Values: Style maps containing attributes like `:border`, `:padding`, `:margin`, `:text_style` (`[:bold]`, `[:underline]`, etc.), `:fg`, `:bg`.
- **Variants:** Different versions of a base theme (e.g., a `:high_contrast` variant modifies colors of a `:dark` theme). Variants are typically defined within the theme module or loaded separately.

## 3. Using Themes

- **Defaults:** Raxol includes built-in themes (e.g., `:default`).
- **Application:** The `Dispatcher` manages the active theme state. The `Renderer` applies the active theme's styles when drawing UI elements.
- **Selection:** Configured at application startup (runtime options). User preference integration is planned.
- **Accessing Styles:** Use `Raxol.Core.ColorSystem.get/1` for retrieving theme colors programmatically.
  - Example: `ColorSystem.get({:primary, :fg})` fetches the primary foreground color.
  - Handles high-contrast mode automatically based on system/user settings detected by `Raxol.Core.Accessibility.ThemeIntegration`.

## 4. Customizing Themes

- **Modification:** Adjust color palettes or component styles within an existing theme's definition (if loaded from configuration) or create a modified struct/map.
- **Variants:** Create custom variants by defining a new map/struct that overrides specific colors or styles of a base theme. See `Theme.create_high_contrast_variant/1` for reference.

## 5. Creating New Themes

- **Definition:** Create an Elixir module returning a `Raxol.UI.Theming.Theme` struct (or similarly structured map) containing all required attributes (`id`, `name`, palettes, `component_styles`).
- **Loading:** Make the theme available via application configuration (exact mechanism TBD).

## 6. Theming and Accessibility

- **High Contrast:** Typically implemented as a theme variant automatically applied when high contrast mode is enabled.
- **Integration:** `Raxol.Core.Accessibility.ThemeIntegration` monitors accessibility settings and informs the `ColorSystem` and potentially the `Dispatcher`.
- **Design:** Ensure sufficient color contrast ratios (WCAG AA minimum: 4.5:1 for normal text, 3:1 for large text) when defining palettes.

## 7. Advanced Topics (Optional)

- **Dynamic Switching:** Possible by updating the theme state in the `Dispatcher` and triggering a re-render (requires application-level logic).
- **Inheritance:** No built-in theme inheritance mechanism currently exists. Define full styles per theme/variant.

## 8. Examples

```elixir
# Example Palette Definition (Partial)
palettes: %{
  primary: %{fg: {220, 220, 220}, bg: {30, 30, 30}, emphasis: {255, 180, 0}},
  neutral: %{fg: {180, 180, 180}, bg: {50, 50, 50}, emphasis: {210, 210, 210}}
  # ... other palettes: secondary, accent, status ...
}

# Example Component Style Definition (Partial)
component_styles: %{
  border: %{fg: {100, 100, 100}},
  button: %{padding: {0, 1}, fg: :primary_fg, bg: :neutral_bg, text_style: [:bold]},
  panel: %{padding: 1, border: true, border_style: :rounded}
  # ... other components ...
}

# Example Color Access
primary_fg_color = Raxol.Core.ColorSystem.get({:primary, :fg})
button_style = Raxol.Core.ColorSystem.get(:button) # Gets the full style map
```
