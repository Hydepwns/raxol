# `Raxol.Terminal.Parser.States.CSIParamState`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/parser/states/csi_param_state.ex#L1)

Handles the :csi_param state of the terminal parser.

# `handle`

```elixir
@spec handle(
  Raxol.Terminal.Emulator.t(),
  Raxol.Terminal.Parser.ParserState.t(),
  binary()
) ::
  {:continue, Raxol.Terminal.Emulator.t(),
   Raxol.Terminal.Parser.ParserState.t(), binary()}
  | {:finished, Raxol.Terminal.Emulator.t(),
     Raxol.Terminal.Parser.ParserState.t()}
  | {:incomplete, Raxol.Terminal.Emulator.t(),
     Raxol.Terminal.Parser.ParserState.t()}
```

Processes input when the parser is in the :csi_param state.
Collects parameter digits (0-9) and semicolons (;).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
