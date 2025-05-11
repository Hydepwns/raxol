---
title: Color Handling in the Terminal
description: How Raxol processes and renders colors using ANSI sequences and the Theme system.
date: 2024-04-27
author: Raxol Team
section: terminal
tags:
  [
    color,
    terminal,
    documentation,
    ansi,
    sgr,
    theme,
    colorsystem,
    emulator,
    parser,
    renderer,
  ]
---

# Color Handling in the Terminal

Raxol supports terminal colors ranging from the basic 16 ANSI colors up to 24-bit true color. Color handling involves multiple layers, from parsing low-level ANSI sequences to applying high-level themes.

## 1. ANSI SGR Color Sequences

At the lowest level, terminal colors are controlled by ANSI Select Graphic Rendition (SGR) escape sequences. Raxol's terminal layer understands:

- **3/4-bit Colors (Standard 16 Colors)**: `\e[30m` - `\e[37m` (foreground), `\e[40m` - `\e[47m` (background), `\e[90m` - `\e[97m` (bright foreground), `\e[100m` - `\e[107m` (bright background).
- **8-bit Colors (256 Colors)**: `\e[38;5;{0-255}m` (foreground), `\e[48;5;{0-255}m` (background). This includes the 16 standard colors, a 6x6x6 color cube, and 24 grayscale levels.
- **24-bit Colors (True Color)**: `\e[38;2;R;G;Bm` (foreground), `\e[48;2;R;G;Bm` (background).
- **Default Colors**: `\e[39m` (default foreground), `\e[49m` (default background).
- **Reset**: `\e[0m` resets all attributes, including colors, to their default.

## 2. Parsing and Emulator State

- **`Raxol.Terminal.Parser`**: This module recognizes the SGR sequences within the incoming byte stream.
- **`Raxol.Terminal.Emulator`**: When the parser identifies an SGR color sequence, it updates the `Emulator`'s state. The `Emulator` tracks the _current_ active foreground and background color attributes (along with other attributes like bold, italic, etc.). These attributes are associated with characters as they are written to the screen buffer.

## 3. Centralized Color System

Raxol's color system is organized into several specialized modules that work together:

### Core Color Representation (`Raxol.Style.Colors.Color`)

- Provides the fundamental color data structure and manipulation functions
- Handles color format conversions through the `Formats` module
- Maintains core color operations (lighten, darken, blend, etc.)
- Supports RGB, RGBA, hex, ANSI, and named color formats

### Color System (`Raxol.Core.ColorSystem`)

- Centralizes theme management and high-level color operations
- Uses `Color`, `Palettes`, and `Utilities` modules for core functionality
- Provides semantic color naming and accessibility features
- Integrates with the accessibility system for high contrast mode

### UI Theming Colors (`Raxol.UI.Theming.Colors`)

- Provides a simpler interface for UI-specific color operations
- Uses `Color` and `Utilities` modules for core functionality
- Maintains backward compatibility with existing code
- Focuses on theme-specific color operations

### Color Utilities (`Raxol.Style.Colors.Utilities`)

- Provides shared color manipulation and analysis functions
- Handles contrast calculations and accessibility checks
- Offers color palette generation and management
- Supports color format conversions and validation

### Palette Manager (`Raxol.Style.Colors.PaletteManager`)

- Manages color palettes and scales
- Handles user preferences for colors
- Provides palette generation and manipulation
- Integrates with the accessibility system

### Theme Management (`Raxol.Style.Colors.Theme`)

- Defines and manages color themes
- Handles theme variants (light, dark, high contrast)
- Provides theme persistence and loading
- Integrates with the color system for theme application

## 4. Theme System Integration

The color system integrates with the theme system through:

- **Theme Definition**: Themes define color palettes and UI mappings
- **Theme Application**: Colors are resolved through the theme system
- **Accessibility**: High contrast mode and accessibility settings are respected
- **Dynamic Updates**: Theme changes trigger appropriate updates

## 5. Rendering (`Raxol.UI.Renderer`)

When the UI is rendered:

1. Components are defined using styled elements (e.g., `Elements.text("Hello", style: Style.new(fg: :primary))`).
2. The `Renderer` receives these elements.
3. For each element or cell, the `Renderer` consults the `ColorSystem` (and thus the active theme) to resolve logical styles (like `fg: :primary`) into concrete color values.
4. The `Renderer` then compares the required colors/attributes with the terminal's current state (as tracked by the `Emulator` via the `ScreenBuffer`) and generates the minimal set of SGR sequences needed to achieve the desired appearance before outputting the character itself.

## Scope and Limitations

- **Focus**: Raxol's color management focuses on applying themed styles and translating them to appropriate ANSI SGR sequences for terminal display.
- **Advanced Manipulation**: Complex color operations like detailed color space conversions (RGB to HSL, etc.), color interpolation, or applying opacity effects are generally outside the scope of the core terminal/theming layer. Such logic might reside in specific UI components or utility libraries if required by an application.
- **Terminal Dependence**: The final appearance depends on the capabilities and configuration of the hosting terminal emulator (e.g., its ability to render true color, its default color palette for the standard 16 colors).

(Previous content based on a hypothetical `Raxol.Terminal.Colors` module, including its API, configuration, events, and examples, has been removed.)
