---
title: Terminal Handling in Raxol
description: Understanding how Raxol interacts with the terminal emulator
date: 2024-07-26
author: DROO AMOR
section: internals
tags: [terminal, emulator, ansi, rendering, internals]
---

# Terminal Handling in Raxol

While you typically interact with Raxol through the `Raxol.Core.Runtime.Application` behaviour and components, understanding how Raxol manages the underlying terminal can be helpful. Raxol includes a sophisticated layer for terminal interaction, ensuring efficient rendering and consistent behaviour across different terminal emulators.

## Key Features

Users of the Raxol library benefit from the following terminal handling features, which operate mostly behind the scenes:

1.  **Efficient Rendering Pipeline:**

    - **Double Buffering:** Raxol renders UI changes to an off-screen buffer first (`Raxol.UI.Renderer`). It then calculates the minimal set of changes required to update the visible terminal screen to match the new buffer.
    - **Diffing:** Only the differing cells between the current screen state and the desired new state are redrawn. This minimizes the amount of data sent to the terminal, reducing flicker and improving performance, especially over slower connections.

2.  **ANSI Escape Code Management:**

    - Raxol abstracts away the complexities of generating ANSI escape codes for cursor positioning, text styling (bold, italics, underline), and color application. The `Raxol.Terminal.Parser` handles incoming codes, and the `Raxol.UI.Renderer` generates outgoing codes based on the view.
    - Components like `<text>`, `<box>`, etc., translate their properties into the correct sequences for the terminal via the rendering pipeline.

3.  **Color Support:**

    - Raxol attempts to detect the color capabilities of the user's terminal (Truecolor, 256-color, 16-color).
    - The `Raxol.Core.ColorSystem` intelligently maps specified colors (e.g., hex codes, names) to the closest available color in the detected mode, respecting themes and accessibility settings (like high contrast) managed via `Raxol.Core.UserPreferences`.

4.  **Unicode Handling:**

    - Raxol is designed to work correctly with Unicode characters, including multi-width characters (like CJK characters or emojis).
    - The layout engine (`Raxol.UI.Layout.Engine`) correctly calculates character widths to ensure proper layout and alignment within components.

5.  **Input Processing:**

    - The `Raxol.Terminal.Driver` captures and parses raw terminal input events (keyboard presses, mouse events - if enabled/supported).
    - These events are translated into a standardized format (`Raxol.Core.Events.Event`).
    - Events are typically dispatched by the `Raxol.Core.Runtime.Events.Dispatcher` to the application's `update/2` function as messages, or potentially handled directly by components implementing the `handle_event/3` callback.

6.  **Sixel Graphics Support:**
    - Raxol includes support for parsing and rendering Sixel graphics sequences (`Raxol.Terminal.ANSI.SixelGraphics`), allowing for bitmap image display in compatible terminals.

## Why This Matters for Library Users

Even though you don't directly interact with modules like `Raxol.Terminal.Parser` or `Raxol.Terminal.Emulator` in typical application code, this underlying system provides:

- **Performance:** Smooth, flicker-free updates even for complex UIs.
- **Consistency:** Your application should look and behave similarly across different terminal emulators (within the limits of the emulator's capabilities).
- **Developer Experience:** You can focus on defining your UI structure and logic using components, without worrying about low-level terminal escape codes.

For most use cases involving `Raxol.Core.Runtime.Application`, you don't need to interact with this layer directly. The `Raxol.Core.Runtime` manages the terminal lifecycle and rendering based on the output of your `view/1` function and how messages are handled in `update/2`.

### Key Concepts

- **`Raxol.Terminal.Driver`**: Handles low-level terminal interaction through the `:rrex_termbox` v2.0.1 NIF-based backend. Responsible for setting raw mode, reading input events, writing output bytes, and translating NIF events into `Raxol.Core.Events.Event` structs. This architecture provides improved performance and reliability over the previous Port-based implementation.
- **`Raxol.Terminal.Parser`**: A state machine responsible for parsing incoming ANSI escape sequences and other control codes, interpreting their meaning, and updating the terminal state. It utilizes helper modules for specific code types.
- **`Raxol.Terminal.Emulator`**: Manages the internal state representation of the terminal, including screen buffers, cursor position, character attributes (color, style), screen modes, character sets, and scroll regions.
- **`Raxol.Terminal.ControlCodes`**: Handles the interpretation and execution of simple C0 control codes (like newline, carriage return, backspace) and basic ESC sequences.
- **`Raxol.Terminal.Buffer`**: Manages the in-memory representation of the terminal screen (often using double buffering) and tracks changes for efficient updates.
- **`Raxol.Terminal.Cursor`**: Manages the logical and physical cursor state, including visibility, shape, and position.
- **`Raxol.Terminal.ANSI.SixelGraphics`**: Specifically handles the parsing and state management related to Sixel bitmap graphics sequences.
- **Rendering Pipeline Integration**: The terminal components work together with the `Raxol.UI.Renderer` (generates styled cell data) and `Raxol.Terminal.Renderer` (outputs optimized diffs to the `Driver`) to display the UI defined by the application's `view/1` function.
