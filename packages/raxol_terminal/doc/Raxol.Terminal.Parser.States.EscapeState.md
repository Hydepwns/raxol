# `Raxol.Terminal.Parser.States.EscapeState`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/parser/states/escape_state.ex#L1)

Handles the :escape state of the terminal parser.

# `handle`

```elixir
@spec handle(
  Raxol.Terminal.Emulator.t(),
  Raxol.Terminal.Parser.ParserState.t(),
  binary()
) ::
  {:continue, Raxol.Terminal.Emulator.t(),
   Raxol.Terminal.Parser.ParserState.t(), binary()}
  | {:incomplete, Raxol.Terminal.Emulator.t(),
     Raxol.Terminal.Parser.ParserState.t()}
```

Processes input when the parser is in the :escape state.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
