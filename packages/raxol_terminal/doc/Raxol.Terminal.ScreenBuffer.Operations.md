# `Raxol.Terminal.ScreenBuffer.Operations`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/screen_buffer/operations.ex#L1)

All buffer mutation operations.
Consolidates: Operations, Ops, OperationsCached, Writer, Updater, CharEditor,
LineOperations, Eraser, Content, Paste functionality.

# `clear_line`

Clears a line.

# `clear_line`

Clears a line (stub).

# `clear_region`

Clears a rectangular region.

# `clear_to_beginning_of_line`

Clears from cursor to beginning of line.

# `clear_to_beginning_of_screen`

Clears from cursor to beginning of screen.

# `clear_to_end_of_line`

Clears from cursor to end of line.

# `clear_to_end_of_screen`

Clears from cursor to end of screen.

# `copy_region`

Copies a region to another location.

# `delete_char`

Deletes a character at the cursor position, shifting content left.

# `delete_chars`

Deletes characters at cursor position.

# `delete_line`

Deletes a line at the specified position.

# `delete_lines`

Deletes lines (stub with 2 args).

# `delete_lines`

Deletes lines at position y with count, within a region.

# `erase_chars`

Erases characters (stub with 2 args).

# `erase_chars`

Erases characters at position (stub with 4 args).

# `erase_display`

Erases display (stub).

# `erase_line`

Erases line (stub with 2 args).

# `erase_line`

Erases line at position (stub with 3 args).

# `fill_region`

Fills a region with a character.

# `get_region`

Gets scroll region (stub).

# `insert_char`

Inserts a character at the cursor position, shifting content right.

# `insert_char`

Inserts a character at the specified position.

# `insert_char`

Inserts a character at the specified position with style.

# `insert_chars`

Inserts spaces at cursor position, shifting content to the right.
Cursor remains at its original position after the operation.

# `insert_line`

Inserts a blank line at the specified position.

# `insert_lines`

Inserts lines at cursor position (stub with 2 args).

# `insert_lines`

Inserts lines at position y with count.

# `insert_lines`

Inserts lines at position y with count, within a scroll region.

# `prepend_lines`

Prepends lines to buffer.

# `put_line`

Puts a line of cells at the specified y position.
Used by scrolling operations and for backward compatibility.

# `scroll_down`

Scrolls content down (stub).

# `scroll_to`

Scrolls to position (stub).

# `scroll_up`

Scrolls content up (stub).

# `set_region`

Sets scroll region (stub).

# `shift_region_to_line`

Shifts region content so that target_line appears at the top of the region.

# `write_char`

Writes a character at the specified position.

# `write_sixel_char`

Writes a sixel graphics character at the specified position with the sixel flag set.

# `write_string`

Writes a string starting at the specified position (alias for write_text).

# `write_string`

Writes a string starting at the specified position with style.

# `write_text`

Writes a string starting at the specified position.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
