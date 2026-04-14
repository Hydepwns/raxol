# `Raxol.Terminal.Integration.Renderer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/integration/integration_renderer.ex#L1)

Handles terminal output rendering and display management using Termbox2.

# `clear_screen`

Clears the terminal screen (specifically, the back buffer).
Call present/0 afterwards to make it visible.
Returns :ok or {:error, reason}.

# `get_dimensions`

Gets the current terminal dimensions.
Returns {:ok, {width, height}} or {:error, :dimensions_unavailable}.
Note: termbox2 width/height C functions return int, not status codes.
A negative value might indicate an error (e.g., not initialized).

# `get_title`

Gets the terminal title.

# `init_terminal`

Initializes the underlying terminal system.
Must be called before other rendering functions.
Returns :ok or {:error, reason}.

# `move_cursor`

Moves the hardware cursor to a specific position on the screen.
Call present/0 afterwards if you want to ensure it's shown with other changes.
The cursor position is typically updated with present/0.
Returns :ok or {:error, reason}.

# `new`

Creates a new renderer with the given options.

# `render`

Renders the current terminal state to the screen.
Returns :ok or {:error, reason}.

# `reset_config`

Resets the renderer configuration to defaults.

# `resize`

Resizes the renderer to the given dimensions.

# `set_config_value`

Sets a specific configuration value.

# `set_cursor_visibility`

Sets the cursor visibility.

# `set_title`

Sets the terminal title.

# `shutdown_terminal`

Shuts down the underlying terminal system.
Must be called to restore terminal state.
Returns :ok or {:error, reason}.

# `update_config`

Updates the renderer configuration.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
