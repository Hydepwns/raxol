defmodule Raxol.Terminal.ScreenBuffer.SharedOperations do
  @moduledoc """
  Shared operations for screen buffer modules to eliminate code duplication.
  This module contains common functionality used across different screen buffer implementations.
  """

  alias Raxol.Terminal.Cell

  @doc """
  Erases a specified number of characters at a given position.
  Replaces characters with empty cells using the buffer's default style.

  ## Parameters
    - buffer: The buffer to modify
    - x: Starting column position
    - y: Row position
    - count: Number of characters to erase

  ## Returns
    Updated buffer with erased characters
  """
  @spec erase_chars_at_position(
          map(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: map()
  def erase_chars_at_position(buffer, x, y, count)
      when x >= 0 and y >= 0 and count > 0 do
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

  def erase_chars_at_position(buffer, _, _, _), do: buffer

  @doc """
  Inserts a character at the specified position, shifting content right.
  Core logic for character insertion without damage tracking.

  ## Parameters
    - buffer: The buffer to modify
    - x: Column position
    - y: Row position
    - char: Character to insert
    - style: Style to apply (uses buffer default if nil)

  ## Returns
    Buffer with updated cells (damage tracking handled by caller)
  """
  @spec insert_char_core_logic(
          map(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          map() | nil
        ) :: map()
  def insert_char_core_logic(buffer, x, y, char, style) do
    if within_bounds?(buffer, x, y) do
      style = style || buffer.default_style
      new_cell = %Cell{char: char, style: style}

      new_cells =
        List.update_at(buffer.cells, y, fn row ->
          {before, after_} = Enum.split(row, x)
          before ++ [new_cell] ++ Enum.take(after_, buffer.width - x - 1)
        end)

      %{buffer | cells: new_cells}
    else
      buffer
    end
  end

  @doc """
  Core logic for deleting lines from a buffer.
  Removes specified lines and adds empty lines at the bottom.

  ## Parameters
    - buffer: The buffer to modify
    - y: Starting line position
    - count: Number of lines to delete

  ## Returns
    Updated buffer with deleted lines
  """
  @spec delete_lines_core_logic(map(), non_neg_integer(), non_neg_integer()) ::
          map()
  def delete_lines_core_logic(buffer, y, count) when count > 0 and y >= 0 do
    cells = buffer.cells || []

    {before, at_and_after} = Enum.split(cells, y)
    remaining = Enum.drop(at_and_after, count)
    empty_lines = List.duplicate(create_empty_line(buffer), count)

    new_cells =
      (before ++ remaining ++ empty_lines)
      |> Enum.take(buffer.height)

    %{buffer | cells: new_cells}
  end

  def delete_lines_core_logic(buffer, _, _), do: buffer

  # Helper function to create an empty line
  defp create_empty_line(buffer) do
    width = Map.get(buffer, :width, 80)

    Enum.map(0..(width - 1), fn _ ->
      %Cell{char: " ", style: buffer.default_style}
    end)
  end

  # Helper function to check if coordinates are within buffer bounds
  defp within_bounds?(buffer, x, y) do
    x >= 0 and y >= 0 and x < buffer.width and y < buffer.height
  end

  @doc """
  Normalizes selection coordinates so that start is always before end.
  Returns {start_x, start_y, end_x, end_y} in proper order.

  ## Parameters
    - x1, y1: First selection point
    - x2, y2: Second selection point

  ## Returns
    Tuple with normalized coordinates {start_x, start_y, end_x, end_y}
  """
  @spec normalize_selection(integer(), integer(), integer(), integer()) ::
          {integer(), integer(), integer(), integer()}
  def normalize_selection(x1, y1, x2, y2) do
    if y1 < y2 or (y1 == y2 and x1 <= x2) do
      {x1, y1, x2, y2}
    else
      {x2, y2, x1, y1}
    end
  end

  @doc """
  Checks if a position (x, y) is within the selection boundaries.

  ## Parameters
    - x, y: Position to check
    - start_x, start_y: Selection start coordinates
    - end_x, end_y: Selection end coordinates

  ## Returns
    Boolean indicating if position is within selection
  """
  @spec position_in_selection?(
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer()
        ) :: boolean()
  def position_in_selection?(x, y, start_x, start_y, end_x, end_y) do
    cond do
      y < start_y or y > end_y -> false
      y > start_y and y < end_y -> true
      y == start_y and y == end_y -> x >= start_x and x <= end_x
      y == start_y -> x >= start_x
      y == end_y -> x <= end_x
      true -> false
    end
  end
end
