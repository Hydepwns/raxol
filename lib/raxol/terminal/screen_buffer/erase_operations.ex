defmodule Raxol.Terminal.ScreenBuffer.EraseOperations do
  @moduledoc """
  Handles all erase operations for the terminal screen buffer.

  This module provides focused functionality for erasing content from the buffer,
  including line erasing, display erasing, and region clearing operations.
  """

  alias Raxol.Terminal.Cell

  @doc """
  Erases from cursor to end of display.
  """
  def erase_from_cursor_to_end(buffer, x, y, _top, bottom) do
    # Clear from cursor to end of line
    line = Enum.at(buffer.cells, y, [])
    empty_cell = Cell.new()

    # Preserve existing cells before cursor, clear from cursor onwards
    preserved_cells = Enum.take(line, x)
    cleared_cells = List.duplicate(empty_cell, buffer.width - x)
    cleared_line = preserved_cells ++ cleared_cells

    new_cells = List.replace_at(buffer.cells, y, cleared_line)

    # Clear remaining lines
    new_cells =
      Enum.reduce((y + 1)..bottom, new_cells, fn line_num, acc ->
        List.replace_at(acc, line_num, List.duplicate(empty_cell, buffer.width))
      end)

    %{buffer | cells: new_cells}
  end

  @doc """
  Erases from start to cursor position.
  """
  def erase_from_start_to_cursor(buffer, x, y, top, _bottom) do
    # DEBUG: erase_from_start_to_cursor called with x=#{x}, y=#{y}, top=#{top}, bottom=#{bottom}

    # Clear from start of line to cursor (inclusive)
    line = Enum.at(buffer.cells, y, [])
    empty_cell = Cell.new()
    # Clear from start of line to cursor position (inclusive)
    cleared_line = List.duplicate(empty_cell, x + 1) ++ Enum.drop(line, x + 1)
    new_cells = List.replace_at(buffer.cells, y, cleared_line)

    # Clear all previous lines completely
    # DEBUG output removed

    new_cells =
      Enum.reduce(top..(y - 1), new_cells, fn line_num, acc ->
        # DEBUG output removed
        List.replace_at(acc, line_num, List.duplicate(empty_cell, buffer.width))
      end)

    # DEBUG output removed
    %{buffer | cells: new_cells}
  end

  @doc """
  Erases the entire buffer.
  """
  def erase_all(buffer) do
    empty_cell = Cell.new()

    %{
      buffer
      | cells:
          List.duplicate(
            List.duplicate(empty_cell, buffer.width),
            buffer.height
          ),
        scrollback: []
    }
  end

  @doc """
  Clears a specific region of the buffer.
  """
  def clear_region(buffer, x, y, width, height) do
    # Clear the specified region by filling it with empty cells
    empty_cell = Cell.new()

    new_cells =
      Enum.reduce(y..(y + height - 1), buffer.cells, fn row_y, acc_cells ->
        clear_row_if_valid(acc_cells, row_y, x, width, buffer, empty_cell)
      end)

    %{buffer | cells: new_cells}
  end

  @doc """
  Erases part or all of the current line based on the cursor position and type.
  Type can be :to_end, :to_beginning, or :all.
  """
  def erase_in_line(buffer, {x, y}, type) do
    case type do
      :to_end -> erase_line_to_end(buffer, x, y)
      :to_beginning -> erase_line_to_beginning(buffer, x, y)
      :all -> erase_entire_line(buffer, y)
      _ -> erase_line_to_end(buffer, x, y)
    end
  end

  @doc """
  Erases part or all of the display based on the cursor position and type.
  Type can be :to_end, :to_beginning, or :all.
  """
  def erase_in_display(buffer, {x, y}, type) do
    case type do
      :to_end ->
        # Erase from cursor to end of display
        erase_from_cursor_to_end(buffer, x, y, 0, buffer.height)

      :to_beginning ->
        # Erase from start of display to cursor
        erase_from_start_to_cursor(buffer, x, y, 0, buffer.height)

      :all ->
        # Erase entire display
        erase_all(buffer)

      _ ->
        # Default to :to_end
        erase_in_display(buffer, {x, y}, :to_end)
    end
  end

  @doc """
  Erases from the cursor to the end of the screen using the current cursor position.
  """
  def erase_from_cursor_to_end(buffer) do
    {x, y} = buffer.cursor_position || {0, 0}
    height = buffer.height || 24
    erase_from_cursor_to_end(buffer, x, y, 0, height)
  end

  # Private helper functions

  defp clear_row_if_valid(cells, row_y, x, width, buffer, empty_cell) do
    case row_y < buffer.height do
      true ->
        List.update_at(cells, row_y, fn row ->
          clear_row_columns(row, x, width, buffer.width, empty_cell)
        end)
      false ->
        cells
    end
  end

  defp clear_row_columns(row, x, width, buffer_width, empty_cell) do
    Enum.reduce(x..(x + width - 1), row, fn col_x, acc_row ->
      case col_x < buffer_width do
        true ->
          List.replace_at(acc_row, col_x, empty_cell)
        false ->
          acc_row
      end
    end)
  end

  defp erase_line_to_end(buffer, x, y) do
    _line = Enum.at(buffer.cells, y, [])
    empty_cell = Cell.new()

    cleared_line =
      List.duplicate(empty_cell, x) ++
        List.duplicate(empty_cell, buffer.width - x)

    new_cells = List.replace_at(buffer.cells, y, cleared_line)
    %{buffer | cells: new_cells}
  end

  defp erase_line_to_beginning(buffer, x, y) do
    line = Enum.at(buffer.cells, y, [])
    empty_cell = Cell.new()
    cleared_line = List.duplicate(empty_cell, x + 1) ++ Enum.drop(line, x + 1)
    new_cells = List.replace_at(buffer.cells, y, cleared_line)
    %{buffer | cells: new_cells}
  end

  defp erase_entire_line(buffer, y) do
    new_cells =
      List.replace_at(buffer.cells, y, List.duplicate(%{}, buffer.width))

    %{buffer | cells: new_cells}
  end
end
