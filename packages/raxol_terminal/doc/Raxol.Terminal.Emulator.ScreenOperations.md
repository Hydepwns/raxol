# `Raxol.Terminal.Emulator.ScreenOperations`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/emulator/screen_operations.ex#L1)

Screen operation functions extracted from the main emulator module.
Handles screen clearing and line clearing operations.

# `emulator`

```elixir
@type emulator() :: Raxol.Terminal.Emulator.Struct.t()
```

# `clear_entire_line`

```elixir
@spec clear_entire_line(emulator(), non_neg_integer()) :: emulator()
```

Clears the entire line.

# `clear_entire_screen`

```elixir
@spec clear_entire_screen(emulator()) :: emulator()
```

Clears the entire screen.

# `clear_from_cursor_to_end`

```elixir
@spec clear_from_cursor_to_end(
  emulator(),
  non_neg_integer(),
  non_neg_integer()
) :: emulator()
```

Clears from cursor to end of screen.

# `clear_from_cursor_to_end_of_line`

```elixir
@spec clear_from_cursor_to_end_of_line(
  emulator(),
  non_neg_integer(),
  non_neg_integer()
) :: emulator()
```

Clears from cursor to end of line.

# `clear_from_start_of_line_to_cursor`

```elixir
@spec clear_from_start_of_line_to_cursor(
  emulator(),
  non_neg_integer(),
  non_neg_integer()
) :: emulator()
```

Clears from start of line to cursor.

# `clear_from_start_to_cursor`

```elixir
@spec clear_from_start_to_cursor(
  emulator(),
  non_neg_integer(),
  non_neg_integer()
) :: emulator()
```

Clears from start of screen to cursor.

# `clear_line`

```elixir
@spec clear_line(emulator()) :: emulator()
```

Clears the current line.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
