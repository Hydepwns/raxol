defmodule Raxol.UI.Components.Input.MultiLineInput.NavigationHelper do
  @moduledoc """
  Navigation helper functions for MultiLineInput component cursor movement and selection operations.
  """

  alias Raxol.UI.Components.Input.MultiLineInput

  @doc """
  Moves the cursor in the specified direction within the multi-line input.
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

  defp move_cursor_left(state, row, col) do
    cond do
      col > 0 ->
        %{state | cursor_pos: {row, col - 1}}

      row > 0 ->
        # Move to end of previous line
        prev_line = Enum.at(state.lines, row - 1, "")
        %{state | cursor_pos: {row - 1, String.length(prev_line)}}

      true ->
        # Already at start of document
        state
    end
  end

  defp move_cursor_right(state, row, col) do
    current_line = Enum.at(state.lines, row, "")
    line_length = String.length(current_line)

    cond do
      col < line_length ->
        %{state | cursor_pos: {row, col + 1}}

      row < length(state.lines) - 1 ->
        # Move to start of next line
        %{state | cursor_pos: {row + 1, 0}}

      true ->
        # Already at end of document
        state
    end
  end

  defp move_cursor_up(state, row, col) do
    if row > 0 do
      prev_line = Enum.at(state.lines, row - 1, "")
      prev_line_length = String.length(prev_line)
      new_col = min(col, prev_line_length)
      %{state | cursor_pos: {row - 1, new_col}}
    else
      state
    end
  end

  defp move_cursor_down(state, row, col) do
    if row < length(state.lines) - 1 do
      next_line = Enum.at(state.lines, row + 1, "")
      next_line_length = String.length(next_line)
      new_col = min(col, next_line_length)
      %{state | cursor_pos: {row + 1, new_col}}
    else
      state
    end
  end

  @doc """
  Moves the cursor to the start of the current line.
  """
  @spec move_cursor_line_start(MultiLineInput.t()) :: MultiLineInput.t()
  def move_cursor_line_start(state) do
    {row, _col} = state.cursor_pos
    %{state | cursor_pos: {row, 0}}
  end

  @doc """
  Moves the cursor to the end of the current line.
  """
  @spec move_cursor_line_end(MultiLineInput.t()) :: MultiLineInput.t()
  def move_cursor_line_end(state) do
    {row, _col} = state.cursor_pos
    current_line = Enum.at(state.lines, row, "")
    line_length = String.length(current_line)
    %{state | cursor_pos: {row, line_length}}
  end

  @doc """
  Moves the cursor by a page (viewport height) in the specified direction.
  """
  @spec move_cursor_page(MultiLineInput.t(), :up | :down) :: MultiLineInput.t()
  def move_cursor_page(state, direction) do
    {row, col} = state.cursor_pos
    page_size = state.height

    new_row =
      case direction do
        :up -> max(0, row - page_size)
        :down -> min(length(state.lines) - 1, row + page_size)
      end

    # Clamp column to the length of the target line
    target_line = Enum.at(state.lines, new_row, "")
    new_col = min(col, String.length(target_line))

    %{state | cursor_pos: {new_row, new_col}}
  end

  @doc """
  Moves the cursor to the start of the document.
  """
  @spec move_cursor_doc_start(MultiLineInput.t()) :: MultiLineInput.t()
  def move_cursor_doc_start(state) do
    %{state | cursor_pos: {0, 0}}
  end

  @doc """
  Moves the cursor to the end of the document.
  """
  @spec move_cursor_doc_end(MultiLineInput.t()) :: MultiLineInput.t()
  def move_cursor_doc_end(state) do
    last_line_index = length(state.lines) - 1
    last_line = Enum.at(state.lines, last_line_index, "")
    last_col = String.length(last_line)
    %{state | cursor_pos: {last_line_index, last_col}}
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
        if pos_to_index(start_pos, state) <= pos_to_index(end_pos, state) do
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

  # Helper function to convert position to linear index for comparison
  defp pos_to_index({row, col}, state) do
    # Calculate the linear position in the text
    lines_before = Enum.take(state.lines, row)
    # +1 for newline
    chars_before = Enum.sum(Enum.map(lines_before, &(String.length(&1) + 1)))
    chars_before + col
  end
end
