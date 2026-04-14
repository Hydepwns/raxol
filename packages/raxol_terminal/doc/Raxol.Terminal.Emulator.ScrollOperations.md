# `Raxol.Terminal.Emulator.ScrollOperations`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/emulator/scroll_operations.ex#L1)

Scroll operation functions extracted from the main emulator module.
Handles scroll region management and scroll positioning.

# `emulator`

```elixir
@type emulator() :: Raxol.Terminal.Emulator.t()
```

# `get_scroll_bottom`

```elixir
@spec get_scroll_bottom(emulator()) :: non_neg_integer()
```

Gets the bottom scroll position.

# `get_scroll_region`

```elixir
@spec get_scroll_region(emulator()) :: {non_neg_integer(), non_neg_integer()} | nil
```

Gets the scroll region from the emulator.

# `get_scroll_top`

```elixir
@spec get_scroll_top(emulator()) :: non_neg_integer()
```

Gets the top scroll position.

# `get_scrollback`

```elixir
@spec get_scrollback(emulator()) :: list()
```

Gets the scrollback buffer from the emulator.

# `maybe_scroll`

```elixir
@spec maybe_scroll(emulator()) :: emulator()
```

Checks if the cursor needs to scroll and performs scrolling if necessary.

# `scroll_down`

```elixir
@spec scroll_down(emulator(), non_neg_integer()) :: emulator()
```

Scrolls the terminal down by the specified number of lines.

# `scroll_up`

```elixir
@spec scroll_up(emulator(), non_neg_integer()) :: emulator()
```

Scrolls the terminal up by the specified number of lines.

# `update_scroll_region`

```elixir
@spec update_scroll_region(
  emulator(),
  {non_neg_integer(), non_neg_integer()}
) :: emulator()
```

Updates the scroll region with new top and bottom bounds.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
