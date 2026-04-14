# `Raxol.Terminal.Parser.States.DCSEntryState`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/parser/states/dcs_entry_state.ex#L1)

Handles the :dcs_entry state of the terminal parser.

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

Processes input when the parser is in the :dcs_entry state.
Similar to CSI Entry - collects params/intermediates/final byte.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
