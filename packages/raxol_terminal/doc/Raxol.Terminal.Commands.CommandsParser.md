# `Raxol.Terminal.Commands.CommandsParser`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/commands/commands_parser.ex#L1)

Handles parsing of command parameters in terminal sequences.

This module is part of the terminal command execution system. It provides
utilities for parsing and extracting parameters from CSI, OSC, and DCS
sequence parameter strings.

# `get_param`

```elixir
@spec get_param([integer() | nil], non_neg_integer(), integer()) :: integer()
```

Gets a parameter at a specific index from the params list.

If the parameter is not available, returns the provided default value.

## Examples

    iex> Parser.get_param([5, 10, 15], 2)
    10

    iex> Parser.get_param([5, 10], 3)
    1

    iex> Parser.get_param([5, 10], 3, 0)
    0

# `parse`

```elixir
@spec parse(String.t()) :: {:ok, map()} | {:error, String.t()}
```

Parses a command string into a structured command.

Returns {:ok, parsed_command} or {:error, reason}.

## Examples

    iex> Parser.parse("\e[5;10H")
    {:ok, %{type: :csi, params: [5, 10], final_byte: ?H}}

    iex> Parser.parse("\e]0;title\a")
    {:ok, %{type: :osc, command: 0, params: ["title"]}}

# `parse_int`

```elixir
@spec parse_int(String.t()) :: integer() | nil
```

Safely parses a string into an integer.

Returns the parsed integer, or nil on failure.

## Examples

    iex> Parser.parse_int("123")
    123

    iex> Parser.parse_int("abc")
    nil

# `parse_params`

```elixir
@spec parse_params(String.t()) :: [integer() | nil | [integer() | nil]]
```

Parses a raw parameter string buffer into a list of integers or nil values.

Handles empty or malformed parameters by converting them to nil.
Handles parameters with sub-parameters (separated by ":")

## Examples

    iex> Parser.parse_params("5;10;15")
    [5, 10, 15]

    iex> Parser.parse_params("5;10;;15")
    [5, 10, nil, 15]

    iex> Parser.parse_params("5:1;10:2;15:3")
    [[5, 1], [10, 2], [15, 3]]

---

*Consult [api-reference.md](api-reference.md) for complete listing*
