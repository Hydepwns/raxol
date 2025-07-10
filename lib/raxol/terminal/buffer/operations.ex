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

  @doc """
  Resizes the buffer to the specified dimensions.
  """
  def resize(buffer, rows, cols)
      when list?(buffer) and is_integer(rows) and is_integer(cols) do
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

  @doc """
  Checks if scrolling is needed and performs it if necessary.
  """
  def maybe_scroll(buffer) when list?(buffer) do
    # Check if we need to scroll
    if needs_scroll?(buffer) do
      scroll_up(buffer, 1)
    else
      buffer
    end
  end

  @doc """
  Moves the cursor to the next line, scrolling if necessary.
  """
  def next_line(buffer) when list?(buffer) do
    buffer
    |> maybe_scroll()
    |> index()
  end

  @doc """
  Moves the cursor to the previous line.
  """
  def reverse_index(buffer) when list?(buffer) do
    # Move cursor up one line
    buffer
  end

  @doc """
  Moves the cursor to the beginning of the next line.
  """
  def index(buffer) when list?(buffer) do
    # Move cursor to beginning of next line
    buffer
  end

  @doc """
  Scrolls the buffer up by the specified number of lines.
  """
  def scroll_up(buffer, lines, cursor_y, cursor_x)
      when list?(buffer) and is_integer(lines) and lines > 0 and
             is_integer(cursor_y) and is_integer(cursor_x) do
    # Remove lines from top and add empty lines at bottom
    new_buffer =
      buffer
      |> Enum.drop(lines)
      |> Enum.concat(
        List.duplicate(create_empty_line(length(hd(buffer))), lines)
      )

    # Adjust cursor position if needed
    if cursor_y >= lines do
      {new_buffer, cursor_y - lines, cursor_x}
    else
      {new_buffer, 0, cursor_x}
    end
  end

  def scroll_up(buffer, lines)
      when list?(buffer) and is_integer(lines) and lines > 0 do
    # Default cursor position to 0, 0 for backward compatibility
    {new_buffer, _cursor_y, _cursor_x} = scroll_up(buffer, lines, 0, 0)
    new_buffer
  end

  # Handle ScreenBuffer structs by extracting cells and calling the list version
  def scroll_up(%Raxol.Terminal.ScreenBuffer{} = buffer, lines)
      when is_integer(lines) and lines > 0 do
    # Extract cells from ScreenBuffer and call the list version
    {new_cells, _cursor_y, _cursor_x} = scroll_up(buffer.cells, lines, 0, 0)
    %{buffer | cells: new_cells}
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
    # Extract cells from ScreenBuffer and call the list version
    {new_cells, new_cursor_y, new_cursor_x} =
      scroll_up(buffer.cells, lines, cursor_y, cursor_x)

    {%{buffer | cells: new_cells}, new_cursor_y, new_cursor_x}
  end

  @doc """
  Scrolls the buffer down by the specified number of lines.
  """
  def scroll_down(buffer, lines, cursor_y, cursor_x)
      when list?(buffer) and is_integer(lines) and lines > 0 and
             is_integer(cursor_y) and is_integer(cursor_x) do
    # Remove lines from bottom and add empty lines at top
    new_buffer =
      buffer
      |> Enum.reverse()
      |> Enum.drop(lines)
      |> Enum.reverse()
      |> Enum.concat(
        List.duplicate(create_empty_line(length(hd(buffer))), lines)
      )

    # Adjust cursor position if needed
    max_y = length(new_buffer) - 1
    new_cursor_y = min(cursor_y + lines, max_y)
    {new_buffer, new_cursor_y, cursor_x}
  end

  def scroll_down(buffer, lines)
      when list?(buffer) and is_integer(lines) and lines > 0 do
    {new_buffer, _cursor_y, _cursor_x} = scroll_down(buffer, lines, 0, 0)
    new_buffer
  end

  # Handle ScreenBuffer structs by extracting cells and calling the list version
  def scroll_down(%Raxol.Terminal.ScreenBuffer{} = buffer, lines)
      when is_integer(lines) and lines > 0 do
    # Extract cells from ScreenBuffer and call the list version
    {new_cells, _cursor_y, _cursor_x} = scroll_down(buffer.cells, lines, 0, 0)
    %{buffer | cells: new_cells}
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
    # Extract cells from ScreenBuffer and call the list version
    {new_cells, new_cursor_y, new_cursor_x} =
      scroll_down(buffer.cells, lines, cursor_y, cursor_x)

    {%{buffer | cells: new_cells}, new_cursor_y, new_cursor_x}
  end

  @doc """
  Inserts the specified number of blank lines at the cursor position.
  """
  def insert_lines(buffer, count, cursor_y, cursor_x)
      when list?(buffer) and is_integer(count) and count > 0 and
             is_integer(cursor_y) and is_integer(cursor_x) do
    # Insert blank lines at cursor position
    new_buffer =
      buffer
      |> Enum.take(cursor_y)
      |> Enum.concat(
        List.duplicate(create_empty_line(length(hd(buffer))), count)
      )
      |> Enum.concat(Enum.drop(buffer, cursor_y))

    {new_buffer, cursor_y, cursor_x}
  end

  @doc """
  Inserts the specified number of blank lines at the cursor position with scroll region.
  """
  def insert_lines(buffer, count, cursor_y, cursor_x, scroll_top, scroll_bottom)
      when list?(buffer) and is_integer(count) and count > 0 and
             is_integer(cursor_y) and is_integer(cursor_x) and
             is_integer(scroll_top) and is_integer(scroll_bottom) do
    if cursor_y >= scroll_top and cursor_y <= scroll_bottom do
      # Insert within scroll region
      new_buffer =
        buffer
        |> Enum.take(cursor_y)
        |> Enum.concat(
          List.duplicate(create_empty_line(length(hd(buffer))), count)
        )
        |> Enum.concat(Enum.drop(buffer, cursor_y))

      {new_buffer, cursor_y, cursor_x}
    else
      {buffer, cursor_y, cursor_x}
    end
  end

  def insert_lines(buffer, y, count, style)
      when is_struct(buffer, Raxol.Terminal.ScreenBuffer) and
             is_integer(y) and is_integer(count) and count > 0 and
             is_map(style) do
    # For ScreenBuffer structs, delegate to LineOperations
    Raxol.Terminal.Buffer.LineOperations.insert_lines(buffer, y, count, style)
  end

  def insert_lines(buffer, lines, y, top, bottom)
      when is_struct(buffer, Raxol.Terminal.ScreenBuffer) and
             is_integer(lines) and is_integer(y) and lines > 0 and
             is_integer(top) and is_integer(bottom) do
    # For ScreenBuffer structs, delegate to LineOperations
    Raxol.Terminal.Buffer.LineOperations.insert_lines(
      buffer,
      lines,
      y,
      top,
      bottom
    )
  end

  @doc """
  Deletes the specified number of lines at the cursor position.
  """
  def delete_lines(buffer, count, cursor_y, cursor_x)
      when list?(buffer) and is_integer(count) and count > 0 and
             is_integer(cursor_y) and is_integer(cursor_x) do
    # Delete lines at cursor position
    new_buffer =
      buffer
      |> Enum.take(cursor_y)
      |> Enum.concat(Enum.drop(buffer, cursor_y + count))

    {new_buffer, cursor_y, cursor_x}
  end

  def delete_lines(buffer, count, cursor_y, cursor_x, scroll_top, scroll_bottom)
      when list?(buffer) and is_integer(count) and count > 0 and
             is_integer(cursor_y) and is_integer(cursor_x) and
             is_integer(scroll_top) and is_integer(scroll_bottom) do
    if cursor_y >= scroll_top and cursor_y <= scroll_bottom do
      # Delete within scroll region
      new_buffer =
        buffer
        |> Enum.take(cursor_y)
        |> Enum.concat(Enum.drop(buffer, cursor_y + count))

      {new_buffer, cursor_y, cursor_x}
    else
      {buffer, cursor_y, cursor_x}
    end
  end

  def delete_lines(buffer, y, count, style, {top, bottom})
      when is_struct(buffer, Raxol.Terminal.ScreenBuffer) and
             is_integer(y) and is_integer(count) and count > 0 and
             is_map(style) and is_tuple({top, bottom}) do
    # For ScreenBuffer structs, delegate to LineOperations
    Raxol.Terminal.Buffer.LineOperations.delete_lines(
      buffer,
      y,
      count,
      style,
      {top, bottom}
    )
  end

  def delete_lines(buffer, lines, y, top, bottom)
      when is_struct(buffer, Raxol.Terminal.ScreenBuffer) and
             is_integer(lines) and is_integer(y) and lines > 0 and
             is_integer(top) and is_integer(bottom) do
    # For ScreenBuffer structs, delegate to LineOperations
    Raxol.Terminal.Buffer.LineOperations.delete_lines(
      buffer,
      lines,
      y,
      top,
      bottom
    )
  end

  @doc """
  Erases characters in the current line based on the mode.
  """
  def erase_in_line(buffer, mode, cursor) do
    {row, col} = get_cursor_position(cursor)

    cond do
      is_struct(buffer, Raxol.Terminal.ScreenBuffer) ->
        updated_cells = erase_in_line_cells(buffer.cells, mode, row, col)
        %{buffer | cells: updated_cells}

      is_list(buffer) ->
        case mode do
          0 -> erase_from_cursor_to_line_end(buffer, row, col)
          1 -> erase_from_line_start_to_cursor(buffer, row, col)
          2 -> erase_entire_line(buffer, row)
          _ -> buffer
        end

      true ->
        buffer
    end
  end

  @doc """
  Erases characters in the display based on the mode.
  """
  def erase_in_display(buffer, mode, cursor) do
    {row, col} = get_cursor_position(cursor)

    cond do
      is_struct(buffer, Raxol.Terminal.ScreenBuffer) ->
        updated_cells = erase_in_display_cells(buffer.cells, mode, row, col)
        updated_buffer = %{buffer | cells: updated_cells}

        # If called from an emulator, ensure the emulator's active buffer is updated
        if Map.has_key?(buffer, :emulator_owner) and
             is_map(buffer.emulator_owner) do
          Emulator.update_active_buffer(buffer.emulator_owner, updated_buffer)
        else
          updated_buffer
        end

      is_list(buffer) ->
        case mode do
          0 -> erase_from_cursor_to_end(buffer, row, col)
          1 -> erase_from_start_to_cursor(buffer, row, col)
          2 -> erase_all(buffer)
          3 -> erase_all_with_scrollback(buffer)
          _ -> buffer
        end

      true ->
        buffer
    end
  end

  # Helper functions for cell-based operations
  defp erase_in_line_cells(cells, mode, row, col) do
    case mode do
      0 -> erase_from_cursor_to_line_end(cells, row, col)
      1 -> erase_from_line_start_to_cursor(cells, row, col)
      2 -> erase_entire_line(cells, row)
      _ -> cells
    end
  end

  defp erase_in_display_cells(cells, mode, row, col) do
    case mode do
      0 -> erase_from_cursor_to_end(cells, row, col)
      1 -> erase_from_start_to_cursor(cells, row, col)
      2 -> erase_all(cells)
      3 -> erase_all_with_scrollback(cells)
      _ -> cells
    end
  end

  # Helper to extract position from cursor struct or GenServer PID
  defp get_cursor_position(%Raxol.Terminal.Cursor.Manager{} = cursor),
    do: cursor.position

  defp get_cursor_position(pid) when is_pid(pid),
    do: Raxol.Terminal.Cursor.Manager.get_position(pid)

  defp get_cursor_position(_), do: {0, 0}

  @doc """
  Writes a character to the buffer at the specified position.
  """
  # Handle ScreenBuffer structs - this is the main path used by the emulator
  def write_char(%Raxol.Terminal.ScreenBuffer{} = buffer, x, y, char, style)
      when is_integer(x) and is_integer(y) and is_binary(char) and is_map(style) do
    # Use the ScreenBuffer's own write_char implementation
    Raxol.Terminal.ScreenBuffer.write_char(buffer, x, y, char, style)
  end

  # Handle list buffers - this should only be used for internal operations
  def write_char(buffer, x, y, char, style)
      when list?(buffer) and is_integer(x) and is_integer(y) and
             is_binary(char) and is_map(style) do
    new_buffer =
      buffer
      |> Enum.with_index()
      |> Enum.map(fn {row, row_y} ->
        if row_y == y do
          replace_cell(row, x, char, style)
        else
          row
        end
      end)

    # Return just the buffer, not a tuple, to avoid corruption
    new_buffer
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
      when list?(buffer) and is_integer(count) and count > 0 do
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
      when list?(buffer) and is_integer(count) and count > 0 do
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
  def write(buffer, data, opts \\ [])

  def write(%Raxol.Terminal.Buffer.Manager.BufferImpl{} = buffer, data, opts) do
    # Handle BufferImpl structs
    case classify_data(data) do
      {:char, x, y, char} ->
        cell = Raxol.Terminal.Cell.new(char, Keyword.get(opts, :style))
        Raxol.Terminal.Buffer.Manager.BufferImpl.set_cell(buffer, x, y, cell)

      {:string, x, y, string} ->
        # For strings, write character by character starting at x, y
        Enum.reduce(Enum.with_index(String.graphemes(string)), buffer, fn {char,
                                                                           index},
                                                                          acc_buffer ->
          cell = Raxol.Terminal.Cell.new(char, Keyword.get(opts, :style))

          Raxol.Terminal.Buffer.Manager.BufferImpl.set_cell(
            acc_buffer,
            x + index,
            y,
            cell
          )
        end)

      :unknown ->
        # If data is just a string, treat it as content to add at cursor position
        if is_binary(data) do
          Raxol.Terminal.Buffer.Manager.BufferImpl.add(buffer, data)
        else
          buffer
        end
    end
  end

  def write(buffer, data, opts) do
    case classify_data(data) do
      {:char, x, y, char} -> write_char_data(buffer, x, y, char, opts)
      {:string, x, y, string} -> write_string_data(buffer, x, y, string)
      :unknown -> buffer
    end
  end

  defp classify_data({x, y, char})
       when is_integer(x) and is_integer(y) and is_binary(char) and
              byte_size(char) == 1 do
    {:char, x, y, char}
  end

  defp classify_data({x, y, string})
       when is_integer(x) and is_integer(y) and is_binary(string) and
              byte_size(string) > 1 do
    {:string, x, y, string}
  end

  defp classify_data(_), do: :unknown

  defp write_char_data(buffer, x, y, char, opts) do
    Raxol.Terminal.Buffer.Writer.write_char(
      buffer,
      x,
      y,
      char,
      Keyword.get(opts, :style)
    )
  end

  defp write_string_data(buffer, x, y, string) do
    Raxol.Terminal.Buffer.Writer.write_string(buffer, x, y, string)
  end

  @doc """
  Reads data from the buffer.
  """
  def read(buffer, opts \\ [])

  def read(%Raxol.Terminal.Buffer.Manager.BufferImpl{} = buffer, opts) do
    # Handle BufferImpl structs
    case Keyword.get(opts, :line) do
      nil ->
        {Raxol.Terminal.Buffer.Manager.BufferImpl.get_content(buffer), buffer}

      line when is_integer(line) ->
        {Raxol.Terminal.Buffer.Manager.BufferImpl.get_line(buffer, line),
         buffer}
    end
  end

  def read(buffer, opts) do
    # Handle ScreenBuffer and other buffer types
    case Keyword.get(opts, :line) do
      nil ->
        {Raxol.Terminal.Buffer.Content.get_content(buffer), buffer}

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
  @spec erase_from_cursor_to_line_end(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: ScreenBuffer.t()
  def erase_from_cursor_to_line_end(buffer, row, col)
      when is_struct(buffer, Raxol.Terminal.ScreenBuffer) do
    LineOperations.erase_chars(buffer, row, col, buffer.width - col)
  end

  def erase_from_cursor_to_line_end(buffer, row, col) when is_list(buffer) do
    Enum.with_index(buffer)
    |> Enum.map(fn {line, idx} ->
      if idx == row do
        map_cells_from_column(line, col)
      else
        line
      end
    end)
  end

  defp map_cells_from_column(line, col) do
    Enum.with_index(line)
    |> Enum.map(fn {cell, cell_col} ->
      if cell_col >= col, do: Cell.new(), else: cell
    end)
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
  @spec erase_from_line_start_to_cursor(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: ScreenBuffer.t()
  def erase_from_line_start_to_cursor(buffer, row, col) when is_list(buffer) do
    Enum.with_index(buffer)
    |> Enum.map(fn {line, idx} ->
      if idx == row do
        map_cells_up_to_column(line, col)
      else
        line
      end
    end)
  end

  defp map_cells_up_to_column(line, col) do
    Enum.with_index(line)
    |> Enum.map(fn {cell, cell_col} ->
      if cell_col < col, do: Cell.new(), else: cell
    end)
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
  @spec erase_entire_line(ScreenBuffer.t(), non_neg_integer()) ::
          ScreenBuffer.t()
  def erase_entire_line(buffer, row)
      when is_struct(buffer, Raxol.Terminal.ScreenBuffer) do
    LineOperations.erase_chars(buffer, row, 0, buffer.width)
  end

  def erase_entire_line(buffer, row) when is_list(buffer) do
    Enum.with_index(buffer)
    |> Enum.map(fn {line, idx} ->
      if idx == row do
        Enum.map(line, fn _ -> Cell.new() end)
      else
        line
      end
    end)
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
  @spec erase_lines_after(ScreenBuffer.t(), non_neg_integer()) ::
          ScreenBuffer.t()
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
  @spec erase_lines_before(ScreenBuffer.t(), non_neg_integer()) ::
          ScreenBuffer.t()
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

  @doc """
  Erases from the cursor position to the end of the display.
  """
  defp erase_from_cursor_to_end(buffer, row, col) when is_list(buffer) do
    buffer
    |> Enum.with_index()
    |> Enum.map(fn {line, line_row} ->
      process_line_for_cursor_end(line, line_row, row, col)
    end)
  end

  defp process_line_for_cursor_end(line, line_row, target_row, col) do
    cond do
      line_row < target_row -> line
      line_row == target_row -> map_cells_from_column(line, col)
      true -> List.duplicate(Cell.new(), length(line))
    end
  end

  @doc """
  Erases from the start of the display to the cursor position.
  """
  defp erase_from_start_to_cursor(buffer, row, col) when is_list(buffer) do
    buffer
    |> Enum.with_index()
    |> Enum.map(fn {line, line_row} ->
      cond do
        line_row > row -> line
        line_row == row -> map_cells_up_to_column(line, col)
        true -> List.duplicate(Cell.new(), length(line))
      end
    end)
  end

  @doc """
  Erases the entire display.
  """
  defp erase_all(buffer) when is_list(buffer) do
    width = length(hd(buffer))
    List.duplicate(List.duplicate(Cell.new(), width), length(buffer))
  end

  @doc """
  Erases the entire display including scrollback.
  """
  defp erase_all_with_scrollback(buffer)
       when is_struct(buffer, Raxol.Terminal.ScreenBuffer) do
    updated_cells = erase_all_with_scrollback(buffer.cells)
    %{buffer | cells: updated_cells, scrollback: []}
  end

  defp erase_all_with_scrollback(buffer) when is_list(buffer) do
    width = length(hd(buffer))
    List.duplicate(List.duplicate(Cell.new(), width), length(buffer))
  end

  @doc """
  Gets a cell from the buffer at the specified coordinates.

  ## Parameters

  * `buffer` - The screen buffer
  * `x` - The x coordinate (column)
  * `y` - The y coordinate (row)

  ## Returns

  The cell at the specified coordinates, or a default cell if out of bounds.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> Operations.get_cell(buffer, 0, 0)
      %Cell{char: "", style: %{}}
  """
  @spec get_cell(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          Cell.t()
  def get_cell(buffer, x, y)
      when list?(buffer) and is_integer(x) and is_integer(y) do
    case get_in(buffer, [Access.at(y), Access.at(x)]) do
      nil -> Cell.new()
      cell -> cell
    end
  end

  @doc """
  Fills a region of the buffer with a specified cell.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `x` - The starting x coordinate
  * `y` - The starting y coordinate
  * `width` - The width of the region
  * `height` - The height of the region
  * `cell` - The cell to fill the region with

  ## Returns

  The modified buffer with the region filled.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> cell = %Cell{char: "X", style: %{bold: true}}
      iex> Operations.fill_region(buffer, 0, 0, 10, 5, cell)
      [%Cell{char: "X", style: %{bold: true}}, ...]
  """
  @spec fill_region(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          Cell.t()
        ) :: ScreenBuffer.t()
  def fill_region(buffer, x, y, width, height, cell) when list?(buffer) do
    buffer
    |> Enum.with_index()
    |> Enum.map(fn {row, row_y} ->
      if row_y >= y and row_y < y + height do
        fill_row_region(row, x, width, cell)
      else
        row
      end
    end)
  end

  defp fill_row_region(row, x, width, cell) do
    row
    |> Enum.with_index()
    |> Enum.map(fn {col_cell, col_x} ->
      if col_x >= x and col_x < x + width do
        cell
      else
        col_cell
      end
    end)
  end
end
