defmodule Raxol.UI.Components.Input.MultiLineInput.TextHelper do
  @moduledoc """
  Helper functions for text and line manipulation in MultiLineInput.
  """

  alias Raxol.UI.Components.Input.TextWrapping
  alias Raxol.UI.Components.Input.MultiLineInput
  alias Raxol.UI.Components.Input.MultiLineInput.NavigationHelper
  require Raxol.Core.Runtime.Log

  # --- Line Splitting and Wrapping ---

  @doc """
  Splits the given text into lines, applying the specified wrapping mode (:none, :char, or :word).
  """
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
  @doc """
  Splits the given text into lines and applies the provided wrapping function to each line.
  """
  def split_and_wrap(text, width, wrap_fun) do
    text
    |> String.split("\n")
    |> Enum.flat_map(&wrap_fun.(&1, width))
  end

  # --- Position Conversion ---

  @doc """
  Converts a {row, col} tuple to a flat string index based on the provided lines.
  """
  def pos_to_index(text_lines, {row, col}) do
    # Original Implementation
    num_lines = length(text_lines)
    safe_row = clamp(row, 0, max(0, num_lines - 1))

    line_length =
      if safe_row >= 0 and safe_row < num_lines do
        String.length(Enum.at(text_lines, safe_row) || "")
      else
        0
      end

    safe_col = clamp(col, 0, line_length)

    # Get lines before the target row
    prefix_lines = Enum.slice(text_lines, 0, safe_row)
    prefix_sum = Enum.sum(Enum.map(prefix_lines, &String.length(&1)))
    # Add count for newline characters (\n) - use max(0, safe_row) for safety
    newline_count = max(0, safe_row)
    # Add the clamped column index on the target row
    total_index = prefix_sum + newline_count + safe_col

    Raxol.Core.Runtime.Log.debug(
      "pos_to_index: lines=#{inspect(text_lines)}, pos={#{row}, #{col}} -> safe_row=#{safe_row}, safe_col=#{safe_col}, index=#{total_index}"
    )

    total_index
  end

  # --- Text Insertion/Deletion ---

  @doc """
  Replaces text within a range (from start_pos_tuple to end_pos_tuple) with the given replacement string. Returns {new_full_text, replaced_text}.
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

    start_index = pos_to_index(lines_list, start_pos_tuple)
    end_index = pos_to_index(lines_list, end_pos_tuple)

    Raxol.Core.Runtime.Log.debug(
      "replace_text_range: start_idx=#{start_index}, end_idx=#{end_index}"
    )

    # Normalize & Clamp original indices
    {norm_start_index, norm_end_index} =
      {min(start_index, end_index), max(start_index, end_index)}

    # Join lines here for slicing
    joined_text = Enum.join(lines_list, "\n")
    joined_text_len = String.length(joined_text)

    clamped_start = clamp(norm_start_index, 0, joined_text_len)
    clamped_end = clamp(norm_end_index, 0, joined_text_len)

    Raxol.Core.Runtime.Log.debug(
      "replace_text_range: clamped_start=#{clamped_start}, clamped_end=#{clamped_end}"
    )

    # Text Before: Slice up to the start index
    text_before = String.slice(joined_text, 0, clamped_start)

    Raxol.Core.Runtime.Log.debug(
      "replace_text_range: text_before=#{inspect(text_before)}"
    )

    # Text After: Needs to start AT the index for insertion, AFTER for deletion/replace
    is_insertion = start_pos_tuple == end_pos_tuple and replacement != ""

    slice_after_start_index =
      if is_insertion do
        # Slice from the insertion point
        clamped_start
      else
        # Slice from the end of the replaced range
        clamped_end
      end

    Raxol.Core.Runtime.Log.debug(
      "replace_text_range: slice_after_start_index=#{slice_after_start_index}"
    )

    text_after =
      String.slice(
        joined_text,
        slice_after_start_index,
        max(0, joined_text_len - slice_after_start_index)
      )

    Raxol.Core.Runtime.Log.debug(
      "replace_text_range: text_after=#{inspect(text_after)}"
    )

    # Replaced Text Calculation - uses exclusive end index logic
    replaced_length =
      if is_insertion do
        0
      else
        if clamped_start <= clamped_end do
          # Exclusive length
          max(0, clamped_end - clamped_start)
        else
          0
        end
      end

    replaced_length =
      min(replaced_length, max(0, joined_text_len - clamped_start))

    replaced_text = String.slice(joined_text, clamped_start, replaced_length)

    # Construct new text
    new_full_text = text_before <> replacement <> text_after

    Raxol.Core.Runtime.Log.debug(
      "replace_text_range: new_full_text=#{inspect(new_full_text)}"
    )

    {new_full_text, replaced_text}
  end

  @doc """
  Inserts a character or codepoint at the current cursor position in the state, updating lines and value.
  """
  def insert_char(state, char_or_codepoint) do
    %{lines: lines, cursor_pos: {row, col}} = state

    # Convert input char/codepoint to binary string
    char_binary =
      case char_or_codepoint do
        cp when is_integer(cp) -> <<cp::utf8>>
        bin when is_binary(bin) -> bin
        # Ignore invalid input for now
        _ -> ""
      end

    # Use range helper to insert the character, passing tuples
    start_pos = {row, col}

    {new_full_text, _} =
      replace_text_range(lines, start_pos, start_pos, char_binary)

    # Calculate new cursor position based on inserted char
    # Simply move cursor one position right after insertion
    new_col = col + 1

    # Split the new full text back into lines
    new_lines = String.split(new_full_text, "\n")

    # Use struct syntax
    new_state = %MultiLineInput{
      state
      | # Use state | pattern for brevity
        # Update lines
        lines: new_lines,
        cursor_pos: {row, new_col},
        # Clear selection after insertion
        selection_start: nil,
        selection_end: nil,
        # Update the value field too
        value: new_full_text
    }

    # Use new_full_text for on_change callback if needed
    if state.on_change, do: state.on_change.(new_full_text)
    new_state
  end

  @doc """
  Deletes the currently selected text in the state, updating lines and value.
  """
  def delete_selection(state) do
    %{lines: lines} = state

    # Get normalized {row, col} tuples
    {start_pos, end_pos} =
      NavigationHelper.normalize_selection(state)

    # Check if selection is valid before proceeding
    if start_pos == nil or end_pos == nil do
      # Or handle differently, maybe return {state, ""}? Logging is good too.
      Raxol.Core.Runtime.Log.warning(
        "Attempted to delete invalid selection: #{inspect(state.selection_start)} to #{inspect(state.selection_end)}"
      )

      # Fix: Remove 'return'
      {state, ""}
    else
      # Use range helper, pass lines list
      {new_full_text, deleted_text} =
        replace_text_range(lines, start_pos, end_pos, "")

      # Split back into lines
      new_lines = String.split(new_full_text, "\n")

      # Move cursor to the start of the deleted selection
      new_state = %MultiLineInput{
        state
        | # Update lines
          lines: new_lines,
          # Fix: Use calculated start_pos
          cursor_pos: start_pos,
          selection_start: nil,
          selection_end: nil,
          # Update the value field
          value: new_full_text
      }

      if state.on_change, do: state.on_change.(new_full_text)
      # Return the state and the deleted text (useful for cut)
      {new_state, deleted_text}
    end
  end

  def handle_backspace_no_selection(state) do
    %{lines: lines, cursor_pos: {row, col}} = state

    # Handle backspace at the beginning of the document
    if row == 0 and col == 0 do
      state
    else
      prev_position =
        cond do
          # If we're at the start of a line (not the first), move to the end of previous line
          col == 0 and row > 0 ->
            prev_line = Enum.at(lines, row - 1)
            prev_col = String.length(prev_line)
            {row - 1, prev_col}

          # If we're in the middle of a line, just move back one
          true ->
            {row, col - 1}
        end

      {new_full_text, _deleted_text} =
        replace_text_range(lines, prev_position, {row, col}, "")

      # Split back to lines
      new_lines = String.split(new_full_text, "\n")

      # Use struct syntax for new_state
      new_state = %MultiLineInput{
        state
        | # Update lines
          lines: new_lines,
          # Set cursor to the previous position
          cursor_pos: prev_position,
          selection_start: nil,
          selection_end: nil,
          # Update the value field
          value: new_full_text
      }

      # Handle on_change function with properly returned value
      if state.on_change do
        # Call on_change but don't ignore the result
        _ = state.on_change.(new_full_text)
      end

      # Return the new state
      new_state
    end
  end

  def handle_delete_no_selection(state) do
    %{lines: lines, cursor_pos: {row, col}} = state
    num_lines = length(lines)

    if row >= num_lines do
      state
    else
      current_line = Enum.at(lines, row) || ""
      current_line_length = String.length(current_line)

      # At the very end of document, nothing to delete
      if col == current_line_length and row == num_lines - 1 do
        state
      else
        next_position =
          cond do
            # If we're at the end of a line (not the last), include the newline
            col == current_line_length and row < num_lines - 1 ->
              {row + 1, 0}

            # If we're in the middle of a line, just delete one character
            true ->
              {row, col + 1}
          end

        {new_full_text, _deleted_text} =
          replace_text_range(lines, {row, col}, next_position, "")

        # Split back to lines
        new_lines = String.split(new_full_text, "\n")

        # Use the value directly from replace_text_range
        new_state = %MultiLineInput{
          state
          | # Use result from helper
            # Update lines
            lines: new_lines,
            selection_start: nil,
            selection_end: nil,
            # Update the value field
            value: new_full_text
            # Cursor position should remain the same after delete
        }

        if state.on_change, do: state.on_change.(new_full_text)
        new_state
      end
    end
  end

  # --- Internal Helpers (used by functions above) ---

  # Make public as it's used by ClipboardHelper
  def clamp(value, min, max) do
    value |> max(min) |> min(max)
  end

  # Make public
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
