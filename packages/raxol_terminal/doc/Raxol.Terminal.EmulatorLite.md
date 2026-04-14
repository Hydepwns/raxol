# `Raxol.Terminal.EmulatorLite`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/emulator_lite.ex#L1)

Lightweight terminal emulator for performance-critical paths.

This is a pure struct-based emulator without GenServer processes,
designed for fast parsing and simple terminal operations.

For full-featured terminal emulation with state management and
concurrent operations, use Raxol.Terminal.Emulator.

# `t`

```elixir
@type t() :: %Raxol.Terminal.EmulatorLite{
  active_buffer_type: :main | :alternate,
  alternate_screen_buffer: Raxol.Terminal.ScreenBuffer.t() | nil,
  charset_state: map(),
  client_options: map(),
  command_history: list() | nil,
  current_command_buffer: String.t() | nil,
  cursor: Raxol.Terminal.Cursor.t(),
  cursor_style: atom(),
  height: non_neg_integer(),
  last_col_exceeded: boolean(),
  main_screen_buffer: Raxol.Terminal.ScreenBuffer.t(),
  max_command_history: non_neg_integer(),
  mode_manager: Raxol.Terminal.ModeManager.t(),
  mode_state: map(),
  output_buffer: String.t(),
  parser_state: any(),
  saved_cursor: Raxol.Terminal.Cursor.t() | nil,
  saved_style: Raxol.Terminal.ANSI.TextFormatting.t() | nil,
  scroll_region: {non_neg_integer(), non_neg_integer()} | nil,
  scrollback_buffer: list(),
  scrollback_limit: non_neg_integer(),
  session_id: String.t() | nil,
  style: Raxol.Terminal.ANSI.TextFormatting.t(),
  width: non_neg_integer(),
  window_state: map(),
  window_title: String.t() | nil
}
```

# `get_active_buffer`

Gets the active screen buffer.

# `move_cursor`

Moves the cursor to a specific position.

# `move_cursor_relative`

Updates the cursor position relatively.

# `new`

Creates a new lightweight emulator with minimal overhead.

Options:
  - :enable_history - Enable command history tracking (default: false)
  - :scrollback_limit - Number of scrollback lines (default: 1000)
  - :alternate_buffer - Create alternate screen buffer (default: false)

# `new_minimal`

Creates a minimal emulator for fastest possible parsing.
No history, no alternate buffer, minimal features.

# `reset`

Resets the emulator to initial state.

# `resize`

Resizes the emulator to new dimensions.

# `switch_buffer`

Switches between main and alternate screen buffers.

# `update_active_buffer`

Updates the active screen buffer.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
