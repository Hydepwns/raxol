# `Raxol.Terminal.Emulator.TextOperations`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/emulator/text_operations.ex#L1)

Text operation functions extracted from the main emulator module.
Handles text writing with charset translation and cursor updates.

# `emulator`

```elixir
@type emulator() :: Raxol.Terminal.Emulator.t()
```

# `set_attribute`

```elixir
@spec set_attribute(emulator(), atom(), any()) :: emulator()
```

Sets an attribute on the emulator (placeholder implementation).

# `write_string`

```elixir
@spec write_string(
  emulator(),
  non_neg_integer(),
  non_neg_integer(),
  String.t(),
  map()
) :: emulator()
```

Writes a string to the terminal with charset translation.
Updates cursor position after writing.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
