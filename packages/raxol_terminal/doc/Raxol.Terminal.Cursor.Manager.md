# `Raxol.Terminal.Cursor.Manager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/cursor/cursor_manager.ex#L1)

Manages cursor state and operations in the terminal.
Handles cursor position, visibility, style, and blinking state.

# `color`

```elixir
@type color() :: {non_neg_integer(), non_neg_integer(), non_neg_integer()} | nil
```

# `cursor_style`

```elixir
@type cursor_style() :: :block | :underline | :bar | :custom
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.Cursor.Manager{
  blink: boolean(),
  blink_rate: non_neg_integer(),
  blink_timer: non_neg_integer() | nil,
  blinking: boolean(),
  bottom_margin: non_neg_integer(),
  col: non_neg_integer(),
  color: color(),
  custom_dimensions: {non_neg_integer(), non_neg_integer()} | nil,
  custom_shape: atom() | String.t() | nil,
  history: list(),
  history_index: non_neg_integer(),
  history_limit: non_neg_integer(),
  position: {non_neg_integer(), non_neg_integer()},
  row: non_neg_integer(),
  saved_blinking: boolean() | nil,
  saved_col: non_neg_integer() | nil,
  saved_color: color() | nil,
  saved_position: {non_neg_integer(), non_neg_integer()} | nil,
  saved_row: non_neg_integer() | nil,
  saved_style: cursor_style() | nil,
  saved_visible: boolean() | nil,
  shape: {non_neg_integer(), non_neg_integer()},
  state: atom(),
  style: cursor_style(),
  top_margin: non_neg_integer(),
  visible: boolean()
}
```

# `add_to_history`

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `constrain_position`

# `emulator_blinking?`

```elixir
@spec emulator_blinking?(Raxol.Terminal.Emulator.t()) :: boolean()
```

# `emulator_visible?`

```elixir
@spec emulator_visible?(Raxol.Terminal.Emulator.t()) :: boolean()
```

# `get_blink`

# `get_color`

# `get_emulator_position`

```elixir
@spec get_emulator_position(Raxol.Terminal.Emulator.t()) :: {integer(), integer()}
```

# `get_emulator_style`

```elixir
@spec get_emulator_style(Raxol.Terminal.Emulator.t()) :: atom()
```

# `get_margins`

# `get_position`

Gets the current cursor position.

# `get_position_tuple`

Gets the cursor position as a tuple {row, col}.

# `get_state`

# `get_style`

# `get_visibility`

Gets the cursor visibility state.

# `move_cursor`

Moves the cursor relative to its current position.

# `move_down`

```elixir
@spec move_down(Raxol.Terminal.Emulator.t(), non_neg_integer()) ::
  Raxol.Terminal.Emulator.t()
```

Moves the cursor down by the specified number of lines.
Returns the updated emulator.

# `move_down`

# `move_home`

# `move_left`

```elixir
@spec move_left(Raxol.Terminal.Emulator.t(), non_neg_integer()) ::
  Raxol.Terminal.Emulator.t()
```

Moves the cursor left by the specified number of columns.
Returns the updated emulator.

# `move_left`

# `move_right`

```elixir
@spec move_right(Raxol.Terminal.Emulator.t(), non_neg_integer()) ::
  Raxol.Terminal.Emulator.t()
```

Moves the cursor right by the specified number of columns.
Returns the updated emulator.

# `move_right`

# `move_to`

Moves the cursor to a specific position.

# `move_to`

Moves the cursor to a specific position with bounds clamping.

# `move_to_column`

# `move_to_column`

# `move_to_line`

# `move_to_line_end`

# `move_to_line_start`

# `move_to_next_tab`

# `move_to_prev_tab`

# `move_up`

```elixir
@spec move_up(Raxol.Terminal.Emulator.t(), non_neg_integer()) ::
  Raxol.Terminal.Emulator.t()
```

Moves the cursor up by the specified number of lines.
Returns the updated emulator.

# `move_up`

# `new`

Creates a new cursor manager instance.

# `new`

Creates a new cursor manager.

# `new`

# `reset`

# `reset_color`

# `reset_position`

# `restore_from_history`

# `restore_position`

# `restore_state`

# `save_position`

# `save_state`

# `set_blink`

# `set_color`

# `set_custom_shape`

# `set_custom_shape`

# `set_emulator_blink`

```elixir
@spec set_emulator_blink(Raxol.Terminal.Emulator.t(), boolean()) ::
  Raxol.Terminal.Emulator.t()
```

# `set_emulator_position`

```elixir
@spec set_emulator_position(
  Raxol.Terminal.Emulator.t(),
  non_neg_integer(),
  non_neg_integer()
) :: Raxol.Terminal.Emulator.t()
```

# `set_emulator_style`

```elixir
@spec set_emulator_style(Raxol.Terminal.Emulator.t(), atom()) ::
  Raxol.Terminal.Emulator.t()
```

# `set_emulator_visibility`

```elixir
@spec set_emulator_visibility(Raxol.Terminal.Emulator.t(), boolean()) ::
  Raxol.Terminal.Emulator.t()
```

# `set_margins`

# `set_position`

Sets the cursor position.

# `set_state`

# `set_style`

# `set_style`

# `set_visibility`

Sets the cursor visibility state.

# `start_link`

# `update_blink`

# `update_blink`

# `update_cursor_position`

```elixir
@spec update_cursor_position(
  Raxol.Terminal.Emulator.t(),
  non_neg_integer(),
  non_neg_integer()
) :: Raxol.Terminal.Emulator.t()
```

Updates the cursor position after a resize operation.
Returns the updated emulator.

# `update_position`

# `update_position_from_text`

# `update_scroll_region_for_resize`

```elixir
@spec update_scroll_region_for_resize(map(), non_neg_integer()) :: map()
```

Updates the scroll region after a resize operation.
Returns the updated emulator.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
