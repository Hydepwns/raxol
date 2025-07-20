defmodule Raxol.Terminal.Buffer.Operations do
  @moduledoc """
  Handles buffer operations for the terminal, including resizing, scrolling,
  and cursor movement.
  """

  import Raxol.Guards
  @behaviour Raxol.Terminal.Buffer.OperationsBehaviour

  alias Raxol.Terminal.Buffer.Cell
  alias Raxol.Terminal.Buffer.{Cursor, LineOperations}
  alias Raxol.Terminal.Emulator

  # Alias the new modules
  alias Raxol.Terminal.Buffer.Operations.{Text, Scrolling, Erasing, Utils}

  @doc """
  Resizes the buffer to the specified dimensions.
  """
  def resize(buffer, rows, cols)
      when list?(buffer) and is_integer(rows) and is_integer(cols) do
    Utils.resize(buffer, rows, cols)
  end

  @doc """
  Checks if scrolling is needed and performs it if necessary.
  """
  def maybe_scroll(buffer) when list?(buffer) do
    Scrolling.maybe_scroll(buffer)
  end

  @doc """
  Moves the cursor to the next line, scrolling if necessary.
  """
  def next_line(buffer) when list?(buffer) do
    Scrolling.next_line(buffer)
  end

  @doc """
  Moves the cursor to the previous line.
  """
  def reverse_index(buffer) when list?(buffer) do
    Scrolling.reverse_index(buffer)
  end

  @doc """
  Moves the cursor to the beginning of the next line.
  """
  def index(buffer) when list?(buffer) do
    Scrolling.index(buffer)
  end

  @doc """
  Scrolls the buffer up by the specified number of lines.
  """
  def scroll_up(buffer, lines, cursor_y, cursor_x)
      when list?(buffer) and is_integer(lines) and lines > 0 and
             is_integer(cursor_y) and is_integer(cursor_x) do
    Scrolling.scroll_up(buffer, lines, cursor_y, cursor_x)
  end

  def scroll_up(buffer, lines)
      when list?(buffer) and is_integer(lines) and lines > 0 do
    Scrolling.scroll_up(buffer, lines)
  end

  # Handle ScreenBuffer structs by extracting cells and calling the list version
  def scroll_up(%Raxol.Terminal.ScreenBuffer{} = buffer, lines)
      when is_integer(lines) and lines > 0 do
    Scrolling.scroll_up(buffer, lines)
  end

  # Handle ScreenBuffer structs with cursor position
  def scroll_up(
        %Raxol.Terminal.ScreenBuffer{} = buffer,
        lines,
        cursor_y,
        cursor_x
      )
      when is_integer(lines) and lines > 0 and
             is_integer(cursor_y) and is_integer(cursor_x) do
    Scrolling.scroll_up(buffer, lines, cursor_y, cursor_x)
  end

  @doc """
  Scrolls the buffer down by the specified number of lines.
  """
  def scroll_down(buffer, lines, cursor_y, cursor_x)
      when list?(buffer) and is_integer(lines) and lines > 0 and
             is_integer(cursor_y) and is_integer(cursor_x) do
    Scrolling.scroll_down(buffer, lines, cursor_y, cursor_x)
  end

  def scroll_down(buffer, lines)
      when list?(buffer) and is_integer(lines) and lines > 0 do
    Scrolling.scroll_down(buffer, lines)
  end

  # Handle ScreenBuffer structs by extracting cells and calling the list version
  def scroll_down(%Raxol.Terminal.ScreenBuffer{} = buffer, lines)
      when is_integer(lines) and lines > 0 do
    Scrolling.scroll_down(buffer, lines)
  end

  # Handle ScreenBuffer structs with cursor position
  def scroll_down(
        %Raxol.Terminal.ScreenBuffer{} = buffer,
        lines,
        cursor_y,
        cursor_x
      )
      when is_integer(lines) and lines > 0 and
             is_integer(cursor_y) and is_integer(cursor_x) do
    Scrolling.scroll_down(buffer, lines, cursor_y, cursor_x)
  end

  @doc """
  Inserts the specified number of blank lines at the cursor position.
  """
  def insert_lines(buffer, count, cursor_y, cursor_x)
      when list?(buffer) and is_integer(count) and count > 0 and
             is_integer(cursor_y) and is_integer(cursor_x) do
    Scrolling.insert_lines(buffer, count, cursor_y, cursor_x)
  end

  @doc """
  Inserts the specified number of blank lines at the cursor position with scroll region.
  """
  def insert_lines(buffer, count, cursor_y, cursor_x, scroll_top, scroll_bottom)
      when list?(buffer) and is_integer(count) and count > 0 and
             is_integer(cursor_y) and is_integer(cursor_x) and
             is_integer(scroll_top) and is_integer(scroll_bottom) do
    Scrolling.insert_lines(buffer, count, cursor_y, cursor_x, scroll_top, scroll_bottom)
  end

  def insert_lines(buffer, y, count, style)
      when is_struct(buffer, Raxol.Terminal.ScreenBuffer) and
             is_integer(y) and is_integer(count) and count > 0 and
             is_map(style) do
    Scrolling.insert_lines(buffer, y, count, style)
  end

  def insert_lines(buffer, lines, y, top, bottom)
      when is_struct(buffer, Raxol.Terminal.ScreenBuffer) and
             is_integer(lines) and is_integer(y) and lines > 0 and
             is_integer(top) and is_integer(bottom) do
    Scrolling.insert_lines(buffer, lines, y, top, bottom)
  end

  @doc """
  Deletes the specified number of lines at the cursor position.
  """
  def delete_lines(buffer, count, cursor_y, cursor_x)
      when list?(buffer) and is_integer(count) and count > 0 and
             is_integer(cursor_y) and is_integer(cursor_x) do
    Scrolling.delete_lines(buffer, count, cursor_y, cursor_x)
  end

  def delete_lines(buffer, count, cursor_y, cursor_x, scroll_top, scroll_bottom)
      when list?(buffer) and is_integer(count) and count > 0 and
             is_integer(cursor_y) and is_integer(cursor_x) and
             is_integer(scroll_top) and is_integer(scroll_bottom) do
    Scrolling.delete_lines(buffer, count, cursor_y, cursor_x, scroll_top, scroll_bottom)
  end

  def delete_lines(buffer, y, count, style, {top, bottom})
      when is_struct(buffer, Raxol.Terminal.ScreenBuffer) and
             is_integer(y) and is_integer(count) and count > 0 and
             is_map(style) and is_tuple({top, bottom}) do
    Scrolling.delete_lines(buffer, y, count, style, {top, bottom})
  end

  def delete_lines(buffer, lines, y, top, bottom)
      when is_struct(buffer, Raxol.Terminal.ScreenBuffer) and
             is_integer(lines) and is_integer(y) and lines > 0 and
             is_integer(top) and is_integer(bottom) do
    Scrolling.delete_lines(buffer, lines, y, top, bottom)
  end

  @doc """
  Erases characters in the current line based on the mode.
  """
  def erase_in_line(buffer, mode, cursor) do
    Erasing.erase_in_line(buffer, mode, cursor)
  end

  @doc """
  Erases characters in the display based on the mode.
  """
  def erase_in_display(buffer, mode, cursor) do
    Erasing.erase_in_display(buffer, mode, cursor)
  end

  defp update_emulator_if_needed(buffer, updated_buffer) do
    if Map.has_key?(buffer, :emulator_owner) and is_map(buffer.emulator_owner) do
      Emulator.update_active_buffer(buffer.emulator_owner, updated_buffer)
    else
      updated_buffer
    end
  end

  @doc """
  Writes a character to the buffer at the specified position.
  """
  # Handle ScreenBuffer structs - this is the main path used by the emulator
  def write_char(%Raxol.Terminal.ScreenBuffer{} = buffer, x, y, char, style)
      when is_integer(x) and is_integer(y) and is_binary(char) and is_map(style) do
    Text.write_char(buffer, x, y, char, style)
  end

  # Handle list buffers - this should only be used for internal operations
  def write_char(buffer, x, y, char, style)
      when list?(buffer) and is_integer(x) and is_integer(y) and
             is_binary(char) and is_map(style) do
    Text.write_char(buffer, x, y, char, style)
  end

  @doc """
  Inserts the specified number of blank characters at the cursor position.
  """
  def insert_chars(buffer, count)
      when list?(buffer) and is_integer(count) and count > 0 do
    Text.insert_chars(buffer, count)
  end

  @doc """
  Deletes the specified number of characters at the cursor position.
  """
  def delete_chars(buffer, count)
      when list?(buffer) and is_integer(count) and count > 0 do
    Text.delete_chars(buffer, count)
  end

  @doc """
  Creates a new buffer with the specified dimensions.
  """
  def new(opts) do
    Utils.new(opts)
  end

  @doc """
  Writes data to the buffer.
  """
  def write(buffer, data, opts \\ []) do
    Text.write(buffer, data, opts)
  end

  @doc """
  Reads data from the buffer.
  """
  def read(buffer, opts \\ []) do
    Utils.read(buffer, opts)
  end

  @doc """
  Scrolls the buffer by the specified number of lines.
  """
  def scroll(buffer, lines) do
    Scrolling.scroll(buffer, lines)
  end

  @doc """
  Writes a string to the buffer.
  """
  def write_string(buffer, x, y, string) do
    Text.write_string(buffer, x, y, string)
  end

  @doc """
  Gets the content of the buffer.
  """
  def get_content(buffer) do
    Utils.get_content(buffer)
  end

  # Delegation functions for backward compatibility

  @doc """
  Creates a new empty line with the specified number of columns.
  """
  def create_empty_line(cols) do
    Scrolling.create_empty_line(cols)
  end

  @doc """
  Erases characters from the cursor position to the end of the line.
  """
  def erase_from_cursor_to_line_end(buffer, row, col) do
    Erasing.erase_from_cursor_to_line_end(buffer, row, col)
  end

  @doc """
  Erases characters from the start of the line to the cursor position.
  """
  def erase_from_line_start_to_cursor(buffer, row, col) do
    Erasing.erase_from_line_start_to_cursor(buffer, row, col)
  end

  @doc """
  Erases the entire line.
  """
  def erase_entire_line(buffer, row) do
    Erasing.erase_entire_line(buffer, row)
  end

  @doc """
  Erases all lines after the specified row.
  """
  def erase_lines_after(buffer, start_row) do
    Erasing.erase_lines_after(buffer, start_row)
  end

  @doc """
  Erases all lines before the specified row.
  """
  def erase_lines_before(buffer, end_row) do
    Erasing.erase_lines_before(buffer, end_row)
  end

  @doc """
  Clears the scrollback buffer.
  """
  def clear_scrollback(buffer) do
    Erasing.clear_scrollback(buffer)
  end

  @doc """
  Checks if scrolling is needed based on buffer state.
  """
  def needs_scroll?(buffer) do
    Scrolling.needs_scroll?(buffer)
  end

  @doc """
  Gets a cell from the buffer at the specified coordinates.
  """
  def get_cell(buffer, x, y) do
    Utils.get_cell(buffer, x, y)
  end

  @doc """
  Fills a region of the buffer with a specified cell.
  """
  def fill_region(buffer, x, y, width, height, cell) do
    Utils.fill_region(buffer, x, y, width, height, cell)
  end
end
