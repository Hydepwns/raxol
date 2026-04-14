# `Raxol.Terminal.ScreenBuffer.EraseOperations`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/screen_buffer/erase_operations.ex#L1)

Handles all erase operations for the terminal screen buffer.

This module provides focused functionality for erasing content from the buffer,
including line erasing, display erasing, and region clearing operations.

# `clear`

Clears the entire buffer, creating a fresh empty grid.

# `clear_region`

```elixir
@spec clear_region(
  Raxol.Terminal.ScreenBuffer.t(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer()
) :: Raxol.Terminal.ScreenBuffer.t()
```

Clears a specific region of the buffer.

# `delete_characters`

Deletes characters at a specific row/col position.

# `delete_chars`

Deletes characters at cursor position, shifting remaining cells left.

# `erase_all`

```elixir
@spec erase_all(Raxol.Terminal.ScreenBuffer.t()) :: Raxol.Terminal.ScreenBuffer.t()
```

Erases the entire buffer.

# `erase_display`

Erases display content based on mode (0=cursor-to-end, 1=start-to-cursor, 2=all).

# `erase_from_cursor_to_end`

```elixir
@spec erase_from_cursor_to_end(Raxol.Terminal.ScreenBuffer.t()) ::
  Raxol.Terminal.ScreenBuffer.t()
```

Erases from the cursor to the end of the screen using the current cursor position.

# `erase_from_cursor_to_end`

```elixir
@spec erase_from_cursor_to_end(
  map(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer()
) :: map()
```

Erases from cursor to end of display.

# `erase_from_start_to_cursor`

```elixir
@spec erase_from_start_to_cursor(
  map(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer()
) :: map()
```

Erases from start to cursor position.

# `erase_in_display`

```elixir
@spec erase_in_display(
  Raxol.Terminal.ScreenBuffer.t(),
  {non_neg_integer(), non_neg_integer()},
  atom()
) :: Raxol.Terminal.ScreenBuffer.t()
```

Erases part or all of the display based on the cursor position and type.
Type can be :to_end, :to_beginning, or :all.

# `erase_in_line`

```elixir
@spec erase_in_line(
  Raxol.Terminal.ScreenBuffer.t(),
  {non_neg_integer(), non_neg_integer()},
  atom()
) :: Raxol.Terminal.ScreenBuffer.t()
```

Erases part or all of the current line based on the cursor position and type.
Type can be :to_end, :to_beginning, or :all.

# `erase_line`

Erases line content based on mode (0=cursor-to-end, 1=start-to-cursor, 2=all).

# `erase_screen`

Erases the entire screen (alias for erase_all).

# `insert_chars`

Inserts blank characters at cursor position (no-op placeholder).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
