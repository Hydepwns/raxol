defmodule Raxol.Terminal.Buffer.LineOperations.CharOperations do
  @moduledoc """
  Handles character operations within lines for the screen buffer.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell

  @doc """
  Erases a specified number of characters in a line.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `row` - The row to modify
  * `col` - The starting column
  * `count` - The number of characters to erase

  ## Returns

  The updated screen buffer.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = LineOperations.CharOperations.erase_chars(buffer, 0, 0, 10)
      iex> LineOperations.CharOperations.get_line(buffer, 0) |> Enum.take(10) |> Enum.all?(fn cell -> cell.char == "" end)
      true
  """
  @spec erase_chars(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: ScreenBuffer.t()
  def erase_chars(buffer, row, col, count) do
    line = get_line(buffer, row)
    handle_erase_operation(line != nil, buffer, row, line, col, count)
  end

  defp handle_erase_operation(false, buffer, _row, _line, _col, _count),
    do: buffer

  defp handle_erase_operation(true, buffer, row, line, col, count) do
    new_line = erase_chars_in_line(line, col, count)
    update_line(buffer, row, new_line)
  end

  @doc """
  Deletes a specified number of characters from the current line.
  """
  @spec delete_chars(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def delete_chars(buffer, count) when count > 0 do
    {x, y} = buffer.cursor_position
    delete_chars_at(buffer, y, x, count)
  end

  def delete_chars(buffer, _count), do: buffer

  @doc """
  Deletes characters at a specific position.
  """
  @spec delete_chars_at(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: ScreenBuffer.t()
  def delete_chars_at(buffer, row, col, count) do
    valid_position =
      row >= 0 and row < length(buffer.cells) and col >= 0 and
        col < buffer.width

    handle_delete_operation(valid_position, buffer, row, col, count)
  end

  defp handle_delete_operation(false, buffer, _row, _col, _count), do: buffer

  defp handle_delete_operation(true, buffer, row, col, count) do
    line = get_line(buffer, row)

    new_line =
      delete_chars_from_line(
        line,
        col,
        count,
        buffer.width,
        buffer.default_style
      )

    update_line(buffer, row, new_line)
  end

  @doc """
  Inserts a specified number of characters at the current position.
  """
  @spec insert_chars(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def insert_chars(buffer, count) when count > 0 do
    {x, y} = buffer.cursor_position
    insert_chars_at(buffer, y, x, count)
  end

  def insert_chars(buffer, _count), do: buffer

  @doc """
  Inserts characters at a specific position.
  """
  @spec insert_chars_at(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: ScreenBuffer.t()
  def insert_chars_at(buffer, row, col, count) do
    valid_position =
      row >= 0 and row < length(buffer.cells) and col >= 0 and
        col < buffer.width

    handle_insert_operation(valid_position, buffer, row, col, count)
  end

  defp handle_insert_operation(false, buffer, _row, _col, _count), do: buffer

  defp handle_insert_operation(true, buffer, row, col, count) do
    line = get_line(buffer, row)

    new_line =
      insert_chars_into_line(
        line,
        col,
        count,
        buffer.width,
        buffer.default_style
      )

    update_line(buffer, row, new_line)
  end

  # Helper functions
  defp erase_chars_in_line(line, col, count) do
    Enum.with_index(line)
    |> Enum.map(fn {cell, index} ->
      should_erase = index >= col and index < col + count
      erase_cell_if_needed(should_erase, cell)
    end)
  end

  defp erase_cell_if_needed(true, _cell), do: Cell.new(" ")
  defp erase_cell_if_needed(false, cell), do: cell

  defp delete_chars_from_line(line, col, count, width, default_style) do
    {before, after_part} = Enum.split(line, col)
    {_, remaining} = Enum.split(after_part, count)

    # Create a new line with the correct content
    new_line = before ++ remaining

    # Ensure the line has the correct width by padding with empty cells
    needs_padding = length(new_line) < width
    pad_line_if_needed(needs_padding, new_line, width, default_style)
  end

  defp pad_line_if_needed(true, new_line, width, default_style) do
    new_line ++ create_empty_line(width - length(new_line), default_style)
  end

  defp pad_line_if_needed(false, new_line, width, _default_style) do
    Enum.take(new_line, width)
  end

  defp insert_chars_into_line(line, col, count, width, default_style) do
    # Split the line at the cursor position
    {before, after_part} = Enum.split(line, col)

    blank_cell = %Cell{
      char: " ",
      style: default_style,
      dirty: false,
      wide_placeholder: false
    }

    empty_chars = List.duplicate(blank_cell, count)
    new_line = before ++ empty_chars ++ after_part
    Enum.take(new_line, width)
  end

  defp create_empty_line(width, style) do
    for _ <- 1..width do
      Cell.new(" ", style)
    end
  end

  defp get_line(buffer, line_index) do
    case buffer.cells do
      nil ->
        # Return empty list if cells is nil
        []

      cells ->
        valid_index = line_index >= 0 and line_index < length(cells)
        get_line_by_index(valid_index, cells, line_index)
    end
  end

  defp update_line(buffer, line_index, new_line) do
    case buffer.cells do
      nil ->
        # Return buffer unchanged if cells is nil
        buffer

      cells ->
        valid_index = line_index >= 0 and line_index < length(cells)
        update_line_by_index(valid_index, buffer, cells, line_index, new_line)
    end
  end

  ## Helper Functions for Pattern Matching

  defp get_line_by_index(false, _cells, _line_index), do: []

  defp get_line_by_index(true, cells, line_index) do
    Enum.at(cells, line_index) || []
  end

  defp update_line_by_index(false, buffer, _cells, _line_index, _new_line),
    do: buffer

  defp update_line_by_index(true, buffer, cells, line_index, new_line) do
    new_cells = List.replace_at(cells, line_index, new_line)
    %{buffer | cells: new_cells}
  end
end
