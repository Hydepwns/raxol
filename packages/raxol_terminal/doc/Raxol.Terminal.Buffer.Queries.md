# `Raxol.Terminal.Buffer.Queries`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/buffer/queries.ex#L1)

Handles buffer state querying operations.
This module provides functions for querying the state of the screen buffer,
including dimensions, content, and selection state.

# `empty?`

```elixir
@spec empty?(Raxol.Terminal.ScreenBuffer.t()) :: boolean()
```

Checks if the buffer is empty.

## Parameters

* `buffer` - The screen buffer to check

## Returns

A boolean indicating if the buffer is empty.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> Queries.empty?(buffer)
    true

# `get_cell`

```elixir
@spec get_cell(Raxol.Terminal.ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
  Raxol.Terminal.Cell.t()
```

Gets a specific cell from the buffer.

# `get_cell_at`

```elixir
@spec get_cell_at(
  Raxol.Terminal.ScreenBuffer.t(),
  non_neg_integer(),
  non_neg_integer()
) ::
  Raxol.Terminal.Cell.t()
```

Gets the cell at the specified position in the buffer.

## Parameters

* `buffer` - The screen buffer to query
* `x` - The x-coordinate (column)
* `y` - The y-coordinate (row)

## Returns

The cell at the specified position, or an empty cell if the position is out of bounds.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> cell = Queries.get_cell_at(buffer, 0, 0)
    iex> cell.char
    ""

# `get_char`

```elixir
@spec get_char(map(), integer(), integer()) :: String.t()
```

Gets the character at the given position in the buffer.

# `get_char_at`

```elixir
@spec get_char_at(
  Raxol.Terminal.ScreenBuffer.t(),
  non_neg_integer(),
  non_neg_integer()
) :: String.t()
```

Gets the character at the specified position in the buffer.

## Parameters

* `buffer` - The screen buffer to query
* `x` - The x-coordinate (column)
* `y` - The y-coordinate (row)

## Returns

The character at the specified position, or a space if the position is out of bounds.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> Queries.get_char_at(buffer, 0, 0)
    " "

# `get_content`

```elixir
@spec get_content(Raxol.Terminal.ScreenBuffer.t()) :: [[Raxol.Terminal.Cell.t()]]
```

Gets the content of the buffer as a list of lines.

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

# `get_line`

```elixir
@spec get_line(Raxol.Terminal.ScreenBuffer.t(), non_neg_integer()) :: [
  Raxol.Terminal.Cell.t()
]
```

Gets a specific line from the buffer.

# `get_line_text`

```elixir
@spec get_line_text(Raxol.Terminal.ScreenBuffer.t(), non_neg_integer()) :: String.t()
```

Gets the text content of a specific line.

# `get_text`

```elixir
@spec get_text(Raxol.Terminal.ScreenBuffer.t()) :: String.t()
```

Gets the text content of the buffer.

# `get_text_at`

```elixir
@spec get_text_at(
  Raxol.Terminal.ScreenBuffer.t(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer()
) :: String.t()
```

Gets text at a specific position with a given length.

# `get_width`

```elixir
@spec get_width(Raxol.Terminal.ScreenBuffer.t()) :: non_neg_integer()
```

Gets the width of the buffer.

# `has_scrollback?`

```elixir
@spec has_scrollback?(Raxol.Terminal.ScreenBuffer.t()) :: boolean()
```

Checks if the buffer has scrollback content.

# `in_bounds?`

```elixir
@spec in_bounds?(
  Raxol.Terminal.ScreenBuffer.t(),
  non_neg_integer(),
  non_neg_integer()
) :: boolean()
```

Checks if a position is within the buffer bounds.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
