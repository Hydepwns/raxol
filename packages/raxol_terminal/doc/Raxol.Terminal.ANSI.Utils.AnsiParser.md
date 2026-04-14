# `Raxol.Terminal.ANSI.Utils.AnsiParser`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/utils.ex#L159)

Provides comprehensive parsing for ANSI escape sequences.
Determines the type of sequence and extracts its parameters.

# `sequence`

```elixir
@type sequence() :: %{
  type: sequence_type(),
  command: String.t(),
  params: [String.t()],
  intermediate: String.t(),
  final: String.t(),
  text: String.t()
}
```

# `sequence_type`

```elixir
@type sequence_type() :: :csi | :osc | :sos | :pm | :apc | :esc | :text
```

# `contains_ansi?`

```elixir
@spec contains_ansi?(String.t()) :: boolean()
```

Determines if a string contains ANSI escape sequences.

# `parse`

```elixir
@spec parse(String.t()) :: [sequence()]
```

Parses a string containing ANSI escape sequences.
Returns a list of parsed sequences.

# `parse`

```elixir
@spec parse(map(), String.t()) :: [sequence()]
```

Parses a string containing ANSI escape sequences with a custom state machine.
Returns a list of parsed sequences.

# `parse_sequence`

```elixir
@spec parse_sequence(String.t()) :: sequence() | nil
```

Parses a single ANSI escape sequence.
Returns a map containing the sequence type and parameters.

# `strip_ansi`

```elixir
@spec strip_ansi(String.t()) :: String.t()
```

Strips all ANSI escape sequences from a string.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
