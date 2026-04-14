# `Raxol.Terminal.Scroll.ScrollServer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/scroll/scroll_server.ex#L1)

Unified scroll management system for the terminal.

This module consolidates all scroll-related functionality including:
- Scroll buffer management
- Scroll operations (up/down)
- Scroll region handling
- Memory management
- Performance optimization

# `t`

```elixir
@type t() :: %Raxol.Terminal.Scroll.ScrollServer{
  buffer: [[Raxol.Terminal.Cell.t()]],
  cache: map(),
  compression_ratio: float(),
  height: non_neg_integer(),
  max_height: non_neg_integer(),
  memory_limit: non_neg_integer(),
  memory_usage: non_neg_integer(),
  position: non_neg_integer(),
  scroll_region: {non_neg_integer(), non_neg_integer()} | nil
}
```

# `add_line`

Adds a line to the scroll buffer.

# `cleanup`

Cleans up the scroll buffer.

# `clear`

Clears the scroll buffer.

# `clear_scroll_region`

Clears the scroll region.

# `get_height`

Gets the total height of the scroll buffer.

# `get_position`

Gets the current scroll position.

# `get_view`

Gets a view of the scroll buffer at the current position.

# `get_visible_region`

Gets the visible region of the scroll buffer.

# `new`

Creates a new scroll buffer with the given dimensions and configuration.

# `resize`

Resizes the scroll buffer to the new height.

# `scroll`

Scrolls the buffer by the given amount.

# `scroll`

# `set_max_height`

Updates the maximum height of the scroll buffer.

# `set_scroll_region`

Sets the scroll region.

# `update`

Updates the scroll buffer with new commands.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
