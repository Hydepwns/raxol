defmodule Raxol.Terminal.Input.InputBufferUtils do
  @moduledoc """
  Utility functions for Raxol.Terminal.Input.InputBuffer.
  """

  # --- Wrapping Logic ---

  def wrap_line(line, width) do
    # Return early if line fits or width is invalid
    if width <= 0 or String.length(line) <= width do
      [line]
    else
      words = String.split(line, " ") # Split into words

      Enum.reduce(words, {[], ""}, fn word, {lines, current_line} ->
        word_len = String.length(word)

        cond do
          # Case 1: Word fits perfectly on the current line (or is the first word)
          current_line == "" && word_len <= width ->
            {lines, word}

          # Case 2: Word fits on the current line with a preceding space
          current_line != "" && String.length(current_line) + 1 + word_len <= width ->
            {lines, current_line <> " " <> word}

          # Case 3: Word is too long for *any* line (longer than width)
          word_len > width ->
            # Break the long word
            {new_lines, remaining_part} = break_long_word(word, width)
            # Add the completed current line (if any) and the broken parts
            updated_lines = if current_line != "", do: lines ++ [current_line], else: lines
            {updated_lines ++ new_lines, remaining_part} # Start new line with remaining part

          # Case 4: Word doesn't fit on current line, start a new line
          true ->
            {lines ++ [current_line], word} # Add completed line, start new one with word
        end
      end)
      |> (fn {lines, last_line} ->
            # Add the final line being built (if not empty)
            if last_line != "", do: lines ++ [last_line], else: lines
          end).()
    end
  end

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
      line_len_with_newline = line_len + if index < length(logical_lines) - 1, do: 1, else: 0

      if cursor_pos <= char_count + line_len do
        # Cursor is within this logical line
        {index, cursor_pos - char_count}
      else
        _char_count = char_count + line_len_with_newline
        nil # Continue searching
      end
    end)
  end

  # Renamed to v2 as it takes the pre-built mapping
  def calculate_new_cursor_pos_v2(
      line_mapping, # Map of %{old_logical_idx => [new_wrapped_idx1, new_wrapped_idx2...]}
      wrapped_lines_new,
      original_logical_line_index,
      original_pos_in_line,
      new_contents # Used for clamping
  ) do
    target_wrapped_line_indices = Map.get(line_mapping, original_logical_line_index, [])

    if target_wrapped_line_indices == [] do
      # Default to end if no mapping found (should indicate an issue)
      String.length(new_contents)
    else
      first_target_wrapped_index = Enum.min(target_wrapped_line_indices)

      # Calculate the starting character offset of the *first* wrapped line
      # belonging to the original logical line.
      start_char_offset = Enum.reduce(0..(first_target_wrapped_index - 1), 0, fn i, acc ->
        # Need to handle potential index out of bounds if mapping is sparse?
        line_content = Enum.at(wrapped_lines_new, i)
        acc + String.length(line_content) + 1 # +1 for newline implicitly separating wrapped lines
      end)

      # Iterate through ONLY the target wrapped lines originating from the original logical line
      # to find the character offset *within* this sequence of lines.
      pos_within_target_sequence = 0
      final_cursor_offset_within_logical_line = Enum.reduce_while(target_wrapped_line_indices, 0, fn wrapped_idx, _current_offset_in_sequence ->
        line = Enum.at(wrapped_lines_new, wrapped_idx)
        line_len = String.length(line)

        if original_pos_in_line <= pos_within_target_sequence + line_len do
          # Cursor position falls within this wrapped line.
          # The offset is the original position minus the length of preceding lines *within this sequence*.
          {:halt, original_pos_in_line - pos_within_target_sequence}
        else
          # Cursor is beyond this wrapped line, continue checking the next one from the same logical origin.
          pos_within_target_sequence = pos_within_target_sequence + line_len
          {:cont, pos_within_target_sequence}
        end
      end)

      # If reduce_while finished without halting (e.g., original_pos_in_line was > total length of sequence)
      # default to the end of the last relevant wrapped line.
      final_cursor_offset_within_logical_line = if is_integer(final_cursor_offset_within_logical_line) do
        final_cursor_offset_within_logical_line
      else
         # Calculate end position relative to the start of the first target wrapped line
         total_len_of_target_sequence = Enum.reduce(target_wrapped_line_indices, 0, fn idx, acc -> acc + String.length(Enum.at(wrapped_lines_new, idx)) end)
         total_len_of_target_sequence
      end


      final_pos = start_char_offset + final_cursor_offset_within_logical_line

      # Clamp to total length as a safety measure
      min(final_pos, String.length(new_contents))
    end
  end

end
