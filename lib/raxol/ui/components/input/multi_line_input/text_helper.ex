defmodule Raxol.UI.Components.Input.MultiLineInput.TextHelper do
  @moduledoc """
  Helper functions for text and line manipulation in MultiLineInput.
  """

  alias Raxol.UI.Components.Input.TextWrapping
  alias Raxol.UI.Components.Input.MultiLineInput
  alias Raxol.UI.Components.Input.MultiLineInput.NavigationHelper
  require Raxol.Core.Runtime.Log
  import Raxol.Guards

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
    num_lines = length(text_lines)
    safe_row = clamp(row, 0, max(0, num_lines - 1))

    line_length =
      if safe_row >= 0 and safe_row < num_lines do
        String.length(Enum.at(text_lines, safe_row) || "")
      else
        0
      end

    # If row is out of bounds, clamp to end of last line
    safe_col =
      if row >= num_lines do
        # End of the last line
        line_length
      else
        clamp(col, 0, line_length)
      end

    # Calculate index by summing lengths of previous lines plus newlines
    prefix_sum =
      text_lines
      |> Enum.slice(0, safe_row)
      |> Enum.map(&String.length(&1))
      |> Enum.sum()

    # Add newline characters (one per line except the last)
    newline_count = safe_row
    # Add the column position on the current line
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
    start_col = clamp(start_col, 0, line_length)
    end_col = clamp(end_col, 0, line_length)

    # If out of bounds or reversed (and not insertion), treat as no-op
    if start_col > end_col do
      {Enum.join(lines_list, "\n"), ""}
    else
      before = String.slice(line, 0, start_col)

      after_part =
        if end_col >= line_length,
          do: "",
          else: String.slice(line, end_col, line_length - end_col)

      new_line = before <> replacement <> after_part
      new_lines = List.replace_at(lines_list, row, new_line)
      new_full_text = Enum.join(new_lines, "\n")
      replaced_text = String.slice(line, start_col, end_col - start_col)
      {new_full_text, replaced_text}
    end
  end

  defp handle_multi_line_replacement(
         lines_list,
         start_row,
         start_col,
         end_row,
         end_col,
         replacement
       ) do
    {clamped_start_row, clamped_start_col, clamped_end_row, clamped_end_col} =
      clamp_positions(lines_list, start_row, start_col, end_row, end_col)

    if invalid_range?(
         clamped_start_row,
         clamped_start_col,
         clamped_end_row,
         clamped_end_col
       ) do
      {Enum.join(lines_list, "\n"), ""}
    else
      build_replacement_result(
        lines_list,
        clamped_start_row,
        clamped_start_col,
        clamped_end_row,
        clamped_end_col,
        replacement
      )
    end
  end

  defp clamp_positions(lines_list, start_row, start_col, end_row, end_col) do
    num_lines = length(lines_list)
    clamped_start_row = clamp(start_row, 0, num_lines - 1)
    clamped_end_row = clamp(end_row, 0, num_lines - 1)

    start_line = Enum.at(lines_list, clamped_start_row, "")
    end_line = Enum.at(lines_list, clamped_end_row, "")
    clamped_start_col = clamp(start_col, 0, String.length(start_line))
    clamped_end_col = clamp(end_col, 0, String.length(end_line))

    {clamped_start_row, clamped_start_col, clamped_end_row, clamped_end_col}
  end

  defp invalid_range?(start_row, start_col, end_row, end_col) do
    start_row > end_row or (start_row == end_row and start_col > end_col)
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

    new_lines =
      build_new_lines(
        lines_before,
        lines_after,
        first_line_part,
        last_line_part,
        replacement
      )

    replaced_text =
      extract_replaced_text(lines_list, start_row, start_col, end_row, end_col)

    {new_lines, replaced_text}
  end

  defp extract_line_parts(lines_list, start_row, start_col, end_row, end_col) do
    start_line = Enum.at(lines_list, start_row, "")
    end_line = Enum.at(lines_list, end_row, "")
    first_line_part = String.slice(start_line, 0, start_col)

    # For multi-line replacement, we want to include everything from end_col onwards
    # This is the part that should remain after the replacement
    last_line_part =
      String.slice(end_line, end_col, String.length(end_line) - end_col)

    {first_line_part, last_line_part}
  end

  defp split_lines_around_range(lines_list, start_row, end_row) do
    lines_before = Enum.slice(lines_list, 0, start_row)

    lines_after =
      Enum.slice(lines_list, end_row + 1, length(lines_list) - (end_row + 1))

    {lines_before, lines_after}
  end

  defp build_new_lines(
         lines_before,
         lines_after,
         first_line_part,
         last_line_part,
         replacement
       ) do
    if replacement == "" do
      # For deletion, join the first and last line parts
      joined_line = first_line_part <> last_line_part

      # Only add the joined line if it's not empty or if there are no other lines
      if joined_line != "" or (lines_before == [] and lines_after == []) do
        lines_before ++ [joined_line] ++ lines_after
      else
        lines_before ++ lines_after
      end
    else
      # For replacement, create a new line with the replacement
      new_line = first_line_part <> replacement <> last_line_part
      lines_before ++ [new_line] ++ lines_after
    end
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
    {start_part, middle_lines, end_part} =
      extract_text_parts(lines_list, start_row, start_col, end_row, end_col)

    parts = [start_part] ++ middle_lines ++ [end_part]

    parts =
      if end_col == 0, do: Enum.slice(parts, 0, length(parts) - 1), else: parts

    Enum.join(parts, "\n")
  end

  defp extract_text_parts(lines_list, start_row, start_col, end_row, end_col) do
    start_line = Enum.at(lines_list, start_row, "")
    end_line = Enum.at(lines_list, end_row, "")
    start_length = String.length(start_line)
    end_length = String.length(end_line)
    start_col = clamp(start_col, 0, start_length)
    end_col = clamp(end_col, 0, end_length)

    start_part = String.slice(start_line, start_col, start_length - start_col)
    middle_lines = extract_middle_lines(lines_list, start_row, end_row)
    end_part = String.slice(end_line, 0, end_col)

    {start_part, middle_lines, end_part}
  end

  defp extract_middle_lines(lines_list, start_row, end_row) do
    if end_row > start_row + 1 do
      Enum.slice(lines_list, start_row + 1, end_row - start_row - 1)
    else
      []
    end
  end

  # --- Private helper functions ---

  def insert_char(state, char_or_codepoint) do
    %{lines: lines, cursor_pos: {row, col}} = state

    char_binary = convert_to_binary(char_or_codepoint)

    {new_full_text, _} =
      replace_text_range(lines, {row, col}, {row, col}, char_binary)

    {new_row, new_col} =
      calculate_new_cursor_position({row, col}, char_or_codepoint, char_binary)

    new_lines = String.split(new_full_text, "\n")

    new_state = %MultiLineInput{
      state
      | lines: new_lines,
        cursor_pos: {new_row, new_col},
        selection_start: nil,
        selection_end: nil,
        value: new_full_text
    }

    if state.on_change, do: state.on_change.(new_full_text)
    new_state
  end

  # --- Private helper functions ---

  defp convert_to_binary(char_or_codepoint) do
    case char_or_codepoint do
      cp when integer?(cp) -> <<cp::utf8>>
      bin when binary?(bin) -> bin
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
      {new_full_text, deleted_text} =
        replace_text_range(lines, start_pos, end_pos, "")

      # Always join to string before splitting
      new_full_text_str =
        if is_list(new_full_text),
          do: Enum.join(new_full_text, "\n"),
          else: new_full_text

      new_lines = String.split(new_full_text_str, "\n")

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

  def handle_delete_no_selection(state) do
    %{lines: lines, cursor_pos: {row, col}} = state
    num_lines = length(lines)

    if row >= num_lines or at_end_of_document?(lines, row, col) do
      state
    else
      next_position = calculate_next_position(lines, row, col)

      {new_full_text, _deleted_text} =
        replace_text_range(lines, {row, col}, next_position, "")

      # Always join to string before splitting
      new_full_text_str =
        if is_list(new_full_text),
          do: Enum.join(new_full_text, "\n"),
          else: new_full_text

      new_lines = String.split(new_full_text_str, "\n")

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

  # --- Additional private helper functions ---

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
    {new_full_text, _deleted_text} =
      replace_text_range(lines, start_pos, end_pos, "")

    new_full_text_str = normalize_full_text(new_full_text)
    new_lines = String.split(new_full_text_str, "\n")

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

  defp normalize_full_text(full_text) do
    if is_list(full_text), do: Enum.join(full_text, "\n"), else: full_text
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
