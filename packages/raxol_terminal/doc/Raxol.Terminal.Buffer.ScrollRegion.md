# `Raxol.Terminal.Buffer.ScrollRegion`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/buffer/scroll_region.ex#L1)

Handles scroll region operations for the screen buffer.
This module manages the scroll region boundaries and provides functions
for scrolling content within the defined region.

## Scroll Region

A scroll region defines a subset of the screen buffer where scrolling operations
are confined. The region is defined by its top and bottom boundaries, and all
scrolling operations (up/down) will only affect the content within these boundaries.

## Operations

* Setting and clearing scroll regions
* Scrolling content up and down within the region
* Getting region boundaries
* Validating region boundaries
* Managing content within the region

# `clear`

```elixir
@spec clear(Raxol.Terminal.ScreenBuffer.t()) :: Raxol.Terminal.ScreenBuffer.t()
```

Clears the scroll region, resetting to full screen.

## Parameters

* `buffer` - The screen buffer to modify

## Returns

The updated screen buffer with scroll region cleared.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = ScrollRegion.set_region(buffer, 5, 15)
    iex> buffer = ScrollRegion.clear(buffer)
    iex> ScrollRegion.get_region(buffer)
    nil

# `clear_region`

```elixir
@spec clear_region(Raxol.Terminal.ScreenBuffer.t()) :: Raxol.Terminal.ScreenBuffer.t()
```

Clears the scroll region, resetting to full screen.
Alias for clear/1 for backward compatibility.

# `get_boundaries`

```elixir
@spec get_boundaries(Raxol.Terminal.ScreenBuffer.t()) ::
  {non_neg_integer(), non_neg_integer()}
```

Gets the current scroll region boundaries.
Returns {0, height-1} if no region is set.

## Parameters

* `buffer` - The screen buffer to query

## Returns

A tuple {top, bottom} representing the effective scroll region boundaries.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> ScrollRegion.get_boundaries(buffer)
    {0, 23}

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = ScrollRegion.set_region(buffer, 5, 15)
    iex> ScrollRegion.get_boundaries(buffer)
    {5, 15}

# `get_dimensions`

```elixir
@spec get_dimensions(Raxol.Terminal.ScreenBuffer.t()) ::
  {non_neg_integer(), non_neg_integer()}
```

Gets the dimensions of the buffer.

# `get_height`

```elixir
@spec get_height(Raxol.Terminal.ScreenBuffer.t()) :: non_neg_integer()
```

Gets the height of the buffer.

# `get_region`

```elixir
@spec get_region(Raxol.Terminal.ScreenBuffer.t()) ::
  {non_neg_integer(), non_neg_integer()} | nil
```

Gets the current scroll region boundaries.

## Parameters

* `buffer` - The screen buffer to query

## Returns

A tuple {top, bottom} representing the scroll region boundaries.
Returns nil if no region is set.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> ScrollRegion.get_region(buffer)
    nil

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = ScrollRegion.set_region(buffer, 5, 15)
    iex> ScrollRegion.get_region(buffer)
    {5, 15}

# `get_scroll_bottom`

```elixir
@spec get_scroll_bottom(Raxol.Terminal.ScreenBuffer.t()) :: non_neg_integer()
```

Gets the scroll bottom boundary.

# `get_scroll_position`

```elixir
@spec get_scroll_position(Raxol.Terminal.ScreenBuffer.t()) :: non_neg_integer()
```

Gets the current scroll position within the scroll region.

# `get_scroll_top`

```elixir
@spec get_scroll_top(Raxol.Terminal.ScreenBuffer.t()) :: non_neg_integer()
```

Gets the scroll top boundary.

# `get_width`

```elixir
@spec get_width(Raxol.Terminal.ScreenBuffer.t()) :: non_neg_integer()
```

Gets the width of the buffer.

# `replace_region_content`

```elixir
@spec replace_region_content(
  [[Raxol.Terminal.Cell.t()]],
  non_neg_integer(),
  non_neg_integer(),
  [
    [Raxol.Terminal.Cell.t()]
  ]
) :: [[Raxol.Terminal.Cell.t()]]
```

Replaces the content of a region in the buffer with new content.

## Parameters

* `cells` - The current cells in the buffer
* `start_line` - The starting line of the region to replace
* `end_line` - The ending line of the region to replace
* `new_content` - The new content to insert in the region

## Returns

The updated cells with the region replaced.

## Examples

    iex> cells = [[%Cell{char: "A"}, %Cell{char: "B"}], [%Cell{char: "C"}, %Cell{char: "D"}]]
    iex> new_content = [[%Cell{char: "X"}, %Cell{char: "Y"}], [%Cell{char: "Z"}, %Cell{char: "W"}]]
    iex> ScrollRegion.replace_region_content(cells, 0, 1, new_content)
    [[%Cell{char: "X"}, %Cell{char: "Y"}], [%Cell{char: "Z"}, %Cell{char: "W"}]]

# `scroll_down`

```elixir
@spec scroll_down(
  Raxol.Terminal.ScreenBuffer.t(),
  integer(),
  {integer(), integer()} | nil
) ::
  Raxol.Terminal.ScreenBuffer.t()
```

Scrolls the content down within the scroll region.

## Parameters

* `buffer` - The screen buffer to modify
* `lines` - The number of lines to scroll down
* `scroll_region_arg` - Optional scroll region override

## Returns

The updated screen buffer with content scrolled down.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = ScrollRegion.set_region(buffer, 5, 15)
    iex> buffer = ScrollRegion.scroll_down(buffer, 1)
    iex> # Content is scrolled down within region 5-15

# `scroll_to`

```elixir
@spec scroll_to(Raxol.Terminal.ScreenBuffer.t(), integer(), integer(), integer()) ::
  Raxol.Terminal.ScreenBuffer.t()
```

# `scroll_up`

```elixir
@spec scroll_up(
  Raxol.Terminal.ScreenBuffer.t(),
  integer(),
  {integer(), integer()} | nil
) ::
  {Raxol.Terminal.ScreenBuffer.t(), list()}
```

Scrolls the content up within the scroll region.

## Parameters

* `buffer` - The screen buffer to modify
* `lines` - The number of lines to scroll up
* `scroll_region_arg` - Optional scroll region override

## Returns

The updated screen buffer with content scrolled up.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = ScrollRegion.set_region(buffer, 5, 15)
    iex> buffer = ScrollRegion.scroll_up(buffer, 1)
    iex> # Content is scrolled up within region 5-15

# `set_region`

```elixir
@spec set_region(
  Raxol.Terminal.ScreenBuffer.t(),
  non_neg_integer(),
  non_neg_integer()
) ::
  Raxol.Terminal.ScreenBuffer.t()
```

Sets the scroll region boundaries.
The region must be valid (top < bottom) and within screen bounds.

## Parameters

* `buffer` - The screen buffer to modify
* `top` - The top boundary of the scroll region
* `bottom` - The bottom boundary of the scroll region

## Returns

The updated screen buffer with new scroll region boundaries.
If the region is invalid, the scroll region is cleared.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = ScrollRegion.set_region(buffer, 5, 15)
    iex> ScrollRegion.get_region(buffer)
    {5, 15}

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = ScrollRegion.set_region(buffer, 15, 5)  # Invalid region
    iex> ScrollRegion.get_region(buffer)
    {5, 15}

# `shift_region_to_line`

```elixir
@spec shift_region_to_line(
  Raxol.Terminal.ScreenBuffer.t(),
  {non_neg_integer(), non_neg_integer()},
  non_neg_integer()
) :: Raxol.Terminal.ScreenBuffer.t()
```

Shifts the content in the scroll region so that the content of the given target line appears at the top of the region.
Fills with blank lines as needed if the shift would go out of bounds.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
