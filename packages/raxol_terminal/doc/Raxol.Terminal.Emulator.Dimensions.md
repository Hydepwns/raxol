# `Raxol.Terminal.Emulator.Dimensions`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/emulator/dimensions.ex#L1)

Dimension and resize operation functions extracted from the main emulator module.
Handles terminal resizing and dimension getters.

# `emulator`

```elixir
@type emulator() :: Raxol.Terminal.Emulator.t()
```

# `get_height`

```elixir
@spec get_height(emulator()) :: non_neg_integer()
```

Gets the height of the terminal.

# `get_scroll_region`

```elixir
@spec get_scroll_region(emulator()) :: {non_neg_integer(), non_neg_integer()} | nil
```

Gets the current scroll region.

# `get_width`

```elixir
@spec get_width(emulator()) :: non_neg_integer()
```

Gets the width of the terminal.

# `resize`

```elixir
@spec resize(emulator(), non_neg_integer(), non_neg_integer()) :: emulator()
```

Resizes the terminal emulator to new dimensions.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
