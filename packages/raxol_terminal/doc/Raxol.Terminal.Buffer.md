# `Raxol.Terminal.Buffer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/terminal_buffer.ex#L1)

Manages the terminal buffer state and operations.

# `t`

```elixir
@type t() :: %Raxol.Terminal.Buffer{
  cells: [[Raxol.Terminal.Buffer.Cell.t()]],
  cursor_x: non_neg_integer(),
  cursor_y: non_neg_integer(),
  damage_regions: [
    {non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()}
  ],
  height: non_neg_integer(),
  scroll_region_bottom: non_neg_integer(),
  scroll_region_top: non_neg_integer(),
  width: non_neg_integer()
}
```

# `add`

```elixir
@spec add(t(), String.t()) :: t()
```

Adds content to the buffer at the current cursor position.

## Examples

    iex> buffer = Buffer.new({80, 24})
    iex> buffer = Buffer.add(buffer, "Hello, World!")
    iex> {content, _} = Buffer.read(buffer)
    iex> content
    "Hello, World!"

# `clear`

```elixir
@spec clear(
  t(),
  keyword()
) :: t()
```

Clears the buffer.

# `clear_region`

Clear a rectangular region in the buffer.

# `draw_box`

Draw a box in the buffer with the specified style.

# `fill_region`

```elixir
@spec fill_region(
  t(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer(),
  Raxol.Terminal.Buffer.Cell.t()
) :: t()
```

Fills a region of the buffer with a specified cell.
Delegates to ScreenBuffer.fill_region/6.

# `get_cell`

```elixir
@spec get_cell(t(), non_neg_integer(), non_neg_integer()) ::
  Raxol.Terminal.Buffer.Cell.t()
```

Gets a cell from the buffer at the specified coordinates.
Delegates to ScreenBuffer.get_cell/3.

# `get_cursor_position`

```elixir
@spec get_cursor_position(t()) :: {non_neg_integer(), non_neg_integer()}
```

Gets the current cursor position.

# `get_damage_regions`

```elixir
@spec get_damage_regions(t()) :: [
  {non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()}
]
```

Gets all damaged regions in the buffer.

# `mark_damaged`

```elixir
@spec mark_damaged(
  t(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer()
) :: t()
```

Marks a region of the buffer as damaged.

# `move_cursor`

Move the cursor to the specified position.

# `new`

```elixir
@spec new() :: t()
```

Creates a new buffer with default dimensions (80x24).

# `new`

```elixir
@spec new({non_neg_integer(), non_neg_integer()}) :: t()
```

Creates a new buffer with the specified dimensions.
Raises ArgumentError if dimensions are invalid.

# `read`

```elixir
@spec read(
  t(),
  keyword()
) :: {String.t(), t()}
```

Reads data from the buffer.

# `resize`

```elixir
@spec resize(t(), non_neg_integer(), non_neg_integer()) :: t()
```

Resizes the buffer to the specified width and height.
Delegates to ScreenBuffer.resize/3.

# `scroll`

```elixir
@spec scroll(t(), integer()) :: t()
```

Scrolls the buffer by the specified number of lines.

# `scroll_state`

```elixir
@spec scroll_state(t(), integer()) :: t()
```

Updates the scroll state without moving content.
This is a fast operation that only updates scroll position.

# `set_cell`

```elixir
@spec set_cell(
  t(),
  non_neg_integer(),
  non_neg_integer(),
  Raxol.Terminal.Buffer.Cell.t()
) :: t()
```

Sets a cell in the buffer at the specified coordinates.
Raises ArgumentError if coordinates or cell data are invalid.

# `set_cursor_position`

```elixir
@spec set_cursor_position(t(), non_neg_integer(), non_neg_integer()) :: t()
```

Sets the cursor position.

# `set_scroll_region`

```elixir
@spec set_scroll_region(t(), non_neg_integer(), non_neg_integer()) :: t()
```

Sets the scroll region.

# `write`

```elixir
@spec write(t(), String.t(), keyword()) :: t()
```

Writes data to the buffer at the current cursor position.

# `write_text`

```elixir
@spec write_text(t(), String.t()) :: t()
```

Writes text to the buffer at the current position.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
