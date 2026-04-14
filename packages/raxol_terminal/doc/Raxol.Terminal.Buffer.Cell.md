# `Raxol.Terminal.Buffer.Cell`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/buffer/cell.ex#L1)

Manages terminal cell operations and attributes.

# `t`

```elixir
@type t() :: %Raxol.Terminal.Buffer.Cell{
  attributes: map(),
  background: integer() | atom() | String.t(),
  bg: term(),
  char: String.t(),
  fg: term(),
  foreground: integer() | atom() | String.t(),
  hyperlink: String.t() | nil,
  width: integer()
}
```

# `bg`

Gets the cell's background color (backward compatibility).

# `bg`

Sets the cell's background color (backward compatibility).

# `copy_attributes`

Copies attributes from one cell to another.

# `empty?`

Checks if the cell is empty.

# `fg`

Gets the cell's foreground color (backward compatibility).

# `fg`

Sets the cell's foreground color (backward compatibility).

# `get_attributes`

Gets the cell's attributes.

# `get_background`

Gets the cell's background color.

# `get_char`

Gets the cell's character.

# `get_foreground`

Gets the cell's foreground color.

# `get_hyperlink`

Gets the cell's hyperlink.

# `get_width`

Gets the cell's width.

# `new`

Creates a new cell with default settings.

# `new`

Creates a new cell with the specified character and style.

# `reset`

Resets a cell to its default state.

# `set_attributes`

Sets the cell's attributes.

# `set_background`

Sets the cell's background color.

# `set_char`

Sets the cell's character.

# `set_foreground`

Sets the cell's foreground color.

# `set_hyperlink`

Sets the cell's hyperlink.

# `set_width`

Sets the cell's width.

# `valid?`

Validates a cell's data.
Returns true if the cell is valid, false otherwise.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
