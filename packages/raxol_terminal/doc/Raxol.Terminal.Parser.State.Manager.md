# `Raxol.Terminal.Parser.State.Manager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/parser/state/parser_state_manager.ex#L1)

Manages the state of the terminal parser, including escape sequences,
control sequences, and parser modes.

# `intermediate`

```elixir
@type intermediate() :: [non_neg_integer()]
```

# `params`

```elixir
@type params() :: [non_neg_integer()]
```

# `parser_state`

```elixir
@type parser_state() ::
  :ground
  | :escape
  | :csi_entry
  | :csi_param
  | :csi_intermediate
  | :csi_ignore
  | :osc_string
  | :dcs_entry
  | :dcs_param
  | :dcs_intermediate
  | :dcs_passthrough
  | :apc_string
  | :pm_string
  | :sos_string
  | :string
```

# `string_flags`

```elixir
@type string_flags() :: %{required(String.t()) =&gt; boolean()}
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.Parser.State.Manager{
  apc_buffer: String.t(),
  dcs_buffer: String.t(),
  designating_gset: term(),
  final_byte: term(),
  ignore: boolean(),
  intermediate: intermediate(),
  intermediates_buffer: term(),
  osc_buffer: String.t(),
  params: params(),
  params_buffer: term(),
  payload_buffer: term(),
  pm_buffer: String.t(),
  single_shift: term(),
  sos_buffer: String.t(),
  state: parser_state(),
  string_buffer: String.t(),
  string_flags: string_flags(),
  string_parser_state: parser_state() | nil,
  string_terminator: non_neg_integer() | nil
}
```

# `append_intermediate`

# `append_param`

# `append_payload`

# `clear_string_buffers`

Clears all string buffers.

# `get_apc_buffer`

Gets the APC buffer content.

# `get_current_state`

# `get_dcs_buffer`

Gets the DCS buffer content.

# `get_intermediate`

Gets the current intermediate characters.

# `get_osc_buffer`

Gets the OSC buffer content.

# `get_params`

Gets the current parameters.

# `get_pm_buffer`

Gets the PM buffer content.

# `get_sos_buffer`

Gets the SOS buffer content.

# `get_state`

Gets the current parser state.

# `get_string_buffer`

Gets the string buffer content.

# `get_string_flags`

Gets the string flags.

# `get_string_parser_state`

Gets the string parser state.

# `get_string_terminator`

Gets the string terminator.

# `ignore?`

Checks if the parser is in ignore mode.

# `new`

Creates a new parser state manager instance.

# `process_char`

Processes a single character and updates the parser state accordingly.

# `process_input`

# `reset`

Resets the parser state manager to its initial state.

# `set_apc_buffer`

Sets the APC buffer content.

# `set_dcs_buffer`

Sets the DCS buffer content.

# `set_designating_gset`

# `set_final_byte`

# `set_ignore`

Sets the ignore mode.

# `set_intermediate`

Sets the intermediate characters.

# `set_osc_buffer`

Sets the OSC buffer content.

# `set_params`

Sets the parameters.

# `set_pm_buffer`

Sets the PM buffer content.

# `set_sos_buffer`

Sets the SOS buffer content.

# `set_state`

Sets the parser state.

# `set_string_buffer`

Sets the string buffer content.

# `set_string_flags`

Sets the string flags.

# `set_string_parser_state`

Sets the string parser state.

# `set_string_terminator`

Sets the string terminator.

# `transition_to`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
