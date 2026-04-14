# `Raxol.Terminal.Parser.States.CSIEntryState`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/parser/states/csi_entry_state.ex#L1)

Handles the CSI Entry state in the terminal parser.
This state is entered after receiving an ESC [ sequence.

# `handle`

```elixir
@spec handle(byte(), map()) :: {atom(), map()}
```

Handles input in CSI Entry state.
Returns the next state and any accumulated data.

# `handle`

```elixir
@spec handle(
  Raxol.Terminal.Emulator.t(),
  map(),
  binary()
) ::
  {:continue, Raxol.Terminal.Emulator.t(), map(), binary()}
  | {:incomplete, Raxol.Terminal.Emulator.t(), map()}
```

Handles input in CSI Entry state with emulator context.
Returns {:continue, emulator, parser_state, input} or {:incomplete, emulator, parser_state}.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
