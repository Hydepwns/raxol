defmodule Raxol.UI.Components.Input.MultiLineInput.UnifiedHelper do
  @moduledoc """
  Consolidated helper functions for MultiLineInput component.
  Combines functionality from TextHelper, NavigationHelper, RenderHelper, and ClipboardHelper.
  """

  alias Raxol.UI.Components.Input.MultiLineInput

  # =============================================================================
  # TEXT MANIPULATION FUNCTIONS (from TextHelper)
  # =============================================================================

  @doc """
  Splits text into lines based on width and wrap mode.
  """
  @spec split_into_lines(String.t(), integer(), :none | :char | :word) :: [
          String.t()
        ]
  def split_into_lines(text, width, wrap_mode) do
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

  @doc """
  Inserts text at the current cursor position.
  """
  @spec insert_text(MultiLineInput.t(), String.t()) :: MultiLineInput.t()
  def insert_text(state, text) do
    {row, col} = state.cursor_pos
    current_line = Enum.at(state.lines, row, "")

    {left, right} = String.split_at(current_line, col)
    new_line = left <> text <> right

    new_lines = List.replace_at(state.lines, row, new_line)
    new_cursor_pos = {row, col + String.length(text)}

    %{state | lines: new_lines, cursor_pos: new_cursor_pos}
  end

  @doc """
  Deletes character at cursor position (backspace behavior).
  """
  @spec delete_char_before(MultiLineInput.t()) :: MultiLineInput.t()
  def delete_char_before(state) do
    {row, col} = state.cursor_pos

    cond do
      col > 0 ->
        current_line = Enum.at(state.lines, row, "")
        {left, right} = String.split_at(current_line, col)
        new_left = String.slice(left, 0..-2//-1)
        new_line = new_left <> right

        new_lines = List.replace_at(state.lines, row, new_line)
        %{state | lines: new_lines, cursor_pos: {row, col - 1}}

      row > 0 ->
        # Join with previous line
        current_line = Enum.at(state.lines, row, "")
        prev_line = Enum.at(state.lines, row - 1, "")
        merged_line = prev_line <> current_line

        new_lines =
          state.lines
          |> List.replace_at(row - 1, merged_line)
          |> List.delete_at(row)

        %{
          state
          | lines: new_lines,
            cursor_pos: {row - 1, String.length(prev_line)}
        }

      true ->
        state
    end
  end

  # =============================================================================
  # NAVIGATION FUNCTIONS (from NavigationHelper)
  # =============================================================================

  @doc """
  Moves cursor in the specified direction.
  """
  @spec move_cursor(MultiLineInput.t(), :left | :right | :up | :down) ::
          MultiLineInput.t()
  def move_cursor(state, direction) do
    {row, col} = state.cursor_pos

    case direction do
      :left -> move_cursor_left(state, row, col)
      :right -> move_cursor_right(state, row, col)
      :up -> move_cursor_up(state, row, col)
      :down -> move_cursor_down(state, row, col)
    end
  end

  @doc """
  Jumps cursor to beginning/end of line or document.
  """
  @spec jump_cursor(
          MultiLineInput.t(),
          :line_start | :line_end | :doc_start | :doc_end
        ) :: MultiLineInput.t()
  def jump_cursor(state, position) do
    {row, _col} = state.cursor_pos

    case position do
      :line_start ->
        %{state | cursor_pos: {row, 0}}

      :line_end ->
        line_length = Enum.at(state.lines, row, "") |> String.length()
        %{state | cursor_pos: {row, line_length}}

      :doc_start ->
        %{state | cursor_pos: {0, 0}}

      :doc_end ->
        last_row = length(state.lines) - 1
        last_col = Enum.at(state.lines, last_row, "") |> String.length()
        %{state | cursor_pos: {last_row, last_col}}
    end
  end

  # =============================================================================
  # CLIPBOARD FUNCTIONS (from ClipboardHelper)
  # =============================================================================

  @doc """
  Copies selected text to clipboard (mock implementation).
  """
  @spec copy_selection(MultiLineInput.t()) :: MultiLineInput.t()
  def copy_selection(state) do
    selected_text = get_selected_text(state)
    # In a real implementation, this would interact with system clipboard
    %{state | clipboard: selected_text}
  end

  @doc """
  Cuts selected text to clipboard and deletes it.
  """
  @spec cut_selection(MultiLineInput.t()) :: MultiLineInput.t()
  def cut_selection(state) do
    state
    |> copy_selection()
    |> delete_selection()
  end

  @doc """
  Pastes clipboard content at cursor position.
  """
  @spec paste_from_clipboard(MultiLineInput.t()) :: MultiLineInput.t()
  def paste_from_clipboard(state) do
    case Map.get(state, :clipboard) do
      nil -> state
      text -> insert_text(state, text)
    end
  end

  # =============================================================================
  # RENDERING FUNCTIONS (from RenderHelper)
  # =============================================================================

  @doc """
  Calculates visible line range for rendering.
  """
  @spec calculate_visible_range(MultiLineInput.t()) :: {integer(), integer()}
  def calculate_visible_range(state) do
    {cursor_row, _} = state.cursor_pos
    height = state.height

    start_row = max(0, cursor_row - div(height, 2))
    end_row = min(length(state.lines) - 1, start_row + height - 1)

    {start_row, end_row}
  end

  @doc """
  Renders visible lines with cursor highlighting.
  """
  @spec render_lines(MultiLineInput.t()) :: [String.t()]
  def render_lines(state) do
    {start_row, end_row} = calculate_visible_range(state)
    {cursor_row, cursor_col} = state.cursor_pos

    start_row..end_row
    |> Enum.map(fn row ->
      line = Enum.at(state.lines, row, "")

      if row == cursor_row do
        add_cursor_highlight(line, cursor_col)
      else
        line
      end
    end)
  end

  # =============================================================================
  # PRIVATE HELPER FUNCTIONS
  # =============================================================================

  defp wrap_line_by_char(line, width) when width <= 0, do: [line]

  defp wrap_line_by_char(line, width) do
    if String.length(line) <= width do
      [line]
    else
      {head, tail} = String.split_at(line, width)
      [head | wrap_line_by_char(tail, width)]
    end
  end

  defp wrap_line_by_word(line, width) when width <= 0, do: [line]

  defp wrap_line_by_word(line, width) do
    words = String.split(line, " ")
    wrap_words(words, width, "", [])
  end

  defp wrap_words([], _width, "", acc), do: Enum.reverse(acc)

  defp wrap_words([], _width, current_line, acc),
    do: Enum.reverse([current_line | acc])

  defp wrap_words([word | rest], width, current_line, acc) do
    new_line =
      if current_line == "", do: word, else: current_line <> " " <> word

    if String.length(new_line) <= width do
      wrap_words(rest, width, new_line, acc)
    else
      if current_line == "" do
        # Word is longer than width, force break
        wrap_words(rest, width, word, acc)
      else
        # Start new line with current word
        wrap_words(rest, width, word, [current_line | acc])
      end
    end
  end

  defp move_cursor_left(state, row, col) do
    cond do
      col > 0 ->
        %{state | cursor_pos: {row, col - 1}}

      row > 0 ->
        prev_line = Enum.at(state.lines, row - 1, "")
        %{state | cursor_pos: {row - 1, String.length(prev_line)}}

      true ->
        state
    end
  end

  defp move_cursor_right(state, row, col) do
    current_line = Enum.at(state.lines, row, "")

    cond do
      col < String.length(current_line) -> %{state | cursor_pos: {row, col + 1}}
      row < length(state.lines) - 1 -> %{state | cursor_pos: {row + 1, 0}}
      true -> state
    end
  end

  defp move_cursor_up(state, row, col) do
    if row > 0 do
      prev_line = Enum.at(state.lines, row - 1, "")
      new_col = min(col, String.length(prev_line))
      %{state | cursor_pos: {row - 1, new_col}}
    else
      state
    end
  end

  defp move_cursor_down(state, row, col) do
    if row < length(state.lines) - 1 do
      next_line = Enum.at(state.lines, row + 1, "")
      new_col = min(col, String.length(next_line))
      %{state | cursor_pos: {row + 1, new_col}}
    else
      state
    end
  end

  defp get_selected_text(state) do
    # Placeholder for selection logic
    case Map.get(state, :selection) do
      nil -> ""
      {start_pos, end_pos} -> extract_text_between(state, start_pos, end_pos)
    end
  end

  defp extract_text_between(state, {start_row, start_col}, {end_row, end_col}) do
    cond do
      start_row == end_row ->
        line = Enum.at(state.lines, start_row, "")
        String.slice(line, start_col, end_col - start_col)

      true ->
        lines = Enum.slice(state.lines, start_row..end_row)
        # Implementation would extract text across multiple lines
        Enum.join(lines, "\n")
    end
  end

  defp delete_selection(state) do
    # Placeholder for selection deletion
    case Map.get(state, :selection) do
      nil ->
        state

      _selection ->
        # Would delete selected text and update cursor position
        %{state | selection: nil}
    end
  end

  defp add_cursor_highlight(line, cursor_col) do
    if cursor_col <= String.length(line) do
      {left, right} = String.split_at(line, cursor_col)

      case right do
        "" ->
          left <> "|"

        _ ->
          {cursor_char, remaining} = String.split_at(right, 1)
          left <> "[" <> cursor_char <> "]" <> remaining
      end
    else
      line <> "|"
    end
  end
end
