defmodule Raxol.Terminal.Buffer.CharEditor do
  @moduledoc """
  Handles character editing operations in the terminal buffer.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ANSI.TextFormatting

  @doc """
  Inserts a specified number of blank characters at the given row and column index
  using the provided default_style.
  Characters to the right of the insertion point are shifted right. Characters shifted
  off the end of the line are discarded. Uses the buffer's default style for new cells.
  """
  @spec insert_characters(
          ScreenBuffer.t(),
          integer(),
          integer(),
          integer(),
          TextFormatting.text_style()
        ) :: ScreenBuffer.t()
  def insert_characters(
        %ScreenBuffer{} = buffer,
        row,
        col,
        count,
        default_style
      )
      when row >= 0 and col >= 0 and count > 0 do
    if row < buffer.height do
      blank_cell = %Cell{char: " ", style: default_style}
      blank_cells_to_insert = List.duplicate(blank_cell, count)

      new_cells =
        List.update_at(buffer.cells, row, fn line ->
          {left_part, right_part} = Enum.split(line, col)
          {to_shift, _rest} = Enum.split(right_part, buffer.width - col - count)
          combined_line = left_part ++ blank_cells_to_insert ++ to_shift
          combined_line ++ List.duplicate(blank_cell, buffer.width - length(combined_line))
        end)

      %{buffer | cells: new_cells}
    else
      buffer
    end
  end

  # No-op for invalid input
  def insert_characters(buffer, _row, _col, _count, _default_style), do: buffer

  @doc """
  Deletes a specified number of characters starting from the given row and column index.
  Characters to the right of the deleted characters are shifted left. Blank characters
  are added at the end of the line to fill the space using the provided default_style.
  Uses the buffer's default style for new cells.
  """
  @spec delete_characters(
          ScreenBuffer.t(),
          integer(),
          integer(),
          integer(),
          TextFormatting.text_style()
        ) :: ScreenBuffer.t()
  def delete_characters(
        %ScreenBuffer{} = buffer,
        row,
        col,
        count,
        default_style
      )
      when row >= 0 and col >= 0 and count > 0 do
    if row < buffer.height do
      eff_col = min(col, buffer.width - 1)
      eff_count = min(count, buffer.width - eff_col)
      blank_cell = %Cell{char: " ", style: default_style}

      new_cells =
        List.update_at(buffer.cells, row, fn line ->
          {left_part, part_to_modify} = Enum.split(line, eff_col)
          right_part_kept = Enum.drop(part_to_modify, eff_count)
          combined_line = left_part ++ right_part_kept
          combined_line ++ List.duplicate(blank_cell, buffer.width - length(combined_line))
        end)

      %{buffer | cells: new_cells}
    else
      buffer
    end
  end

  # No-op for invalid input
  def delete_characters(buffer, _row, _col, _count, _default_style), do: buffer
end
