# `Raxol.Terminal.EscapeSequence`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/escape_sequence.ex#L1)

Handles parsing of ANSI escape sequences and other control sequences.

This module provides functions for parsing ANSI escape sequences
into structured data representing terminal commands.

# `parse`

```elixir
@spec parse(String.t()) ::
  {:ok, term(), String.t()}
  | {:incomplete, String.t()}
  | {:error, atom(), String.t()}
```

Parses an input string, potentially containing an escape sequence.

Returns:
  * `{:ok, command_data, remaining_input}` if a complete sequence is parsed.
  * `{:incomplete, remaining_input}` if the input is potentially part of a sequence but incomplete.
  * `{:error, :invalid_sequence, remaining_input}` if the sequence is malformed.
  * `{:error, :not_escape_sequence, input}` if the input doesn't start with ESC.

`command_data` is a tuple representing the parsed command, e.g.:
  * `{:cursor_position, {row, col}}`
  * `{:cursor_move, :up, count}`
  * `{:set_mode, :dec_private, mode_code, boolean_value}`
  * `{:set_mode, :standard, mode_code, boolean_value}`
  * `{:designate_charset, target_g_set, charset_atom}`
  * `{:invoke_charset, target_g_set}`
  * etc.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
