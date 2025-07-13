defmodule Raxol.UI.Components.Input.MultiLineInput.TextOperations do
  @moduledoc """
  Handles text replacement operations including single-line and multi-line replacements.

  This module delegates to specialized sub-modules:
  - `TextOperations.Utils` - Utility functions for text manipulation
  - `TextOperations.Selection` - Selection ranges and text extraction
  - `TextOperations.SingleLine` - Single-line text operations
  - `TextOperations.MultiLine` - Multi-line text operations
  """

  require Raxol.Core.Runtime.Log
  import Raxol.Guards
  require Logger

  alias Raxol.UI.Components.Input.MultiLineInput.TextOperations.Utils
  alias Raxol.UI.Components.Input.MultiLineInput.TextOperations.Selection
  alias Raxol.UI.Components.Input.MultiLineInput.TextOperations.SingleLine
  alias Raxol.UI.Components.Input.MultiLineInput.TextOperations.MultiLine

  @doc """
  Replaces text within a range (from start_pos_tuple to end_pos_tuple) with the given replacement string.
  Returns {new_full_text, replaced_text}.
  """
  def replace_text_range(lines_list, start_pos_tuple, end_pos_tuple, replacement) do
    Raxol.Core.Runtime.Log.debug(
      "replace_text_range: lines=#{inspect(lines_list)}, start=#{inspect(start_pos_tuple)}, end=#{inspect(end_pos_tuple)}, repl=#{inspect(replacement)}"
    )

    {start_row, start_col, end_row, end_col} = Selection.normalize_positions(start_pos_tuple, end_pos_tuple)

    {new_full_text, replaced_text} =
      if start_row == end_row do
        SingleLine.handle_single_line_replacement(lines_list, start_row, start_col, end_col, replacement)
      else
        MultiLine.handle_multi_line_replacement(lines_list, start_row, start_col, end_row, end_col, replacement)
      end

    {Utils.format_result(new_full_text), replaced_text}
  end

  @doc """
  Extracts text within a selection range.
  """
  def extract_selection(lines_list, start_pos, end_pos) do
    Selection.extract_selection(lines_list, start_pos, end_pos)
  end

  @doc """
  Inserts text at a specific position.
  """
  def insert_text(lines_list, row, col, text) do
    lines = String.split(text, "\n")

    if length(lines) == 1 do
      SingleLine.insert_text(lines_list, row, col, text)
    else
      MultiLine.insert_multi_line_text(lines_list, row, col, text)
    end
  end

  @doc """
  Deletes text from a specific range.
  """
  def delete_text(lines_list, start_row, start_col, end_row, end_col) do
    replace_text_range(lines_list, {start_row, start_col}, {end_row, end_col}, "")
  end
end
