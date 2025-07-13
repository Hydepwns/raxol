defmodule Raxol.UI.Components.Input.MultiLineInput.TextEditing do
  @moduledoc """
  Handles text editing operations including character insertion, deletion, and cursor management.
  """

  alias Raxol.UI.Components.Input.MultiLineInput
  alias Raxol.UI.Components.Input.MultiLineInput.NavigationHelper
  alias Raxol.UI.Components.Input.MultiLineInput.TextOperations
  require Raxol.Core.Runtime.Log

  @doc """
  Inserts a character or codepoint at the current cursor position.
  """
  def insert_char(state, char_or_codepoint) do
    %{lines: lines, cursor_pos: {row, col}} = state

    char_binary = convert_to_binary(char_or_codepoint)

    {new_text, _} =
      TextOperations.replace_text_range(lines, {row, col}, {row, col}, char_binary)

    new_lines = String.split(new_text, "\n")
    {new_row, new_col} =
      calculate_new_cursor_position({row, col}, char_or_codepoint, char_binary)

    new_state = %MultiLineInput{
      state
      | lines: new_lines,
        cursor_pos: {new_row, new_col},
        selection_start: nil,
        selection_end: nil,
        value: new_text
    }

    if state.on_change, do: state.on_change.(new_text)
    new_state
  end

  @doc """
  Deletes the currently selected text in the state, updating lines and value.
  """
  def delete_selection(state) do
    %{lines: lines} = state

    {start_pos, end_pos} =
      NavigationHelper.normalize_selection(state)

    if start_pos == nil or end_pos == nil do
      Raxol.Core.Runtime.Log.warning(
        "Attempted to delete invalid selection: #{inspect(state.selection_start)} to #{inspect(state.selection_end)}"
      )

      {state, ""}
    else
      {new_text, deleted_text} =
        TextOperations.replace_text_range(lines, start_pos, end_pos, "")

      new_lines = String.split(new_text, "\n")
      new_full_text_str = new_text

      new_state = %MultiLineInput{
        state
        | lines: new_lines,
          cursor_pos: start_pos,
          selection_start: nil,
          selection_end: nil,
          value: new_full_text_str
      }

      if state.on_change, do: state.on_change.(new_full_text_str)
      {new_state, deleted_text}
    end
  end

  @doc """
  Handles backspace when no text is selected.
  """
  def handle_backspace_no_selection(state) do
    %{lines: lines, cursor_pos: {row, col}} = state

    # Handle backspace at the beginning of the document
    if at_document_start?(row, col) do
      state
    else
      prev_position = calculate_previous_position(lines, row, col)
      update_state_after_deletion(state, lines, prev_position, {row, col})
    end
  end

  @doc """
  Handles delete key when no text is selected.
  """
  def handle_delete_no_selection(state) do
    %{lines: lines, cursor_pos: {row, col}} = state
    num_lines = length(lines)

    if row >= num_lines or at_end_of_document?(lines, row, col) do
      state
    else
      next_position = calculate_next_position(lines, row, col)

      {new_text, _deleted_text} =
        TextOperations.replace_text_range(lines, {row, col}, next_position, "")

      new_lines = String.split(new_text, "\n")
      new_full_text_str = new_text

      new_state = %MultiLineInput{
        state
        | lines: new_lines,
          selection_start: nil,
          selection_end: nil,
          value: new_full_text_str
      }

      if state.on_change, do: state.on_change.(new_full_text_str)
      new_state
    end
  end

  # --- Private helper functions ---

  defp convert_to_binary(char_or_codepoint) do
    case char_or_codepoint do
      cp when is_integer(cp) -> <<cp::utf8>>
      bin when is_binary(bin) -> bin
      _ -> ""
    end
  end

  defp calculate_new_cursor_position({row, col}, char_or_codepoint, char_binary) do
    case char_or_codepoint do
      10 -> {row + 1, 0}
      _ -> calculate_position_for_text({row, col}, char_binary)
    end
  end

  defp calculate_position_for_text({row, col}, char_binary) do
    lines_in_inserted = String.split(char_binary, "\n")
    num_lines = length(lines_in_inserted)

    if num_lines == 1 do
      {row, col + String.length(char_binary)}
    else
      last_line_length = String.length(List.last(lines_in_inserted))
      {row + num_lines - 1, last_line_length}
    end
  end

  defp at_end_of_document?(lines, row, col) do
    num_lines = length(lines)
    current_line = Enum.at(lines, row) || ""
    current_line_length = String.length(current_line)
    col == current_line_length and row == num_lines - 1
  end

  defp calculate_next_position(lines, row, col) do
    current_line = Enum.at(lines, row) || ""
    current_line_length = String.length(current_line)
    num_lines = length(lines)

    if col == current_line_length and row < num_lines - 1 do
      {row + 1, 0}
    else
      {row, col + 1}
    end
  end

  defp at_document_start?(row, col), do: row == 0 and col == 0

  defp calculate_previous_position(lines, row, col) do
    if col == 0 and row > 0 do
      prev_line = Enum.at(lines, row - 1)
      prev_col = String.length(prev_line)
      {row - 1, prev_col}
    else
      {row, col - 1}
    end
  end

  defp update_state_after_deletion(state, lines, start_pos, end_pos) do
    {new_text, _deleted_text} =
      TextOperations.replace_text_range(lines, start_pos, end_pos, "")

    new_lines = String.split(new_text, "\n")
    new_full_text_str = new_text

    new_state = %MultiLineInput{
      state
      | lines: new_lines,
        cursor_pos: start_pos,
        selection_start: nil,
        selection_end: nil,
        value: new_full_text_str
    }

    if state.on_change, do: state.on_change.(new_full_text_str)
    new_state
  end

  @doc """
  Calculates the new cursor position after inserting text.
  """
  def calculate_new_position(row, col, inserted_text) do
    if inserted_text == "" do
      {row, col}
    else
      lines = String.split(inserted_text, "\n", trim: false)
      num_lines = length(lines)

      if num_lines == 1 do
        # Single line insertion
        {row, col + String.length(inserted_text)}
      else
        # Multi-line insertion
        last_line_len = String.length(List.last(lines))
        {row + num_lines - 1, last_line_len}
      end
    end
  end
end
