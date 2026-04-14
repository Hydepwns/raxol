# `Raxol.Terminal.ScreenBuffer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/screen_buffer.ex#L1)

Manages the terminal's screen buffer state (grid, scrollback, selection).
This module serves as the main interface for terminal buffer operations,
delegating specific operations to specialized modules in Raxol.Terminal.Buffer.*.

## Structure

The buffer consists of:
* A main grid of cells (the visible screen)
* A scrollback buffer for history
* Selection state
* Scroll region settings
* Dimensions (width and height)

## Operations

The module delegates operations to specialized modules:
* `Content` - Writing and content management
* `ScrollRegion` - Scroll region and scrolling operations
* `LineOperations` - Line manipulation
* `CharEditor` - Character editing
* `LineEditor` - Line editing
* `Eraser` - Clearing operations
* `Selection` - Text selection
* `Scrollback` - History management
* `Queries` - State querying
* `Initializer` - Buffer creation and validation
* `Cursor` - Cursor state management
* `Charset` - Character set management
* `Formatting` - Text formatting and styling

# `t`

```elixir
@type t() :: %Raxol.Terminal.ScreenBuffer{
  alternate_screen: boolean(),
  cells: [[Raxol.Terminal.Cell.t()]],
  cursor_blink: boolean(),
  cursor_position: {non_neg_integer(), non_neg_integer()},
  cursor_style: atom(),
  cursor_visible: boolean(),
  damage_regions: [
    {non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()}
  ],
  default_style: Raxol.Terminal.ANSI.TextFormatting.text_style(),
  height: non_neg_integer(),
  scroll_position: non_neg_integer(),
  scroll_region: {integer(), integer()} | nil,
  scrollback: [[Raxol.Terminal.Cell.t()]],
  scrollback_limit: non_neg_integer(),
  selection: {integer(), integer(), integer(), integer()} | nil,
  width: non_neg_integer()
}
```

# `cleanup`

# `clear`

# `clear_damaged_regions`

# `clear_line`

# `clear_region`

# `clear_selection`

# `cursor_blinking?`

# `cursor_visible?`

# `delete_characters`

# `delete_chars`

# `delete_chars`

# `delete_lines`

# `delete_lines`

# `delete_lines_in_region`

# `erase_chars`

# `erase_chars`

# `erase_display`

# `erase_display`

# `erase_from_cursor_to_end`

# `erase_from_start_to_cursor`

# `erase_in_display`

# `erase_in_line`

# `erase_line`

# `erase_line`

# `erase_line`

# `erase_screen`

# `fill_region`

# `get_cell_at`

# `get_content`

# `get_cursor_position`

# `get_cursor_style`

# `get_damaged_regions`

# `get_line`

# `get_lines`

# `get_scroll_bottom`

# `get_scroll_region`

# `get_scroll_top`

# `get_scrollback`

# `get_selected_text`

# `get_selection`

# `get_selection_boundaries`

# `get_selection_end`

# `get_selection_start`

# `get_text_in_region`

# `handle_single_line_replacement`

# `in_selection?`

# `insert_chars`

# `insert_chars`

# `insert_lines`

# `insert_lines`

# `insert_lines`

# `mark_damaged`

# `new`

# `new`

# `new`

Creates a new screen buffer with the specified dimensions.
Validates and normalizes the input dimensions to ensure they are valid.

# `pop_bottom_lines`

# `prepend_lines`

# `put_line`

# `reset_charset_state`

# `reset_scroll_region`

# `resize`

# `scroll`

# `scroll_down`

# `scroll_down`

# `scroll_to`

# `scroll_up`

# `selection_active?`

# `set_cursor_blink`

# `set_cursor_position`

# `set_cursor_style`

# `set_cursor_visibility`

# `set_dimensions`

# `set_scroll_region`

# `set_scrollback`

# `shift_region_to_line`

# `start_selection`

# `update`

# `update_selection`

# `write`

# `write`

# `write_char`

# `write_string`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
