# `Raxol.Terminal.Parser.States.CSIIntermediateState`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/parser/states/csi_intermediate_state.ex#L1)

Handles the :csi_intermediate state of the terminal parser.

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

Processes input when the parser is in the :csi_intermediate state.
Collects intermediate bytes (0x20-0x2F).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
