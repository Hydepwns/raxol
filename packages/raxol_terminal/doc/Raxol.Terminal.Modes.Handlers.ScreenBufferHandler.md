# `Raxol.Terminal.Modes.Handlers.ScreenBufferHandler`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/modes/handlers/screen_buffer_handler.ex#L1)

Handles screen buffer mode operations and their side effects.
Manages alternate screen buffer switching and related functionality.

# `handle_mode_change`

```elixir
@spec handle_mode_change(
  atom(),
  Raxol.Terminal.Modes.Types.ModeTypes.mode_value(),
  Raxol.Terminal.Emulator.t()
) :: {:ok, Raxol.Terminal.Emulator.t()} | {:error, term()}
```

Handles a screen buffer mode change and applies its effects to the emulator.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
