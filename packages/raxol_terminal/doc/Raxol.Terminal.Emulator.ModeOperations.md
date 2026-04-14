# `Raxol.Terminal.Emulator.ModeOperations`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/emulator/mode_operations.ex#L1)

Mode operation functions extracted from the main emulator module.
Handles terminal mode setting and resetting operations.

# `emulator`

```elixir
@type emulator() :: Raxol.Terminal.Emulator.t()
```

# `reset_mode`

```elixir
@spec reset_mode(emulator(), atom()) :: {:ok, emulator()} | {:error, term()}
```

Resets a terminal mode using the mode manager.

# `set_mode`

```elixir
@spec set_mode(emulator(), atom()) :: {:ok, emulator()} | {:error, term()}
```

Sets a terminal mode using the mode manager.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
