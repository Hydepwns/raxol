# `Raxol.Terminal.Emulator.CursorOperations`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/emulator/cursor_operations.ex#L1)

Cursor operation functions extracted from the main emulator module.
Handles cursor movement, positioning, and blink operations.

# `emulator`

```elixir
@type emulator() :: Raxol.Terminal.Emulator.t()
```

# `move_cursor`

```elixir
@spec move_cursor(emulator(), non_neg_integer(), non_neg_integer()) :: emulator()
```

Moves the cursor to the specified position (alias for move_cursor_to).

# `move_cursor_back`

```elixir
@spec move_cursor_back(emulator(), non_neg_integer()) :: emulator()
```

Moves the cursor back by the specified count.

# `move_cursor_down`

```elixir
@spec move_cursor_down(emulator(), non_neg_integer()) :: emulator()
```

# `move_cursor_down`

Moves the cursor down by the specified count.

# `move_cursor_forward`

```elixir
@spec move_cursor_forward(emulator(), non_neg_integer()) :: emulator()
```

Moves the cursor forward by the specified count.

# `move_cursor_left`

```elixir
@spec move_cursor_left(
  emulator(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer()
) :: emulator()
```

Moves the cursor left by the specified count.

# `move_cursor_right`

```elixir
@spec move_cursor_right(
  emulator(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer()
) :: emulator()
```

Moves the cursor right by the specified count.

# `move_cursor_to`

```elixir
@spec move_cursor_to(
  emulator(),
  {non_neg_integer(), non_neg_integer()}
) :: emulator()
```

Moves the cursor to the specified position (2-arity version).

# `move_cursor_to`

```elixir
@spec move_cursor_to(emulator(), non_neg_integer(), non_neg_integer()) :: emulator()
```

Moves the cursor to the specified position.

# `move_cursor_to_column`

```elixir
@spec move_cursor_to_column(
  emulator(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer()
) :: emulator()
```

Moves the cursor to the specified column.

# `move_cursor_to_line_start`

```elixir
@spec move_cursor_to_line_start(emulator()) :: emulator()
```

Moves the cursor to the start of the current line.

# `move_cursor_up`

```elixir
@spec move_cursor_up(emulator(), non_neg_integer()) :: emulator()
```

# `move_cursor_up`

```elixir
@spec move_cursor_up(emulator(), non_neg_integer(), term(), term()) :: emulator()
```

Moves the cursor up by the specified count.

# `set_blink_rate`

```elixir
@spec set_blink_rate(emulator(), non_neg_integer()) :: emulator()
```

Sets the blink rate for the cursor.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
