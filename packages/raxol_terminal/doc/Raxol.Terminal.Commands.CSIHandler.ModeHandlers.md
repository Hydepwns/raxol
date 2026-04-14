# `Raxol.Terminal.Commands.CSIHandler.ModeHandlers`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/commands/csi_handler/mode_handlers.ex#L1)

Handles CSI mode commands (Set Mode/Reset Mode).

# `handle_h_or_l`

```elixir
@spec handle_h_or_l(Raxol.Terminal.Emulator.t(), list(), String.t(), integer()) ::
  {:ok, Raxol.Terminal.Emulator.t()}
```

Handles Set Mode (SM - 'h') and Reset Mode (RM - 'l') commands.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
