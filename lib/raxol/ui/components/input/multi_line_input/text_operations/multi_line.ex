defmodule Raxol.UI.Components.Input.MultiLineInput.TextOperations.MultiLine do
  @moduledoc """
  Handles multi-line text operations.
  """

  alias Raxol.UI.Components.Input.MultiLineInput.TextOperations.Utils
  alias Raxol.UI.Components.Input.MultiLineInput.TextOperations.Selection

  def handle_multi_line_replacement(lines_list, start_row, start_col, end_row, end_col, replacement) do
    start_line = Selection.get_line(lines_list, start_row)
    end_line = Selection.get_line(lines_list, end_row)

    first_line_part = String.slice(start_line, 0, start_col)
    last_line_part = String.slice(end_line, end_col, String.length(end_line) - end_col)

    new_lines = build_new_lines(lines_list, start_row, end_row, first_line_part, last_line_part, replacement)
    new_full_text = Enum.join(new_lines, "\n")
    replaced_text = extract_replaced_text(lines_list, start_row, start_col, end_row, end_col)

    {new_full_text, replaced_text}
  end

  defp build_new_lines(lines_list, start_row, end_row, first_line_part, last_line_part, replacement) do
    lines_before = Enum.slice(lines_list, 0, start_row)

    new_middle_lines =
      if replacement == "" do
        []
      else
        [first_line_part <> replacement <> last_line_part]
      end

    lines_after = Enum.slice(lines_list, end_row + 1, length(lines_list) - (end_row + 1))
    lines_before ++ new_middle_lines ++ lines_after
  end

  defp extract_replaced_text(lines_list, start_row, start_col, end_row, end_col) do
    start_line = Selection.get_line(lines_list, start_row)
    end_line = Selection.get_line(lines_list, end_row)

    start_line_part = String.slice(start_line, start_col, String.length(start_line) - start_col)
    middle_lines = Enum.slice(lines_list, start_row + 1, end_row - start_row - 1)
    end_line_part = String.slice(end_line, 0, end_col)

    [start_line_part | middle_lines] ++ [end_line_part]
    |> Enum.join("\n")
  end

  def insert_multi_line_text(lines_list, row, col, text) do
    lines = String.split(text, "\n")

    if length(lines) == 1 do
      line = Selection.get_line(lines_list, row)
      line_length = String.length(line)
      col = Utils.clamp(col, 0, line_length)

      before = String.slice(line, 0, col)
      after_part = String.slice(line, col, line_length - col)
      new_line = before <> text <> after_part

      new_lines = List.replace_at(lines_list, row, new_line)
      {Enum.join(new_lines, "\n"), ""}
    else
      handle_multi_line_insertion(lines_list, row, col, lines)
    end
  end

  defp handle_multi_line_insertion(lines_list, row, col, [first_line | rest_lines]) do
    current_line = Selection.get_line(lines_list, row)
    line_length = String.length(current_line)
    col = Utils.clamp(col, 0, line_length)

    before = String.slice(current_line, 0, col)
    after_part = String.slice(current_line, col, line_length - col)

    new_first_line = before <> first_line

    case rest_lines do
      [] ->
        new_lines = List.replace_at(lines_list, row, new_first_line <> after_part)
        {Enum.join(new_lines, "\n"), ""}
      [last_line] ->
        new_last_line = last_line <> after_part
        lines_before = Enum.slice(lines_list, 0, row)
        lines_after = Enum.slice(lines_list, row + 1, length(lines_list) - (row + 1))
        new_lines = lines_before ++ [new_first_line, new_last_line] ++ lines_after
        {Enum.join(new_lines, "\n"), ""}
      _ ->
        last_line = List.last(rest_lines)
        middle_lines = Enum.slice(rest_lines, 0, length(rest_lines) - 1)
        new_last_line = last_line <> after_part

        lines_before = Enum.slice(lines_list, 0, row)
        lines_after = Enum.slice(lines_list, row + 1, length(lines_list) - (row + 1))
        new_lines = lines_before ++ [new_first_line | middle_lines] ++ [new_last_line] ++ lines_after
        {Enum.join(new_lines, "\n"), ""}
    end
  end
end
