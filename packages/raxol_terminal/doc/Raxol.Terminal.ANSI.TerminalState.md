# `Raxol.Terminal.ANSI.TerminalState`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/terminal_state.ex#L1)

Manages terminal state operations for ANSI escape sequences.

# `state_stack`

```elixir
@type state_stack() :: [map()]
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.ANSI.TerminalState{
  current_state: map(),
  max_saved_states: integer(),
  saved_states: [map()],
  state_stack: state_stack()
}
```

# `apply_restored_data`

Applies restored data to the emulator state.

# `clear`

Clears all saved states.

# `clear_state`

Clears the terminal state stack.

# `count`

Gets the count of states in the state stack.

# `current`

Gets the current state from the state stack.

# `empty?`

Checks if the state stack is empty.

# `get_current_state`

Gets the current state.

# `get_saved_states_count`

Gets the number of saved states.

# `get_state_stack`

Gets the current state stack.

# `has_saved_states?`

Checks if there are any saved states.

# `new`

Creates a new terminal state with default settings.

# `pop`

Pops a state from the state stack.

# `push`

Pushes the current state onto the state stack.

# `restore`

Restores the most recently saved state.

# `restore_state`

Restores the most recently saved terminal state from the state stack.
Returns the restored state and the updated stack.

# `save`

Saves the current state.

# `save_state`

Saves the current terminal state to the state stack.

# `update_current_state`

Updates the current state.

# `update_state_stack`

Updates the state stack.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
