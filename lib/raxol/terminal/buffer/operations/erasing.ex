defmodule Raxol.Terminal.Buffer.Operations.Erasing do
  @moduledoc """
  Handles erasing operations for terminal buffers including line and display erasing.
  """

  import Raxol.Guards
  alias Raxol.Terminal.Buffer.Cell

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
    handle_erase_in_display(buffer, mode, row, col)
  end

  defp handle_erase_in_display(
         %Raxol.Terminal.ScreenBuffer{} = buffer,
         mode,
         row,
         col
       ) do
    updated_cells = erase_in_display_cells(buffer.cells, mode, row, col)
    %{buffer | cells: updated_cells}
  end

  defp handle_erase_in_display(buffer, mode, row, col) when is_list(buffer) do
    case mode do
      0 -> erase_from_cursor_to_end(buffer, row, col)
      1 -> erase_from_start_to_cursor(buffer, row, col)
      2 -> erase_all(buffer)
      3 -> erase_all_with_scrollback(buffer)
      _ -> buffer
    end
  end

  defp handle_erase_in_display(buffer, _mode, _row, _col), do: buffer

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
  Erases characters from the cursor position to the end of the line.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `row` - The row to erase from
  * `col` - The column to start erasing from

  ## Returns

  The modified buffer with characters erased.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> Operations.Erasing.erase_from_cursor_to_line_end(buffer, 0, 40)
      [%Cell{char: "", style: %{}}, ...]
  """
  @spec erase_from_cursor_to_line_end(
          Raxol.Terminal.ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: Raxol.Terminal.ScreenBuffer.t()
  def erase_from_cursor_to_line_end(buffer, row, col)
      when is_struct(buffer, Raxol.Terminal.ScreenBuffer) do
    Raxol.Terminal.Buffer.LineOperations.erase_chars(buffer, row, col, buffer.width - col)
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
      if cell_col >= col, do: Cell.new(" "), else: cell
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
      iex> Operations.Erasing.erase_from_line_start_to_cursor(buffer, 0, 40)
      [%Cell{char: "", style: %{}}, ...]
  """
  @spec erase_from_line_start_to_cursor(
          Raxol.Terminal.ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: Raxol.Terminal.ScreenBuffer.t()
  def erase_from_line_start_to_cursor(buffer, row, col)
      when is_struct(buffer, Raxol.Terminal.ScreenBuffer) do
    Raxol.Terminal.Buffer.LineOperations.erase_chars(buffer, row, 0, col + 1)
  end

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
      if cell_col < col, do: Cell.new(" "), else: cell
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
      iex> Operations.Erasing.erase_entire_line(buffer, 0)
      [%Cell{char: "", style: %{}}, ...]
  """
  @spec erase_entire_line(Raxol.Terminal.ScreenBuffer.t(), non_neg_integer()) ::
          Raxol.Terminal.ScreenBuffer.t()
  def erase_entire_line(buffer, row)
      when is_struct(buffer, Raxol.Terminal.ScreenBuffer) do
    Raxol.Terminal.Buffer.LineOperations.erase_chars(buffer, row, 0, buffer.width)
  end

  def erase_entire_line(buffer, row) when is_list(buffer) do
    Enum.with_index(buffer)
    |> Enum.map(fn {line, idx} ->
      process_line_for_erase(line, idx, row)
    end)
  end

  defp process_line_for_erase(line, idx, row) do
    if idx == row do
      Enum.map(line, fn _ -> Cell.new(" ") end)
    else
      line
    end
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
      iex> Operations.Erasing.erase_lines_after(buffer, 12)
      [%Cell{char: "", style: %{}}, ...]
  """
  @spec erase_lines_after(Raxol.Terminal.ScreenBuffer.t(), non_neg_integer()) ::
          Raxol.Terminal.ScreenBuffer.t()
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
      iex> Operations.Erasing.erase_lines_before(buffer, 12)
      [%Cell{char: "", style: %{}}, ...]
  """
  @spec erase_lines_before(Raxol.Terminal.ScreenBuffer.t(), non_neg_integer()) ::
          Raxol.Terminal.ScreenBuffer.t()
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
      iex> Operations.Erasing.clear_scrollback(buffer)
      %{buffer | scrollback: []}
  """
  @spec clear_scrollback(Raxol.Terminal.ScreenBuffer.t()) :: Raxol.Terminal.ScreenBuffer.t()
  def clear_scrollback(buffer) do
    %{buffer | scrollback: []}
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
      true -> List.duplicate(Cell.new(" "), length(line))
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
        true -> List.duplicate(Cell.new(" "), length(line))
      end
    end)
  end

  @doc """
  Erases the entire display.
  """
  defp erase_all(buffer) when is_list(buffer) do
    width = length(hd(buffer))
    List.duplicate(List.duplicate(Cell.new(" "), width), length(buffer))
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
    List.duplicate(List.duplicate(Cell.new(" "), width), length(buffer))
  end
end
