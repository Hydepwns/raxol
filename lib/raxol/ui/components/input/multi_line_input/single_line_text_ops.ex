defmodule Raxol.UI.Components.Input.MultiLineInput.TextOperations.SingleLine do
  @moduledoc """
  Handles single-line text operations.
  """

  alias Raxol.UI.Components.Input.MultiLineInput.TextOperations.Utils
  alias Raxol.UI.Components.Input.MultiLineInput.TextOperations.Selection

  @doc """
  Handles single-line text replacement.
  """
  def handle_single_line_replacement(
        lines_list,
        row,
        start_col,
        end_col,
        replacement
      ) do
    line = Selection.get_line(lines_list, row)
    line_length = String.length(line)

    handle_replacement_bounds(out_of_bounds?(start_col, end_col, line_length), {
      lines_list,
      row,
      start_col,
      end_col,
      replacement,
      line,
      line_length
    })
  end

  defp out_of_bounds?(start_col, end_col, line_length) do
    start_col > line_length and end_col > line_length
  end

  defp build_replacement_result(
         lines_list,
         row,
         start_col,
         end_col,
         replacement,
         line,
         line_length
       ) do
    {actual_start_col, actual_end_col} = normalize_positions(start_col, end_col)

    {before, after_part} =
      extract_line_parts(line, actual_start_col, actual_end_col, line_length)

    new_line = before <> replacement <> after_part
    new_lines = List.replace_at(lines_list, row, new_line)
    new_full_text = Enum.join(new_lines, "\n")

    replaced_text =
      String.slice(line, actual_start_col, actual_end_col - actual_start_col)

    {new_full_text, replaced_text}
  end

  defp normalize_positions(start_col, end_col) do
    swap_positions_if_needed(start_col > end_col, start_col, end_col)
  end

  defp extract_line_parts(line, actual_start_col, actual_end_col, line_length) do
    before = String.slice(line, 0, actual_start_col)

    after_part =
      get_line_remainder(
        actual_end_col >= line_length,
        line,
        actual_end_col,
        line_length
      )

    {before, after_part}
  end

  @doc """
  Inserts text at a specific position in a single line.
  """
  def insert_text(lines_list, row, col, text) do
    line = Selection.get_line(lines_list, row)
    {new_line, _remainder} = Utils.insert_into_line(line, col, text)

    new_lines = List.replace_at(lines_list, row, new_line)
    {Enum.join(new_lines, "\n"), ""}
  end

  @doc """
  Deletes text from a specific range in a single line.
  """
  def delete_text(lines_list, row, start_col, end_col) do
    handle_single_line_replacement(lines_list, row, start_col, end_col, "")
  end

  # Pattern matching helpers to eliminate if statements
  defp handle_replacement_bounds(
         true,
         {lines_list, _row, _start_col, _end_col, _replacement, _line,
          _line_length}
       ) do
    {Enum.join(lines_list, "\n"), ""}
  end

  defp handle_replacement_bounds(
         false,
         {lines_list, row, start_col, end_col, replacement, line, line_length}
       ) do
    build_replacement_result(
      lines_list,
      row,
      start_col,
      end_col,
      replacement,
      line,
      line_length
    )
  end

  defp swap_positions_if_needed(true, start_col, end_col),
    do: {end_col, start_col}

  defp swap_positions_if_needed(false, start_col, end_col),
    do: {start_col, end_col}

  defp get_line_remainder(true, _line, _actual_end_col, _line_length), do: ""

  defp get_line_remainder(false, line, actual_end_col, line_length) do
    String.slice(line, actual_end_col, line_length - actual_end_col)
  end
end
