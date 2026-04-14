# `Raxol.Terminal.Modes.Handlers.StandardHandler`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/modes/handlers/standard_handler.ex#L1)

Handles standard mode operations and their side effects.
Manages standard terminal modes like insert mode and line feed mode.

# `handle_mode`

```elixir
@spec handle_mode(
  Raxol.Terminal.Emulator.t(),
  atom(),
  Raxol.Terminal.Modes.Types.ModeTypes.mode_value()
) :: {:ok, Raxol.Terminal.Emulator.t()} | {:error, term()}
```

Handles a standard mode change (alias for handle_mode_change/3 for compatibility).

# `handle_mode_change`

```elixir
@spec handle_mode_change(
  atom(),
  Raxol.Terminal.Modes.Types.ModeTypes.mode_value(),
  Raxol.Terminal.Emulator.t()
) :: {:ok, Raxol.Terminal.Emulator.t()} | {:error, term()}
```

Handles a standard mode change and applies its effects to the emulator.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
