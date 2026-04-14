# `Raxol.Terminal.Parser.States.DCSPassthroughState`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/parser/states/dcs_passthrough_state.ex#L1)

Handles the :dcs_passthrough state of the terminal parser.

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

Processes input when the parser is in the :dcs_passthrough state.
Collects the DCS data string until ST (ESC ).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
