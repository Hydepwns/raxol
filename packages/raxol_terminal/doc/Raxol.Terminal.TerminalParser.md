# `Raxol.Terminal.TerminalParser`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/terminal_parser.ex#L1)

Parses raw byte streams into terminal events and commands.
Handles escape sequences (CSI, OSC, DCS, etc.) and plain text.

# `parse`

Parses input using the default ground state.

# `parse_chunk`

```elixir
@spec parse_chunk(
  map(),
  Raxol.Terminal.Parser.ParserState.t() | nil,
  String.t()
) :: {map(), Raxol.Terminal.Parser.ParserState.t(), String.t()}
```

Parses a chunk of input data, updating the parser state and emulator.

Takes the current emulator state and input binary, returns the updated emulator state
after processing the input chunk.

Takes the emulator state, the *current* parser state, and the input binary.
Returns `{final_emulator_state, final_parser_state}`.

# `transition_to_escape`

Transitions parser to escape state.

# `transition_to_ground`

Transitions parser to ground state.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
