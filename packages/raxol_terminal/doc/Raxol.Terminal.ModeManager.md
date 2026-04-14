# `Raxol.Terminal.ModeManager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/mode_manager.ex#L1)

Manages terminal modes (DEC Private Modes, Standard Modes) and their effects.

This module centralizes the state and logic for various terminal modes,
handling both simple flag toggles and modes with side effects on the
emulator state (like screen buffer switching or resizing).

# `mode`

```elixir
@type mode() :: atom()
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.ModeManager{
  active_buffer_type: term(),
  alt_screen_mode: term(),
  alternate_buffer_active: term(),
  auto_repeat_mode: term(),
  auto_wrap: term(),
  bracketed_paste_mode: term(),
  column_width_mode: term(),
  cursor_keys_mode: term(),
  cursor_visible: term(),
  focus_events_enabled: term(),
  insert_mode: term(),
  interlacing_mode: term(),
  line_feed_mode: term(),
  mouse_report_mode: term(),
  origin_mode: term(),
  screen_mode_reverse: term()
}
```

# `get_manager`

Gets the mode manager.

# `get_set_modes`

Gets the set modes.

# `lookup_private`

Looks up a DEC private mode code and returns the corresponding mode atom.

# `lookup_standard`

Looks up a standard mode code and returns the corresponding mode atom.

# `mode_enabled?`

# `mode_set?`

Checks if the given mode is set.

# `new`

Creates a new mode manager with default values.

# `reset_all_modes`

Resets all modes.

# `reset_mode`

Resets one or more modes. Dispatches to specific handlers.
Returns potentially updated Emulator state if side effects occurred.

# `restore_modes`

Restores the saved modes.

# `restore_state`

Restores the previously saved terminal state.

# `save_modes`

Saves the current modes.

# `save_state`

Saves the current terminal state.

# `set_mode`

Sets one or more modes. Dispatches to specific handlers.
Returns potentially updated Emulator state if side effects occurred.

# `set_mode`

Sets a mode with a value and options.

# `set_mode_with_private`

Sets a mode with a value and private flag.

# `set_private_mode`

Sets a private mode with a value.

# `set_standard_mode`

Sets a standard mode with a value.

# `update_auto_repeat_mode`

Updates the auto repeat mode.

# `update_auto_wrap_mode`

Updates the auto wrap mode.

# `update_bracketed_paste_mode`

Updates the bracketed paste mode.

# `update_column_width_132`

Updates the column width 132 mode.

# `update_cursor_visible`

Updates the cursor visible mode.

# `update_insert_mode`

Updates the insert mode.

# `update_interlacing_mode`

Updates the interlacing mode.

# `update_line_feed_mode`

Updates the line feed mode.

# `update_manager`

Updates the mode manager.

# `update_origin_mode`

Updates the origin mode.

# `update_screen_mode_reverse`

Updates the screen mode reverse.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
