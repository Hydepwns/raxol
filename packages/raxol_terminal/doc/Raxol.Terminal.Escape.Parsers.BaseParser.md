# `Raxol.Terminal.Escape.Parsers.BaseParser`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/escape/parsers/base_parser.ex#L1)

Base parser utilities for escape sequence parsers.

Provides common functionality for logging and handling unknown sequences.

# `extract_final_byte`

```elixir
@spec extract_final_byte(String.t()) :: {String.t(), String.t()} | nil
```

Extracts the final byte from a CSI sequence.

The final byte determines the command type in CSI sequences.

## Parameters
  - input: The input string

## Returns
  {final_byte, params_string} or nil if no final byte found

# `final?`

```elixir
@spec final?(integer()) :: boolean()
```

Checks if a character is a valid CSI final character.

Final characters are in the range 0x40-0x7E (@ through ~)

## Parameters
  - char: Character code to check

## Returns
  Boolean indicating if it's a final character

# `intermediate?`

```elixir
@spec intermediate?(integer()) :: boolean()
```

Checks if a character is a valid CSI intermediate character.

Intermediate characters are in the range 0x20-0x2F (space through /)

## Parameters
  - char: Character code to check

## Returns
  Boolean indicating if it's an intermediate character

# `log_unknown_sequence`

```elixir
@spec log_unknown_sequence(String.t(), String.t()) :: :ok
```

Logs an unknown escape sequence for debugging purposes.

## Parameters
  - prefix: The escape sequence prefix (e.g., "ESC", "CSI")
  - sequence: The unknown sequence

## Returns
  :ok

# `parameter?`

```elixir
@spec parameter?(integer()) :: boolean()
```

Checks if a character is a valid CSI parameter character.

Parameter characters are in the range 0x30-0x3F (0 through ?)

## Parameters
  - char: Character code to check

## Returns
  Boolean indicating if it's a parameter character

# `parse_int`

```elixir
@spec parse_int(String.t()) :: integer() | nil
```

Parses a numeric parameter from a string.

## Parameters
  - str: String containing the number

## Returns
  The parsed integer or nil if parsing fails

# `parse_params`

```elixir
@spec parse_params(String.t()) :: [integer()]
```

Splits parameters by semicolon and parses them as integers.

## Parameters
  - params: String containing semicolon-separated parameters

## Returns
  List of parsed integers (nils are filtered out)

---

*Consult [api-reference.md](api-reference.md) for complete listing*
