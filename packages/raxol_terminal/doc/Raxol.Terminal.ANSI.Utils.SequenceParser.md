# `Raxol.Terminal.ANSI.Utils.SequenceParser`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/utils.ex#L96)

Helper module for parsing ANSI escape sequences.

This module provides common utilities for parsing and handling ANSI sequences,
extracted from duplicate implementations in other ANSI-related modules.

# `parse_params`

```elixir
@spec parse_params(binary()) :: {:ok, [integer()]} | :error
```

Parses parameters from an ANSI sequence.

Splits the parameter string by semicolons and converts them to integers.

## Returns

* `{:ok, params}` - Successfully parsed parameters
* `:error` - Failed to parse parameters

# `parse_sequence`

```elixir
@spec parse_sequence(binary(), function()) :: {:ok, atom(), [integer()]} | :error
```

Generic parser for ANSI sequences that follow the pattern: params + operation code.

## Parameters

* `sequence` - The binary sequence to parse
* `operation_decoder` - Function to decode operation from character code

## Returns

* `{:ok, operation, params}` - Successfully parsed sequence
* `:error` - Failed to parse sequence

---

*Consult [api-reference.md](api-reference.md) for complete listing*
