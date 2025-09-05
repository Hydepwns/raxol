defmodule Raxol.Terminal.Input.InputBufferUtils do
  @moduledoc """
  Utility functions for Raxol.Terminal.Input.InputBuffer.
  """

  # --- Wrapping Logic ---

  def wrap_line(line, width) do
    should_wrap = width > 0 and String.length(line) > width
    process_line_wrapping(should_wrap, line, width)
  end

  defp process_line_wrapping(false, line, _width), do: [line]

  defp process_line_wrapping(true, line, width) do
    # Split into words
    words = String.split(line, " ")

    Enum.reduce(words, {[], ""}, fn word, {lines, current_line} ->
      process_word(word, width, {lines, current_line})
    end)
    |> finalize_wrapped_lines()
  end

  defp finalize_wrapped_lines({lines, last_line}) do
    add_final_line(last_line != "", lines, last_line)
  end

  defp add_final_line(false, lines, _last_line), do: lines
  defp add_final_line(true, lines, last_line), do: [last_line | lines]

  defp process_word(word, width, {lines, current_line}) do
    word_len = String.length(word)
    current_line_len = String.length(current_line)

    process_word_by_fit(
      word,
      word_len,
      width,
      lines,
      current_line,
      current_line_len
    )
  end

  # Case 1: Word fits perfectly on empty current line (first word)
  defp process_word_by_fit(word, word_len, width, lines, "", _current_line_len)
       when word_len <= width do
    {lines, word}
  end

  # Case 2: Word fits on current line with a preceding space
  defp process_word_by_fit(
         word,
         word_len,
         width,
         lines,
         current_line,
         current_line_len
       )
       when current_line != "" and current_line_len + 1 + word_len <= width do
    {lines, current_line <> " " <> word}
  end

  # Case 3: Word is too long for any line (longer than width)
  defp process_word_by_fit(
         word,
         word_len,
         width,
         lines,
         current_line,
         _current_line_len
       )
       when word_len > width do
    handle_long_word(word, width, lines, current_line)
  end

  # Case 4: Word doesn't fit on current line, start a new line
  defp process_word_by_fit(
         word,
         _word_len,
         _width,
         lines,
         current_line,
         _current_line_len
       ) do
    {[current_line | lines], word}
  end

  defp handle_long_word(word, width, lines, current_line) do
    # Break the long word
    {new_lines, remaining_part} = break_long_word(word, width)
    # Add the completed current line (if any) and the broken parts
    updated_lines = add_current_line(current_line != "", current_line, lines)

    # Start new line with remaining part
    {new_lines ++ updated_lines, remaining_part}
  end

  defp add_current_line(false, _current_line, lines), do: lines
  defp add_current_line(true, current_line, lines), do: [current_line | lines]

  # Private helper for wrap_line
  defp break_long_word(word, width) do
    graphemes = String.graphemes(word)
    parts = Enum.chunk_every(graphemes, width) |> Enum.map(&Enum.join/1)

    # The last part might be shorter and becomes the start of the next line
    {Enum.slice(parts, 0..-2//1), List.last(parts)}
  end

  # --- Position Calculation Logic ---

  def find_logical_position(contents, cursor_pos) do
    logical_lines = String.split(contents, "\n")
    char_count = 0

    Enum.find_value(Enum.with_index(logical_lines), {0, 0}, fn {line, index} ->
      line_len = String.length(line)
      # +1 for the newline character, except for the very last line
      line_len_with_newline =
        line_len + calculate_newline_length(index < length(logical_lines) - 1)

      check_cursor_position(
        cursor_pos <= char_count + line_len,
        index,
        cursor_pos,
        char_count,
        line_len_with_newline
      )
    end)
  end

  # Renamed to v2 as it takes the pre-built mapping
  def calculate_new_cursor_pos_v2(
        # Map of %{old_logical_idx => [new_wrapped_idx1, new_wrapped_idx2...]}
        line_mapping,
        wrapped_lines_new,
        original_logical_line_index,
        original_pos_in_line,
        # Used for clamping
        new_contents
      ) do
    target_wrapped_line_indices =
      Map.get(line_mapping, original_logical_line_index, [])

    process_cursor_mapping(
      target_wrapped_line_indices == [],
      new_contents,
      target_wrapped_line_indices,
      wrapped_lines_new,
      original_logical_line_index,
      original_pos_in_line
    )
  end

  defp process_cursor_mapping(
         true,
         new_contents,
         _target_wrapped_line_indices,
         _wrapped_lines_new,
         _original_logical_line_index,
         _original_pos_in_line
       ) do
    # Default to end if no mapping found (should indicate an issue)
    String.length(new_contents)
  end

  defp process_cursor_mapping(
         false,
         new_contents,
         target_wrapped_line_indices,
         wrapped_lines_new,
         _original_logical_line_index,
         original_pos_in_line
       ) do
    first_target_wrapped_index = Enum.min(target_wrapped_line_indices)

    # Calculate the starting character offset of the *first* wrapped line
    # belonging to the original logical line.
    start_char_offset =
      Enum.reduce(0..(first_target_wrapped_index - 1), 0, fn i, acc ->
        # Need to handle potential index out of bounds if mapping is sparse?
        line_content = Enum.at(wrapped_lines_new, i)
        # +1 for newline implicitly separating wrapped lines
        acc + String.length(line_content) + 1
      end)

    # Iterate through ONLY the target wrapped lines originating from the original logical line
    # to find the character offset *within* this sequence of lines.
    final_cursor_offset_within_logical_line =
      find_cursor_offset_in_target_sequence(
        target_wrapped_line_indices,
        wrapped_lines_new,
        original_pos_in_line
      )

    # If reduce_while finished without halting (e.g., original_pos_in_line was > total length of sequence)
    # default to the end of the last relevant wrapped line.
    final_cursor_offset_within_logical_line =
      resolve_cursor_offset(
        is_integer(final_cursor_offset_within_logical_line),
        final_cursor_offset_within_logical_line,
        target_wrapped_line_indices,
        wrapped_lines_new
      )

    final_pos = start_char_offset + final_cursor_offset_within_logical_line

    # Clamp to total length as a safety measure
    min(final_pos, String.length(new_contents))
  end

  defp calculate_total_length_of_target_sequence(
         target_wrapped_line_indices,
         wrapped_lines_new
       ) do
    Enum.reduce(target_wrapped_line_indices, 0, fn idx, acc ->
      acc + String.length(Enum.at(wrapped_lines_new, idx))
    end)
  end

  defp find_cursor_offset_in_target_sequence(
         target_wrapped_line_indices,
         wrapped_lines_new,
         original_pos_in_line
       ) do
    Enum.reduce_while(target_wrapped_line_indices, 0, fn wrapped_idx,
                                                         pos_within_target_sequence ->
      line = Enum.at(wrapped_lines_new, wrapped_idx)
      line_len = String.length(line)

      handle_cursor_in_line(
        original_pos_in_line <= pos_within_target_sequence + line_len,
        original_pos_in_line,
        pos_within_target_sequence,
        line_len
      )
    end)
  end

  ## Helper Functions for Pattern Matching

  defp calculate_newline_length(true), do: 1
  defp calculate_newline_length(false), do: 0

  defp check_cursor_position(
         true,
         index,
         cursor_pos,
         char_count,
         _line_len_with_newline
       ) do
    # Cursor is within this logical line
    {index, cursor_pos - char_count}
  end

  defp check_cursor_position(
         false,
         _index,
         _cursor_pos,
         char_count,
         line_len_with_newline
       ) do
    _char_count = char_count + line_len_with_newline
    # Continue searching
    nil
  end

  defp resolve_cursor_offset(
         true,
         final_cursor_offset_within_logical_line,
         _target_wrapped_line_indices,
         _wrapped_lines_new
       ) do
    final_cursor_offset_within_logical_line
  end

  defp resolve_cursor_offset(
         false,
         _final_cursor_offset_within_logical_line,
         target_wrapped_line_indices,
         wrapped_lines_new
       ) do
    calculate_total_length_of_target_sequence(
      target_wrapped_line_indices,
      wrapped_lines_new
    )
  end

  defp handle_cursor_in_line(
         true,
         original_pos_in_line,
         pos_within_target_sequence,
         _line_len
       ) do
    # Cursor position falls within this wrapped line.
    # The offset is the original position minus the length of preceding lines *within this sequence*.
    {:halt, original_pos_in_line - pos_within_target_sequence}
  end

  defp handle_cursor_in_line(
         false,
         _original_pos_in_line,
         pos_within_target_sequence,
         line_len
       ) do
    # Cursor is beyond this wrapped line, continue checking the next one from the same logical origin.
    {:cont, pos_within_target_sequence + line_len}
  end
end
