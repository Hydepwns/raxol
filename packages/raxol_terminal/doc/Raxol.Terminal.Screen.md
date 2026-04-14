# `Raxol.Terminal.Screen`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/screen.ex#L1)

Provides screen manipulation functions for the terminal emulator.

This module handles operations like resizing, marking damaged regions,
and clearing the screen. It works in conjunction with `Raxol.Terminal.ScreenBuffer`
to manage the terminal display state.

## Features

* Screen resizing
* Region damage tracking
* Screen and line clearing
* Line and character insertion/deletion
* Cursor movement
* Screen scrolling

## Usage

```elixir
# Create a new screen buffer
buffer = ScreenBuffer.new(80, 24)

# Resize the screen
buffer = Screen.resize(buffer, 100, 30)

# Clear the screen
buffer = Screen.clear_screen(buffer)
```

# `clear_line`

Clears a specific line in the screen.

## Parameters

  * `buffer` - The current screen buffer
  * `line` - Line number to clear (0-based)

## Returns

  * Updated screen buffer with cleared line

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = Screen.clear_line(buffer, 0)
    iex> get_in(buffer.content, [0])
    %{}

# `clear_screen`

Clears the entire screen and resets formatting.

## Parameters

  * `buffer` - The current screen buffer

## Returns

  * Updated screen buffer with cleared content

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = Screen.clear_screen(buffer)
    iex> buffer.content
    %{}

# `delete_chars`

Deletes characters at the current cursor position.

# `delete_lines`

Deletes lines at the current cursor position, pulling content up.

## Parameters

  * `buffer` - The current screen buffer
  * `count` - Number of lines to delete

## Returns

  * Updated screen buffer with deleted lines

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = Screen.delete_lines(buffer, 2)
    iex> buffer.scroll_region
    {0, 23}

# `erase_chars`

Erases characters at the current cursor position.

# `erase_display`

Erases the display based on the specified mode.

Mode values:
* 0 - Erase from cursor to end of screen
* 1 - Erase from start of screen to cursor
* 2 - Erase entire screen
* 3 - Erase entire screen and scrollback buffer

# `insert_chars`

Inserts characters at the current cursor position, pushing existing content right.

## Parameters

  * `buffer` - The current screen buffer
  * `count` - Number of characters to insert

## Returns

  * Updated screen buffer with inserted characters

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = Screen.insert_chars(buffer, 5)
    iex> buffer.cursor
    {5, 0}

# `insert_lines`

Inserts lines at the current cursor position, pushing existing content down.

## Parameters

  * `buffer` - The current screen buffer
  * `count` - Number of lines to insert

## Returns

  * Updated screen buffer with inserted lines

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = Screen.insert_lines(buffer, 2)
    iex> buffer.scroll_region
    {0, 23}

# `mark_damaged`

Marks a region of the screen as damaged, indicating it needs to be redrawn.

## Parameters

  * `buffer` - The current screen buffer
  * `x` - Starting x coordinate
  * `y` - Starting y coordinate
  * `width` - Width of damaged region
  * `height` - Height of damaged region

## Returns

  * Updated screen buffer with marked damage region

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = Screen.mark_damaged(buffer, 0, 0, 10, 5)
    iex> buffer.damage_regions
    [{0, 0, 10, 5}]

# `resize`

Resizes the screen buffer to new dimensions.

## Parameters

  * `buffer` - The current screen buffer
  * `width` - New width in characters
  * `height` - New height in characters

## Returns

  * Updated screen buffer with new dimensions

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> new_buffer = Screen.resize(buffer, 100, 30)
    iex> {new_buffer.width, new_buffer.height}
    {100, 30}

# `scroll_down`

Scrolls the screen down by the specified number of lines.

# `scroll_up_screen`

Scrolls the screen up by the specified number of lines.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
