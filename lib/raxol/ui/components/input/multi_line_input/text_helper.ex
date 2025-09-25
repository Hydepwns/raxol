defmodule Raxol.UI.Components.Input.MultiLineInput.TextHelper do
  @moduledoc """
  Text manipulation helper functions for MultiLineInput component.
  """

  alias Raxol.UI.Components.Input.MultiLineInput

  @doc """
  Splits text into lines based on width and wrap mode.
  """
  @spec split_into_lines(String.t(), integer(), :none | :char | :word) :: [
          String.t()
        ]
  def split_into_lines(text, width, wrap_mode) do
    # Handle empty text case - should return [""] not []
    if text == "" do
      [""]
    else
      case wrap_mode do
        :none ->
          String.split(text, "\n")

        :char ->
          text
          |> String.split("\n")
          |> Enum.flat_map(&wrap_line_by_char(&1, width))

        :word ->
          text
          |> String.split("\n")
          |> Enum.flat_map(&wrap_line_by_word(&1, width))
      end
    end
  end

  defp wrap_line_by_char(line, width) when width <= 0, do: [line]

  defp wrap_line_by_char(line, width) do
    if String.length(line) <= width do
      [line]
    else
      {chunk, rest} = String.split_at(line, width)
      [chunk | wrap_line_by_char(rest, width)]
    end
  end

  defp wrap_line_by_word(line, width) when width <= 0, do: [line]

  defp wrap_line_by_word(line, width) do
    words = String.split(line, " ")
    wrap_words(words, width, "", [])
  end

  defp wrap_words([], _width, current_line, acc) do
    if current_line == "" do
      Enum.reverse(acc)
    else
      Enum.reverse([String.trim(current_line) | acc])
    end
  end

  defp wrap_words([word | rest], width, current_line, acc) do
    candidate_line =
      if current_line == "", do: word, else: current_line <> " " <> word

    if String.length(candidate_line) <= width do
      wrap_words(rest, width, candidate_line, acc)
    else
      # Word doesn't fit, start new line
      new_acc =
        if current_line == "" do
          # Single word longer than width, force it on its own line
          [word | acc]
        else
          [String.trim(current_line) | acc]
        end

      new_current = if current_line == "", do: "", else: word
      wrap_words(rest, width, new_current, new_acc)
    end
  end

  @doc """
  Inserts a character at the cursor position.
  """
  @spec insert_char(MultiLineInput.t(), integer()) :: MultiLineInput.t()
  def insert_char(state, char_codepoint) do
    char = <<char_codepoint::utf8>>
    {row, col} = state.cursor_pos

    # Handle newline separately
    if char_codepoint == 10 do
      insert_newline(state, row, col)
    else
      insert_regular_char(state, row, col, char)
    end
  end

  defp insert_newline(state, row, col) do
    current_line = Enum.at(state.lines, row, "")
    {before_cursor, after_cursor} = String.split_at(current_line, col)

    new_lines =
      state.lines
      |> List.replace_at(row, before_cursor)
      |> List.insert_at(row + 1, after_cursor)

    new_value = Enum.join(new_lines, "\n")

    %{state | lines: new_lines, value: new_value, cursor_pos: {row + 1, 0}}
  end

  defp insert_regular_char(state, row, col, char) do
    current_line = Enum.at(state.lines, row, "")
    {before_cursor, after_cursor} = String.split_at(current_line, col)
    new_line = before_cursor <> char <> after_cursor

    new_lines = List.replace_at(state.lines, row, new_line)
    new_value = Enum.join(new_lines, "\n")

    %{state | lines: new_lines, value: new_value, cursor_pos: {row, col + 1}}
  end

  @doc """
  Handles backspace when no selection exists.
  """
  @spec handle_backspace_no_selection(MultiLineInput.t()) :: MultiLineInput.t()
  def handle_backspace_no_selection(state) do
    {row, col} = state.cursor_pos

    cond do
      col > 0 ->
        # Delete character before cursor in same line
        current_line = Enum.at(state.lines, row, "")
        {before_cursor, after_cursor} = String.split_at(current_line, col)
        {before_char, _} = String.split_at(before_cursor, col - 1)
        new_line = before_char <> after_cursor

        new_lines = List.replace_at(state.lines, row, new_line)
        new_value = Enum.join(new_lines, "\n")

        %{
          state
          | lines: new_lines,
            value: new_value,
            cursor_pos: {row, col - 1}
        }

      row > 0 ->
        # Join with previous line
        current_line = Enum.at(state.lines, row, "")
        prev_line = Enum.at(state.lines, row - 1, "")
        new_line = prev_line <> current_line

        new_lines =
          state.lines
          |> List.replace_at(row - 1, new_line)
          |> List.delete_at(row)

        new_value = Enum.join(new_lines, "\n")

        %{
          state
          | lines: new_lines,
            value: new_value,
            cursor_pos: {row - 1, String.length(prev_line)}
        }

      true ->
        # At beginning of document, nothing to delete
        state
    end
  end

  @doc """
  Handles delete when no selection exists.
  """
  @spec handle_delete_no_selection(MultiLineInput.t()) :: MultiLineInput.t()
  def handle_delete_no_selection(state) do
    {row, col} = state.cursor_pos
    current_line = Enum.at(state.lines, row, "")

    cond do
      col < String.length(current_line) ->
        # Delete character at cursor in same line
        {before_cursor, after_cursor} = String.split_at(current_line, col)
        {_, rest} = String.split_at(after_cursor, 1)
        new_line = before_cursor <> rest

        new_lines = List.replace_at(state.lines, row, new_line)
        new_value = Enum.join(new_lines, "\n")

        %{state | lines: new_lines, value: new_value}

      row < length(state.lines) - 1 ->
        # Join with next line
        next_line = Enum.at(state.lines, row + 1, "")
        new_line = current_line <> next_line

        new_lines =
          state.lines
          |> List.replace_at(row, new_line)
          |> List.delete_at(row + 1)

        new_value = Enum.join(new_lines, "\n")

        %{state | lines: new_lines, value: new_value}

      true ->
        # At end of document, nothing to delete
        state
    end
  end

  @doc """
  Deletes the current selection and returns the updated state.
  """
  @spec delete_selection(MultiLineInput.t()) :: MultiLineInput.t()
  def delete_selection(state) do
    case {state.selection_start, state.selection_end} do
      {nil, _} ->
        state

      {_, nil} ->
        state

      {start_pos, end_pos} ->
        # Normalize selection (ensure start comes before end)
        {norm_start, norm_end} =
          normalize_selection_positions(start_pos, end_pos, state)

        delete_text_range(state, norm_start, norm_end)
    end
  end

  defp normalize_selection_positions(start_pos, end_pos, state) do
    if pos_to_index(start_pos, state) <= pos_to_index(end_pos, state) do
      {start_pos, end_pos}
    else
      {end_pos, start_pos}
    end
  end

  defp pos_to_index({row, col}, state) do
    # Calculate linear position in text
    lines_before = Enum.take(state.lines, row)
    # +1 for newline
    chars_before = Enum.sum(Enum.map(lines_before, &(String.length(&1) + 1)))
    chars_before + col
  end

  defp delete_text_range(state, {start_row, start_col}, {end_row, end_col}) do
    if start_row == end_row do
      # Selection within single line
      current_line = Enum.at(state.lines, start_row, "")
      {before, _} = String.split_at(current_line, start_col)
      {_, after_cursor} = String.split_at(current_line, end_col)
      new_line = before <> after_cursor

      new_lines = List.replace_at(state.lines, start_row, new_line)
      new_value = Enum.join(new_lines, "\n")

      %{
        state
        | lines: new_lines,
          value: new_value,
          cursor_pos: {start_row, start_col},
          selection_start: nil,
          selection_end: nil
      }
    else
      # Selection spans multiple lines
      start_line = Enum.at(state.lines, start_row, "")
      end_line = Enum.at(state.lines, end_row, "")

      {before_start, _} = String.split_at(start_line, start_col)
      {_, after_end} = String.split_at(end_line, end_col)
      new_line = before_start <> after_end

      # Remove lines between start and end, replace start line with merged line
      new_lines =
        state.lines
        |> Enum.with_index()
        |> Enum.filter(fn {_, idx} -> idx < start_row or idx > end_row end)
        |> Enum.map(&elem(&1, 0))
        |> List.insert_at(start_row, new_line)

      new_value = Enum.join(new_lines, "\n")

      %{
        state
        | lines: new_lines,
          value: new_value,
          cursor_pos: {start_row, start_col},
          selection_start: nil,
          selection_end: nil
      }
    end
  end

  @doc """
  Replaces text in a range with new text.
  """
  @spec replace_text_range(
          MultiLineInput.t(),
          {integer(), integer()},
          {integer(), integer()},
          String.t()
        ) :: MultiLineInput.t()
  def replace_text_range(state, start_pos, end_pos, replacement_text) do
    # First delete the range
    state_after_delete = delete_text_range(state, start_pos, end_pos)

    # Then insert the replacement text
    insert_text_at_position(state_after_delete, start_pos, replacement_text)
  end

  defp insert_text_at_position(state, {row, col}, text) do
    replacement_lines = String.split(text, "\n")

    case replacement_lines do
      [single_line] ->
        # Single line replacement
        current_line = Enum.at(state.lines, row, "")
        {before, after_cursor} = String.split_at(current_line, col)
        new_line = before <> single_line <> after_cursor

        new_lines = List.replace_at(state.lines, row, new_line)
        new_value = Enum.join(new_lines, "\n")

        %{
          state
          | lines: new_lines,
            value: new_value,
            cursor_pos: {row, col + String.length(single_line)}
        }

      [first_line | rest_lines] ->
        # Multi-line replacement
        current_line = Enum.at(state.lines, row, "")
        {before, after_cursor} = String.split_at(current_line, col)

        first_new_line = before <> first_line
        last_line_index = length(rest_lines) - 1
        {middle_lines, [last_line]} = Enum.split(rest_lines, last_line_index)
        last_new_line = last_line <> after_cursor

        new_lines =
          state.lines
          |> List.replace_at(row, first_new_line)
          |> insert_lines_after(row, middle_lines ++ [last_new_line])

        new_value = Enum.join(new_lines, "\n")
        final_row = row + length(rest_lines)
        final_col = String.length(last_line)

        %{
          state
          | lines: new_lines,
            value: new_value,
            cursor_pos: {final_row, final_col}
        }
    end
  end

  defp insert_lines_after(lines, index, new_lines) do
    {before, after_lines} = Enum.split(lines, index + 1)
    before ++ new_lines ++ after_lines
  end

  @doc """
  Calculates new cursor position.

  Can be used for:
  - Calculating position after text changes (2 args)
  - Calculating position after text insertion (3 args)
  """
  @spec calculate_new_position(MultiLineInput.t(), {integer(), integer()}) ::
          {integer(), integer()}
  @spec calculate_new_position(
          MultiLineInput.t(),
          String.t(),
          {integer(), integer()}
        ) :: {integer(), integer()}
  def calculate_new_position(_state, text, {row, col}) do
    lines = String.split(text, "\n")

    if length(lines) == 1 do
      {row, col + String.length(text)}
    else
      new_row = row + length(lines) - 1
      new_col = String.length(List.last(lines))
      {new_row, new_col}
    end
  end

  def calculate_new_position(state, {target_row, target_col}) do
    max_row = length(state.lines) - 1
    clamped_row = min(max(target_row, 0), max_row)

    target_line = Enum.at(state.lines, clamped_row, "")
    max_col = String.length(target_line)
    clamped_col = min(max(target_col, 0), max_col)

    {clamped_row, clamped_col}
  end
end
