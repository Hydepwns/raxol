defmodule Raxol.UI.Components.Input.MultiLineInput.NavigationHelper do
  @moduledoc """
  Helper functions for cursor navigation and text selection in MultiLineInput.
  """

  # alias Raxol.UI.Components.Input.MultiLineInput # May need state struct definition
  # Need pos_to_index
  alias Raxol.UI.Components.Input.MultiLineInput.TextHelper
  require Raxol.Core.Runtime.Log

  @doc """
  Moves the cursor.

  It can take a `{row, col}` tuple to move to a specific position, or an atom to move directionally.

  ## Directions
  - `{row, col}`: Moves to the specified position, clamped to document bounds.
  - `:left`: Moves one position to the left, or to the end of the previous line.
  - `:right`: Moves one position to the right, or to the start of the next line.
  - `:up`: Moves up by one line.
  - `:down`: Moves down by one line.
  - `:word_left`: Moves one word to the left.
  - `:word_right`: Moves one word to the right.
  """
  def move_cursor(state, {target_row, target_col}) do
    lines = TextHelper.split_into_lines(state.value, state.width, state.wrap)
    num_lines = length(lines)

    # Clamp target row within document bounds
    clamped_row = clamp(target_row, 0, num_lines - 1)

    # Clamp target column within the target line's bounds
    target_line_length = String.length(Enum.at(lines, clamped_row, ""))
    clamped_col = clamp(target_col, 0, target_line_length)

    %{
      state
      | cursor_pos: {clamped_row, clamped_col},
        desired_col: clamped_col,
        selection_start: nil,
        selection_end: nil
    }
  end

  # --- Add heads for directional movement ---
  def move_cursor(state, :left) do
    {row, col} = state.cursor_pos

    move_cursor_left_within_line_or_previous(state, row, col)
  end

  def move_cursor(state, :right) do
    {row, col} = state.cursor_pos
    lines = state.lines
    current_line = Enum.at(lines, row, "")
    current_line_length = String.length(current_line)

    move_cursor_right_within_line_or_next(
      state,
      row,
      col,
      lines,
      current_line_length
    )
  end

  def move_cursor(state, :up) do
    {row, col} = state.cursor_pos
    new_row = max(0, row - 1)

    # Use state.lines if present, otherwise split lines
    lines =
      Map.get(state, :lines) ||
        TextHelper.split_into_lines(state.value, state.width, state.wrap)

    # Use desired_col if available, otherwise use current column
    desired_col = state.desired_col || col

    # Get the target line to check its length
    target_line = Enum.at(lines, new_row, "")
    target_line_length = String.length(target_line)

    # Use desired_col if it fits on the target line, otherwise use the line length
    new_col = min(desired_col, target_line_length)

    %{state | cursor_pos: {new_row, new_col}, desired_col: desired_col}
  end

  def move_cursor(state, :down) do
    {row, col} = state.cursor_pos
    # Use state.lines if present, otherwise split lines
    lines =
      Map.get(state, :lines) ||
        TextHelper.split_into_lines(state.value, state.width, state.wrap)

    num_lines = length(lines)
    new_row = min(num_lines - 1, row + 1)

    # Use desired_col if available, otherwise use current column
    desired_col = state.desired_col || col

    # Get the target line to check its length
    target_line = Enum.at(lines, new_row, "")
    target_line_length = String.length(target_line)

    # Use desired_col if it fits on the target line, otherwise use the line length
    new_col = min(desired_col, target_line_length)

    %{state | cursor_pos: {new_row, new_col}, desired_col: desired_col}
  end

  def move_cursor(state, :word_left) do
    move_cursor_word_left(state)
  end

  def move_cursor(state, :word_right) do
    move_cursor_word_right(state)
  end

  # --- End added heads ---

  # Helper for clamping values (Needed by move_cursor)
  defp clamp(value, min_val, max_val) do
    max(min_val, min(value, max_val))
  end

  # Placeholder function
  def select(state, _range_or_direction), do: state

  # Moves cursor one word to the left, using regex to find the previous word boundary.
  @doc """
  Moves the cursor one word to the left, using regex to find the previous word boundary.
  """
  def move_cursor_word_left(state) do
    lines = TextHelper.split_into_lines(state.value, state.width, state.wrap)
    {current_row, current_col} = state.cursor_pos

    # If at start of doc, do nothing
    case at_document_start?(current_row, current_col) do
      true ->
        state

      false ->
        # Combine lines up to cursor for easier searching
        flat_index = TextHelper.pos_to_index(lines, {current_row, current_col})
        text_before_cursor = String.slice(state.value, 0, flat_index)

        # Find the start of the previous word (regex for non-whitespace preceded by whitespace or start)
        # This is a simplified regex; a more robust one would handle punctuation.
        case :binary.match(text_before_cursor, ~r/\S+$/, [
               :global,
               :capture_original
             ]) do
          # No non-whitespace found before cursor (e.g., only spaces)
          [] ->
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

  # Moves cursor one word to the right, using regex to find the next word boundary.
  @doc """
  Moves the cursor one word to the right, using regex to find the next word boundary.
  """
  def move_cursor_word_right(state) do
    lines = TextHelper.split_into_lines(state.value, state.width, state.wrap)
    {current_row, current_col} = state.cursor_pos

    flat_index = TextHelper.pos_to_index(lines, {current_row, current_col})
    text_after_cursor = String.slice(state.value, flat_index..-1)

    # Find the start of the next word (whitespace followed by non-whitespace)
    case Regex.run(~r/^\s*(\S)/, text_after_cursor, capture: :first) do
      # No more words on this or subsequent lines
      nil ->
        # Move to end of document
        move_cursor_doc_end(state)

      [_full_match, _first_char] ->
        # Find the position of the *start* of the *next* word sequence
        # Search for first non-space AFTER current position, potentially after spaces
        case Regex.scan(~r/\S+/, text_after_cursor, return: :index) do
          # Should not happen if the run matched, but handle defensively
          [] ->
            move_cursor_doc_end(state)

          [{word_start_offset, _word_len} | _] ->
            new_flat_index = flat_index + word_start_offset
            new_pos = index_to_pos(lines, new_flat_index)
            move_cursor(state, new_pos)
        end
    end
  end

  # --- Helper needed for word movement ---
  # Converts flat index back to {row, col}.
  defp index_to_pos(text_lines, target_index) do
    find_position(text_lines, target_index, 0, 0)
  end

  defp find_position([], _target_index, row, _col) do
    {row, 0}
  end

  defp find_position([line | rest], target_index, row, current_index) do
    line_length = String.length(line)
    end_of_line_index = current_index + line_length

    find_position_in_line_or_continue(
      target_index,
      end_of_line_index,
      current_index,
      row,
      rest
    )
  end

  # Moves cursor up or down by one page (component height)
  def move_cursor_page(state, direction) do
    {row, col} = state.cursor_pos
    # Use component height as page size, defaulting to 10 if not available
    page_size = Map.get(state, :height, 10)

    target_row =
      case direction do
        :up ->
          max(0, row - page_size)

        :down ->
          # Calculate max row based on number of lines
          max_row = max(0, length(state.lines) - 1)
          min(max_row, row + page_size)

        _ ->
          row
      end

    # Keep the same column position if possible
    # but ensure it's valid for the target line
    target_line = Enum.at(state.lines, target_row, "")
    target_col = min(col, String.length(target_line))

    # Create a new state with the updated cursor position
    %{state | cursor_pos: {target_row, target_col}}
  end

  # Moves cursor to the beginning of the current line
  def move_cursor_line_start(state) do
    {row, _col} = state.cursor_pos
    %{state | cursor_pos: {row, 0}, selection_start: nil, selection_end: nil}
  end

  # Moves cursor to the end of the current line
  def move_cursor_line_end(state) do
    {row, _col} = state.cursor_pos
    lines = TextHelper.split_into_lines(state.value, state.width, state.wrap)
    current_line_length = String.length(Enum.at(lines, row, ""))

    %{
      state
      | cursor_pos: {row, current_line_length},
        selection_start: nil,
        selection_end: nil
    }
  end

  # Moves cursor to the beginning of the document
  def move_cursor_doc_start(state) do
    %{state | cursor_pos: {0, 0}, selection_start: nil, selection_end: nil}
  end

  # Moves cursor to the end of the document
  def move_cursor_doc_end(state) do
    lines = TextHelper.split_into_lines(state.value, state.width, state.wrap)
    last_row = max(0, length(lines) - 1)
    last_col = String.length(Enum.at(lines, last_row, ""))

    %{
      state
      | cursor_pos: {last_row, last_col},
        selection_start: nil,
        selection_end: nil
    }
  end

  # Clears the selection
  def clear_selection(state) do
    %{state | selection_start: nil, selection_end: nil}
  end

  # Selects all text in the document
  def select_all(state) do
    lines = state.lines
    last_row = max(0, length(lines) - 1)
    last_col = String.length(Enum.at(lines, last_row, ""))
    %{state | selection_start: {0, 0}, selection_end: {last_row, last_col}}
  end

  # --- Selection Helpers ---

  # Returns the normalized selection {start_pos, end_pos} or {nil, nil} if no selection
  def normalize_selection(state) do
    case {state.selection_start, state.selection_end} do
      {nil, _} ->
        {nil, nil}

      {_, nil} ->
        {nil, nil}

      {start_pos, end_pos} ->
        # Compare positions to ensure start <= end
        start_index = TextHelper.pos_to_index(state.lines, start_pos)
        end_index = TextHelper.pos_to_index(state.lines, end_pos)

        normalize_selection_positions(
          start_index,
          end_index,
          start_pos,
          end_pos
        )
    end
  end

  # Checks if the given line index is within the selection
  def line_in_selection?(line_index, start_pos, end_pos) do
    case {start_pos, end_pos} do
      {nil, _} ->
        false

      {_, nil} ->
        false

      {{start_row, _}, {end_row, _}} ->
        # Ensure start_row <= end_row (normalize)
        {min_row, max_row} = normalize_row_range(start_row, end_row)

        line_index >= min_row && line_index <= max_row
    end
  end

  ## Helper functions for refactored if statements

  defp move_cursor_left_within_line_or_previous(state, row, col) when col > 0 do
    # Simple case: move cursor left within the current line
    new_state = %{state | desired_col: col - 1}
    move_cursor(new_state, {row, col - 1})
  end

  defp move_cursor_left_within_line_or_previous(state, row, _col) do
    # At beginning of line, try to move to end of previous line
    move_to_previous_line_end(state, row)
  end

  defp move_to_previous_line_end(state, row) when row > 0 do
    prev_row = row - 1
    lines = state.lines
    prev_line_length = String.length(Enum.at(lines, prev_row, ""))
    new_state = %{state | desired_col: prev_line_length}
    move_cursor(new_state, {prev_row, prev_line_length})
  end

  defp move_to_previous_line_end(state, _row) do
    # Already at document start, no change
    state
  end

  defp move_cursor_right_within_line_or_next(
         state,
         row,
         col,
         _lines,
         current_line_length
       )
       when col < current_line_length do
    # Simple case: move cursor right within the current line
    new_state = %{state | desired_col: col + 1}
    move_cursor(new_state, {row, col + 1})
  end

  defp move_cursor_right_within_line_or_next(
         state,
         row,
         _col,
         lines,
         _current_line_length
       ) do
    # At end of line, try to move to beginning of next line
    move_to_next_line_start(state, row, lines)
  end

  defp move_to_next_line_start(state, row, lines)
       when row < length(lines) - 1 do
    next_row = row + 1
    new_state = %{state | desired_col: 0}
    move_cursor(new_state, {next_row, 0})
  end

  defp move_to_next_line_start(state, _row, _lines) do
    # Already at document end, no change
    state
  end

  defp at_document_start?(0, 0), do: true
  defp at_document_start?(_row, _col), do: false

  defp find_position_in_line_or_continue(
         target_index,
         end_of_line_index,
         current_index,
         row,
         _rest
       )
       when target_index <= end_of_line_index do
    # Target is within this line
    col = target_index - current_index
    {row, col}
  end

  defp find_position_in_line_or_continue(
         target_index,
         end_of_line_index,
         _current_index,
         row,
         rest
       ) do
    # Target is after this line, continue to next
    next_index = end_of_line_index + calculate_newline_offset(rest)
    find_position(rest, target_index, row + 1, next_index)
  end

  defp calculate_newline_offset([]), do: 0
  defp calculate_newline_offset(_rest), do: 1

  defp normalize_selection_positions(start_index, end_index, start_pos, end_pos)
       when start_index <= end_index do
    {start_pos, end_pos}
  end

  defp normalize_selection_positions(
         _start_index,
         _end_index,
         start_pos,
         end_pos
       ) do
    {end_pos, start_pos}
  end

  defp normalize_row_range(start_row, end_row) when start_row <= end_row do
    {start_row, end_row}
  end

  defp normalize_row_range(start_row, end_row) do
    {end_row, start_row}
  end
end
