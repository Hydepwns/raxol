# `Raxol.Terminal.Input.Manager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/input/input_manager.ex#L1)

Manages terminal input processing including character input, key events, and input mode handling.
This module is responsible for processing all input events and converting them into appropriate
terminal actions.

# `t`

```elixir
@type t() :: %Raxol.Terminal.Input.Manager{
  buffer: map(),
  completion_callback: function() | nil,
  history_index: integer() | nil,
  input_history: list(),
  key_mappings: map(),
  metrics: map(),
  mode: atom(),
  modifier_state: map(),
  mouse_buttons: MapSet.t(),
  mouse_enabled: boolean(),
  mouse_position: {integer(), integer()},
  processor: module(),
  validation_rules: list()
}
```

# `add_key_mapping`

Adds a custom key mapping.

# `add_validation_rule`

Adds a custom validation rule.

# `flush_buffer`

Flushes the input buffer.

# `get_buffer_contents`

Gets the buffer contents.

# `get_input_mode`

Gets the current input mode.
Returns the input mode.

# `get_metrics`

Gets the current metrics.

# `get_mode`

Gets the current mode.

# `handle_key_event`

Handles a key event.
Returns the updated emulator and any output.

# `new`

Creates a new input manager with default configuration.

# `new`

Creates a new input manager with custom options.

# `process_input`

Processes a single character input.
Returns the updated emulator and any output.

# `process_input_sequence`

Processes a sequence of character inputs.
Returns the updated emulator and any output.

# `process_key_event`

Processes a key event.

# `process_key_with_modifiers`

Processes a key with modifiers.

# `process_keyboard`

Processes keyboard input.

# `process_mouse`

Processes mouse events.

# `process_special_key`

Processes special keys.

# `set_input_mode`

Sets the input mode.
Returns the updated emulator.

# `set_mode`

Sets the mode.

# `set_mouse_enabled`

Sets mouse enabled state.

# `update_modifier`

Updates modifier state.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
