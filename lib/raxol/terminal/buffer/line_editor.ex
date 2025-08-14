defmodule Raxol.Terminal.Buffer.LineEditor do
  @moduledoc """
  Provides functionality for line editing operations in the terminal buffer.
  """

    alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ANSI.TextFormatting

  @doc """
  Inserts a specified number of blank lines at the given row index using the provided default_style.
  Existing lines from the insertion point downwards are shifted down.
  Lines shifted off the bottom of the buffer are discarded.
  Uses the buffer's default style for new lines.
  """
  @spec insert_lines(
          ScreenBuffer.t(),
          integer(),
          integer(),
          TextFormatting.text_style()
        ) :: ScreenBuffer.t()
  def insert_lines(%{__struct__: _} = buffer, row, count, default_style)
      when row >= 0 and count > 0 do
    # Ensure row is within bounds
    eff_row = min(row, buffer.height - 1)

    # Create blank lines with the provided default style
    blank_cell = %Cell{style: default_style, char: " "}
    blank_line = List.duplicate(blank_cell, buffer.width)
    blank_lines_to_insert = List.duplicate(blank_line, count)

    # Split the buffer cells at the insertion row
    {top_part, bottom_part} = Enum.split(buffer.cells, eff_row)

    # Take lines from the bottom part that will fit after insertion
    # We want to keep as many lines as possible, but ensure we don't exceed buffer height
    max_lines_after_insertion = buffer.height - eff_row - count
    kept_bottom_part = Enum.take(bottom_part, max_lines_after_insertion)

    # Combine the parts
    new_cells = top_part ++ blank_lines_to_insert ++ kept_bottom_part

    # Ensure we don't exceed the buffer height
    final_cells = Enum.take(new_cells, buffer.height)

    %{buffer | cells: final_cells}
  end

  def insert_lines(buffer, _row, _count, _blank_cell) when is_tuple(buffer) do
    raise ArgumentError,
          "Expected buffer struct, got tuple (did you pass result of get_dimensions/1?)"
  end

  @doc """
  Deletes a specified number of lines starting from the given row index.
  Lines below the deleted lines are shifted up.
  Blank lines are added at the bottom of the buffer to fill the space using the provided default_style.
  Uses the buffer's default style for new lines.
  """
  @spec delete_lines(
          ScreenBuffer.t(),
          integer(),
          integer(),
          TextFormatting.text_style()
        ) :: ScreenBuffer.t()
  def delete_lines(%ScreenBuffer{} = buffer, row, count, default_style)
      when row >= 0 and count > 0 do
    # Ensure row is within bounds
    eff_row = min(row, buffer.height - 1)

    # Calculate actual number of lines to delete
    eff_count = min(count, buffer.height - eff_row)

    # Create blank lines with the provided default style to add at the bottom
    blank_cell = %Cell{style: default_style, char: " "}
    blank_line = List.duplicate(blank_cell, buffer.width)
    blank_lines_to_add = List.duplicate(blank_line, eff_count)

    # Split the buffer cells at the deletion row
    {top_part, part_to_modify} = Enum.split(buffer.cells, eff_row)

    # Skip the deleted lines and take the rest
    bottom_part_kept = Enum.drop(part_to_modify, eff_count)

    # Combine the parts
    new_cells = top_part ++ bottom_part_kept ++ blank_lines_to_add

    %{buffer | cells: new_cells}
  end

  # No-op for invalid input
  def delete_lines(buffer, _row, _count, _default_style), do: buffer
end
