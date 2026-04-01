defmodule Raxol.UI.Components.Input.MultiLineInput.NavigationHelper do
  @moduledoc """
  Navigation helper functions for MultiLineInput component cursor movement and selection operations.
  """

  alias Raxol.UI.Components.Input.MultiLineInput
  alias Raxol.UI.Components.Input.MultiLineInput.TextHelper

  @doc """
  Moves the cursor in the specified direction within the multi-line input.
  """
  @spec move_cursor(
          MultiLineInput.t(),
          :left | :right | :up | :down | :word_left | :word_right
        ) ::
          MultiLineInput.t()
  def move_cursor(state, direction) do
    {row, col} = state.cursor_pos

    case direction do
      :left -> move_cursor_left(state, row, col)
      :right -> move_cursor_right(state, row, col)
      :up -> move_cursor_up(state, row, col)
      :down -> move_cursor_down(state, row, col)
      :word_left -> move_cursor_word_left(state, row, col)
      :word_right -> move_cursor_word_right(state, row, col)
    end
  end

  defp move_cursor_left(state, row, col) do
    cond do
      col > 0 ->
        %{state | cursor_pos: {row, col - 1}, desired_col: nil}

      row > 0 ->
        prev_line = Enum.at(state.lines, row - 1, "")

        %{
          state
          | cursor_pos: {row - 1, String.length(prev_line)},
            desired_col: nil
        }

      true ->
        state
    end
  end

  defp move_cursor_right(state, row, col) do
    current_line = Enum.at(state.lines, row, "")
    line_length = String.length(current_line)

    cond do
      col < line_length ->
        %{state | cursor_pos: {row, col + 1}, desired_col: nil}

      row < length(state.lines) - 1 ->
        %{state | cursor_pos: {row + 1, 0}, desired_col: nil}

      true ->
        state
    end
  end

  defp move_cursor_up(state, row, col) do
    if row > 0 do
      target_col = state.desired_col || col
      prev_line = Enum.at(state.lines, row - 1, "")
      new_col = min(target_col, String.length(prev_line))
      %{state | cursor_pos: {row - 1, new_col}, desired_col: target_col}
    else
      state
    end
  end

  defp move_cursor_down(state, row, col) do
    if row < length(state.lines) - 1 do
      target_col = state.desired_col || col
      next_line = Enum.at(state.lines, row + 1, "")
      new_col = min(target_col, String.length(next_line))
      %{state | cursor_pos: {row + 1, new_col}, desired_col: target_col}
    else
      state
    end
  end

  defp move_cursor_word_left(state, row, col) do
    current_line = Enum.at(state.lines, row, "")
    before_cursor = String.slice(current_line, 0, col)

    case find_word_boundary_left(before_cursor) do
      0 when row > 0 ->
        prev_line = Enum.at(state.lines, row - 1, "")

        %{
          state
          | cursor_pos: {row - 1, String.length(prev_line)},
            desired_col: nil
        }

      new_col ->
        %{state | cursor_pos: {row, new_col}, desired_col: nil}
    end
  end

  defp move_cursor_word_right(state, row, col) do
    current_line = Enum.at(state.lines, row, "")
    line_length = String.length(current_line)
    after_cursor = String.slice(current_line, col, line_length - col)

    case find_word_boundary_right(after_cursor) do
      offset
      when col + offset >= line_length and row < length(state.lines) - 1 ->
        %{state | cursor_pos: {row + 1, 0}, desired_col: nil}

      offset ->
        %{state | cursor_pos: {row, col + offset}, desired_col: nil}
    end
  end

  defp find_word_boundary_left(text) do
    # Find start of previous word
    text
    |> String.reverse()
    |> String.replace(~r/^\s*/, "")
    |> String.replace(~r/^\S*/, "")
    |> String.length()
    |> then(&(String.length(text) - &1))
  end

  defp find_word_boundary_right(text) do
    # Find end of current word or start of next word
    text
    |> String.replace(~r/^\S*/, "")
    |> String.replace(~r/^\s*/, "")
    |> String.length()
    |> then(&(String.length(text) - &1))
  end

  @doc """
  Moves the cursor to the start of the current line.
  """
  @spec move_cursor_line_start(MultiLineInput.t()) :: MultiLineInput.t()
  def move_cursor_line_start(state) do
    {row, _col} = state.cursor_pos
    %{state | cursor_pos: {row, 0}, desired_col: nil}
  end

  @doc """
  Moves the cursor to the end of the current line.
  """
  @spec move_cursor_line_end(MultiLineInput.t()) :: MultiLineInput.t()
  def move_cursor_line_end(state) do
    {row, _col} = state.cursor_pos
    current_line = Enum.at(state.lines, row, "")
    line_length = String.length(current_line)
    %{state | cursor_pos: {row, line_length}, desired_col: nil}
  end

  @doc """
  Moves the cursor by a page (viewport height) in the specified direction.
  """
  @spec move_cursor_page(MultiLineInput.t(), :up | :down) :: MultiLineInput.t()
  def move_cursor_page(state, direction) do
    {row, col} = state.cursor_pos
    target_col = state.desired_col || col
    page_size = state.height

    new_row =
      case direction do
        :up -> max(0, row - page_size)
        :down -> min(length(state.lines) - 1, row + page_size)
      end

    target_line = Enum.at(state.lines, new_row, "")
    new_col = min(target_col, String.length(target_line))

    %{state | cursor_pos: {new_row, new_col}, desired_col: target_col}
  end

  @doc """
  Moves the cursor to the start of the document.
  """
  @spec move_cursor_doc_start(MultiLineInput.t()) :: MultiLineInput.t()
  def move_cursor_doc_start(state) do
    %{state | cursor_pos: {0, 0}, desired_col: nil}
  end

  @doc """
  Moves the cursor to the end of the document.
  """
  @spec move_cursor_doc_end(MultiLineInput.t()) :: MultiLineInput.t()
  def move_cursor_doc_end(state) do
    last_line_index = length(state.lines) - 1
    last_line = Enum.at(state.lines, last_line_index, "")
    last_col = String.length(last_line)
    %{state | cursor_pos: {last_line_index, last_col}, desired_col: nil}
  end

  @doc """
  Normalizes the selection range, ensuring start comes before end.
  Returns {nil, nil} if no selection exists.
  """
  @spec normalize_selection(MultiLineInput.t()) ::
          {{integer(), integer()}, {integer(), integer()}} | {nil, nil}
  def normalize_selection(state) do
    case {state.selection_start, state.selection_end} do
      {nil, _} ->
        {nil, nil}

      {_, nil} ->
        {nil, nil}

      {start_pos, end_pos} ->
        if TextHelper.pos_to_index(start_pos, state) <=
             TextHelper.pos_to_index(end_pos, state) do
          {start_pos, end_pos}
        else
          {end_pos, start_pos}
        end
    end
  end

  @doc """
  Checks if a line index is within the selection range.
  """
  @spec line_in_selection?(
          integer(),
          {integer(), integer()} | nil,
          {integer(), integer()} | nil
        ) :: boolean()
  def line_in_selection?(_line_index, nil, _), do: false
  def line_in_selection?(_line_index, _, nil), do: false

  def line_in_selection?(line_index, start_pos, end_pos) do
    {start_row, _} = start_pos
    {end_row, _} = end_pos

    # Normalize the range
    {min_row, max_row} =
      if start_row <= end_row,
        do: {start_row, end_row},
        else: {end_row, start_row}

    line_index >= min_row and line_index <= max_row
  end

  @doc """
  Selects all text in the input.
  """
  @spec select_all(MultiLineInput.t()) :: MultiLineInput.t()
  def select_all(state) do
    last_line_index = length(state.lines) - 1
    last_line = Enum.at(state.lines, last_line_index, "")
    last_col = String.length(last_line)

    %{
      state
      | selection_start: {0, 0},
        selection_end: {last_line_index, last_col}
    }
  end

  @doc """
  Clears the current selection.
  """
  @spec clear_selection(MultiLineInput.t()) :: MultiLineInput.t()
  def clear_selection(state) do
    %{state | selection_start: nil, selection_end: nil}
  end
end
