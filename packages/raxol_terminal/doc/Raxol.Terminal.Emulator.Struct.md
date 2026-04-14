# `Raxol.Terminal.Emulator.Struct`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/emulator/struct.ex#L1)

Provides terminal emulator structure and related functionality.

# `t`

```elixir
@type t() :: %Raxol.Terminal.Emulator.Struct{
  active_buffer: Raxol.Terminal.ScreenBuffer.t(),
  active_buffer_type: :main | :alternate,
  alternate_screen_buffer: Raxol.Terminal.ScreenBuffer.t(),
  buffer: term(),
  charset_state: %{
    g0: atom(),
    g1: atom(),
    g2: atom(),
    g3: atom(),
    gl: atom(),
    gr: atom(),
    single_shift: atom() | nil
  },
  client_options: map(),
  color_palette: map(),
  command: term(),
  command_history: [String.t()],
  config: term(),
  current_command_buffer: String.t(),
  current_hyperlink: term(),
  current_hyperlink_url: String.t() | nil,
  cursor: %{
    position: {integer(), integer()},
    style: atom(),
    visible: boolean(),
    blink_state: boolean()
  },
  cursor_manager: term(),
  cursor_style: atom(),
  event: term(),
  height: non_neg_integer(),
  icon_name: String.t() | nil,
  last_col_exceeded: boolean(),
  last_key_event: term(),
  main_screen_buffer: Raxol.Terminal.ScreenBuffer.t(),
  max_command_history: non_neg_integer(),
  memory_limit: non_neg_integer(),
  mode_manager: term(),
  output_buffer: String.t(),
  parser_state: term(),
  plugin_manager: term(),
  saved_cursor:
    %{
      position: {integer(), integer()},
      style: atom(),
      visible: boolean(),
      blink_state: boolean()
    }
    | nil,
  scroll_region: {non_neg_integer(), non_neg_integer()} | nil,
  scrollback_buffer: [Raxol.Terminal.ScreenBuffer.t()],
  scrollback_limit: non_neg_integer(),
  session_id: String.t(),
  state: atom(),
  state_stack: list(),
  style: map(),
  tab_stops: [integer()],
  width: non_neg_integer(),
  window_manager: term(),
  window_title: String.t() | nil
}
```

# `get_cursor_position`

```elixir
@spec get_cursor_position(t()) :: {non_neg_integer(), non_neg_integer()}
```

Gets the cursor position from the emulator.

# `get_screen_buffer`

```elixir
@spec get_screen_buffer(t()) :: Raxol.Terminal.ScreenBuffer.t()
```

Gets the active buffer from the emulator.

# `maybe_scroll`

```elixir
@spec maybe_scroll(t()) :: t()
```

Checks if scrolling is needed and performs it if necessary.

# `move_cursor`

```elixir
@spec move_cursor(t(), integer(), integer()) :: t()
```

Moves the cursor to the specified position.

# `move_cursor_down`

```elixir
@spec move_cursor_down(t(), integer(), integer(), integer()) :: t()
```

Moves the cursor down by the specified number of lines.

# `move_cursor_left`

```elixir
@spec move_cursor_left(t(), integer(), integer(), integer()) :: t()
```

Moves the cursor left by the specified number of columns.

# `move_cursor_right`

```elixir
@spec move_cursor_right(t(), integer(), integer(), integer()) :: t()
```

Moves the cursor right by the specified number of columns.

# `move_cursor_to`

```elixir
@spec move_cursor_to(t(), {integer(), integer()}, integer(), integer()) :: t()
```

Moves the cursor to the specified position.

# `move_cursor_to_column`

```elixir
@spec move_cursor_to_column(t(), integer(), integer(), integer()) :: t()
```

Moves the cursor to the specified column.

# `move_cursor_to_line_start`

```elixir
@spec move_cursor_to_line_start(t()) :: t()
```

Moves the cursor to the start of the current line.

# `move_cursor_up`

```elixir
@spec move_cursor_up(t(), integer(), integer(), integer()) :: t()
```

Moves the cursor up by the specified number of lines.

# `new`

```elixir
@spec new(non_neg_integer(), non_neg_integer(), keyword()) :: map()
```

Creates a new terminal emulator with the given options.

# `process_input`

```elixir
@spec process_input(t(), String.t()) :: {t(), String.t()}
```

Processes input for the emulator.

# `reset_mode`

```elixir
@spec reset_mode(t(), atom()) :: t()
```

Resets a terminal mode.

# `set_charset`

```elixir
@spec set_charset(t(), atom()) :: {:ok, t()} | {:error, atom(), t()}
```

Sets the character set for the emulator.

# `set_mode`

```elixir
@spec set_mode(t(), atom()) :: t()
```

Sets a terminal mode.

# `update_active_buffer`

```elixir
@spec update_active_buffer(t(), map()) :: t()
```

Updates the active buffer in the emulator.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
