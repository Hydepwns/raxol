defmodule Raxol.Terminal.Buffer.CharEditor do
  @moduledoc """
  Handles character insertion and deletion within the Raxol.Terminal.ScreenBuffer lines.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Buffer.Updater
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ANSI.TextFormatting # Keep for style type hint

  @doc """
  Inserts a specified number of blank characters at the given row and column index
  using the provided default_style.
  Characters to the right of the insertion point are shifted right. Characters shifted
  off the end of the line are discarded. Uses the buffer's default style for new cells.
  """
  @spec insert_characters(ScreenBuffer.t(), integer(), integer(), integer(), TextFormatting.text_style()) :: ScreenBuffer.t()
  def insert_characters(%ScreenBuffer{} = buffer, row, col, count, default_style) when row >= 0 and col >= 0 and count > 0 do
    # Ensure row is valid
    if row < buffer.height do
      # Create blank cell with space character
      blank_cell = %Cell{char: " ", style: default_style}
      blank_cells_to_insert = List.duplicate(blank_cell, count)

      # Update the specific line
      new_cells = List.update_at(buffer.cells, row, fn line ->
        {left_part, right_part} = Enum.split(line, col)
        # Combine parts with inserted blanks
        combined_line = left_part ++ blank_cells_to_insert ++ right_part
        # Ensure the line has the correct width by taking only the first `buffer.width` cells
        Enum.take(combined_line, buffer.width)
      end)
      %{buffer | cells: new_cells}
    else
       buffer # Row out of bounds
    end
  end
  def insert_characters(buffer, _row, _col, _count, _default_style), do: buffer # No-op for invalid input


  @doc """
  Deletes a specified number of characters starting from the given row and column index.
  Characters to the right of the deleted characters are shifted left. Blank characters
  are added at the end of the line to fill the space using the provided default_style.
  Uses the buffer's default style for new cells.
  """
  @spec delete_characters(ScreenBuffer.t(), integer(), integer(), integer(), TextFormatting.text_style()) :: ScreenBuffer.t()
  def delete_characters(%ScreenBuffer{} = buffer, row, col, count, default_style) when row >= 0 and col >= 0 and count > 0 do
    # Ensure row is valid
    if row < buffer.height do
       # Ensure col is within bounds
      eff_col = min(col, buffer.width - 1)
      # Ensure count doesn't exceed available characters
      eff_count = min(count, buffer.width - eff_col)

      # Explicitly create blank cell with space character
      blank_cell = %Cell{char: " ", style: default_style}
      blank_cells_to_add = List.duplicate(blank_cell, eff_count)

      # Update the specific line
      new_cells = List.update_at(buffer.cells, row, fn line ->
        {left_part, part_to_modify} = Enum.split(line, eff_col)
        # Skip deleted chars and take the rest
        right_part_kept = Enum.drop(part_to_modify, eff_count)
        left_part ++ right_part_kept ++ blank_cells_to_add
      end)
      %{buffer | cells: new_cells}
    else
       buffer # Row out of bounds
    end
  end
  def delete_characters(buffer, _row, _col, _count, _default_style), do: buffer # No-op for invalid input

end
