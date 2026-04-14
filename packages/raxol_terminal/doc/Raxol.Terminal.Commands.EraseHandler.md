# `Raxol.Terminal.Commands.EraseHandler`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/commands/erase_handler.ex#L1)

Handles terminal erase commands like Erase in Display (ED) and Erase in Line (EL).
This module provides simple fallback implementations.

# `handle_erase`

Handles erase operations for display, line, or character.

Modes:
- :screen (ED): Erase in Display
- :line (EL): Erase in Line
- :character (ECH): Erase Characters

Parameters:
- mode: 0 = from cursor to end, 1 = from start to cursor, 2 = entire area
- position: {row, col} cursor position

---

*Consult [api-reference.md](api-reference.md) for complete listing*
