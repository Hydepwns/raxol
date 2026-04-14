# `Raxol.Terminal.Commands.CSIHandler.CursorMovementHandler`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/commands/csi_handler/cursor_movement_handler.ex#L1)

Handles cursor movement operations for CSI sequences.

Provides full implementation of cursor movement commands integrating with the
existing Raxol.Terminal.Cursor module for consistent cursor state management.

Supports all standard VT100/ANSI cursor movement sequences:
- Cursor Up (CUU)
- Cursor Down (CUD)
- Cursor Forward/Right (CUF)
- Cursor Backward/Left (CUB)
- Cursor Position (CUP)
- Horizontal and Vertical Position Absolute (HPA/VPA)

# `cursor_amount`

```elixir
@type cursor_amount() :: non_neg_integer()
```

# `cursor_position`

```elixir
@type cursor_position() :: {non_neg_integer(), non_neg_integer()}
```

# `emulator`

```elixir
@type emulator() :: Raxol.Terminal.Emulator.t()
```

# `cursor_at_edge?`

```elixir
@spec cursor_at_edge?(emulator()) :: %{
  top: boolean(),
  bottom: boolean(),
  left: boolean(),
  right: boolean()
}
```

Checks if cursor is at the edge of the screen.

# `get_cursor_position`

```elixir
@spec get_cursor_position(emulator()) :: cursor_position()
```

Gets the current cursor position.

# `handle_cursor_backward`

```elixir
@spec handle_cursor_backward(emulator(), cursor_amount()) :: {:ok, emulator()}
```

Moves cursor backward (left) by specified amount.
CUB - Cursor Backward

# `handle_cursor_column`

```elixir
@spec handle_cursor_column(emulator(), non_neg_integer()) :: {:ok, emulator()}
```

Sets cursor to specific column (Horizontal Position Absolute).
HPA - Horizontal Position Absolute

# `handle_cursor_down`

```elixir
@spec handle_cursor_down(emulator(), cursor_amount()) :: {:ok, emulator()}
```

Moves cursor down by specified amount.
CUD - Cursor Down

# `handle_cursor_forward`

```elixir
@spec handle_cursor_forward(emulator(), cursor_amount()) :: {:ok, emulator()}
```

Moves cursor forward (right) by specified amount.
CUF - Cursor Forward

# `handle_cursor_position`

```elixir
@spec handle_cursor_position(emulator(), [non_neg_integer()]) :: {:ok, emulator()}
```

Sets cursor position from parameter list.
CUP - Cursor Position

# `handle_cursor_position`

```elixir
@spec handle_cursor_position(emulator(), non_neg_integer(), non_neg_integer()) ::
  {:ok, emulator()}
```

Sets cursor position directly with row and column.
CUP - Cursor Position (Direct)

# `handle_cursor_position_direct`

```elixir
@spec handle_cursor_position_direct(
  emulator(),
  non_neg_integer(),
  non_neg_integer()
) :: {:ok, emulator()}
```

Sets cursor position directly without parameter validation.
Used internally for absolute positioning.

# `handle_cursor_row`

```elixir
@spec handle_cursor_row(emulator(), non_neg_integer()) :: {:ok, emulator()}
```

Sets cursor to specific row (Vertical Position Absolute).
VPA - Vertical Position Absolute

# `handle_cursor_up`

```elixir
@spec handle_cursor_up(emulator(), cursor_amount()) :: {:ok, emulator()}
```

Moves cursor up by specified amount.
CUU - Cursor Up

---

*Consult [api-reference.md](api-reference.md) for complete listing*
