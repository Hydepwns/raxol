# `Raxol.Terminal.Buffer.Writer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/buffer/writer.ex#L1)

Handles writing characters and strings to the Raxol.Terminal.ScreenBuffer.
Responsible for character width, bidirectional text segmentation, and cell creation.

# `create_cell_style`

```elixir
@spec create_cell_style(Raxol.Terminal.ANSI.TextFormatting.text_style() | nil) ::
  Raxol.Terminal.ANSI.TextFormatting.t()
```

Creates a cell style by merging the provided style with default formatting.

## Parameters

* `style` - The style to merge with default formatting, or nil for default style

## Returns

A map containing the merged text formatting style.

## Examples

    iex> Writer.create_cell_style(%{fg: :red})
    %{fg: :red, bg: :default, bold: false, ...}

# `log_char_write`

```elixir
@spec log_char_write(
  String.t(),
  non_neg_integer(),
  non_neg_integer(),
  Raxol.Terminal.ANSI.TextFormatting.text_style()
) :: :ok
```

Logs character write operations for debugging purposes.

## Parameters

* `char` - The character being written
* `x` - The x-coordinate where the character is being written
* `y` - The y-coordinate where the character is being written
* `cell_style` - The style being applied to the cell

## Returns

:ok

## Examples

    iex> Writer.log_char_write("A", 0, 0, %{fg: :red})
    :ok

# `update_cells`

```elixir
@spec update_cells(
  Raxol.Terminal.ScreenBuffer.t() | map(),
  non_neg_integer(),
  non_neg_integer(),
  String.t(),
  Raxol.Terminal.ANSI.TextFormatting.text_style(),
  1..2
) :: [[Raxol.Terminal.Cell.t()]]
```

Updates cells in the buffer at the specified position.

## Parameters

* `buffer` - The screen buffer to update
* `x` - The x-coordinate to update
* `y` - The y-coordinate to update
* `char` - The character to write
* `cell_style` - The style to apply
* `width` - The width of the character (1 or 2 for wide characters)

## Returns

The updated list of cells.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> Writer.update_cells(buffer, 0, 0, "A", %{fg: :red}, 1)
    [%Cell{char: "A", style: %{fg: :red}}, ...]

# `update_row`

```elixir
@spec update_row(
  [Raxol.Terminal.Cell.t()],
  non_neg_integer(),
  String.t(),
  Raxol.Terminal.ANSI.TextFormatting.text_style(),
  1..2,
  non_neg_integer()
) :: [Raxol.Terminal.Cell.t()]
```

Updates a row in the buffer at the specified position.

## Parameters

* `row` - The row to update
* `x` - The x-coordinate to update
* `char` - The character to write
* `cell_style` - The style to apply
* `width` - The width of the character (1 or 2 for wide characters)
* `buffer_width` - The total width of the buffer

## Returns

The updated row of cells.

## Examples

    iex> row = List.duplicate(Cell.new(), 80)
    iex> Writer.update_row(row, 0, "A", %{fg: :red}, 1, 80)
    [%Cell{char: "A", style: %{fg: :red}}, ...]

# `write_char`

```elixir
@spec write_char(
  Raxol.Terminal.ScreenBuffer.t() | map(),
  non_neg_integer(),
  non_neg_integer(),
  String.t(),
  Raxol.Terminal.ANSI.TextFormatting.text_style() | nil
) :: Raxol.Terminal.ScreenBuffer.t() | map()
```

Writes a character to the buffer at the specified position.
Handles wide characters by taking up two cells when necessary.
Accepts an optional style to apply to the cell.

# `write_segment`

```elixir
@spec write_segment(
  Raxol.Terminal.ScreenBuffer.t() | map(),
  non_neg_integer(),
  non_neg_integer(),
  String.t(),
  Raxol.Terminal.ANSI.TextFormatting.text_style() | nil
) :: {Raxol.Terminal.ScreenBuffer.t() | map(), non_neg_integer()}
```

Writes a segment of text to the buffer.

## Parameters

* `buffer` - The screen buffer to write to
* `x` - The x-coordinate to start writing at
* `y` - The y-coordinate to write at
* `segment` - The text segment to write

## Returns

A tuple containing the updated buffer and the new x-coordinate.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> {new_buffer, new_x} = Writer.write_segment(buffer, 0, 0, "Hello")
    iex> new_x
    5

# `write_string`

```elixir
@spec write_string(
  Raxol.Terminal.ScreenBuffer.t() | map(),
  non_neg_integer(),
  non_neg_integer(),
  String.t(),
  Raxol.Terminal.ANSI.TextFormatting.text_style() | nil
) :: Raxol.Terminal.ScreenBuffer.t() | map()
```

Writes a string to the buffer at the specified position.
Handles wide characters and bidirectional text.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
