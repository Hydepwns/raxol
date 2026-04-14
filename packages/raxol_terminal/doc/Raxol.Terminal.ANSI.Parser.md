# `Raxol.Terminal.ANSI.Parser`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/parser.ex#L1)

ANSI escape sequence parser for terminal emulation.

This module provides high-performance parsing of ANSI escape sequences,
supporting CSI, OSC, DCS, and other control sequences.

# `parsed_token`

```elixir
@type parsed_token() ::
  {:text, binary()}
  | {:csi, binary(), binary()}
  | {:osc, binary()}
  | {:dcs, binary()}
  | {:escape, binary()}
```

# `parse`

```elixir
@spec parse(binary()) :: [parsed_token()]
```

Parses ANSI escape sequences from input.

Returns a list of parsed tokens.

# `strip_ansi`

```elixir
@spec strip_ansi(binary()) :: binary()
```

Strips ANSI escape sequences from input.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
