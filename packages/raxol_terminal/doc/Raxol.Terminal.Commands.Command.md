# `Raxol.Terminal.Commands.Command`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/commands/command.ex#L1)

Defines the structure for terminal commands.

# `t`

```elixir
@type t() :: %Raxol.Terminal.Commands.Command{
  command_buffer: String.t(),
  command_state: any(),
  current: String.t() | nil,
  history: [String.t()],
  history_index: integer(),
  last_key_event: any(),
  max_history: non_neg_integer()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
