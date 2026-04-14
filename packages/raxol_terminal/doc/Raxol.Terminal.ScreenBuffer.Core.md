# `Raxol.Terminal.ScreenBuffer.Core`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/screen_buffer/core.ex#L1)

Core functionality for screen buffer creation, initialization, and basic queries.
Consolidates: Initializer, Common, Helpers, and basic state management.

# `t`

```elixir
@type t() :: %Raxol.Terminal.ScreenBuffer.Core{
  alternate_screen: boolean(),
  cells: [[Raxol.Terminal.Cell.t()]],
  cursor_blink: boolean(),
  cursor_position: {non_neg_integer(), non_neg_integer()},
  cursor_style: atom(),
  cursor_visible: boolean(),
  damage_regions: [tuple()],
  default_style: map(),
  height: non_neg_integer(),
  scroll_position: non_neg_integer(),
  scroll_region: nil | {non_neg_integer(), non_neg_integer()},
  scrollback: [[Raxol.Terminal.Cell.t()]],
  scrollback_limit: non_neg_integer(),
  selection:
    nil
    | {non_neg_integer(), non_neg_integer(), non_neg_integer(),
       non_neg_integer()},
  width: non_neg_integer()
}
```

# `clear`

Clears the entire buffer.

# `get_cell`

Gets a cell at the specified coordinates.

# `get_char`

Gets the character at the specified coordinates.

# `get_dimensions`

Gets the buffer dimensions.

# `get_height`

Gets the buffer height.

# `get_line`

Gets a line of cells.

# `get_width`

Gets the buffer width.

# `new`

Creates a new screen buffer with the specified dimensions.

# `resize`

Resizes the buffer to new dimensions.

# `to_cell_grid`

Converts buffer to legacy cell grid format for backward compatibility.

# `within_bounds?`

Checks if coordinates are within buffer bounds.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
