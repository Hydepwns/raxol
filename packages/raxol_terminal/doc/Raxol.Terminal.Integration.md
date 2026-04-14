# `Raxol.Terminal.Integration`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/integration/main.ex#L1)

Coordinates terminal integration components and provides a unified interface
for terminal operations.

This module manages the interaction between various terminal components:
- State management
- Input/output processing (via TerminalIO)
- Buffer management
- Rendering
- Configuration

# `clear`

Clears the terminal (delegates to buffer manager and renderer).

# `get_config`

Gets the current terminal configuration.

# `get_cursor_position`

Gets the current cursor position.

# `get_dimensions`

Gets the current terminal dimensions.

# `get_scroll_position`

Gets the current scroll position.

# `get_title`

Gets the current terminal title.

# `get_total_lines`

Gets the total number of lines in the buffer.

# `get_visible_content`

Gets the current visible content.

# `get_visible_lines`

Gets the number of visible lines.

# `handle_input`

Processes user input and updates the terminal state using TerminalIO.

# `init`

Initializes a new terminal integration state.

# `move_cursor`

Moves the cursor to a specific position.

# `reset_config`

Resets the terminal configuration to default values.

# `resize`

Resizes the terminal.

# `scroll`

Scrolls the terminal.

# `set_config_value`

Sets a specific configuration value.

# `set_cursor_visibility`

Shows or hides the cursor.

# `set_title`

Sets the terminal title.

# `update_config`

Updates the configuration.

# `write`

Writes text to the terminal using TerminalIO output processing.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
