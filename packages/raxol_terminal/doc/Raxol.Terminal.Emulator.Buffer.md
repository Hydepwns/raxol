# `Raxol.Terminal.Emulator.Buffer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/emulator/emulator_buffer.ex#L1)

Provides buffer management functionality for the terminal emulator.

# `clear_buffer`

Clears the entire buffer.

# `clear_from_cursor_to_end`

Clears from cursor to end of screen.

# `clear_from_cursor_to_start`

Clears from start of screen to cursor.

# `clear_line`

Clears the current line.

# `clear_scroll_region`

```elixir
@spec clear_scroll_region(Raxol.Terminal.Emulator.Struct.t()) ::
  {:ok, Raxol.Terminal.Emulator.Struct.t()}
```

Clears the scroll region, allowing scrolling of the entire screen.
Returns {:ok, updated_emulator}.

# `scroll_down`

Scrolls the buffer down by the specified number of lines.

# `scroll_up_emulator`

Scrolls the buffer up by the specified number of lines.

# `set_scroll_region`

```elixir
@spec set_scroll_region(
  Raxol.Terminal.Emulator.Struct.t(),
  non_neg_integer(),
  non_neg_integer()
) :: {:ok, Raxol.Terminal.Emulator.Struct.t()} | {:error, String.t()}
```

Sets the scroll region for the active buffer.
Returns {:ok, updated_emulator} or {:error, reason}.

# `switch_buffer`

```elixir
@spec switch_buffer(Raxol.Terminal.Emulator.Struct.t(), :main | :alternate) ::
  {:ok, Raxol.Terminal.Emulator.Struct.t()} | {:error, String.t()}
```

Switches between main and alternate screen buffers.
Returns {:ok, updated_emulator} or {:error, reason}.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
