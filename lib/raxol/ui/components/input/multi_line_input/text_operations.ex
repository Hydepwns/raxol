defmodule Raxol.UI.Components.Input.MultiLineInput.TextOperations do
  @moduledoc """
  Handles text replacement operations including single-line and multi-line replacements.
  """

  require Raxol.Core.Runtime.Log
  import Raxol.Guards
  require Logger

  @doc """
  Replaces text within a range (from start_pos_tuple to end_pos_tuple) with the given replacement string.
  Returns {new_full_text, replaced_text}.
  """
  def replace_text_range(
        lines_list,
        start_pos_tuple,
        end_pos_tuple,
        replacement
      ) do
    Raxol.Core.Runtime.Log.debug(
      "replace_text_range: lines=#{inspect(lines_list)}, start=#{inspect(start_pos_tuple)}, end=#{inspect(end_pos_tuple)}, repl=#{inspect(replacement)}"
    )

    {start_row, start_col, end_row, end_col} =
      normalize_positions(start_pos_tuple, end_pos_tuple)

    {new_full_text, replaced_text} =
      perform_replacement(
        lines_list,
        start_row,
        start_col,
        end_row,
        end_col,
        replacement
      )

    {format_result(new_full_text), replaced_text}
  end

  defp normalize_positions({start_row, start_col}, {end_row, end_col}) do
    if start_row < end_row or (start_row == end_row and start_col <= end_col) do
      {start_row, start_col, end_row, end_col}
    else
      {end_row, end_col, start_row, start_col}
    end
  end

  defp perform_replacement(
         lines_list,
         start_row,
         start_col,
         end_row,
         end_col,
         replacement
       ) do
    if start_row == end_row do
      handle_single_line_replacement(
        lines_list,
        start_row,
        start_col,
        end_col,
        replacement
      )
    else
      handle_multi_line_replacement(
        lines_list,
        start_row,
        start_col,
        end_row,
        end_col,
        replacement
      )
    end
  end

  defp format_result(new_full_text) do
    if is_list(new_full_text),
      do: Enum.join(new_full_text, "\n"),
      else: new_full_text
  end

  defp handle_single_line_replacement(
         lines_list,
         row,
         start_col,
         end_col,
         replacement
       ) do
    line = Enum.at(lines_list, row, "")
    line_length = String.length(line)

    # Allow insertion at end of line (start_col == end_col and start_col == line_length)
    if start_col > line_length or
         (end_col > line_length and start_col != end_col) do
      {Enum.join(lines_list, "\n"), ""}
    else
      perform_single_line_replacement(
        lines_list,
        row,
        line,
        start_col,
        end_col,
        replacement,
        line_length
      )
    end
  end

  defp perform_single_line_replacement(
         lines_list,
         row,
         line,
         start_col,
         end_col,
         replacement,
         line_length
       ) do
    start_col = clamp(start_col, 0, line_length)
    end_col = clamp(end_col, 0, line_length)
    before = String.slice(line, 0, start_col)

    after_part =
      if end_col >= line_length - 1,
        do: "",
        else: String.slice(line, end_col, line_length - end_col)

    new_line = before <> replacement <> after_part
    new_lines = List.replace_at(lines_list, row, new_line)
    new_full_text = Enum.join(new_lines, "\n")
    replaced_text = String.slice(line, start_col, end_col - start_col)
    {new_full_text, replaced_text}
  end

  defp handle_multi_line_replacement(
         lines_list,
         start_row,
         start_col,
         end_row,
         end_col,
         replacement
       ) do
    num_lines = length(lines_list)
    # Out-of-bounds: treat as no-op
    if start_row >= num_lines or end_row >= num_lines or start_row < 0 or
         end_row < 0 do
      {Enum.join(lines_list, "\n"), ""}
    else
      build_replacement_result(
        lines_list,
        start_row,
        start_col,
        end_row,
        end_col,
        replacement
      )
    end
  end

  defp build_replacement_result(
         lines_list,
         start_row,
         start_col,
         end_row,
         end_col,
         replacement
       ) do
    {first_line_part, last_line_part} =
      extract_line_parts(lines_list, start_row, start_col, end_row, end_col)

    {lines_before, lines_after} =
      split_lines_around_range(lines_list, start_row, end_row)

    replaced_text =
      extract_replaced_text(lines_list, start_row, start_col, end_row, end_col)

    if replacement == "" do
      build_deletion_result(%{
        lines_list: lines_list,
        start_row: start_row,
        start_col: start_col,
        end_row: end_row,
        end_col: end_col,
        first_line_part: first_line_part,
        last_line_part: last_line_part,
        lines_before: lines_before,
        lines_after: lines_after,
        replaced_text: replaced_text
      })
    else
      new_line = first_line_part <> replacement <> last_line_part
      new_lines = lines_before ++ [new_line] ++ lines_after
      {Enum.join(new_lines, "\n"), replaced_text}
    end
  end

  defp build_deletion_result(%{
         lines_list: lines_list,
         start_row: start_row,
         start_col: start_col,
         end_row: end_row,
         end_col: end_col,
         first_line_part: first_line_part,
         last_line_part: last_line_part,
         lines_before: lines_before,
         lines_after: lines_after,
         replaced_text: replaced_text
       }) do
    start_line = Enum.at(lines_list, start_row, "")
    end_line = Enum.at(lines_list, end_row, "")

    if start_col == String.length(start_line) and end_col == 0 do
      # Join lines when deleting from end of one line to start of next
      joined_line =
        String.slice(start_line, 0, start_col) <>
          String.slice(end_line, end_col, String.length(end_line) - end_col)

      new_lines = lines_before ++ [joined_line] ++ lines_after
      {Enum.join(new_lines, "\n"), replaced_text}
    else
      # For multi-line deletions, join prefix of first line and suffix of last line into a single line
      joined_line =
        String.slice(start_line, 0, start_col) <>
          String.slice(end_line, end_col, String.length(end_line) - end_col)

      new_lines = lines_before ++ [joined_line] ++ lines_after
      {Enum.join(new_lines, "\n"), replaced_text}
    end
  end

  defp extract_line_parts(lines_list, start_row, start_col, end_row, end_col) do
    start_line = Enum.at(lines_list, start_row, "")
    end_line = Enum.at(lines_list, end_row, "")
    start_length = String.length(start_line)
    end_length = String.length(end_line)

    first_line_part =
      if start_row == end_row do
        String.slice(start_line, 0, start_col)
      else
        # For multi-line, prefix is up to start_col (exclusive)
        String.slice(start_line, 0, start_col)
      end

    last_line_part =
      if start_row == end_row do
        ""
      else
        # For multi-line, suffix is from end_col to end of line (exclusive)
        String.slice(end_line, end_col, end_length - end_col)
      end

    {first_line_part, last_line_part}
  end

  defp split_lines_around_range(lines_list, start_row, end_row) do
    lines_before = Enum.slice(lines_list, 0, start_row)

    lines_after =
      Enum.slice(lines_list, end_row + 1, length(lines_list) - (end_row + 1))

    {lines_before, lines_after}
  end

  defp extract_replaced_text(lines_list, start_row, start_col, end_row, end_col) do
    if start_row == end_row do
      extract_single_line_text(lines_list, start_row, start_col, end_col)
    else
      extract_multi_line_text(
        lines_list,
        start_row,
        start_col,
        end_row,
        end_col
      )
    end
  end

  defp extract_single_line_text(lines_list, row, start_col, end_col) do
    line = Enum.at(lines_list, row, "")
    line_length = String.length(line)
    start_col = clamp(start_col, 0, line_length)
    end_col = clamp(end_col, 0, line_length)

    if start_col >= end_col do
      ""
    else
      String.slice(line, start_col, end_col - start_col)
    end
  end

  defp extract_multi_line_text(
         lines_list,
         start_row,
         start_col,
         end_row,
         end_col
       ) do
    start_line = Enum.at(lines_list, start_row, "")
    start_length = String.length(start_line)
    start_col = clamp(start_col, 0, start_length)
    start_part = String.slice(start_line, start_col, start_length - start_col)

    end_line = Enum.at(lines_list, end_row, "")
    end_length = String.length(end_line)
    end_col = clamp(end_col, 0, end_length)
    end_part = String.slice(end_line, 0, end_col)

    middle_lines =
      if end_row > start_row + 1 do
        Enum.slice(lines_list, start_row + 1, end_row - start_row - 1)
      else
        []
      end

    if start_row == end_row do
      String.slice(start_line, start_col, end_col - start_col)
    else
      parts = [start_part] ++ middle_lines ++ [end_part]
      Enum.join(Enum.reject(parts, &(&1 == "")), "\n")
    end
  end

  defp clamp(value, min, max) do
    value |> max(min) |> min(max)
  end
end
