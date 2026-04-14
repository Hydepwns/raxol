# `Raxol.Terminal.ParserState`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/parser_state.ex#L1)

Alias module for parser state functionality.
This module delegates to the actual implementation in Parser.ParserState.

# `t`

```elixir
@type t() :: Raxol.Terminal.Parser.ParserState.t()
```

# `new`

```elixir
@spec new() :: t()
```

Creates a new parser state.

# `process_char`

```elixir
@spec process_char(t(), byte()) :: {t(), list()}
```

Processes a character through the parser state.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
