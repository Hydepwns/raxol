# `Raxol.Terminal.Input.Types`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/input/input_types.ex#L1)

Defines shared types for the Raxol terminal input subsystem.

# `input_buffer`

```elixir
@type input_buffer() :: %{
  contents: String.t(),
  max_size: non_neg_integer(),
  overflow_mode: :truncate | :error | :wrap,
  escape_sequence: String.t(),
  escape_sequence_mode: boolean(),
  cursor_pos: non_neg_integer(),
  width: non_neg_integer()
}
```

Represents the state of the terminal input buffer.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
