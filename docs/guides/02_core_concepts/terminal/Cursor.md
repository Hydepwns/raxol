---
title: Cursor Management
description: How Raxol handles terminal cursor position, visibility, and style via ANSI sequences.
date: 2024-07-27 # Updated date
author: Raxol Team
section: terminal
tags: [cursor, terminal, documentation, ansi, csi, emulator, parser]
---

# Cursor Management

Raxol controls the terminal's cursor position, visibility, and potentially its style using standard ANSI escape sequences. The management is primarily handled by the `Emulator` module tracking state based on sequences identified by the `Parser`.

## Key ANSI Cursor Sequences

Raxol's terminal layer processes the following common CSI (Control Sequence Introducer) sequences related to the cursor:

- **Movement (Absolute):**
  - `CSI Pl ; Pc H` (CUP - Cursor Position): Moves cursor to line `Pl`, column `Pc` (1-based).
  - `CSI Pl ; Pc f` (HVP - Horizontal Vertical Position): Same as CUP.
- **Movement (Relative):**
  - `CSI Pn A` (CUU - Cursor Up): Moves cursor up `Pn` lines.
  - `CSI Pn B` (CUD - Cursor Down): Moves cursor down `Pn` lines.
  - `CSI Pn C` (CUF - Cursor Forward): Moves cursor forward `Pn` columns.
  - `CSI Pn D` (CUB - Cursor Back): Moves cursor back `Pn` columns.
- **Visibility (DECTCEM - Show/Hide Cursor):**
  - `CSI ? 25 h`: Makes cursor visible.
  - `CSI ? 25 l`: Makes cursor invisible.
- **Style (DECSCUSR - Set Cursor Style - _Support Varies_):**
  - `CSI 0 SP q` or `CSI 1 SP q`: Blinking block (default).
  - `CSI 2 SP q`: Steady block.
  - `CSI 3 SP q`: Blinking underline.
  - `CSI 4 SP q`: Steady underline.
  - `CSI 5 SP q`: Blinking bar (I-beam).
  - `CSI 6 SP q`: Steady bar (I-beam).
  - _Note: Support for DECSCUSR varies significantly between terminal emulators._
- **Save/Restore Position (DECSC / DECRC):**
  - `ESC 7` or `CSI s` (DECSC - Save Cursor Position): Saves current cursor position, rendition attributes, and potentially character set state.
  - `ESC 8` or `CSI u` (DECRC - Restore Cursor Position): Restores the state saved by DECSC.
- **Blinking (Mode Set - _Often Handled by Terminal_):**
  - `CSI ? 12 h`: Start blinking cursor.
  - `CSI ? 12 l`: Stop blinking cursor.
  - _Note: Cursor blinking is often a terminal emulator setting or controlled by DECSCUSR, rather than this separate mode._

## Implementation in Raxol

1.  **Parsing (`Raxol.Terminal.Parser`)**: The `Parser` identifies these CSI sequences in the input stream received from the application or generated internally.
2.  **State Management (`Raxol.Terminal.Emulator`)**: Based on the parsed sequence, the `Emulator` updates its internal state, which includes:
    - The current logical cursor row (`curs_y`).
    - The current logical cursor column (`curs_x`).
    - The cursor visibility flag (`curs_visible`).
    - Potentially the cursor style (`curs_style`), if DECSCUSR is implemented.
    - Saved cursor state (`saved_curs_state`) for DECSC/DECRC.
3.  **Sequence Generation (`Raxol.UI.Renderer` / `Raxol.Terminal.Driver`)**: When Raxol needs to position the cursor for output or input, the `Renderer` or other components query the `Emulator`'s state. The necessary ANSI sequence (most commonly CUP - `CSI Pl ; Pc H`) is then generated and sent to the terminal via the `Driver` to move the physical cursor.

## Application Interaction

Applications running within Raxol typically don't interact with cursor state directly via a `Cursor` module. Instead:

- UI components (like `TextInput` or `MultiLineInput`) manage their own internal cursor position relative to their content.
- During rendering, the framework calculates the absolute screen position for the component's logical cursor.
- The `Renderer` ensures the physical terminal cursor is moved to this absolute position before drawing the component or waiting for input.
- Direct cursor manipulation might occur via specific commands or low-level terminal operations if necessary, but usually relies on the `Emulator`'s state tracking.

## Terminal Emulator Dependence

- The actual appearance of the cursor (block, underline, bar), its blinking behavior, and its color are primarily determined by the **hosting terminal emulator** and its settings.
- Raxol sends the standard ANSI sequences, but the terminal interprets them. Support for sequences like DECSCUSR can vary.

## Harmonized Cursor Management in Input Components

Modern input components such as `MultiLineInput` now use a harmonized API for managing their internal cursor position, selection, and focus. This ensures consistent cursor behavior, keyboard navigation, and accessibility support across all major input components.

For usage details and supported props, see the [Main UI Components Guide](../../03_component_reference/Elements.md#multilineinput).

> **Note:** Legacy input components may not fully support the harmonized cursor conventions. Prefer the modern components for new development.

(Previous content based on a hypothetical `Raxol.Terminal.Cursor` module, including its API, configuration, specific animation system, events, and examples, has been removed.)
