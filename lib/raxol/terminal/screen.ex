defmodule Raxol.Terminal.Screen do
  @moduledoc """
  Provides screen manipulation functions for the terminal emulator.
  This module handles operations like resizing, marking damaged regions,
  and clearing the screen.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.ANSI.TextFormatting

  @doc """
  Resizes the screen buffer to new dimensions.
  """
  @spec resize(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          ScreenBuffer.t()
  def resize(buffer, width, height) do
    ScreenBuffer.resize(buffer, width, height)
  end

  @doc """
  Marks a region of the screen as damaged.
  """
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

  @doc """
  Clears the entire screen.
  """
  @spec clear_screen(ScreenBuffer.t()) :: ScreenBuffer.t()
  def clear_screen(buffer) do
    ScreenBuffer.clear(buffer, TextFormatting.new())
  end

  @doc """
  Clears a specific line in the screen.
  """
  @spec clear_line(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def clear_line(buffer, line) do
    ScreenBuffer.clear_line(buffer, line, TextFormatting.new())
  end

  @doc """
  Inserts lines at the current cursor position.
  """
  @spec insert_lines(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def insert_lines(buffer, count) do
    ScreenBuffer.insert_lines(buffer, count)
  end

  @doc """
  Deletes lines at the current cursor position.
  """
  @spec delete_lines(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def delete_lines(buffer, count) do
    ScreenBuffer.delete_lines(buffer, count)
  end

  @doc """
  Inserts characters at the current cursor position.
  """
  @spec insert_chars(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def insert_chars(buffer, count) do
    ScreenBuffer.insert_chars(buffer, count)
  end

  @doc """
  Deletes characters at the current cursor position.
  """
  @spec delete_chars(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def delete_chars(buffer, count) do
    ScreenBuffer.delete_chars(buffer, count)
  end

  @doc """
  Erases characters at the current cursor position.
  """
  @spec erase_chars(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def erase_chars(buffer, count) do
    ScreenBuffer.erase_chars(buffer, count)
  end

  @doc """
  Scrolls the screen up by the specified number of lines.
  """
  @spec scroll_up_screen(ScreenBuffer.t(), non_neg_integer()) ::
          ScreenBuffer.t()
  def scroll_up_screen(buffer, lines) do
    ScreenBuffer.scroll_up(buffer, lines)
  end

  @doc """
  Scrolls the screen down by the specified number of lines.
  """
  @spec scroll_down(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
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
