# `Raxol.Terminal.ANSI.InputParser`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/input_parser.ex#L1)

Parses raw ANSI terminal input bytes into Raxol Event structs.

Handles:
- Arrow keys, Enter, Backspace, Tab, Escape
- Function keys F1-F12 (SS3 and CSI variants)
- Navigation keys (Home, End, Insert, Delete, PageUp, PageDown)
- Modifier combos (Shift+Tab, Ctrl+Arrow, Alt+key, etc.)
- Ctrl+A through Ctrl+Z
- Mouse SGR and X10/normal mode events
- Focus in/out events
- Bracketed paste
- Printable ASCII and UTF-8 characters

# `parse`

```elixir
@spec parse(binary()) :: [Raxol.Core.Events.Event.t()]
```

Parses a binary of raw terminal input into a list of Event structs.

Returns a list because a single read may contain multiple events
(e.g., pasted text or buffered input).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
