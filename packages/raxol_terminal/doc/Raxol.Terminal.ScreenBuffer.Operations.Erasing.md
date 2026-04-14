# `Raxol.Terminal.ScreenBuffer.Operations.Erasing`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/screen_buffer/operations/erasing.ex#L1)

Erasing operations for the screen buffer.

This module handles various erasing operations including
erase in display and erase in line with different modes.

# `erase_in_display`

```elixir
@spec erase_in_display(Raxol.Terminal.ScreenBuffer.t(), non_neg_integer(), map()) ::
  Raxol.Terminal.ScreenBuffer.t()
```

Erases in display based on mode.

Mode values:
- 0: From cursor to end of display
- 1: From start to cursor
- 2: Entire display
- 3: Entire display including scrollback

# `erase_in_line`

```elixir
@spec erase_in_line(Raxol.Terminal.ScreenBuffer.t(), non_neg_integer(), map()) ::
  Raxol.Terminal.ScreenBuffer.t()
```

Erases in line based on mode.

Mode values:
- 0: From cursor to end of line
- 1: From start of line to cursor
- 2: Entire line

---

*Consult [api-reference.md](api-reference.md) for complete listing*
