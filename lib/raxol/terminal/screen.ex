defmodule Raxol.Terminal.Screen do
  @moduledoc '''
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
  '''

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.ANSI.TextFormatting

  @doc '''
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
  '''
  @spec resize(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          ScreenBuffer.t()
  def resize(buffer, width, height) do
    ScreenBuffer.resize(buffer, width, height)
  end

  @doc '''
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
  '''
  @spec mark_damaged(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: ScreenBuffer.t()
  def mark_damaged(buffer, x, y, width, height) do
    ScreenBuffer.mark_damaged(buffer, x, y, width, height, nil)
  end

  @doc '''
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
  '''
  @spec clear_screen(ScreenBuffer.t()) :: ScreenBuffer.t()
  def clear_screen(buffer) do
    ScreenBuffer.clear(buffer, TextFormatting.new())
  end

  @doc '''
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
  '''
  @spec clear_line(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def clear_line(buffer, line) do
    ScreenBuffer.clear_line(buffer, line, TextFormatting.new())
  end

  @doc '''
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
  '''
  @spec insert_lines(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def insert_lines(buffer, count) do
    ScreenBuffer.insert_lines(buffer, count)
  end

  @doc '''
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
  '''
  @spec delete_lines(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def delete_lines(buffer, count) do
    ScreenBuffer.delete_lines(buffer, count)
  end

  @doc '''
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
  '''
  @spec insert_chars(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def insert_chars(buffer, count) do
    ScreenBuffer.insert_chars(buffer, count)
  end

  @doc '''
  Deletes characters at the current cursor position.
  '''
  @spec delete_chars(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def delete_chars(buffer, count) do
    ScreenBuffer.delete_chars(buffer, count)
  end

  @doc '''
  Erases characters at the current cursor position.
  '''
  @spec erase_chars(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def erase_chars(buffer, count) do
    ScreenBuffer.erase_chars(buffer, count)
  end

  @doc '''
  Scrolls the screen up by the specified number of lines.
  '''
  @spec scroll_up_screen(ScreenBuffer.t(), non_neg_integer()) ::
          ScreenBuffer.t()
  def scroll_up_screen(buffer, lines) do
    ScreenBuffer.scroll_up(buffer, lines)
  end

  @doc '''
  Scrolls the screen down by the specified number of lines.
  '''
  @spec scroll_down(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def scroll_down(buffer, lines) do
    ScreenBuffer.scroll_down(buffer, lines)
  end

  @doc '''
  Erases the display based on the specified mode.

  Mode values:
  * 0 - Erase from cursor to end of screen
  * 1 - Erase from start of screen to cursor
  * 2 - Erase entire screen
  * 3 - Erase entire screen and scrollback buffer
  '''
  @spec erase_display(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def erase_display(buffer, mode) do
    {x, y} = ScreenBuffer.get_cursor_position(buffer)
    {width, height} = ScreenBuffer.get_dimensions(buffer)

    case mode do
      0 -> ScreenBuffer.erase_from_cursor_to_end(buffer, x, y, width, height)
      1 -> ScreenBuffer.erase_from_start_to_cursor(buffer, x, y, width, height)
      2 -> clear_screen(buffer)
      3 -> ScreenBuffer.erase_all(buffer)
    end
  end
end
