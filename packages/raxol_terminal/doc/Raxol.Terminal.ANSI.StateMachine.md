# `Raxol.Terminal.ANSI.StateMachine`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/state_machine.ex#L1)

A state machine for parsing ANSI escape sequences.
This module provides a more efficient alternative to regex-based parsing.

# `parser_state`

```elixir
@type parser_state() :: %{
  state: state(),
  params_buffer: String.t(),
  intermediates_buffer: String.t(),
  payload_buffer: String.t(),
  final_byte: String.t() | nil,
  designating_gset: atom() | nil
}
```

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

# `state`

```elixir
@type state() ::
  :ground
  | :escape
  | :csi_entry
  | :csi_param
  | :csi_intermediate
  | :csi_final
  | :osc_string
  | :osc_string_maybe_st
  | :dcs_entry
  | :dcs_passthrough
  | :dcs_passthrough_maybe_st
  | :designate_charset
  | :ignore
```

# `cancel_byte?`
*macro* 

# `csi_final_byte?`
*macro* 

# `intermediate_byte?`
*macro* 

# `new`

```elixir
@spec new() :: parser_state()
```

Creates a new parser state with default values.

# `param_byte?`
*macro* 

# `process`

```elixir
@spec process(parser_state(), binary()) :: {parser_state(), [sequence()]}
```

Processes input bytes through the state machine.
Returns the updated state and any parsed sequences.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
