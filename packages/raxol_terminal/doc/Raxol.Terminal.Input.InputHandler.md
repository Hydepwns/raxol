# `Raxol.Terminal.Input.InputHandler`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/input/input_handler.ex#L1)

Handles input processing for the terminal emulator.

This module manages keyboard input, mouse events, input history,
and modifier key states.

# `t`

```elixir
@type t() :: %Raxol.Terminal.Input.InputHandler{
  buffer: term(),
  history_index: term(),
  input_history: term(),
  mode: term(),
  modifier_state: term(),
  mouse_buttons: term(),
  mouse_enabled: term(),
  mouse_position: term()
}
```

# `add_to_history`

Adds current buffer to history if not empty.

# `buffer_empty?`

Checks if buffer is empty.

# `clear_buffer`

Clears the input buffer.

# `get_buffer_contents`

Gets buffer contents.

# `get_history_entry`

Gets history entry at specified index.

# `get_mode`

Gets current input mode.

# `handle_printable_character`

Handles printable character input for the terminal emulator.

# `new`

Creates a new input handler with default values.

# `next_history_entry`

Moves to next (newer) history entry.

# `previous_history_entry`

Moves to previous (older) history entry.

# `process_key_with_modifiers`

Processes key with current modifier state.

# `process_keyboard`

Processes regular keyboard input.

# `process_mouse`

Processes mouse events.

# `process_special_key`

Processes special keys like arrow keys, function keys, etc.

# `set_mode`

Sets input mode.

# `set_mouse_enabled`

Sets mouse enabled state.

# `update_modifier`

Updates modifier key state.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
