# `Raxol.Terminal.Cursor.Movement`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/cursor/movement.ex#L1)

Handles cursor movement operations for the terminal cursor.
Extracted from Raxol.Terminal.Cursor.Manager to reduce file size.

# `constrain_position`

```elixir
@spec constrain_position(
  Raxol.Terminal.Cursor.Manager.t(),
  non_neg_integer(),
  non_neg_integer()
) ::
  Raxol.Terminal.Cursor.Manager.t()
```

Constrains the cursor position to within the specified bounds.

# `move_down`

Moves the cursor down by the specified number of lines.

# `move_home`

Moves the cursor to the home position (0, 0).

# `move_left`

Moves the cursor left by the specified number of columns.

# `move_right`

Moves the cursor right by the specified number of columns.

# `move_to_bounded`

Moves the cursor to a specific position with bounds clamping.

# `move_to_column`

Moves the cursor to the specified column.

# `move_to_column`

```elixir
@spec move_to_column(
  Raxol.Terminal.Cursor.Manager.t(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer()
) :: Raxol.Terminal.Cursor.Manager.t()
```

Moves the cursor to the specified column with bounds clamping.

# `move_to_line`

Moves the cursor to the specified line.

# `move_to_line_end`

Moves the cursor to the end of the line.

# `move_to_line_start`

Moves the cursor to the beginning of the line.

# `move_to_next_tab`

Moves the cursor to the next tab stop.

# `move_to_prev_tab`

Moves the cursor to the previous tab stop.

# `move_up`

Moves the cursor up by the specified number of lines.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
