defmodule Raxol.Terminal.ScreenBuffer.EraseOperations do
  @moduledoc """
  Handles all erase operations for the terminal screen buffer.

  This module provides focused functionality for erasing content from the buffer,
  including line erasing, display erasing, and region clearing operations.
  """

  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ScreenBuffer

  @doc """
  Erases from cursor to end of display.
  """
  @spec erase_from_cursor_to_end(
          map(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: map()
  def erase_from_cursor_to_end(buffer, x, y, _top, bottom) do
    # Log.info("[DEBUG] erase_from_cursor_to_end called with x=#{x}, y=#{y}, bottom=#{bottom}")

    empty_cell = Cell.new()

    # Process each line
    new_cells =
      Enum.with_index(buffer.cells)
      |> Enum.map(fn {line, line_idx} ->
        cond do
          # Lines before cursor row remain unchanged
          line_idx < y ->
            line

          # Cursor row: clear from cursor position to end
          line_idx == y ->
            preserved_cells = Enum.take(line, x)
            cleared_cells = List.duplicate(empty_cell, buffer.width - x)
            preserved_cells ++ cleared_cells

          # Lines after cursor row: clear entirely if within bottom
          line_idx <= bottom ->
            List.duplicate(empty_cell, buffer.width)

          # Lines beyond bottom remain unchanged
          true ->
            line
        end
      end)

    %{buffer | cells: new_cells}
  end

  @doc """
  Erases from start to cursor position.
  """
  @spec erase_from_start_to_cursor(
          map(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: map()
  def erase_from_start_to_cursor(buffer, x, y, top, _bottom) do
    empty_cell = Cell.new()

    # Process each line
    new_cells =
      Enum.with_index(buffer.cells)
      |> Enum.map(fn {line, line_idx} ->
        cond do
          # Lines before top remain unchanged
          line_idx < top ->
            line

          # Lines from top to before cursor row: clear entirely
          line_idx < y ->
            List.duplicate(empty_cell, buffer.width)

          # Cursor row: clear from start to cursor position (inclusive)
          line_idx == y ->
            cleared_cells = List.duplicate(empty_cell, x + 1)
            preserved_cells = Enum.drop(line, x + 1)
            cleared_cells ++ preserved_cells

          # Lines after cursor row remain unchanged
          true ->
            line
        end
      end)

    %{buffer | cells: new_cells}
  end

  @doc """
  Erases the entire buffer.
  """
  @spec erase_all(ScreenBuffer.t()) :: ScreenBuffer.t()
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
  @spec clear_region(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: ScreenBuffer.t()
  def clear_region(buffer, x, y, width, height) do
    # Clear the specified region by filling it with empty cells
    empty_cell = Cell.new()

    new_cells =
      buffer.cells
      |> Enum.with_index()
      |> Enum.map(fn {row, row_idx} ->
        cond do
          row_idx < y or row_idx >= y + height ->
            row

          true ->
            # Clear columns x to x+width-1 in this row
            row
            |> Enum.with_index()
            |> Enum.map(fn {cell, col_idx} ->
              if col_idx >= x and col_idx < x + width do
                empty_cell
              else
                cell
              end
            end)
        end
      end)

    %{buffer | cells: new_cells}
  end

  @doc """
  Erases part or all of the current line based on the cursor position and type.
  Type can be :to_end, :to_beginning, or :all.
  """
  @spec erase_in_line(
          ScreenBuffer.t(),
          {non_neg_integer(), non_neg_integer()},
          atom()
        ) :: ScreenBuffer.t()
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
  @spec erase_in_display(
          ScreenBuffer.t(),
          {non_neg_integer(), non_neg_integer()},
          atom()
        ) :: ScreenBuffer.t()
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
  @spec erase_from_cursor_to_end(ScreenBuffer.t()) :: ScreenBuffer.t()
  def erase_from_cursor_to_end(buffer) do
    {x, y} = buffer.cursor_position || {0, 0}
    height = buffer.height || 24
    erase_from_cursor_to_end(buffer, x, y, 0, height)
  end

  # Private helper functions

  @spec erase_line_to_end(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: ScreenBuffer.t()
  defp erase_line_to_end(buffer, x, y) do
    line = Enum.at(buffer.cells, y, [])
    empty_cell = Cell.new()

    # Preserve cells before cursor, clear from cursor to end
    preserved_cells = Enum.take(line, x)
    cleared_cells = List.duplicate(empty_cell, buffer.width - x)
    cleared_line = preserved_cells ++ cleared_cells

    new_cells = List.replace_at(buffer.cells, y, cleared_line)
    %{buffer | cells: new_cells}
  end

  @spec erase_line_to_beginning(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: ScreenBuffer.t()
  defp erase_line_to_beginning(buffer, x, y) do
    line = Enum.at(buffer.cells, y, [])
    empty_cell = Cell.new()
    cleared_line = List.duplicate(empty_cell, x + 1) ++ Enum.drop(line, x + 1)
    new_cells = List.replace_at(buffer.cells, y, cleared_line)
    %{buffer | cells: new_cells}
  end

  @spec erase_entire_line(ScreenBuffer.t(), non_neg_integer()) ::
          ScreenBuffer.t()
  defp erase_entire_line(buffer, y) do
    empty_cell = Cell.new()

    new_cells =
      List.replace_at(buffer.cells, y, List.duplicate(empty_cell, buffer.width))

    %{buffer | cells: new_cells}
  end
end
