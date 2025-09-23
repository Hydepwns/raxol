defmodule Raxol.Terminal.ScreenBuffer.Operations do
  @moduledoc """
  Consolidated operations for ScreenBuffer including erasing, line operations, and scrolling.
  This module combines functionality from Eraser, LineOperations, and ScrollRegion modules.
  """

  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ScreenBuffer

  # ========== Erase Operations ==========

  @doc """
  Clears a specific line in the buffer.
  """
  @spec clear_line(ScreenBuffer.t(), non_neg_integer(), any()) :: ScreenBuffer.t()
  def clear_line(buffer, line, style \\ nil)

  def clear_line(buffer, line, style) when line >= 0 and line < buffer.height do
    empty_line = List.duplicate(%Cell{char: " ", style: style}, buffer.width)
    new_cells = List.replace_at(buffer.cells || [], line, empty_line)
    %{buffer | cells: new_cells}
  end

  def clear_line(buffer, _, _), do: buffer

  @doc """
  Erases a specified number of characters from the current cursor position.
  """
  @spec erase_chars(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def erase_chars(buffer, count) when count > 0 do
    {x, y} = buffer.cursor_position || {0, 0}
    erase_chars(buffer, x, y, count)
  end

  def erase_chars(buffer, _), do: buffer

  @doc """
  Erases a specified number of characters at a given position.
  """
  @spec erase_chars(ScreenBuffer.t(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: ScreenBuffer.t()
  def erase_chars(buffer, x, y, count) when x >= 0 and y >= 0 and y < buffer.height and count > 0 do
    cells = buffer.cells || []
    row = Enum.at(cells, y, [])

    new_row =
      row
      |> Enum.with_index()
      |> Enum.map(fn {cell, idx} ->
        if idx >= x and idx < x + count do
          %Cell{char: " ", style: buffer.default_style}
        else
          cell
        end
      end)

    new_cells = List.replace_at(cells, y, new_row)
    %{buffer | cells: new_cells}
  end

  def erase_chars(buffer, _, _, _), do: buffer

  @doc """
  Erases display based on mode.
  Mode 0: From cursor to end of display
  Mode 1: From start to cursor
  Mode 2: Entire display
  """
  @spec erase_display(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def erase_display(buffer, mode) do
    {x, y} = buffer.cursor_position || {0, 0}

    case mode do
      0 -> erase_from_cursor_to_end(buffer, x, y)
      1 -> erase_from_start_to_cursor(buffer, x, y)
      2 -> clear_entire_buffer(buffer)
      _ -> buffer
    end
  end

  @doc """
  Erases line based on mode.
  Mode 0: From cursor to end of line
  Mode 1: From start to cursor
  Mode 2: Entire line
  """
  @spec erase_line(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def erase_line(buffer, mode) do
    {x, y} = buffer.cursor_position || {0, 0}
    erase_line(buffer, y, mode, x)
  end

  @spec erase_line(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) :: ScreenBuffer.t()
  def erase_line(buffer, line, mode) do
    {x, _} = buffer.cursor_position || {0, 0}
    erase_line(buffer, line, mode, x)
  end

  defp erase_line(buffer, line, mode, cursor_x) when line >= 0 and line < buffer.height do
    cells = buffer.cells || []
    row = Enum.at(cells, line, [])

    new_row = case mode do
      0 -> # From cursor to end
        row
        |> Enum.with_index()
        |> Enum.map(fn {cell, idx} ->
          if idx >= cursor_x, do: %Cell{char: " ", style: buffer.default_style}, else: cell
        end)

      1 -> # From start to cursor
        row
        |> Enum.with_index()
        |> Enum.map(fn {cell, idx} ->
          if idx <= cursor_x, do: %Cell{char: " ", style: buffer.default_style}, else: cell
        end)

      2 -> # Entire line
        List.duplicate(%Cell{char: " ", style: buffer.default_style}, buffer.width)

      _ -> row
    end

    new_cells = List.replace_at(cells, line, new_row)
    %{buffer | cells: new_cells}
  end

  defp erase_line(buffer, _, _, _), do: buffer

  # ========== Line Operations ==========

  @doc """
  Inserts blank lines at the current cursor position.
  """
  @spec insert_lines(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def insert_lines(buffer, count) when count > 0 do
    {_, y} = buffer.cursor_position || {0, 0}

    if y < buffer.height do
      cells = buffer.cells || []
      empty_lines = List.duplicate(create_empty_line(buffer), count)

      {before, at_and_after} = Enum.split(cells, y)
      # Take only as many lines as will fit
      kept_lines = Enum.take(at_and_after, buffer.height - y - count)

      new_cells = before ++ empty_lines ++ kept_lines
      |> Enum.take(buffer.height)

      %{buffer | cells: new_cells}
    else
      buffer
    end
  end

  def insert_lines(buffer, _), do: buffer

  @doc """
  Deletes lines at the current cursor position.
  """
  @spec delete_lines(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def delete_lines(buffer, count) when count > 0 do
    {_, y} = buffer.cursor_position || {0, 0}

    if y < buffer.height do
      cells = buffer.cells || []

      {before, at_and_after} = Enum.split(cells, y)
      remaining = Enum.drop(at_and_after, count)
      empty_lines = List.duplicate(create_empty_line(buffer), count)

      new_cells = (before ++ remaining ++ empty_lines)
      |> Enum.take(buffer.height)

      %{buffer | cells: new_cells}
    else
      buffer
    end
  end

  def delete_lines(buffer, _), do: buffer

  @doc """
  Inserts blank characters at the current cursor position.
  """
  @spec insert_chars(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def insert_chars(buffer, count) when count > 0 do
    {x, y} = buffer.cursor_position || {0, 0}

    if y < buffer.height and x < buffer.width do
      cells = buffer.cells || []
      row = Enum.at(cells, y, [])

      {before_cursor, at_and_after} = Enum.split(row, x)
      blanks = List.duplicate(%Cell{char: " ", style: buffer.default_style}, count)

      new_row = (before_cursor ++ blanks ++ at_and_after)
      |> Enum.take(buffer.width)

      new_cells = List.replace_at(cells, y, new_row)
      %{buffer | cells: new_cells}
    else
      buffer
    end
  end

  def insert_chars(buffer, _), do: buffer

  @doc """
  Deletes characters at the current cursor position.
  """
  @spec delete_chars(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def delete_chars(buffer, count) when count > 0 do
    {x, y} = buffer.cursor_position || {0, 0}

    if y < buffer.height and x < buffer.width do
      cells = buffer.cells || []
      row = Enum.at(cells, y, [])

      {before_cursor, at_and_after} = Enum.split(row, x)
      remaining = Enum.drop(at_and_after, count)
      blanks = List.duplicate(%Cell{char: " ", style: buffer.default_style}, count)

      new_row = (before_cursor ++ remaining ++ blanks)
      |> Enum.take(buffer.width)

      new_cells = List.replace_at(cells, y, new_row)
      %{buffer | cells: new_cells}
    else
      buffer
    end
  end

  def delete_chars(buffer, _), do: buffer

  @doc """
  Prepends lines to the buffer's scrollback.
  """
  @spec prepend_lines(ScreenBuffer.t(), list(list(Cell.t()))) :: ScreenBuffer.t()
  def prepend_lines(buffer, lines) when is_list(lines) do
    current_scrollback = buffer.scrollback || []
    new_scrollback = (lines ++ current_scrollback)
    |> Enum.take(buffer.scrollback_limit)

    %{buffer | scrollback: new_scrollback}
  end

  def prepend_lines(buffer, _), do: buffer

  # ========== Scroll Region Operations ==========

  @doc """
  Scrolls to a specific line within the scroll region.
  """
  @spec scroll_to(ScreenBuffer.t(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: ScreenBuffer.t()
  def scroll_to(buffer, _top, _bottom, _line) do
    # Simple implementation - just return buffer for now
    # This would need proper implementation based on requirements
    buffer
  end

  @doc """
  Sets the scroll region boundaries.
  """
  @spec set_region(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) :: ScreenBuffer.t()
  def set_region(buffer, top, bottom) when top >= 0 and bottom >= 0 and top < bottom do
    if bottom < buffer.height do
      %{buffer | scroll_region: {top, bottom}}
    else
      %{buffer | scroll_region: nil}
    end
  end

  def set_region(buffer, _, _), do: %{buffer | scroll_region: nil}

  @doc """
  Gets the current scroll region.
  """
  @spec get_region(ScreenBuffer.t()) :: {non_neg_integer(), non_neg_integer()} | nil
  def get_region(buffer) do
    buffer.scroll_region
  end

  @doc """
  Shifts region content to a specific line.
  """
  @spec shift_region_to_line(ScreenBuffer.t(), any(), non_neg_integer()) :: ScreenBuffer.t()
  def shift_region_to_line(buffer, _region, _target_line) do
    # Simple implementation - would need proper logic
    buffer
  end

  @doc """
  Implements delete_lines_in_region for specific region handling.
  """
  @spec delete_lines_in_region(ScreenBuffer.t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: ScreenBuffer.t()
  def delete_lines_in_region(buffer, lines, y, top, bottom) do
    if y >= top and y <= bottom and lines > 0 do
      cells = buffer.cells || []

      # Get the parts before, within, and after the region
      {before_region, rest} = Enum.split(cells, top)
      {region, after_region} = Enum.split(rest, bottom - top + 1)

      # Delete lines within the region starting from y
      region_offset = y - top
      {before_delete, at_and_after} = Enum.split(region, region_offset)
      remaining = Enum.drop(at_and_after, lines)
      empty_lines = List.duplicate(create_empty_line(buffer), min(lines, length(at_and_after)))

      new_region = before_delete ++ remaining ++ empty_lines
      |> Enum.take(bottom - top + 1)

      # Reconstruct the buffer
      new_cells = before_region ++ new_region ++ after_region
      %{buffer | cells: new_cells}
    else
      buffer
    end
  end

  # ========== Helper Functions ==========

  defp erase_from_cursor_to_end(buffer, x, y) do
    cells = buffer.cells || []

    new_cells =
      cells
      |> Enum.with_index()
      |> Enum.map(fn {row, row_idx} ->
        cond do
          row_idx < y -> row
          row_idx == y ->
            row
            |> Enum.with_index()
            |> Enum.map(fn {cell, col_idx} ->
              if col_idx >= x, do: %Cell{char: " ", style: buffer.default_style}, else: cell
            end)
          true ->
            List.duplicate(%Cell{char: " ", style: buffer.default_style}, buffer.width)
        end
      end)

    %{buffer | cells: new_cells}
  end

  defp erase_from_start_to_cursor(buffer, x, y) do
    cells = buffer.cells || []

    new_cells =
      cells
      |> Enum.with_index()
      |> Enum.map(fn {row, row_idx} ->
        cond do
          row_idx > y -> row
          row_idx == y ->
            row
            |> Enum.with_index()
            |> Enum.map(fn {cell, col_idx} ->
              if col_idx <= x, do: %Cell{char: " ", style: buffer.default_style}, else: cell
            end)
          true ->
            List.duplicate(%Cell{char: " ", style: buffer.default_style}, buffer.width)
        end
      end)

    %{buffer | cells: new_cells}
  end

  defp clear_entire_buffer(buffer) do
    new_cells = List.duplicate(
      List.duplicate(%Cell{char: " ", style: buffer.default_style}, buffer.width),
      buffer.height
    )
    %{buffer | cells: new_cells}
  end

  defp create_empty_line(buffer) do
    List.duplicate(%Cell{char: " ", style: buffer.default_style}, buffer.width)
  end
end