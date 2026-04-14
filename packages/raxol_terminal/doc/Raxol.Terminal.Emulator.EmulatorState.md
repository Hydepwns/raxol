# `Raxol.Terminal.Emulator.EmulatorState`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/emulator/emulator_state.ex#L1)

Handles state management for the terminal emulator.
Provides functions for managing terminal state, modes, and character sets.

# `get_charset_state`

Gets the current character set state.
Returns the current charset state.

# `get_current_state`

Gets the current state from the state stack.
Returns the current state or nil if stack is empty.

# `get_hyperlink_url`

Gets the current hyperlink URL.
Returns the current hyperlink URL or nil.

# `get_memory_limit`

Gets the current memory limit.
Returns the memory limit.

# `get_mode`

Gets the value of a terminal mode.
Returns the mode value or nil if not set.

# `get_tab_stops`

Gets the current tab stops.
Returns the current tab stops.

# `pop_state`

Pops a state from the state stack.
Returns {:ok, updated_emulator} or {:error, reason}.

# `push_state`

Pushes a new state onto the state stack.
Returns {:ok, updated_emulator} or {:error, reason}.

# `set_charset_state`

Sets the character set state.
Returns {:ok, updated_emulator} or {:error, reason}.

# `set_hyperlink_url`

Sets the current hyperlink URL.
Returns {:ok, updated_emulator}.

# `set_memory_limit`

Sets the memory limit for the terminal.
Returns {:ok, updated_emulator} or {:error, reason}.

# `set_mode`

Sets a terminal mode.
Returns {:ok, updated_emulator} or {:error, reason}.

# `set_tab_stops`

Sets the tab stops for the terminal.
Returns {:ok, updated_emulator}.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
