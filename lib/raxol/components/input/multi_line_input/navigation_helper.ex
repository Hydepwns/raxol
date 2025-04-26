defmodule Raxol.Components.Input.MultiLineInput.NavigationHelper do
  @moduledoc """
  Helper functions for cursor navigation and text selection in MultiLineInput.
  """

  alias Raxol.Components.Input.MultiLineInput # May need state struct definition
  alias Raxol.Components.Input.MultiLineInput.TextHelper # Need pos_to_index
  require Logger

  # Implements cursor movement logic
  def move_cursor(state, {target_row, target_col}) do
    lines = TextHelper.split_into_lines(state.value, state.width, state.wrap)
    num_lines = length(lines)

    # Clamp target row within document bounds
    clamped_row = clamp(target_row, 0, num_lines - 1)

    # Clamp target column within the target line's bounds
    target_line_length = String.length(Enum.at(lines, clamped_row, ""))
    clamped_col = clamp(target_col, 0, target_line_length)

    %{state | cursor_row: clamped_row, cursor_col: clamped_col, selection_start: nil, selection_end: nil}
  end

  # Helper for clamping values (Needed by move_cursor)
  defp clamp(value, min_val, max_val) do
    max(min_val, min(value, max_val))
  end

  # Placeholder function
  def select(state, _range_or_direction), do: state

  # Moves cursor one word to the left
  def move_cursor_word_left(state) do
    lines = TextHelper.split_into_lines(state.value, state.width, state.wrap)
    {current_row, current_col} = {state.cursor_row, state.cursor_col}

    # If at start of doc, do nothing
    if current_row == 0 and current_col == 0 do
      state
    else
      # Combine lines up to cursor for easier searching
      flat_index = TextHelper.pos_to_index(lines, {current_row, current_col})
      text_before_cursor = String.slice(state.value, 0, flat_index)

      # Find the start of the previous word (regex for non-whitespace preceded by whitespace or start)
      # This is a simplified regex; a more robust one would handle punctuation.
      case :binary.match(text_before_cursor, ~r/\S+$/, [:global, :capture_original]) do
        [] -> # No non-whitespace found before cursor (e.g., only spaces)
              # Move to beginning of the current line if possible
              move_cursor(state, {current_row, 0})
        matches ->
          # Find the last match (closest non-whitespace sequence)
          last_match = List.last(matches)
          start_of_word_index = elem(last_match, 1)

          # Convert flat index back to {row, col}
          # This is inefficient, a dedicated index_to_pos helper would be better
          new_pos = index_to_pos(lines, start_of_word_index)
          move_cursor(state, new_pos)
      end
    end
  end

  # Moves cursor one word to the right
  def move_cursor_word_right(state) do
    lines = TextHelper.split_into_lines(state.value, state.width, state.wrap)
    {current_row, current_col} = {state.cursor_row, state.cursor_col}

    flat_index = TextHelper.pos_to_index(lines, {current_row, current_col})
    text_after_cursor = String.slice(state.value, flat_index..-1)

    # Find the start of the next word (whitespace followed by non-whitespace)
    case Regex.run(~r/^\s*(\S)/, text_after_cursor, capture: :first) do
      nil -> # No more words on this or subsequent lines
             # Move to end of document
             move_cursor_doc_end(state)
      [_full_match, _first_char] ->
        # Find the position of the *start* of the *next* word sequence
        # Search for first non-space AFTER current position, potentially after spaces
        case Regex.scan(~r/\S+/, text_after_cursor, return: :index) do
          [] -> # Should not happen if the run matched, but handle defensively
            move_cursor_doc_end(state)
          [{word_start_offset, _word_len} | _] ->
            new_flat_index = flat_index + word_start_offset
            new_pos = index_to_pos(lines, new_flat_index)
            move_cursor(state, new_pos)
        end
    end
  end

  # --- Helper needed for word movement ---
  # Inefficient: Converts flat index back to {row, col}.
  # TODO: Optimize this if performance becomes an issue.
  defp index_to_pos(text_lines, target_index) do
    Enum.reduce_while(Enum.with_index(text_lines), {0, 0, 0}, fn {line, row_idx}, {current_index, _found_row, _found_col} ->
      line_len = String.length(line)
      # Index at the end of this line (including newline char if not last line)
      end_of_line_index = current_index + line_len + (if row_idx < length(text_lines) - 1, do: 1, else: 0)

      if target_index <= current_index + line_len do
        # Target is within this line
        col = target_index - current_index
        {:halt, {0, row_idx, col}} # Use 0 in first element to signal found
      else
        # Target is after this line
        {:cont, {end_of_line_index, 0, 0}}
      end
    end)
    |> case do
      {0, found_row, found_col} -> {found_row, found_col}
      # Fallback if not found (e.g., index out of bounds), return end of doc
      _ ->
        last_row = max(0, length(text_lines) - 1)
        last_col = String.length(Enum.at(text_lines, last_row, ""))
        {last_row, last_col}
    end
  end

  # Moves cursor up or down by one page (component height)
  def move_cursor_page(state, direction) do
    page_amount = state.height
    current_row = state.cursor_row
    target_row =
      case direction do
        :up -> current_row - page_amount
        :down -> current_row + page_amount
        _ -> current_row
      end

    # Use existing move_cursor logic for clamping
    move_cursor(state, {target_row, state.cursor_col})
    # Note: Does not handle scroll_offset changes yet.
  end

  # Moves cursor to the beginning of the current line
  def move_cursor_line_start(state) do
    %{state | cursor_col: 0, selection_start: nil, selection_end: nil}
  end

  # Moves cursor to the end of the current line
  def move_cursor_line_end(state) do
    lines = TextHelper.split_into_lines(state.value, state.width, state.wrap)
    current_line_length = String.length(Enum.at(lines, state.cursor_row, ""))
    %{state | cursor_col: current_line_length, selection_start: nil, selection_end: nil}
  end

  # Moves cursor to the beginning of the document
  def move_cursor_doc_start(state) do
    %{state | cursor_row: 0, cursor_col: 0, selection_start: nil, selection_end: nil}
  end

  # Moves cursor to the end of the document
  def move_cursor_doc_end(state) do
    lines = TextHelper.split_into_lines(state.value, state.width, state.wrap)
    last_row = max(0, length(lines) - 1)
    last_col = String.length(Enum.at(lines, last_row, ""))
    %{state | cursor_row: last_row, cursor_col: last_col, selection_start: nil, selection_end: nil}
  end

  # Selects all text in the document
  def select_all(state) do
    lines = TextHelper.split_into_lines(state.value, state.width, state.wrap)
    last_row = max(0, length(lines) - 1)
    last_col = String.length(Enum.at(lines, last_row, ""))
    %{state | selection_start: {0, 0}, selection_end: {last_row, last_col}}
  end

  # Clears the current selection
  def clear_selection(state) do
    %{state | selection_start: nil, selection_end: nil}
  end

  # --- Selection Helpers ---

  # Checks if a given line index falls within the current selection range.
  def is_line_in_selection?(row_index, selection_start, selection_end)
      when not is_nil(selection_start) and not is_nil(selection_end) do
    {start_row, _start_col} = selection_start
    {end_row, _end_col} = selection_end

    # Ensure start_row <= end_row for comparison
    {start_row, end_row} =
      if start_row <= end_row, do: {start_row, end_row}, else: {end_row, start_row}

    row_index >= start_row and row_index <= end_row
  end

  def is_line_in_selection?(_row_index, _nil_start, _nil_end), do: false

  # Normalize selection ensuring start is before end based on text index.
  # Accepts state, returns {start_tuple, end_tuple} or {nil, nil} if no selection.
  def normalize_selection(%{selection_start: start_pos, selection_end: end_pos} = state) do
    case {start_pos, end_pos} do
      {nil, _} -> {nil, nil}
      {_, nil} -> {nil, nil}
      {{_start_row, _start_col} = start_tuple, {_end_row, _end_col} = end_tuple} ->
        # Convert to indices to determine order
        lines = String.split(state.value, "\n")
        start_index = TextHelper.pos_to_index(lines, start_tuple)
        end_index = TextHelper.pos_to_index(lines, end_tuple)

        if start_index <= end_index do
          {start_tuple, end_tuple}
        else
          # Swap them
          {end_tuple, start_tuple}
        end
      # Handle potential invalid state if selection is not nil or a tuple
      {_, _} -> {nil, nil}
    end
  end

end
