# `Raxol.Terminal.Parser.States.OSCStringMaybeSTState`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/parser/states/osc_string_maybe_st_state.ex#L1)

Handles the :osc_string_maybe_st state of the terminal parser.

# `handle`

```elixir
@spec handle(
  Raxol.Terminal.Emulator.t(),
  Raxol.Terminal.Parser.ParserState.t(),
  binary()
) ::
  {:continue, Raxol.Terminal.Emulator.t(),
   Raxol.Terminal.Parser.ParserState.t(), binary()}
  | {:handled, Raxol.Terminal.Emulator.t()}
```

Processes input when the parser is in the :osc_string_maybe_st state.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
