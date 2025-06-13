defmodule Raxol.Terminal.Buffer.LineOperations do
  @moduledoc """
  Provides line-level operations for the screen buffer.
  This module handles operations like inserting, deleting, and manipulating lines.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ANSI.TextFormatting

  @doc """
  Inserts lines at the current cursor position.
  """
  @spec insert_lines(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def insert_lines(buffer, count) do
    {_, y} = buffer.cursor_position
    {before_cursor, after_cursor} = Enum.split(buffer.cells, y)

    # Create new empty lines
    new_lines = create_empty_lines(buffer.width, count)

    # Combine the parts
    new_cells = before_cursor ++ new_lines ++ after_cursor

    # Remove excess lines from bottom
    new_cells = Enum.take(new_cells, buffer.height)

    %{buffer | cells: new_cells}
  end

  @doc """
  Deletes lines at the current cursor position.
  """
  @spec delete_lines(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def delete_lines(buffer, count) do
    {_, y} = buffer.cursor_position
    {before_cursor, after_cursor} = Enum.split(buffer.cells, y)

    # Remove lines after cursor
    new_after_cursor = Enum.drop(after_cursor, count)

    # Add empty lines at the bottom
    empty_lines = create_empty_lines(buffer.width, count)
    new_cells = before_cursor ++ new_after_cursor ++ empty_lines

    %{buffer | cells: new_cells}
  end

  @doc """
  Prepends lines to the top of the buffer.
  """
  @spec prepend_lines(ScreenBuffer.t(), list(list(Cell.t()))) :: ScreenBuffer.t()
  def prepend_lines(buffer, lines) do
    new_cells = lines ++ buffer.cells

    # Remove excess lines from bottom
    new_cells = Enum.take(new_cells, buffer.height)

    %{buffer | cells: new_cells}
  end

  @doc """
  Removes lines from the top of the buffer.
  """
  @spec pop_top_lines(ScreenBuffer.t(), non_neg_integer()) :: {list(list(Cell.t())), ScreenBuffer.t()}
  def pop_top_lines(buffer, count) do
    {popped_lines, remaining_cells} = Enum.split(buffer.cells, count)

    # Add empty lines at the bottom
    empty_lines = create_empty_lines(buffer.width, count)
    new_cells = remaining_cells ++ empty_lines

    {popped_lines, %{buffer | cells: new_cells}}
  end

  @doc """
  Gets a line from the buffer.
  """
  @spec get_line(ScreenBuffer.t(), non_neg_integer()) :: list(Cell.t()) | nil
  def get_line(buffer, line_index) do
    Enum.at(buffer.cells, line_index)
  end

  @doc """
  Updates a line in the buffer.
  """
  @spec update_line(ScreenBuffer.t(), non_neg_integer(), list(Cell.t())) :: ScreenBuffer.t()
  def update_line(buffer, line_index, new_line) do
    new_cells = List.update_at(buffer.cells, line_index, fn _ -> new_line end)
    %{buffer | cells: new_cells}
  end

  @doc """
  Clears a line in the buffer.
  """
  @spec clear_line(ScreenBuffer.t(), non_neg_integer(), TextFormatting.text_style() | nil) :: ScreenBuffer.t()
  def clear_line(buffer, line_index, style \\ nil) do
    empty_line = create_empty_line(buffer.width, style || buffer.default_style)
    update_line(buffer, line_index, empty_line)
  end

  # Private helper functions

  defp create_empty_lines(width, count) do
    for _ <- 1..count do
      create_empty_line(width)
    end
  end

  defp create_empty_line(width, style \\ nil) do
    for _ <- 1..width do
      Cell.new("", style)
    end
  end
end
