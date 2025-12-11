defmodule Raxol.Terminal.Screen do
  @moduledoc """
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
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.ANSI.TextFormatting

  @doc """
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
  """
  def resize(buffer, width, height) do
    ScreenBuffer.resize(buffer, width, height)
  end

  @doc """
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
  """
  def mark_damaged(buffer, x, y, width, height) do
    ScreenBuffer.mark_damaged(buffer, x, y, width, height, nil)
  end

  @doc """
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
  """
  def clear_screen(buffer) do
    ScreenBuffer.clear(buffer, TextFormatting.new())
  end

  @doc """
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
  """
  def clear_line(buffer, line) do
    ScreenBuffer.clear_line(buffer, line, TextFormatting.new())
  end

  @doc """
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
  """
  def insert_lines(buffer, count) do
    ScreenBuffer.insert_lines(buffer, count)
  end

  @doc """
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
  """
  def delete_lines(buffer, count) do
    ScreenBuffer.delete_lines(buffer, count)
  end

  @doc """
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
  """
  def insert_chars(buffer, count) do
    ScreenBuffer.insert_chars(buffer, count)
  end

  @doc """
  Deletes characters at the current cursor position.
  """
  def delete_chars(buffer, count) do
    ScreenBuffer.delete_chars(buffer, count)
  end

  @doc """
  Erases characters at the current cursor position.
  """
  def erase_chars(buffer, count) do
    ScreenBuffer.erase_chars(buffer, count)
  end

  @doc """
  Scrolls the screen up by the specified number of lines.
  """
  def scroll_up_screen(buffer, lines) do
    {new_buffer, _scrolled_lines} = ScreenBuffer.scroll_up(buffer, lines)
    new_buffer
  end

  @doc """
  Scrolls the screen down by the specified number of lines.
  """
  def scroll_down(buffer, lines) do
    ScreenBuffer.scroll_down(buffer, lines)
  end

  @doc """
  Erases the display based on the specified mode.

  Mode values:
  * 0 - Erase from cursor to end of screen
  * 1 - Erase from start of screen to cursor
  * 2 - Erase entire screen
  * 3 - Erase entire screen and scrollback buffer
  """
  def erase_display(buffer, mode) do
    {x, y} = ScreenBuffer.get_cursor_position(buffer)
    {_width, height} = ScreenBuffer.get_dimensions(buffer)

    case mode do
      0 -> ScreenBuffer.erase_from_cursor_to_end(buffer, x, y, 0, height)
      1 -> ScreenBuffer.erase_from_start_to_cursor(buffer, x, y, 0, height)
      2 -> clear_screen(buffer)
      3 -> ScreenBuffer.erase_all(buffer)
    end
  end
end
