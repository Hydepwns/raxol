# `Raxol.Terminal.ANSI.Behaviours.TerminalState`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/behaviours.ex#L31)

Behaviour for managing terminal state saving and restoring.

# `state_data_map`

```elixir
@type state_data_map() :: map()
```

# `apply_restored_data`

```elixir
@callback apply_restored_data(
  emulator_state :: Raxol.Terminal.Emulator.t(),
  state_data :: state_data_map() | nil,
  fields_to_restore :: [atom()]
) :: Raxol.Terminal.Emulator.t()
```

# `restore_state`

```elixir
@callback restore_state(stack :: Raxol.Terminal.ANSI.TerminalState.state_stack()) ::
  {new_stack :: Raxol.Terminal.ANSI.TerminalState.state_stack(),
   state_data :: state_data_map() | nil}
```

# `save_state`

```elixir
@callback save_state(
  stack :: Raxol.Terminal.ANSI.TerminalState.state_stack(),
  current_emulator_state :: map()
) :: Raxol.Terminal.ANSI.TerminalState.state_stack()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
