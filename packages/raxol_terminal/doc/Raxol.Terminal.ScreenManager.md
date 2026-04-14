# `Raxol.Terminal.ScreenManager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/screen/screen_manager.ex#L1)

Manages screen buffer operations for the terminal emulator.
This module handles operations related to the main and alternate screen buffers,
including buffer switching, initialization, and state management.

# `clear_selection`

Clears the current selection.

# `get_buffer_type`

Gets the current buffer type (main or alternate).

# `get_screen_buffer`

Gets the currently active screen buffer.

# `get_scroll_bottom`

Gets the scroll bottom from the active buffer.

# `get_scroll_region`

Gets the scroll region from the active buffer.

# `get_scroll_top`

Gets the scroll top from the active buffer.

# `get_selected_text`

Gets the selected text from the buffer.

# `get_selection`

Gets the current selection from the buffer.

# `get_selection_boundaries`

Gets the selection boundaries as {start, end} tuple.

# `get_selection_end`

Gets the selection end coordinates.

# `get_selection_start`

Gets the selection start coordinates.

# `get_state`

Gets the current state of the buffer.

# `get_style`

Gets the current style of the buffer.

# `get_style_at`

Gets the style at a specific position.

# `get_style_at_cursor`

Gets the style at the cursor position.

# `in_selection?`

Checks if a position is within the current selection.

# `initialize_buffers`

Initializes both main and alternate screen buffers with default scrollback limit.

# `initialize_buffers`

Initializes both main and alternate screen buffers.

# `parse_scrollback_limit`

Parses scrollback limit from options, defaulting to 1000.

# `resize_buffers`

Resizes both screen buffers.

# `selection_active?`

Checks if a selection is currently active.

# `set_buffer_type`

Sets the buffer type.

# `set_scroll_region`

Sets the scroll region on the buffer.

# `start_selection`

Starts a selection at the specified position.

# `switch_buffer`

Switches between main and alternate screen buffers.

# `update_active_buffer`

Updates the currently active screen buffer.

# `update_selection`

Updates the selection end position.

# `write_string`

Writes a string to the buffer at the given position with the given style.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
