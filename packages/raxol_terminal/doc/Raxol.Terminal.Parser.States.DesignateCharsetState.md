# `Raxol.Terminal.Parser.States.DesignateCharsetState`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/parser/states/designate_charset_state.ex#L1)

Handles the :designate_charset state of the terminal parser.

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

Processes input when the parser is in the :designate_charset state.
Expects a single character designating the character set.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
