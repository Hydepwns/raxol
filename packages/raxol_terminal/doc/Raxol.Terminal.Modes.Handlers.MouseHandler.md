# `Raxol.Terminal.Modes.Handlers.MouseHandler`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/modes/handlers/mouse_handler.ex#L1)

Handles mouse mode operations and their side effects.
Manages different mouse reporting modes and their effects on the terminal.

# `handle_mode_change`

```elixir
@spec handle_mode_change(
  atom(),
  Raxol.Terminal.Modes.Types.ModeTypes.mode_value(),
  Raxol.Terminal.Emulator.t()
) :: {:ok, Raxol.Terminal.Emulator.t()} | {:error, term()}
```

Handles a mouse mode change and applies its effects to the emulator.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
