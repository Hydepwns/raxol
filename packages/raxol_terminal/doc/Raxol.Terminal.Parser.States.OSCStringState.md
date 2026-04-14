# `Raxol.Terminal.Parser.States.OSCStringState`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/parser/states/osc_string_state.ex#L1)

Handles the OSC String state in the terminal parser.
This state is entered when an OSC sequence is initiated.

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

Processes input when the parser is in the :osc_string state.
Collects the OSC string until ST (ESC ) or BEL.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
