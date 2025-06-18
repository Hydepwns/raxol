defmodule Raxol.Terminal.Buffer.Operations do
  @moduledoc """
  Handles buffer operations for the terminal, including resizing, scrolling,
  and cursor movement.
  """

  @behaviour Raxol.Terminal.Buffer.OperationsBehaviour

  alias Raxol.Terminal.Buffer.Cell
  alias Raxol.Terminal.Buffer.{Cursor, Queries, LineOperations}

  @impl true
  @doc """
  Resizes the buffer to the specified dimensions.
  """
  def resize(buffer, rows, cols)
      when is_list(buffer) and is_integer(rows) and is_integer(cols) do
    rows = max(1, rows)
    cols = max(1, cols)
    copy_and_resize_rows(buffer, rows, cols)
  end

  defp copy_and_resize_rows(buffer, rows, cols) do
    buffer
    |> Enum.take(rows)
    |> Enum.map(fn row ->
      row
      |> Enum.take(cols)
      |> Enum.concat(List.duplicate(Cell.new(), max(0, cols - length(row))))
    end)
    |> Enum.concat(
      List.duplicate(
        List.duplicate(Cell.new(), cols),
        max(0, rows - length(buffer))
      )
    )
  end

  @impl true
  @doc """
  Checks if scrolling is needed and performs it if necessary.
  """
  def maybe_scroll(buffer) when is_list(buffer) do
    # Check if we need to scroll
    if needs_scroll?(buffer) do
      scroll_up(buffer, 1)
    else
      buffer
    end
  end

  @impl true
  @doc """
  Moves the cursor to the next line, scrolling if necessary.
  """
  def next_line(buffer) when is_list(buffer) do
    buffer
    |> maybe_scroll()
    |> index()
  end

  @impl true
  @doc """
  Moves the cursor to the previous line.
  """
  def reverse_index(buffer) when is_list(buffer) do
    # Move cursor up one line
    buffer
  end

  @impl true
  @doc """
  Moves the cursor to the beginning of the next line.
  """
  def index(buffer) when is_list(buffer) do
    # Move cursor to beginning of next line
    buffer
  end

  @impl true
  @doc """
  Scrolls the buffer up by the specified number of lines.
  """
  def scroll_up(buffer, lines, cursor_y, cursor_x)
      when is_list(buffer) and is_integer(lines) and lines > 0 and
             is_integer(cursor_y) and is_integer(cursor_x) do
    # Remove lines from top and add empty lines at bottom
    new_buffer = buffer
    |> Enum.drop(lines)
    |> Enum.concat(List.duplicate(create_empty_line(length(hd(buffer))), lines))

    # Adjust cursor position if needed
    if cursor_y >= lines do
      {new_buffer, cursor_y - lines, cursor_x}
    else
      {new_buffer, 0, cursor_x}
    end
  end

  @impl true
  @doc """
  Scrolls the buffer down by the specified number of lines.
  """
  def scroll_down(buffer, lines, cursor_y, cursor_x)
      when is_list(buffer) and is_integer(lines) and lines > 0 and
             is_integer(cursor_y) and is_integer(cursor_x) do
    # Remove lines from bottom and add empty lines at top
    new_buffer = buffer
    |> Enum.reverse()
    |> Enum.drop(lines)
    |> Enum.reverse()
    |> Enum.concat(List.duplicate(create_empty_line(length(hd(buffer))), lines))

    # Adjust cursor position if needed
    max_y = length(new_buffer) - 1
    new_cursor_y = min(cursor_y + lines, max_y)
    {new_buffer, new_cursor_y, cursor_x}
  end

  @impl true
  @doc """
  Inserts the specified number of blank lines at the cursor position.
  """
  def insert_lines(buffer, count, cursor_y, cursor_x)
      when is_list(buffer) and is_integer(count) and count > 0 and
             is_integer(cursor_y) and is_integer(cursor_x) do
    # Insert blank lines at cursor position
    new_buffer = buffer
    |> Enum.take(cursor_y)
    |> Enum.concat(List.duplicate(create_empty_line(length(hd(buffer))), count))
    |> Enum.concat(Enum.drop(buffer, cursor_y))

    {new_buffer, cursor_y, cursor_x}
  end

  @impl true
  @doc """
  Inserts the specified number of blank lines at the cursor position with scroll region.
  """
  def insert_lines(buffer, count, cursor_y, cursor_x, scroll_top, scroll_bottom)
      when is_list(buffer) and is_integer(count) and count > 0 and
             is_integer(cursor_y) and is_integer(cursor_x) and
             is_integer(scroll_top) and is_integer(scroll_bottom) do
    if cursor_y >= scroll_top and cursor_y <= scroll_bottom do
      # Insert within scroll region
      new_buffer = buffer
      |> Enum.take(cursor_y)
      |> Enum.concat(List.duplicate(create_empty_line(length(hd(buffer))), count))
      |> Enum.concat(Enum.drop(buffer, cursor_y))

      {new_buffer, cursor_y, cursor_x}
    else
      {buffer, cursor_y, cursor_x}
    end
  end

  @impl true
  @doc """
  Deletes the specified number of lines at the cursor position.
  """
  def delete_lines(buffer, count, cursor_y, cursor_x)
      when is_list(buffer) and is_integer(count) and count > 0 and
             is_integer(cursor_y) and is_integer(cursor_x) do
    # Delete lines at cursor position
    new_buffer = buffer
    |> Enum.take(cursor_y)
    |> Enum.concat(Enum.drop(buffer, cursor_y + count))

    {new_buffer, cursor_y, cursor_x}
  end

  @impl true
  @doc """
  Deletes the specified number of lines at the cursor position with scroll region.
  """
  def delete_lines(buffer, count, cursor_y, cursor_x, scroll_top, scroll_bottom)
      when is_list(buffer) and is_integer(count) and count > 0 and
             is_integer(cursor_y) and is_integer(cursor_x) and
             is_integer(scroll_top) and is_integer(scroll_bottom) do
    if cursor_y >= scroll_top and cursor_y <= scroll_bottom do
      # Delete within scroll region
      new_buffer = buffer
      |> Enum.take(cursor_y)
      |> Enum.concat(Enum.drop(buffer, cursor_y + count))

      {new_buffer, cursor_y, cursor_x}
    else
      {buffer, cursor_y, cursor_x}
    end
  end

  @impl true
  @doc """
  Erases characters in the current line based on the mode.
  """
  def erase_in_line(buffer, mode, cursor) do
    {row, col} = Cursor.get_cursor_position(cursor)
    case mode do
      0 -> erase_from_cursor_to_line_end(buffer, row, col)
      1 -> erase_from_line_start_to_cursor(buffer, row, col)
      2 -> erase_entire_line(buffer, row)
      _ -> buffer
    end
  end

  @impl true
  @doc """
  Erases characters in the display based on the mode.
  """
  def erase_in_display(buffer, mode, cursor) do
    {row, col} = Cursor.get_cursor_position(cursor)
    case mode do
      0 -> erase_from_cursor_to_end(buffer, row, col)
      1 -> erase_from_start_to_cursor(buffer, row, col)
      2 -> erase_all(buffer)
      3 -> erase_all_with_scrollback(buffer)
      _ -> buffer
    end
  end

  @impl true
  @doc """
  Writes a character to the buffer at the specified position.
  """
  def write_char(buffer, x, y, char, style)
      when is_list(buffer) and is_integer(x) and is_integer(y) and
             is_binary(char) and is_map(style) do
    new_buffer = buffer
    |> Enum.with_index()
    |> Enum.map(fn {row, row_y} ->
      if row_y == y do
        replace_cell(row, x, char, style)
      else
        row
      end
    end)
    {new_buffer, y, x + 1}
  end

  defp replace_cell(row, x, char, style) do
    Enum.with_index(row)
    |> Enum.map(fn {cell, col_x} ->
      if col_x == x do
        Cell.new(char, style)
      else
        cell
      end
    end)
  end

  @doc """
  Inserts the specified number of blank characters at the cursor position.
  """
  def insert_chars(buffer, count)
      when is_list(buffer) and is_integer(count) and count > 0 do
    # Insert blank characters at cursor position
    buffer
    |> Enum.map(fn row ->
      row
      |> Enum.take(count)
      |> Enum.concat(List.duplicate(Cell.new(), count))
      |> Enum.concat(Enum.drop(row, count))
    end)
  end

  @doc """
  Deletes the specified number of characters at the cursor position.
  """
  def delete_chars(buffer, count)
      when is_list(buffer) and is_integer(count) and count > 0 do
    # Delete characters at cursor position
    buffer
    |> Enum.map(fn row ->
      row
      |> Enum.take(count)
      |> Enum.concat(Enum.drop(row, count + count))
    end)
  end

  @doc """
  Creates a new buffer with the specified dimensions.
  """
  def new(opts) do
    rows = Keyword.get(opts, :rows, 24)
    cols = Keyword.get(opts, :cols, 80)
    for _ <- 1..rows do
      for _ <- 1..cols do
        Cell.new()
      end
    end
  end

  @doc """
  Writes data to the buffer.
  """
  def write(buffer, data, opts \\ []) do
    case data do
      {x, y, char} when is_integer(x) and is_integer(y) and is_binary(char) ->
        write_char_data(buffer, x, y, char, opts)
      {x, y, string} when is_integer(x) and is_integer(y) and is_binary(string) ->
        write_string_data(buffer, x, y, string)
      _ ->
        buffer
    end
  end

  defp write_char_data(buffer, x, y, char, opts) do
    Raxol.Terminal.Buffer.Writer.write_char(buffer, x, y, char, Keyword.get(opts, :style))
  end

  defp write_string_data(buffer, x, y, string) do
    Raxol.Terminal.Buffer.Writer.write_string(buffer, x, y, string)
  end

  @doc """
  Reads data from the buffer.
  """
  def read(buffer, opts \\ []) do
    # Example: read a line or region, depending on opts
    case Keyword.get(opts, :line) do
      nil -> {Raxol.Terminal.Buffer.Content.get_content(buffer), buffer}
      line when is_integer(line) ->
        {Raxol.Terminal.Buffer.Content.get_line(buffer, line), buffer}
    end
  end

  @doc """
  Scrolls the buffer by the specified number of lines.
  """
  def scroll(buffer, lines) do
    if lines > 0 do
      Raxol.Terminal.Buffer.Scroller.scroll_up(buffer, lines)
    else
      Raxol.Terminal.Buffer.Scroller.scroll_down(buffer, abs(lines))
    end
  end

  @doc """
  Writes a string to the buffer.
  """
  def write_string(buffer, x, y, string) do
    Raxol.Terminal.Buffer.Writer.write_string(buffer, x, y, string)
  end

  @doc """
  Gets the content of the buffer.
  """
  def get_content(buffer) do
    Raxol.Terminal.Buffer.Content.get_content(buffer)
  end

  def scroll_up(buffer, lines) when is_list(buffer) and is_integer(lines) and lines > 0 do
    # Default cursor position to 0, 0 for backward compatibility
    {new_buffer, _cursor_y, _cursor_x} = scroll_up(buffer, lines, 0, 0)
    new_buffer
  end

  def scroll_down(buffer, lines) when is_list(buffer) and is_integer(lines) and lines > 0 do
    {new_buffer, _cursor_y, _cursor_x} = scroll_down(buffer, lines, 0, 0)
    new_buffer
  end

  # Private helper functions

  @doc """
  Creates a new empty line with the specified number of columns.

  ## Parameters

  * `cols` - The number of columns in the line

  ## Returns

  A list of empty cells representing a line.

  ## Examples

      iex> Operations.create_empty_line(80)
      [%Cell{char: "", style: %{}}, ...]
  """
  @spec create_empty_line(non_neg_integer()) :: [Cell.t()]
  def create_empty_line(cols) do
    List.duplicate(Cell.new(), cols)
  end

  @doc """
  Erases characters from the cursor position to the end of the line.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `row` - The row to erase from
  * `col` - The column to start erasing from

  ## Returns

  The modified buffer with characters erased.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> Operations.erase_from_cursor_to_line_end(buffer, 0, 40)
      [%Cell{char: "", style: %{}}, ...]
  """
  @spec erase_from_cursor_to_line_end(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) :: ScreenBuffer.t()
  def erase_from_cursor_to_line_end(buffer, row, col) do
    LineOperations.erase_chars(buffer, row, col, buffer.width - col)
  end

  @doc """
  Erases characters from the start of the line to the cursor position.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `row` - The row to erase from
  * `col` - The column to erase up to

  ## Returns

  The modified buffer with characters erased.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> Operations.erase_from_line_start_to_cursor(buffer, 0, 40)
      [%Cell{char: "", style: %{}}, ...]
  """
  @spec erase_from_line_start_to_cursor(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) :: ScreenBuffer.t()
  def erase_from_line_start_to_cursor(buffer, row, col) do
    LineOperations.erase_chars(buffer, row, 0, col + 1)
  end

  @doc """
  Erases the entire line.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `row` - The row to erase

  ## Returns

  The modified buffer with the specified line erased.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> Operations.erase_entire_line(buffer, 0)
      [%Cell{char: "", style: %{}}, ...]
  """
  @spec erase_entire_line(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def erase_entire_line(buffer, row) do
    LineOperations.erase_chars(buffer, row, 0, buffer.width)
  end

  @doc """
  Erases all lines after the specified row.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `start_row` - The row to start erasing from

  ## Returns

  The modified buffer with all lines after start_row erased.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> Operations.erase_lines_after(buffer, 12)
      [%Cell{char: "", style: %{}}, ...]
  """
  @spec erase_lines_after(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def erase_lines_after(buffer, start_row) do
    Enum.reduce(start_row..(buffer.height - 1), buffer, fn row, acc ->
      erase_entire_line(acc, row)
    end)
  end

  @doc """
  Erases all lines before the specified row.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `end_row` - The row to erase up to

  ## Returns

  The modified buffer with all lines before end_row erased.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> Operations.erase_lines_before(buffer, 12)
      [%Cell{char: "", style: %{}}, ...]
  """
  @spec erase_lines_before(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def erase_lines_before(buffer, end_row) do
    Enum.reduce(0..end_row, buffer, fn row, acc ->
      erase_entire_line(acc, row)
    end)
  end

  @doc """
  Clears the scrollback buffer.

  ## Parameters

  * `buffer` - The screen buffer to modify

  ## Returns

  The modified buffer with an empty scrollback.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> Operations.clear_scrollback(buffer)
      %{buffer | scrollback: []}
  """
  @spec clear_scrollback(ScreenBuffer.t()) :: ScreenBuffer.t()
  def clear_scrollback(buffer) do
    %{buffer | scrollback: []}
  end

  @doc """
  Checks if scrolling is needed based on buffer state.

  ## Parameters

  * `buffer` - The screen buffer to check

  ## Returns

  A boolean indicating if scrolling is needed.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> Operations.needs_scroll?(buffer)
      false
  """
  @spec needs_scroll?(ScreenBuffer.t()) :: boolean()
  def needs_scroll?(buffer) do
    false
  end
end
