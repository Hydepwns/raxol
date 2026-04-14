# `Raxol.Terminal.StateManager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/state_manager.ex#L1)

Manages terminal state transitions and state stack operations.
This module is responsible for maintaining and manipulating the terminal's state.

This module implements the StateManager behavior for consistent state management
patterns across the codebase while maintaining its specific terminal functionality.

# `clear_states`

```elixir
@spec clear_states(Raxol.Terminal.Emulator.t()) :: {:ok, Raxol.Terminal.Emulator.t()}
```

Clears all saved states.
Returns {:ok, updated_emulator}.

# `get_current_state`

```elixir
@spec get_current_state(Raxol.Terminal.Emulator.t()) :: map()
```

Gets the current terminal state.
Returns the current state map.

# `init`

# `init`

# `restore_state`

```elixir
@spec restore_state(Raxol.Terminal.Emulator.t()) :: {:ok, Raxol.Terminal.Emulator.t()}
```

Restores the most recently saved terminal state.
Returns {:ok, updated_emulator}.

# `save_state`

```elixir
@spec save_state(Raxol.Terminal.Emulator.t()) :: {:ok, Raxol.Terminal.Emulator.t()}
```

Saves the current terminal state.
Returns {:ok, updated_emulator}.

# `update_current_state`

```elixir
@spec update_current_state(Raxol.Terminal.Emulator.t(), map()) ::
  {:ok, Raxol.Terminal.Emulator.t()}
```

Updates the current terminal state.
Returns {:ok, updated_emulator}.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
