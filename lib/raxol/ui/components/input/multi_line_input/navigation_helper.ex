defmodule Raxol.UI.Components.Input.MultiLineInput.NavigationHelper do
  @moduledoc """
  Helper functions for cursor navigation and text selection in MultiLineInput.
  """

  # alias Raxol.UI.Components.Input.MultiLineInput # May need state struct definition
  # Need pos_to_index
  alias Raxol.UI.Components.Input.MultiLineInput.TextHelper
  require Logger

  @doc """
  Moves the cursor to the specified {row, col} position, clamping to document bounds and clearing selection.
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
        selection_start: nil,
        selection_end: nil
    }
  end

  # --- Add heads for directional movement ---
  @doc """
  Moves the cursor one position to the left, or to the end of the previous line if at the start of a line.
  """
  def move_cursor(state, :left) do
    {row, col} = state.cursor_pos

    if col > 0 do
      # Simple case: move cursor left within the current line
      move_cursor(state, {row, col - 1})
    else
      # At beginning of line, try to move to end of previous line
      if row > 0 do
        prev_row = row - 1
        lines = state.lines
        prev_line_length = String.length(Enum.at(lines, prev_row, ""))
        move_cursor(state, {prev_row, prev_line_length})
      else
        # Already at document start, no change
        state
      end
    end
  end

  @doc """
  Moves the cursor one position to the right, or to the start of the next line if at the end of a line.
  """
  def move_cursor(state, :right) do
    {row, col} = state.cursor_pos
    lines = state.lines
    current_line = Enum.at(lines, row, "")
    current_line_length = String.length(current_line)

    if col < current_line_length do
      # Simple case: move cursor right within the current line
      move_cursor(state, {row, col + 1})
    else
      # At end of line, try to move to beginning of next line
      if row < length(lines) - 1 do
        next_row = row + 1
        move_cursor(state, {next_row, 0})
      else
        # Already at document end, no change
        state
      end
    end
  end

  @doc """
  Moves the cursor up by one line, keeping the same column if possible.
  """
  def move_cursor(state, :up) do
    {row, col} = state.cursor_pos
    new_row = max(0, row - 1)
    # Keep same column if possible (TODO: handle desired_col?)
    new_col = col
    move_cursor(state, {new_row, new_col})
  end

  @doc """
  Moves the cursor down by one line, keeping the same column if possible.
  """
  def move_cursor(state, :down) do
    {row, col} = state.cursor_pos
    lines = TextHelper.split_into_lines(state.value, state.width, state.wrap)
    num_lines = length(lines)
    new_row = min(num_lines - 1, row + 1)
    # Keep same column if possible (TODO: handle desired_col?)
    new_col = col
    move_cursor(state, {new_row, new_col})
  end

  @doc """
  Moves the cursor one word to the left.
  """
  def move_cursor(state, :word_left) do
    move_cursor_word_left(state)
  end

  @doc """
  Moves the cursor one word to the right.
  """
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
    if current_row == 0 and current_col == 0 do
      state
    else
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
  # Inefficient: Converts flat index back to {row, col}.
  # TODO: Optimize this if performance becomes an issue.
  defp index_to_pos(text_lines, target_index) do
    Enum.reduce_while(Enum.with_index(text_lines), {0, 0, 0}, fn {line, row_idx},
                                                                 {current_index,
                                                                  _found_row,
                                                                  _found_col} ->
      line_len = String.length(line)
      # Index at the end of this line (including newline char if not last line)
      end_of_line_index =
        current_index + line_len +
          if row_idx < length(text_lines) - 1, do: 1, else: 0

      if target_index <= current_index + line_len do
        # Target is within this line
        col = target_index - current_index
        # Use 0 in first element to signal found
        {:halt, {0, row_idx, col}}
      else
        # Target is after this line
        {:cont, {end_of_line_index, 0, 0}}
      end
    end)
    |> case do
      {0, found_row, found_col} ->
        {found_row, found_col}

      # Fallback if not found (e.g., index out of bounds), return end of doc
      _ ->
        last_row = max(0, length(text_lines) - 1)
        last_col = String.length(Enum.at(text_lines, last_row, ""))
        {last_row, last_col}
    end
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

        if start_index <= end_index do
          {start_pos, end_pos}
        else
          {end_pos, start_pos}
        end
    end
  end

  # Checks if the given line index is within the selection
  def is_line_in_selection?(line_index, start_pos, end_pos) do
    case {start_pos, end_pos} do
      {nil, _} ->
        false

      {_, nil} ->
        false

      {{start_row, _}, {end_row, _}} ->
        # Ensure start_row <= end_row (normalize)
        {min_row, max_row} =
          if start_row <= end_row,
            do: {start_row, end_row},
            else: {end_row, start_row}

        line_index >= min_row && line_index <= max_row
    end
  end
end
