# `Raxol.Terminal.Emulator`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/emulator.ex#L1)

Enterprise-grade terminal emulator with VT100/ANSI support and high-performance parsing.

Provides full terminal emulation with true color, mouse tracking, alternate screen,
and modern features. Uses modular architecture with separate coordinators for
buffer, mode, input, and output operations.

## Usage

    # Create standard emulator
    emulator = Raxol.Terminal.Emulator.new(80, 24)

    # Process input with colors
    {emulator, output} = Raxol.Terminal.Emulator.process_input(
      emulator,
      "\e[1;31mRed Bold\e[0m Normal text"
    )

## Performance Modes

* `new/2` - Full features (2.8MB, ~95ms startup)
* `new_lite/3` - Most features (1.2MB, ~30ms startup)
* `new_minimal/2` - Basic only (8.8KB, <10ms startup)

# `t`

```elixir
@type t() :: %Raxol.Terminal.Emulator{
  active: any(),
  active_buffer: any(),
  active_buffer_type: atom(),
  alternate: any(),
  alternate_screen_buffer: any(),
  bracketed_paste_active: boolean(),
  bracketed_paste_buffer: String.t(),
  buffer: any(),
  capabilities_manager: any(),
  charset_state: map(),
  client_options: map(),
  clipboard_manager: any(),
  color_manager: any(),
  color_palette: map(),
  command: any(),
  command_history: list(),
  config: any(),
  current_command_buffer: String.t(),
  current_hyperlink: any(),
  cursor: any(),
  cursor_blink_rate: non_neg_integer(),
  cursor_manager: any(),
  cursor_position_reported: boolean(),
  cursor_style: atom(),
  damage_tracker: any(),
  device_status_manager: any(),
  device_status_reported: boolean(),
  event: any(),
  font_manager: any(),
  graphics_manager: any(),
  height: non_neg_integer(),
  history_buffer: term(),
  hyperlink_manager: any(),
  icon_name: String.t() | nil,
  input_manager: any(),
  last_col_exceeded: boolean(),
  last_key_event: any(),
  main_screen_buffer: any(),
  max_command_history: non_neg_integer(),
  memory_limit: non_neg_integer(),
  metrics_manager: any(),
  mode_manager: any(),
  mode_manager_pid: any(),
  mode_state: map(),
  mouse_manager: any(),
  notification_manager: any(),
  output_buffer: list(),
  output_manager: any(),
  parser_state: any(),
  plugin_manager: any(),
  registry: any(),
  renderer: any(),
  saved_cursor: any(),
  screen_buffer_manager: any(),
  scroll_manager: any(),
  scroll_region: tuple(),
  scrollback_buffer: list(),
  scrollback_limit: non_neg_integer(),
  scrollback_manager: any(),
  selection_manager: any(),
  session_id: String.t(),
  session_manager: any(),
  sixel_state: any(),
  state: any(),
  state_manager: any(),
  state_stack: list(),
  style: any(),
  style_manager: any(),
  supervisor: any(),
  sync_manager: any(),
  tab_manager: any(),
  tab_stops: list(),
  terminal_state_manager: any(),
  theme_manager: any(),
  validation_service: any(),
  width: non_neg_integer(),
  window_manager: any(),
  window_registry: any(),
  window_state: map(),
  window_title: String.t() | nil
}
```

# `apply_color_changes`

Applies color changes (legacy compatibility).

# `blinking?`

Returns cursor blinking state.

# `cleanup`

```elixir
@spec cleanup(t()) :: :ok
```

Cleans up emulator resources.

# `clear_line`

Clears the specified line.

# `clear_screen`

Clears the entire screen.

# `clear_screen_and_home`

Clears the screen and moves cursor to home position.

# `clear_scrollback`

Clears the scrollback buffer.

# `clear_selection`

Clears the current text selection.

# `cursor_blinking?`

Returns true if the cursor is blinking.

# `cursor_visible?`

Returns true if the cursor is visible.

# `delete_char`

Deletes the character at the cursor position.

# `delete_chars`

Deletes the specified number of characters.

# `end_selection`

Ends the current text selection.

# `erase_chars`

Erases the specified number of characters.

# `erase_display`

Erases display content based on mode (0=to end, 1=from start, 2=entire).

# `erase_from_cursor_to_end`

Erases from cursor position to end of screen.

# `erase_from_start_to_cursor`

Erases from start of screen to cursor position.

# `erase_in_display`

Erases content within the display.

# `erase_in_line`

Erases content within the current line.

# `erase_line`

Erases line content based on mode.

# `get_config_struct`

Gets the configuration structure.

# `get_cursor_position`

Gets the current cursor position as {x, y}.

# `get_cursor_position_struct`

Gets cursor position as a structured object.

# `get_cursor_style`

Gets the current cursor style (:block, :line, :underscore).

# `get_cursor_visible`

Gets cursor visibility state.

# `get_height`

Gets the terminal height in rows.

# `get_mode_manager`

Gets the mode manager.

# `get_mode_manager_cursor_visible`

Gets cursor visibility from mode manager.

# `get_output`

```elixir
@spec get_output(t()) :: String.t()
```

Gets output from the emulator.

# `get_output_buffer`

Gets output buffer (legacy compatibility).

# `get_screen_buffer`

Gets the active screen buffer.

# `get_scroll_region`

Gets the current scroll region as {top, bottom}.

# `get_scrollback`

Gets the scrollback buffer contents.

# `get_selection`

Gets the currently selected text.

# `get_width`

Gets the terminal width in columns.

# `handle_esc_equals`

Handles ESC = sequence (DECKPAM - Enable application keypad mode).

# `handle_esc_greater`

Handles ESC > sequence (DECKPNM - Disable application keypad mode).

# `has_selection?`

Returns true if text is currently selected.

# `insert_char`

Inserts a character at the cursor position.

# `insert_chars`

Inserts the specified number of blank characters.

# `maybe_scroll`

Performs automatic scrolling if needed.

# `move_cursor`

Moves the cursor to the specified position.

# `move_cursor_back`

Moves cursor back (stub implementation).

# `move_cursor_down`

Moves cursor down (stub implementation).

# `move_cursor_forward`

Moves cursor forward (stub implementation).

# `move_cursor_to`

Moves cursor to specified position.

# `move_cursor_to`

Moves cursor to specified position with options.

# `move_cursor_up`

Moves cursor up (stub implementation).

# `new_lite`

> This function is deprecated. Use new/3 with use_genservers: false option instead.

# `new_minimal`

> This function is deprecated. Use new/3 with enable_history: false, alternate_buffer: false options instead.

# `process_input`

Processes input and returns updated emulator with output.

# `render_screen`

```elixir
@spec render_screen(t()) :: String.t()
```

Renders the emulator screen.

# `reset`

Resets the terminal emulator to its initial state.

# `reset_mode`

Resets a terminal mode.

# `resize`

Resizes the terminal to the specified dimensions.

# `restore_state`

Restores the previously saved terminal state.

# `save_state`

Saves the current terminal state.

# `scroll_down`

Scrolls the display down by the specified number of lines.

# `scroll_up`

Scrolls the display up by the specified number of lines.

# `set_attribute`

Sets a terminal attribute.

# `set_cursor_blink`

Sets cursor blinking state.

# `set_cursor_position`

Sets the cursor position to the specified coordinates.

# `set_cursor_style`

Sets the cursor style to :block, :line, or :underscore.

# `set_cursor_visibility`

Sets cursor visibility.

# `set_dimensions`

Sets terminal dimensions after validation.

# `set_mode`

Sets a terminal mode.

# `start_link`

Starts a linked terminal emulator process.

# `start_selection`

Starts text selection at the specified coordinates.

# `switch_to_alternate_screen`

Switches to the alternate screen buffer.

# `switch_to_normal_screen`

Switches to the normal screen buffer.

# `update_active_buffer`

Updates the active buffer with new content.

# `update_auto_wrap_mode`

Updates auto wrap mode state.

# `update_blink_state`

Updates blink state (legacy compatibility).

# `update_insert_mode`

Updates insert mode state.

# `update_selection`

Updates the selection endpoint to the specified coordinates.

# `validate_dimensions`

Validates terminal dimensions.

# `visible?`

Returns cursor visibility state.

# `write_text`

Writes text to the terminal at the cursor position.

# `write_to_output`

Writes data to the output buffer.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
