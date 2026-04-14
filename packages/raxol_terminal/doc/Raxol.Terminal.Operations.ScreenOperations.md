# `Raxol.Terminal.Operations.ScreenOperations`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/operations/screen_operations.ex#L1)

Implements screen-related operations for the terminal emulator.

# `emulator`

```elixir
@type emulator() :: map()
```

# `clear_line`

# `clear_line`

# `clear_screen`

# `delete_chars`

# `delete_lines`

# `erase_chars`

# `erase_display`

Erases the entire display (1-arity version).

# `erase_display`

```elixir
@spec erase_display(emulator(), integer()) :: emulator()
```

Erases the display based on the specified mode.

# `erase_from_cursor_to_end`

# `erase_from_start_to_cursor`

# `erase_in_display`

Erases from cursor to end of display (1-arity version).

# `erase_in_display`

```elixir
@spec erase_in_display(emulator(), integer()) :: emulator()
```

Erases in display based on the specified mode.

# `erase_in_line`

Erases from cursor to end of line (1-arity version).

# `erase_in_line`

# `erase_line`

# `erase_line`

# `get_content`

# `get_cursor_position`

# `get_line`

# `insert_chars`

# `insert_lines`

# `prepend_lines`

# `set_cursor_position`

# `write_string`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
