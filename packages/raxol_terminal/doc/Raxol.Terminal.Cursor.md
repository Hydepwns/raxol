# `Raxol.Terminal.Cursor`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/cursor.ex#L1)

Provides cursor manipulation functions for the terminal emulator.
This module handles operations like moving the cursor, setting its visibility,
and managing cursor state.

# `t`

```elixir
@type t() :: %Raxol.Terminal.Cursor{
  position: {non_neg_integer(), non_neg_integer()},
  saved_position: {non_neg_integer(), non_neg_integer()} | nil,
  shape: atom(),
  visible: boolean()
}
```

# `get_position`

Gets the current cursor position.

# `get_style`

Gets the cursor style.

# `move_backward`

Moves the cursor backward by the specified number of columns.

# `move_down`

Moves the cursor down by the specified number of lines.

# `move_down_and_home`

Moves the cursor down and to the beginning of the line.

# `move_forward`

Moves the cursor forward by the specified number of columns.

# `move_left`

Moves the cursor left by the specified number of columns.

# `move_relative`

Moves the cursor relative to its current position.

# `move_right`

Moves the cursor right by the specified number of columns.

# `move_to`

Moves the cursor to the specified position.

# `move_to`

Moves the cursor to the specified row and column.

# `move_to`

Moves the cursor to the specified position, taking into account the screen width and height.

# `move_to_column`

Moves the cursor to the specified column.

# `move_up`

Moves the cursor up by the specified number of lines.

# `move_up_and_home`

Moves the cursor up and to the beginning of the line.

# `new`

Creates a new cursor with default settings.

# `reset_color`

Resets the cursor color to default.

# `restore`

Restores the cursor to a previously saved position.

# `save`

Saves the current cursor position.

# `set_blink`

Sets the cursor blink state.

# `set_color`

Sets the cursor color.

# `set_position`

Sets the cursor position.

# `set_shape`

Sets the cursor shape.

# `set_style`

Sets the cursor style.

# `set_visibility`

Sets the cursor visibility.

# `set_visible`

Sets the cursor visibility.

# `visible?`

Checks if the cursor is visible.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
