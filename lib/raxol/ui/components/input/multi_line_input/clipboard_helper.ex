defmodule Raxol.UI.Components.Input.MultiLineInput.ClipboardHelper do
  @moduledoc """
  Clipboard operations for MultiLineInput component.
  """

  alias Raxol.System.Clipboard
  alias Raxol.UI.Components.Input.MultiLineInput

  @doc """
  Copies the current selection to clipboard.
  """
  @spec copy_selection(MultiLineInput.t()) :: MultiLineInput.t()
  def copy_selection(%MultiLineInput{selection_start: nil} = state), do: state
  def copy_selection(%MultiLineInput{selection_end: nil} = state), do: state

  def copy_selection(%MultiLineInput{} = state) do
    selected_text = get_selected_text(state)

    _ =
      if selected_text != "" do
        Clipboard.copy(selected_text)
      end

    state
  end

  @doc """
  Cuts the current selection to clipboard.
  """
  @spec cut_selection(MultiLineInput.t()) :: MultiLineInput.t()
  def cut_selection(%MultiLineInput{selection_start: nil} = state), do: state
  def cut_selection(%MultiLineInput{selection_end: nil} = state), do: state

  def cut_selection(%MultiLineInput{} = state) do
    selected_text = get_selected_text(state)

    if selected_text != "" do
      _ = Clipboard.copy(selected_text)
      delete_selection(state)
    else
      state
    end
  end

  @doc """
  Pastes content from clipboard at cursor position.
  """
  @spec paste(MultiLineInput.t()) :: MultiLineInput.t()
  def paste(%MultiLineInput{} = state) do
    case Clipboard.paste() do
      {:ok, content} ->
        insert_text(state, content)

      _ ->
        state
    end
  end

  # Private helpers

  defp ordered_selection_bounds(%MultiLineInput{} = state) do
    {start_row, start_col} = normalize_position(state.selection_start)
    {end_row, end_col} = normalize_position(state.selection_end)

    if start_row > end_row or (start_row == end_row and start_col > end_col) do
      {end_row, end_col, start_row, start_col}
    else
      {start_row, start_col, end_row, end_col}
    end
  end

  defp get_selected_text(%MultiLineInput{} = state) do
    {start_row, start_col, end_row, end_col} = ordered_selection_bounds(state)
    lines = state.lines || []
    extract_text(lines, start_row, start_col, end_row, end_col)
  end

  defp extract_text(lines, row, start_col, row, end_col) do
    line = Enum.at(lines, row, "")
    String.slice(line, start_col, end_col - start_col)
  end

  defp extract_text(lines, start_row, start_col, end_row, end_col) do
    lines
    |> Enum.slice(start_row..end_row)
    |> Enum.with_index(start_row)
    |> Enum.map_join(
      "\n",
      &slice_selected_line(&1, start_row, start_col, end_row, end_col)
    )
  end

  defp slice_selected_line({line, idx}, idx, start_col, _end_row, _end_col) do
    String.slice(line, start_col..-1//1)
  end

  defp slice_selected_line({line, idx}, _start_row, _start_col, idx, end_col) do
    String.slice(line, 0, end_col)
  end

  defp slice_selected_line(
         {line, _idx},
         _start_row,
         _start_col,
         _end_row,
         _end_col
       ) do
    line
  end

  defp delete_selection(%MultiLineInput{} = state) do
    {start_row, start_col, end_row, end_col} = ordered_selection_bounds(state)
    lines = state.lines || []

    new_lines =
      remove_selected_range(lines, start_row, start_col, end_row, end_col)

    %{
      state
      | lines: new_lines,
        value: Enum.join(new_lines, "\n"),
        cursor_pos: {start_row, start_col},
        selection_start: nil,
        selection_end: nil
    }
  end

  defp remove_selected_range(lines, row, start_col, row, end_col) do
    line = Enum.at(lines, row, "")

    new_line =
      String.slice(line, 0, start_col) <> String.slice(line, end_col..-1//1)

    List.replace_at(lines, row, new_line)
  end

  defp remove_selected_range(lines, start_row, start_col, end_row, end_col) do
    start_line = Enum.at(lines, start_row, "")
    end_line = Enum.at(lines, end_row, "")

    merged_line =
      String.slice(start_line, 0, start_col) <>
        String.slice(end_line, end_col..-1//1)

    lines
    |> List.replace_at(start_row, merged_line)
    |> List.delete_at(end_row)
    |> delete_lines_between(start_row + 1, end_row - 1)
  end

  defp insert_text(%MultiLineInput{} = state, text) do
    {row, col} = state.cursor_pos
    lines = state.lines || []
    current_line = Enum.at(lines, row, "")
    do_insert_text(state, lines, current_line, row, col, text)
  end

  defp do_insert_text(state, lines, current_line, row, col, text) do
    if String.contains?(text, "\n") do
      insert_multiline_text(state, lines, current_line, row, col, text)
    else
      insert_single_line_text(state, lines, current_line, row, col, text)
    end
  end

  defp insert_multiline_text(state, lines, current_line, row, col, text) do
    text_lines = String.split(text, "\n")
    first_line = hd(text_lines)
    last_line = List.last(text_lines)
    middle_lines = text_lines |> tl() |> Enum.drop(-1)

    before = String.slice(current_line, 0, col)
    after_text = String.slice(current_line, col..-1//1)

    new_lines =
      lines
      |> List.replace_at(row, before <> first_line)
      # credo:disable-for-next-line Credo.Check.Refactor.AppendSingleItem
      |> List.insert_at(row + 1, middle_lines ++ [last_line <> after_text])
      |> List.flatten()

    %{
      state
      | lines: new_lines,
        value: Enum.join(new_lines, "\n"),
        cursor_pos: {row + length(text_lines) - 1, String.length(last_line)}
    }
  end

  defp insert_single_line_text(state, lines, current_line, row, col, text) do
    new_line =
      String.slice(current_line, 0, col) <>
        text <> String.slice(current_line, col..-1//1)

    new_lines = List.replace_at(lines, row, new_line)

    %{
      state
      | lines: new_lines,
        value: Enum.join(new_lines, "\n"),
        cursor_pos: {row, col + String.length(text)}
    }
  end

  defp normalize_position(nil), do: {0, 0}
  defp normalize_position({row, col}), do: {max(0, row), max(0, col)}

  defp delete_lines_between(lines, start, stop) when stop < start, do: lines

  defp delete_lines_between(lines, start, stop) do
    Enum.reduce(start..stop, lines, fn _idx, acc ->
      List.delete_at(acc, start)
    end)
  end
end
