# `Raxol.Terminal.Cursor.CursorState`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/cursor/cursor_state.ex#L1)

Handles cursor state management operations for the terminal cursor.
Extracted from Raxol.Terminal.Cursor.Manager to reduce file size.

# `add_to_history`

Adds the current cursor state to history.

# `get_margins`

Gets the cursor margins.

# `get_state`

Gets the cursor state atom (:visible, :hidden, :blinking).

# `reset`

Resets the cursor state to default values.

# `restore_from_history`

Restores cursor state from history.

# `restore_position`

Restores the saved cursor position.

# `restore_state`

Restores the saved cursor state.

# `save_position`

Saves the current cursor position.

# `save_state`

Saves the current cursor state.

# `set_custom_shape`

Sets a custom cursor shape.

# `set_margins`

Sets the cursor margins.

# `set_state`

Sets the cursor state based on a state atom.
Supported states: :visible, :hidden, :blinking

# `update_blink`

Updates the cursor blink state.

# `update_position_from_text`

Updates cursor position based on text input.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
