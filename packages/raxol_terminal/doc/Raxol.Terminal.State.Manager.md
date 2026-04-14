# `Raxol.Terminal.State.Manager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/state/manager.ex#L1)

State manager for terminal emulator state.
Provides functions for managing modes, attributes, and state stack.

This is a compatibility wrapper that delegates to the actual StateManager
implementation while maintaining the expected API for tests.

# `clear_state_stack`

Clears the state stack.

# `get_attribute`

Gets an attribute value from the emulator state.

# `get_mode`

Gets a mode value from the emulator state.

# `get_state_stack`

Gets the state stack.

# `new`

Creates a new state manager instance.

# `pop_state`

Pops state from the state stack.

# `push_state`

Pushes current state onto the state stack.

# `reset_state`

Resets state to initial values.

# `set_attribute`

Sets an attribute value in the emulator state.

# `set_mode`

Sets a mode value in the emulator state.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
