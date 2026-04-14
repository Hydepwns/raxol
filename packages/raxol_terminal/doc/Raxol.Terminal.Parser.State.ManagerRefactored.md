# `Raxol.Terminal.Parser.State.ManagerRefactored`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/parser/state/manager_refactored.ex#L1)

Refactored version of Terminal Parser State Manager using pattern matching
instead of cond statements.

This demonstrates Sprint 9's pattern matching improvements.

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

# `t`

```elixir
@type t() :: %Raxol.Terminal.Parser.State.ManagerRefactored{
  apc_buffer: term(),
  dcs_buffer: term(),
  designating_gset: term(),
  final_byte: term(),
  ignore: term(),
  intermediate: list(),
  intermediates_buffer: term(),
  osc_buffer: term(),
  params: list(),
  params_buffer: term(),
  payload_buffer: term(),
  pm_buffer: term(),
  single_shift: term(),
  sos_buffer: term(),
  state: parser_state(),
  string_buffer: term(),
  string_flags: term(),
  string_parser_state: term(),
  string_terminator: term()
}
```

# `parse_sequence`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
