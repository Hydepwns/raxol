defmodule Raxol.Terminal.Commands.Editor do
  @moduledoc """
  Handles editor operations for the terminal buffer.

  This module provides functions for inserting and deleting lines and characters,
  as well as erasing characters in the terminal buffer. It also handles screen
  and line operations like clearing the screen or parts of it.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Buffer.{LineEditor, CharEditor, Eraser}
  alias Raxol.Terminal.ANSI.TextFormatting

  @doc """
  Inserts a specified number of blank lines at the current cursor position.
  Lines below the cursor are shifted down, and lines shifted off the bottom are discarded.
  """
  @spec insert_lines(ScreenBuffer.t(), non_neg_integer(), non_neg_integer(), TextFormatting.text_style()) :: ScreenBuffer.t()
  def insert_lines(buffer, row, count, default_style) do
    LineEditor.insert_lines(buffer, row, count, default_style)
  end

  @doc """
  Deletes a specified number of lines starting from the current cursor position.
  Lines below the deleted lines are shifted up, and blank lines are added at the bottom.
  """
  @spec delete_lines(ScreenBuffer.t(), non_neg_integer(), non_neg_integer(), TextFormatting.text_style()) :: ScreenBuffer.t()
  def delete_lines(buffer, row, count, default_style) do
    LineEditor.delete_lines(buffer, row, count, default_style)
  end

  @doc """
  Inserts a specified number of blank characters at the current cursor position.
  Characters to the right of the cursor are shifted right, and characters shifted off the end are discarded.
  """
  @spec insert_chars(ScreenBuffer.t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), TextFormatting.text_style()) :: ScreenBuffer.t()
  def insert_chars(buffer, row, col, count, default_style) do
    CharEditor.insert_characters(buffer, row, col, count, default_style)
  end

  @doc """
  Deletes a specified number of characters starting from the current cursor position.
  Characters to the right of the deleted characters are shifted left, and blank characters are added at the end.
  """
  @spec delete_chars(ScreenBuffer.t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), TextFormatting.text_style()) :: ScreenBuffer.t()
  def delete_chars(buffer, row, col, count, default_style) do
    CharEditor.delete_characters(buffer, row, col, count, default_style)
  end

  @doc """
  Erases a specified number of characters starting from the current cursor position.
  Characters are replaced with blank spaces using the default style.
  """
  @spec erase_chars(ScreenBuffer.t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), TextFormatting.text_style()) :: ScreenBuffer.t()
  def erase_chars(buffer, row, col, count, default_style) do
    # First delete the characters
    buffer = delete_chars(buffer, row, col, count, default_style)
    # Then insert blank characters
    insert_chars(buffer, row, col, count, default_style)
  end

  @doc """
  Clears the screen or a part of it based on the mode parameter.

  ## Parameters

  * `buffer` - The current screen buffer
  * `cursor_pos` - The current cursor position {x, y}
  * `mode` - The clear mode:
    * 0 - Clear from cursor to end of screen
    * 1 - Clear from beginning of screen to cursor
    * 2 - Clear entire screen but don't move cursor
    * 3 - Clear entire screen including scrollback
  * `default_style` - The style to use for cleared areas

  ## Returns

  * Updated screen buffer
  """
  @spec clear_screen(ScreenBuffer.t(), {non_neg_integer(), non_neg_integer()}, integer(), TextFormatting.text_style()) :: ScreenBuffer.t()
  def clear_screen(buffer, cursor_pos, mode, default_style) do
    case mode do
      0 -> Eraser.clear_screen_from(buffer, cursor_pos, default_style)
      1 -> Eraser.clear_screen_to(buffer, cursor_pos, default_style)
      2 -> Eraser.clear_screen(buffer, default_style)
      3 -> clear_screen_with_scrollback(buffer, default_style)
      _ -> buffer
    end
  end

  @doc """
  Clears a line or a part of it based on the mode parameter.

  ## Parameters

  * `buffer` - The current screen buffer
  * `cursor_pos` - The current cursor position {x, y}
  * `mode` - The clear mode:
    * 0 - Clear from cursor to end of line
    * 1 - Clear from beginning of line to cursor
    * 2 - Clear entire line
  * `default_style` - The style to use for cleared areas

  ## Returns

  * Updated screen buffer
  """
  @spec clear_line(ScreenBuffer.t(), {non_neg_integer(), non_neg_integer()}, integer(), TextFormatting.text_style()) :: ScreenBuffer.t()
  def clear_line(buffer, cursor_pos, mode, default_style) do
    case mode do
      0 -> Eraser.clear_line_from(buffer, cursor_pos, default_style)
      1 -> Eraser.clear_line_to(buffer, cursor_pos, default_style)
      2 -> Eraser.clear_line(buffer, elem(cursor_pos, 1), default_style)
      _ -> buffer
    end
  end

  @doc """
  Clears a rectangular region of the screen.

  ## Parameters

  * `buffer` - The current screen buffer
  * `start_x` - Starting x coordinate
  * `start_y` - Starting y coordinate
  * `end_x` - Ending x coordinate
  * `end_y` - Ending y coordinate
  * `default_style` - The style to use for cleared areas

  ## Returns

  * Updated screen buffer
  """
  @spec clear_region(ScreenBuffer.t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer(), TextFormatting.text_style()) :: ScreenBuffer.t()
  def clear_region(buffer, start_x, start_y, end_x, end_y, default_style) do
    Eraser.clear_region(buffer, start_x, start_y, end_x, end_y, default_style)
  end

  # Private helper function to clear screen and scrollback
  defp clear_screen_with_scrollback(buffer, default_style) do
    # First clear the screen
    buffer = Eraser.clear_screen(buffer, default_style)
    # Then clear the scrollback
    %{buffer | scrollback: []}
  end
end
