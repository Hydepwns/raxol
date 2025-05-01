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

## 3. Theming System (`Raxol.UI.Theming.*`)

While the terminal layer understands raw SGR sequences, Raxol applications typically define and use colors through the high-level Theming system.

- **Color Schemes**: The `UI.Theming` modules allow defining complete color schemes (e.g., "Solarized", "Dracula", "Nord") which specify palettes of named colors for various UI elements (background, foreground, primary button, error text, etc.).
- **Palettes**: Themes contain palettes mapping abstract names (like `:primary`, `:background`, `:accent`) to specific color values (which could be 16-color names, 256-color indices, or 24-bit RGB values).
- **Active Theme**: The Raxol runtime manages an active theme for the application.

## 4. Core Color System (`Raxol.Core.ColorSystem`)

Application code and UI components should generally not use raw SGR codes or hardcoded color values. Instead, they interact with the `Raxol.Core.ColorSystem`.

- **Theme-Aware Retrieval**: This module provides functions like `Raxol.Core.ColorSystem.get/2` which allow retrieving a color value (e.g., an RGB tuple or an appropriate ANSI code) based on a semantic name (e.g., `:text_primary`) and the _currently active theme_.
- **Accessibility Integration**: The `ColorSystem` also considers accessibility settings (like high contrast mode) when resolving colors, ensuring appropriate contrast or alternative palettes are used when needed.

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
