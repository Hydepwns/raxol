---
title: Terminal Handling in Raxol
description: Understanding how Raxol interacts with the terminal emulator
date: 2025-04-22
author: DROO AMOR
section: internals
tags: [terminal, emulator, ansi, rendering, internals]
---

# Terminal Handling in Raxol

While you typically interact with Raxol through the `Raxol.App` behaviour and components, understanding how Raxol manages the underlying terminal can be helpful. Raxol includes a sophisticated layer for terminal interaction, ensuring efficient rendering and consistent behaviour across different terminal emulators.

## Key Features

Users of the Raxol library benefit from the following terminal handling features, which operate mostly behind the scenes:

1.  **Efficient Rendering Pipeline:**

    - **Double Buffering:** Raxol renders UI changes to an off-screen buffer first. It then calculates the minimal set of changes required to update the visible terminal screen to match the new buffer.
    - **Diffing:** Only the differing cells between the current screen state and the desired new state are redrawn. This minimizes the amount of data sent to the terminal, reducing flicker and improving performance, especially over slower connections.

2.  **ANSI Escape Code Management:**

    - Raxol abstracts away the complexities of generating ANSI escape codes for cursor positioning, text styling (bold, italics, underline), and color application.
    - Components like `<text>`, `<box>`, etc., translate their properties into the correct sequences for the terminal.

3.  **Color Support:**

    - Raxol attempts to detect the color capabilities of the user's terminal (Truecolor, 256-color, 16-color).
    - It intelligently maps specified colors (e.g., hex codes, names) to the closest available color in the detected mode, providing the best possible visual fidelity.
    - (Future: Add details on how users can override or hint color modes if needed).

4.  **Unicode Handling:**

    - Raxol is designed to work correctly with Unicode characters, including multi-width characters (like CJK characters or emojis).
    - It correctly calculates character widths to ensure proper layout and alignment within components.

5.  **Input Processing:**
    - Raxol captures and parses raw terminal input events (keyboard presses, mouse events - if enabled/supported).
    - These events are translated into a standardized format (`Raxol.Event`) that can be handled within your `Raxol.App` implementation (e.g., in `handle_event/3`).

## Why This Matters for Library Users

Even though you don't directly call functions like `Raxol.Terminal.Emulator.write_char/2`, this underlying system provides:

- **Performance:** Smooth, flicker-free updates even for complex UIs.
- **Consistency:** Your application should look and behave similarly across different terminal emulators (within the limits of the emulator's capabilities).
- **Developer Experience:** You can focus on defining your UI structure and logic using components, without worrying about low-level terminal escape codes.

For most use cases involving `Raxol.App`, you don't need to interact with this layer directly. The `Raxol.Core.Runtime` manages the terminal lifecycle and rendering based on the output of your `render/1` function and event handlers.

### Key Concepts
