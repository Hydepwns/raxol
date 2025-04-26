defmodule Raxol.Components.Input.MultiLineInput.TextHelper do
  @moduledoc """
  Helper functions for text and line manipulation in MultiLineInput.
  """

  alias Raxol.Components.Input.TextWrapping
  alias Raxol.Components.Input.MultiLineInput # May need state struct definition
  require Logger

  # --- Line Splitting and Wrapping ---

  def split_into_lines("", _width, _wrap), do: [""]

  def split_into_lines(text, width, wrap_mode) do
    lines = String.split(text, "\n")

    case wrap_mode do
      :none -> lines
      :char -> Enum.flat_map(lines, &TextWrapping.wrap_line_by_char(&1, width))
      :word -> Enum.flat_map(lines, &TextWrapping.wrap_line_by_word(&1, width))
    end
  end

  # Helper to split by newline and apply wrapping function
  def split_and_wrap(text, width, wrap_fun) do
    text
    |> String.split("\n")
    |> Enum.flat_map(&wrap_fun.(&1, width))
  end

  # --- Position Conversion ---

  # Helper to convert {row, col} tuple to a flat string index based on lines
  def pos_to_index(text_lines, {row, col}) do
    # Ensure col is within bounds of the line
    line_length =
      if row >= 0 and row < length(text_lines) do
        String.length(Enum.at(text_lines, row))
      else
        # Handle potential out-of-bounds row access gracefully
        0
      end

    safe_col = clamp(col, 0, line_length)

    # Get lines before the target row
    Enum.slice(text_lines, 0, row)
    |> Enum.map(&String.length(&1))
    # Sum lengths
    |> Enum.sum()
    # Add count for newline characters (\n) - use max(0, row) for safety
    |> Kernel.+(max(0, row))
    # Add the clamped column index on the target row
    |> Kernel.+(safe_col)
  end

  # --- Text Insertion/Deletion ---

  # Replaces text within a range ({row, col} tuples) with new text
  # Returns {new_full_text, replaced_text}
  def replace_text_range(text, start_pos_tuple, end_pos_tuple, replacement) do
    # Needed for index calculation
    lines = String.split(text, "\n")

    start_index = pos_to_index(lines, start_pos_tuple)
    end_index = pos_to_index(lines, end_pos_tuple)

    # Ensure start_index is <= end_index
    {start_index, end_index} = {min(start_index, end_index), max(start_index, end_index)}

    # Ensure indices are within the bounds of the original text length
    text_len = String.length(text)
    start_index = clamp(start_index, 0, text_len)
    end_index = clamp(end_index, 0, text_len)

    text_before = String.slice(text, 0, start_index)
    text_after = String.slice(text, end_index..-1//1)

    # The actual text being replaced
    replaced_text = String.slice(text, start_index, max(0, end_index - start_index))

    new_full_text = text_before <> replacement <> text_after

    {new_full_text, replaced_text}
  end


  def insert_char(state, char) do
    %{value: value, cursor_row: row, cursor_col: col} = state
    # Use range helper to insert the character, passing tuples
    start_pos = {row, col}
    {new_value, _} = replace_text_range(value, start_pos, start_pos, char)

    # Calculate new cursor position based on inserted char
    {new_row, new_col} = calculate_new_position(row, col, char)

    # Use struct syntax
    new_state = %MultiLineInput{
      # Use state | pattern for brevity
      state
      | value: new_value,
        cursor_row: new_row,
        cursor_col: new_col,
        # Clear selection after insertion
        selection_start: nil,
        selection_end: nil
    }

    if state.on_change, do: state.on_change.(new_value)
    new_state
  end

  def delete_selection(state) do
    # Get normalized {row, col} tuples
    {start_pos, end_pos} = normalize_selection(state)
    # Use range helper
    {new_value, deleted_text} =
      replace_text_range(state.value, start_pos, end_pos, "")

    # Move cursor to the start of the deleted selection
    new_state = %MultiLineInput{
      state
      | value: new_value,
        cursor_row: elem(start_pos, 0),
        cursor_col: elem(start_pos, 1),
        selection_start: nil,
        selection_end: nil
    }

    if state.on_change, do: state.on_change.(new_value)
    # Return the state and the deleted text (useful for cut)
    {new_state, deleted_text}
  end

  def handle_backspace_no_selection(state) do
    %{value: value, cursor_row: row, cursor_col: col} = state

    # Handle backspace at the beginning of the document
    if row == 0 and col == 0 do
      state
    else
      # Calculate position before backspace
      {prev_row, prev_col} =
        if col > 0 do
          {row, col - 1}
        else
          # Move to the end of the previous line
          lines = String.split(value, "\n")
          prev_line_index = row - 1
          prev_line_length = String.length(Enum.at(lines, prev_line_index))
          {prev_line_index, prev_line_length}
        end

      # Use range helpers with {row, col} tuples
      start_pos = {prev_row, prev_col}
      end_pos = {row, col}

      {new_value, _deleted_text} =
        replace_text_range(value, start_pos, end_pos, "")

      # Use struct syntax for new_state
      new_state = %MultiLineInput{
        state
        | value: new_value,
          cursor_row: prev_row,
          cursor_col: prev_col,
          selection_start: nil,
          selection_end: nil
      }

      # Handle on_change function with properly returned value
      if state.on_change do
        # Call on_change but don't ignore the result
        _ = state.on_change.(new_value)
      end

      # Return the new state
      new_state
    end
  end

  def handle_delete_no_selection(state) do
    %{value: value, cursor_row: row, cursor_col: col} = state
    lines = String.split(value, "\n")
    current_line = Enum.at(lines, row)

    # Handle delete at the end of the document/line
    if col == String.length(current_line) and row == length(lines) - 1 do
      # At the very end, nothing to delete
      state
    else
      # Calculate position after the character to delete
      {next_row, next_col} =
        if col < String.length(current_line) do
          # Delete char on the same line
          {row, col + 1}
        else
          # Delete the newline character
          {row + 1, 0}
        end

      # Use range helpers with {row, col} tuples
      start_pos = {row, col}
      end_pos = {next_row, next_col}

      {new_value_from_replace, _deleted_text} =
        replace_text_range(value, start_pos, end_pos, "")

      # Use the value directly from replace_text_range
      new_state = %MultiLineInput{
        state
        | # Use result from helper
          value: new_value_from_replace,
          selection_start: nil,
          selection_end: nil
      }

      # Handle on_change function with properly returned value
      if state.on_change do
        # Call on_change but don't ignore the result
        _ = state.on_change.(new_value_from_replace)
      end

      # Return the updated state
      new_state
    end
  end

  # --- Internal Helpers (used by functions above) ---

  defp clamp(value, min, max) do
    value |> max(min) |> min(max)
  end

  defp calculate_new_position(row, col, inserted_text) do
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

  # Need normalize_selection here as delete_selection depends on it
  defp normalize_selection(state) do
    start_pos = state.selection_start || {state.cursor_row, state.cursor_col}
    end_pos = state.selection_end || {state.cursor_row, state.cursor_col}

    # Convert to indices and normalize
    lines = String.split(state.value, "\n")
    start_index = pos_to_index(lines, start_pos)
    end_index = pos_to_index(lines, end_pos)

    # Swap if needed
    if start_index <= end_index do
      {start_pos, end_pos}
    else
      {end_pos, start_pos}
    end
  end

end
