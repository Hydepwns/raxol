# `Raxol.Terminal.Buffer.LineEditor`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/buffer/line_editor.ex#L1)

Provides functionality for line editing operations in the terminal buffer.

# `delete_lines`

```elixir
@spec delete_lines(
  Raxol.Terminal.ScreenBuffer.t(),
  integer(),
  integer(),
  Raxol.Terminal.ANSI.TextFormatting.text_style()
) :: Raxol.Terminal.ScreenBuffer.t()
```

Deletes a specified number of lines starting from the given row index.
Lines below the deleted lines are shifted up.
Blank lines are added at the bottom of the buffer to fill the space using the provided default_style.
Uses the buffer's default style for new lines.

# `insert_lines`

```elixir
@spec insert_lines(
  Raxol.Terminal.ScreenBuffer.t(),
  integer(),
  integer(),
  Raxol.Terminal.ANSI.TextFormatting.text_style()
) :: Raxol.Terminal.ScreenBuffer.t()
```

Inserts a specified number of blank lines at the given row index using the provided default_style.
Existing lines from the insertion point downwards are shifted down.
Lines shifted off the bottom of the buffer are discarded.
Uses the buffer's default style for new lines.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
