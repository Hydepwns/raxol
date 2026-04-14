# `Raxol.Terminal.Buffer.Scroller`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/buffer/scroller.ex#L1)

Handles scrolling operations for the terminal buffer.

# `get_scroll_bottom`

Gets the scroll bottom position.

# `get_scroll_top`

Gets the scroll top position.

# `scroll_down`

Scrolls the buffer down by the specified number of lines.

# `scroll_entire_buffer_down`

```elixir
@spec scroll_entire_buffer_down(Raxol.Terminal.ScreenBuffer.t(), non_neg_integer()) ::
  {:ok, Raxol.Terminal.ScreenBuffer.t()}
```

Scrolls the entire buffer down by the specified number of lines.

## Parameters

* `buffer` - The screen buffer to scroll
* `count` - The number of lines to scroll down

## Returns

A tuple containing :ok and the updated buffer.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> {:ok, new_buffer} = Scroller.scroll_entire_buffer_down(buffer, 1)
    iex> length(new_buffer.content)
    24

# `scroll_entire_buffer_up`

```elixir
@spec scroll_entire_buffer_up(Raxol.Terminal.ScreenBuffer.t(), non_neg_integer()) ::
  {:ok, Raxol.Terminal.ScreenBuffer.t()}
```

Scrolls the entire buffer up by the specified number of lines.

## Parameters

* `buffer` - The screen buffer to scroll
* `count` - The number of lines to scroll up

## Returns

A tuple containing :ok and the updated buffer.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> {:ok, new_buffer} = Scroller.scroll_entire_buffer_up(buffer, 1)
    iex> length(new_buffer.content)
    24

# `scroll_region_down`

```elixir
@spec scroll_region_down(
  Raxol.Terminal.ScreenBuffer.t(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer()
) :: {:ok, Raxol.Terminal.ScreenBuffer.t()}
```

Scrolls a specific region of the buffer down by the specified number of lines.

## Parameters

* `buffer` - The screen buffer to scroll
* `count` - The number of lines to scroll down
* `top` - The top boundary of the scroll region
* `bottom` - The bottom boundary of the scroll region

## Returns

A tuple containing :ok and the updated buffer.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> {:ok, new_buffer} = Scroller.scroll_region_down(buffer, 1, 5, 15)
    iex> length(new_buffer.content)
    24

# `scroll_region_up`

```elixir
@spec scroll_region_up(
  Raxol.Terminal.ScreenBuffer.t(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer()
) :: {:ok, Raxol.Terminal.ScreenBuffer.t()}
```

Scrolls a specific region of the buffer up by the specified number of lines.

## Parameters

* `buffer` - The screen buffer to scroll
* `count` - The number of lines to scroll up
* `top` - The top boundary of the scroll region
* `bottom` - The bottom boundary of the scroll region

## Returns

A tuple containing :ok and the updated buffer.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> {:ok, new_buffer} = Scroller.scroll_region_up(buffer, 1, 5, 15)
    iex> length(new_buffer.content)
    24

# `scroll_up`

Scrolls the buffer up by the specified number of lines.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
