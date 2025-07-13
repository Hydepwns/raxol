defmodule Raxol.UI.Components.Input.MultiLineInput.TextOperations.SingleLine do
  @moduledoc """
  Handles single-line text operations.
  """

  alias Raxol.UI.Components.Input.MultiLineInput.TextOperations.Utils
  alias Raxol.UI.Components.Input.MultiLineInput.TextOperations.Selection

  @doc """
  Handles single-line text replacement.
  """
  def handle_single_line_replacement(lines_list, row, start_col, end_col, replacement) do
    line = Selection.get_line(lines_list, row)
    line_length = String.length(line)

    start_col = Utils.clamp(start_col, 0, line_length)
    end_col = Utils.clamp(end_col, 0, line_length)

    before = String.slice(line, 0, start_col)

    after_part =
      if end_col >= line_length - 1 and end_col < line_length,
        do: "",
        else: String.slice(line, end_col, line_length - end_col)

    new_line = before <> replacement <> after_part
    new_lines = List.replace_at(lines_list, row, new_line)
    new_full_text = Enum.join(new_lines, "\n")
    replaced_text = String.slice(line, start_col, end_col - start_col)

    {new_full_text, replaced_text}
  end

  @doc """
  Inserts text at a specific position in a single line.
  """
  def insert_text(lines_list, row, col, text) do
    line = Selection.get_line(lines_list, row)
    line_length = String.length(line)
    col = Utils.clamp(col, 0, line_length)

    before = String.slice(line, 0, col)
    after_part = String.slice(line, col, line_length - col)
    new_line = before <> text <> after_part

    new_lines = List.replace_at(lines_list, row, new_line)
    {Enum.join(new_lines, "\n"), ""}
  end

  @doc """
  Deletes text from a specific range in a single line.
  """
  def delete_text(lines_list, row, start_col, end_col) do
    handle_single_line_replacement(lines_list, row, start_col, end_col, "")
  end
end
