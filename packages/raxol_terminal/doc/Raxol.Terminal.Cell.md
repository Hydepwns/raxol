# `Raxol.Terminal.Cell`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/cell.ex#L1)

Terminal character cell module.

This module handles the representation and manipulation of individual
character cells in the terminal screen buffer, including:
- Character content
- Text attributes (color, style)
- Cell state

# `style`

```elixir
@type style() :: Raxol.Terminal.ANSI.TextFormatting.text_style()
```

Text style for a terminal cell. See `Raxol.Terminal.ANSI.TextFormatting.text_style()` type for details.

# `t`

```elixir
@type t() :: %Raxol.Terminal.Cell{
  char: String.t() | nil,
  dirty: boolean(),
  sixel: boolean(),
  style: Raxol.Terminal.ANSI.TextFormatting.text_style() | nil,
  wide_placeholder: boolean()
}
```

# `bg`

Gets the cell's background color (compatibility function).

# `copy`

Creates a deep copy of a cell.

## Examples

    iex> cell = Cell.new("A", %{foreground: :red})
    iex> copy = Cell.copy(cell)
    iex> Cell.get_char(copy)
    "A"
    iex> Cell.get_style(copy)
    %{foreground: :red}

# `double_height?`

Checks if the cell is in double-height mode.

## Examples

    iex> cell = Cell.new("A", %{foreground: :red})
    iex> Cell.double_height?(cell)
    false

# `double_width?`

Checks if the cell is in double-width mode.

## Examples

    iex> cell = Cell.new("A", %{foreground: :red})
    iex> Cell.double_width?(cell)
    false

# `empty`

```elixir
@spec empty() :: t()
```

Creates an empty cell.

# `empty?`

```elixir
@spec empty?(t()) :: boolean()
```

Checks if the cell is empty.

## Examples

    iex> cell = Cell.new()
    iex> Cell.empty?(cell)
    true

    iex> cell = Cell.new("A")
    iex> Cell.empty?(cell)
    false

# `equals?`

Compares two cells for equality.

Cells are considered equal if they have the same character and the same style map.
Handles comparison with `nil`.

## Examples
    iex> style1 = TextFormatting.new() |> TextFormatting.apply_attribute(:bold)
    iex> style2 = TextFormatting.new() |> TextFormatting.apply_attribute(:bold)
    iex> style3 = TextFormatting.new() |> TextFormatting.apply_attribute(:underline)
    iex> cell1 = Cell.new("A", style1)
    iex> cell2 = Cell.new("A", style2) # Same char and style attributes
    iex> cell3 = Cell.new("B", style1) # Different char
    iex> cell4 = Cell.new("A", style3) # Different style
    iex> Cell.equals?(cell1, cell2)
    true
    iex> Cell.equals?(cell1, cell3)
    false
    iex> Cell.equals?(cell1, cell4)
    false
    iex> Cell.equals?(cell1, nil)
    false
    iex> Cell.equals?(nil, cell1)
    false
    iex> Cell.equals?(nil, nil)
    true

# `fg`

Gets the cell's foreground color (compatibility function).

# `from_map`

```elixir
@spec from_map(map()) :: t() | nil
```

Creates a Cell struct from a map representation, typically from rendering.
Expects a map like %{char: integer_codepoint, style: map, wide_placeholder: boolean | nil}.
Returns nil if the map is invalid.

# `get_char`

```elixir
@spec get_char(t()) :: String.t() | char()
```

Returns the character of the cell.

# `get_style`

```elixir
@spec get_style(t()) :: Raxol.Terminal.ANSI.TextFormatting.text_style() | nil
```

Gets the text style of the cell.

## Examples

    iex> cell = Cell.new("A", %{foreground: :red})
    iex> Cell.get_style(cell)
    %{foreground: :red}

# `has_attribute?`

Checks if the cell has a specific attribute.

## Examples

    iex> cell = Cell.new("A", %{foreground: :red})
    iex> Cell.has_attribute?(cell, :foreground)
    true

# `has_decoration?`

Checks if the cell has a specific decoration.

## Examples

    iex> cell = Cell.new("A", %{foreground: :red})
    iex> Cell.has_decoration?(cell, :bold)
    false

# `merge_style`

Merges a given style map into the cell's style.

Only non-default attributes from the `style` map will overwrite existing attributes
in the cell's style. This prevents merging default values (like `bold: false`)
and unintentionally removing existing attributes.

## Examples

    iex> initial_style = TextFormatting.new() |> TextFormatting.apply_attribute(:bold) # %{bold: true, ...}
    iex> merge_style = TextFormatting.new() |> TextFormatting.apply_attribute(:underline) # %{underline: true, bold: false, ...}
    iex> cell = Cell.new("A", initial_style)
    iex> merged_cell = Cell.merge_style(cell, merge_style)
    iex> Cell.get_style(merged_cell)
    %{bold: true, underline: true} # Note: :bold remains, :underline added

# `new`

```elixir
@spec new(
  String.t() | nil,
  Raxol.Terminal.ANSI.TextFormatting.t()
  | Raxol.Terminal.ANSI.TextFormatting.text_style()
  | nil
) :: t()
```

Creates a new cell with optional character and style.

## Examples

    iex> cell = Cell.new()
    iex> Cell.empty?(cell)
    true

    iex> cell = Cell.new("A")
    iex> Cell.get_char(cell)
    "A"

    iex> cell = Cell.new("A", %{foreground: :red})
    iex> Cell.get_char(cell)
    "A"
    iex> Cell.get_style(cell)
    %{foreground: :red}

# `new_sixel`

Creates a new cell representing a sixel graphics pixel.

# `new_wide_placeholder`

Creates a new cell representing the second half of a wide character.
Inherits the style from the primary cell.

# `set_char`

```elixir
@spec set_char(t(), String.t()) :: t()
```

Sets the character content of a cell.

## Examples

    iex> cell = Cell.new()
    iex> cell = Cell.set_char(cell, "A")
    iex> Cell.get_char(cell)
    "A"

# `set_style`

```elixir
@spec set_style(t(), Raxol.Terminal.ANSI.TextFormatting.text_style() | nil) :: t()
```

Sets the text style of the cell.

## Examples

    iex> cell = Cell.new("A")
    iex> cell = Cell.set_style(cell, %{foreground: :red})
    iex> Cell.get_style(cell)
    %{foreground: :red}

# `with_attributes`

Creates a copy of a cell with new attributes applied.

Accepts a map of attributes or a list of attribute atoms.
If a list is provided, the attributes are applied sequentially, starting from the cell's *existing* style.

## Examples

    iex> cell = Cell.new("A", %{bold: true})
    iex> new_cell = Cell.with_attributes(cell, %{underline: true}) # Using a map
    iex> Cell.get_style(new_cell)
    %{bold: true, underline: true} # Merged

    iex> cell = Cell.new("B", %{bold: true})
    iex> new_cell = Cell.with_attributes(cell, [:underline, :reverse]) # Using a list
    iex> Cell.get_style(new_cell)
    %{bold: true, underline: true, reverse: true} # Original bold + list applied

# `with_char`

Creates a copy of a cell with a new character.

## Examples

    iex> cell = Cell.new("A", %{foreground: :red})
    iex> new_cell = Cell.with_char(cell, "B")
    iex> Cell.get_char(new_cell)
    "B"
    iex> Cell.get_style(new_cell)
    %{foreground: :red}

---

*Consult [api-reference.md](api-reference.md) for complete listing*
