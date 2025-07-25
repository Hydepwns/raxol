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

    if line do
      new_line = erase_chars_in_line(line, col, count)
      update_line(buffer, row, new_line)
    else
      buffer
    end
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
    if row >= 0 and row < length(buffer.cells) and col >= 0 and
         col < buffer.width do
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
    else
      buffer
    end
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
    if row >= 0 and row < length(buffer.cells) and col >= 0 and
         col < buffer.width do
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
    else
      buffer
    end
  end

  # Helper functions
  defp erase_chars_in_line(line, col, count) do
    Enum.with_index(line)
    |> Enum.map(fn {cell, index} ->
      if index >= col and index < col + count do
        Cell.new(" ")
      else
        cell
      end
    end)
  end

  defp delete_chars_from_line(line, col, count, width, default_style) do
    {before, after_part} = Enum.split(line, col)
    {_, remaining} = Enum.split(after_part, count)

    # Create a new line with the correct content
    new_line = before ++ remaining

    # Ensure the line has the correct width by padding with empty cells
    if length(new_line) < width do
      new_line ++ create_empty_line(width - length(new_line), default_style)
    else
      Enum.take(new_line, width)
    end
  end

  defp insert_chars_into_line(line, col, count, width, default_style) do
    # If the character at the cursor is a space, skip it when inserting
    {before, after_part} = Enum.split(line, col)

    # If the first char in after_part is a space, drop it (to avoid duplicating the space)
    after_part =
      case after_part do
        [%{char: " "} | rest] -> rest
        _ -> after_part
      end

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
        if line_index >= 0 and line_index < length(cells) do
          Enum.at(cells, line_index) || []
        else
          []
        end
    end
  end

  defp update_line(buffer, line_index, new_line) do
    case buffer.cells do
      nil ->
        # Return buffer unchanged if cells is nil
        buffer

      cells ->
        if line_index >= 0 and line_index < length(cells) do
          new_cells = List.replace_at(cells, line_index, new_line)
          %{buffer | cells: new_cells}
        else
          buffer
        end
    end
  end
end
