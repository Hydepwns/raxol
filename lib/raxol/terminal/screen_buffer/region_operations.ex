defmodule Raxol.Terminal.ScreenBuffer.RegionOperations do
  @moduledoc """
  Handles region operations for the terminal screen buffer.

  This module provides functionality for filling regions with content,
  text replacement operations, and region manipulation utilities.
  """

  alias Raxol.Terminal.Buffer.Selection

  @doc """
  Fills a region of the buffer with a specified cell.
  """
  def fill_region(buffer, x, y, width, height, cell) do
    # Validate coordinates
    validate_region_params(x, y, width, height)
    validate_region_bounds(x, y, width, height, buffer)

    # Fill the region with the specified cell
    new_cells =
      Enum.reduce(y..(y + height - 1), buffer.cells, fn row_y, acc_cells ->
        List.update_at(acc_cells, row_y, &fill_row(&1, x, width, cell))
      end)

    %{buffer | cells: new_cells}
  end

  @doc """
  Handles single line text replacement within a region.
  """
  def handle_single_line_replacement(
        lines_list,
        row,
        start_col,
        end_col,
        replacement
      ) do
    line = get_line(lines_list, row)
    line_length = String.length(line)

    # Only allow replacement if both start_col and end_col are within bounds
    handle_line_replacement(
      start_col < 0 or end_col > line_length or start_col > end_col,
      lines_list,
      line,
      row,
      start_col,
      end_col,
      line_length,
      replacement
    )
  end

  # Private helper functions

  defp fill_row(row, x, width, cell) do
    Enum.reduce(x..(x + width - 1), row, fn col_x, acc_row ->
      List.replace_at(acc_row, col_x, cell)
    end)
  end

  # Helper functions for if-statement elimination
  defp validate_region_params(x, y, width, height) do
    check_region_params(
      x < 0 or y < 0 or width <= 0 or height <= 0,
      x,
      y,
      width,
      height
    )
  end

  defp check_region_params(true, x, y, width, height) do
    raise ArgumentError,
          "Invalid region parameters: x=#{x}, y=#{y}, width=#{width}, height=#{height}"
  end

  defp check_region_params(false, _x, _y, _width, _height), do: :ok

  defp validate_region_bounds(x, y, width, height, buffer) do
    check_region_bounds(x + width > buffer.width or y + height > buffer.height)
  end

  defp check_region_bounds(true) do
    raise ArgumentError, "Region extends beyond buffer bounds"
  end

  defp check_region_bounds(false), do: :ok

  defp handle_line_replacement(
         true,
         lines_list,
         _line,
         _row,
         _start_col,
         _end_col,
         _line_length,
         _replacement
       ) do
    new_full_text = Enum.join(lines_list, "\n")
    {new_full_text, ""}
  end

  defp handle_line_replacement(
         false,
         lines_list,
         line,
         row,
         start_col,
         end_col,
         line_length,
         replacement
       ) do
    before = String.slice(line, 0, start_col)
    after_part = String.slice(line, end_col, line_length - end_col)
    new_line = before <> replacement <> after_part
    new_lines = List.replace_at(lines_list, row, new_line)
    new_full_text = Enum.join(new_lines, "\n")
    replaced_text = String.slice(line, start_col, end_col - start_col)
    {new_full_text, replaced_text}
  end

  defp get_line(lines_list, row) do
    Selection.get_line(lines_list, row)
  end
end
