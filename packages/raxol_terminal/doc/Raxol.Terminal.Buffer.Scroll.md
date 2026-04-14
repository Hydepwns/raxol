# `Raxol.Terminal.Buffer.Scroll`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/buffer/scroll.ex#L1)

Terminal scroll buffer module.

This module handles the management of terminal scrollback buffers, including:
- Virtual scrolling implementation
- Memory-efficient buffer management
- Scroll position tracking
- Buffer compression

# `t`

```elixir
@type t() :: %Raxol.Terminal.Buffer.Scroll{
  buffer: [[Raxol.Terminal.Cell.t()]],
  compression_ratio: float(),
  height: non_neg_integer(),
  max_height: non_neg_integer(),
  memory_limit: non_neg_integer(),
  memory_usage: non_neg_integer(),
  position: non_neg_integer(),
  scroll_region: {non_neg_integer(), non_neg_integer()} | nil
}
```

# `add_content`

Adds content (multiple lines) to the scroll buffer.

# `add_line`

Adds a line to the scroll buffer.

## Examples

    iex> scroll = Scroll.new(1000)
    iex> line = [Cell.new("A"), Cell.new("B")]
    iex> scroll = Scroll.add_line(scroll, line)
    iex> scroll.height
    1

# `cleanup`

Cleans up the scroll buffer.

# `clear`

Clears the scroll buffer.

## Examples

    iex> scroll = Scroll.new(1000)
    iex> line = [Cell.new("A"), Cell.new("B")]
    iex> scroll = Scroll.add_line(scroll, line)
    iex> scroll = Scroll.clear(scroll)
    iex> scroll.height
    0

# `clear_scroll_region`

Clears the scroll region.

## Examples

    iex> scroll = Scroll.new(1000)
    iex> scroll = Scroll.set_scroll_region(scroll, 1, 5)
    iex> scroll = Scroll.clear_scroll_region(scroll)
    iex> scroll.scroll_region
    nil

# `get_height`

Gets the total height of the scroll buffer.

## Examples

    iex> scroll = Scroll.new(1000)
    iex> line = [Cell.new("A"), Cell.new("B")]
    iex> scroll = Scroll.add_line(scroll, line)
    iex> Scroll.get_height(scroll)
    1

# `get_memory_usage`

Gets the memory usage of the scroll buffer.

# `get_position`

Gets the current scroll position.

## Examples

    iex> scroll = Scroll.new(1000)
    iex> Scroll.get_position(scroll)
    0

# `get_size`

Gets the size of the scroll buffer.

# `get_view`

Gets a view of the scroll buffer at the current position.

## Examples

    iex> scroll = Scroll.new(1000)
    iex> line = [Cell.new("A"), Cell.new("B")]
    iex> scroll = Scroll.add_line(scroll, line)
    iex> view = Scroll.get_view(scroll, 10)
    iex> length(view)
    1

# `get_visible_region`

Gets the visible region of the scroll buffer.

# `new`

Creates a new scroll buffer with the given dimensions.

## Examples

    iex> scroll = Scroll.new(1000)
    iex> scroll.max_height
    1000
    iex> scroll.position
    0

# `resize`

Resizes the scroll buffer to the new height.

# `scroll`

Scrolls the buffer by the given amount.

## Examples

    iex> scroll = Scroll.new(1000)
    iex> line = [Cell.new("A"), Cell.new("B")]
    iex> scroll = Scroll.add_line(scroll, line)
    iex> scroll = Scroll.scroll(scroll, 5)
    iex> scroll.position
    5

# `scroll`

Scrolls the buffer in the specified direction by the given amount.

# `set_max_height`

Updates the maximum height of the scroll buffer.
Trims the buffer if the new max height is smaller than the current content.

# `set_scroll_region`

Sets the scroll region.

## Parameters
  - scroll: The scroll buffer
  - top: Top boundary of the scroll region
  - bottom: Bottom boundary of the scroll region

## Examples

    iex> scroll = Scroll.new(1000)
    iex> scroll = Scroll.set_scroll_region(scroll, 1, 5)
    iex> scroll.scroll_region
    {1, 5}

---

*Consult [api-reference.md](api-reference.md) for complete listing*
