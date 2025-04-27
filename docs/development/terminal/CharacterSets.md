---
title: Character Set Handling
description: How Raxol handles terminal character set designation and invocation.
date: 2025-04-27
author: Raxol Team
section: terminal
tags: [character sets, terminal, documentation, emulator, parser, ansi]
---

# Character Set Handling

Raxol implements terminal character set handling based on standards like ECMA-48 and DEC VT series terminals. This allows applications to switch between different character mappings, primarily for accessing line drawing characters or national character sets.

## Concepts

- **Character Set Slots (G0, G1, G2, G3)**: The terminal maintains four slots, each capable of holding a designated character set (e.g., US-ASCII, DEC Special Graphics and Line Drawing, UK National).
- **Invocation Areas (GL, GR)**: At any time, one set is invoked into the "Graphics Left" (GL) area (codes `0x20` to `0x7F`) and potentially another into the "Graphics Right" (GR) area (codes `0xA0` to `0xFF` in an 8-bit environment).
- **Designation Sequences**: ANSI escape sequences (`ESC ( c`, `ESC ) c`, `ESC * c`, `ESC + c`) are used to designate a specific character set (`c`) into one of the G0-G3 slots.
- **Invocation Sequences**: Other sequences determine which designated set (G0-G3) is currently mapped to GL and GR.
  - **Shift Out (SO / ^N)**: Invokes G1 into GL.
  - **Shift In (SI / ^O)**: Invokes G0 into GL.
  - **Locking Shifts (LS2, LS3, LS1R, LS2R, LS3R in 8-bit)**: Invoke G2/G3 into GL or GR respectively.

## Implementation in Raxol

1. **Parsing (`Raxol.Terminal.Parser`)**: The parser recognizes the ANSI sequences for character set designation (e.g., `ESC ( 0` for DEC Special Graphics into G0) and invocation (e.g., `SI`, `SO`).
2. **State Management (`Raxol.Terminal.Emulator`)**: The `Emulator` maintains the state:
   - Which character set is currently designated for each slot (G0, G1, G2, G3).
   - Which slot is currently invoked into the GL area.
   - (If applicable) Which slot is currently invoked into the GR area.
     When the `Parser` recognizes a designation or invocation sequence, it calls functions within the `Emulator` to update this state.
3. **Character Set Definitions (`Raxol.Terminal.ANSI.Charsets`)**: This module (or similar) likely holds the actual mappings for standard character sets like US-ASCII and DEC Special Graphics and Line Drawing. It provides functions to translate a standard code point (like `0x6A`, lowercase 'j') to its representation in a specific set (like the bottom-right corner `┘` in DEC Special Graphics).
4. **Translation During Processing**: When the `Emulator` processes a printable character code (e.g., `0x71`), it checks its current GL/GR invocation state. If the invoked set for that area (GL for `0x71`) is something other than the default (US-ASCII), it uses the `Charsets` module to translate the incoming code point before storing the resulting character (e.g., the line drawing character `q` - `─`) in the `ScreenBuffer`.
5. **Font Handling**: Raxol does not control the actual font rendering. It outputs character codes (potentially translated via the character set mechanism). The displaying terminal application is responsible for selecting a font that can render these characters correctly (especially line drawing characters).

## Supported Character Sets (Common)

- **US-ASCII** (Designator `B`)
- **DEC Special Graphics and Line Drawing** (Designator `0`)
- **UK National** (Designator `A`)
- _(Support for other national or specialized sets may vary)_

## Interaction with Sixel Graphics

Sixel graphics sequences (`DCS P...q DATA ST`, often starting with `\eP...q`) represent a separate mode for transmitting pixel-based image data.

The character data _within_ a Sixel sequence (typically characters `?` through `~`, along with commands like `"`, `#`, `!`, `$`, `-`) is interpreted according to the Sixel protocol itself and is **not** processed by the standard G0-G3 character set translation described in this document.

Normal character set designation and translation apply to characters _outside_ of active Sixel sequences.
