defmodule Raxol.UI.Components.Input.MultiLineInput.TextOperations.Selection do
  @moduledoc """
  Handles selection ranges and text extraction operations.
  """

  alias Raxol.UI.Components.Input.MultiLineInput.TextOperations.Utils

  @doc """
  Normalizes positions to ensure start is before end.
  Returns {start_row, start_col, end_row, end_col}.
  """
  def normalize_positions({start_row, start_col}, {end_row, end_col}) do
    if start_row < end_row or (start_row == end_row and start_col <= end_col) do
      {start_row, start_col, end_row, end_col}
    else
      {end_row, end_col, start_row, start_col}
    end
  end

  @doc """
  Extracts text within a selection range.
  """
  def extract_selection(lines_list, start_pos, end_pos) do
    {start_row, start_col, end_row, end_col} = normalize_positions(start_pos, end_pos)

    if start_row == end_row do
      extract_single_line_selection(lines_list, start_row, start_col, end_col)
    else
      extract_multi_line_selection(lines_list, start_row, start_col, end_row, end_col)
    end
  end

  defp extract_single_line_selection(lines_list, row, start_col, end_col) do
    line = get_line(lines_list, row)
    line_length = String.length(line)
    start_col = Utils.clamp(start_col, 0, line_length)
    end_col = Utils.clamp(end_col, 0, line_length)
    String.slice(line, start_col, end_col - start_col)
  end

  defp extract_multi_line_selection(lines_list, start_row, start_col, end_row, end_col) do
    start_line = get_line(lines_list, start_row)
    end_line = get_line(lines_list, end_row)

    start_line_part = String.slice(start_line, start_col, String.length(start_line) - start_col)
    middle_lines = Enum.slice(lines_list, start_row + 1, end_row - start_row - 1)
    end_line_part = String.slice(end_line, 0, end_col)

    [start_line_part | middle_lines] ++ [end_line_part]
    |> Enum.join("\n")
  end

  @doc """
  Gets a line from a list of lines with bounds checking.
  """
  def get_line(lines_list, row, default \\ "") do
    Enum.at(lines_list, row, default)
  end

  @doc """
  Gets the length of a line with bounds checking.
  """
  def line_length(lines_list, row) do
    get_line(lines_list, row) |> String.length()
  end
end
