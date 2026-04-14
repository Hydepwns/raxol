# `Raxol.Terminal.Parser.ParserState`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/parser/parser_state.ex#L1)

Parser state for the terminal emulator.

# `t`

```elixir
@type t() :: %Raxol.Terminal.Parser.ParserState{
  designating_gset: term() | nil,
  final_byte: byte() | nil,
  intermediates_buffer: binary(),
  params: list(),
  params_buffer: binary(),
  payload_buffer: binary(),
  single_shift: term() | nil,
  state: atom()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
