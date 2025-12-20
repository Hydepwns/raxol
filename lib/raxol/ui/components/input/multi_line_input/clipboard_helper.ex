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

  defp get_selected_text(%MultiLineInput{} = state) do
    {start_row, start_col} = normalize_position(state.selection_start)
    {end_row, end_col} = normalize_position(state.selection_end)

    # Ensure start is before end
    {start_row, start_col, end_row, end_col} =
      if start_row > end_row or (start_row == end_row and start_col > end_col) do
        {end_row, end_col, start_row, start_col}
      else
        {start_row, start_col, end_row, end_col}
      end

    lines = state.lines || []

    if start_row == end_row do
      # Single line selection
      line = Enum.at(lines, start_row, "")
      String.slice(line, start_col, end_col - start_col)
    else
      # Multi-line selection
      selected_lines =
        lines
        |> Enum.slice(start_row..end_row)
        |> Enum.with_index(start_row)
        |> Enum.map(fn {line, idx} ->
          cond do
            idx == start_row ->
              String.slice(line, start_col..-1//1)

            idx == end_row ->
              String.slice(line, 0, end_col)

            true ->
              line
          end
        end)

      Enum.join(selected_lines, "\n")
    end
  end

  defp delete_selection(%MultiLineInput{} = state) do
    {start_row, start_col} = normalize_position(state.selection_start)
    {end_row, end_col} = normalize_position(state.selection_end)

    # Ensure start is before end
    {start_row, start_col, end_row, end_col} =
      if start_row > end_row or (start_row == end_row and start_col > end_col) do
        {end_row, end_col, start_row, start_col}
      else
        {start_row, start_col, end_row, end_col}
      end

    lines = state.lines || []

    new_lines =
      if start_row == end_row do
        # Single line deletion
        line = Enum.at(lines, start_row, "")

        new_line =
          String.slice(line, 0, start_col) <> String.slice(line, end_col..-1//1)

        List.replace_at(lines, start_row, new_line)
      else
        # Multi-line deletion
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

    %{
      state
      | lines: new_lines,
        value: Enum.join(new_lines, "\n"),
        cursor_pos: {start_row, start_col},
        selection_start: nil,
        selection_end: nil
    }
  end

  defp insert_text(%MultiLineInput{} = state, text) do
    {row, col} = state.cursor_pos
    lines = state.lines || []
    current_line = Enum.at(lines, row, "")

    if String.contains?(text, "\n") do
      # Multi-line insert
      text_lines = String.split(text, "\n")
      first_line = hd(text_lines)
      last_line = List.last(text_lines)
      middle_lines = text_lines |> tl() |> Enum.drop(-1)

      before = String.slice(current_line, 0, col)
      after_text = String.slice(current_line, col..-1//1)

      new_first_line = before <> first_line
      new_last_line = last_line <> after_text

      new_lines =
        lines
        |> List.replace_at(row, new_first_line)
        |> List.insert_at(row + 1, middle_lines ++ [new_last_line])
        |> List.flatten()

      new_row = row + length(text_lines) - 1
      new_col = String.length(last_line)

      %{
        state
        | lines: new_lines,
          value: Enum.join(new_lines, "\n"),
          cursor_pos: {new_row, new_col}
      }
    else
      # Single line insert
      new_line =
        String.slice(current_line, 0, col) <>
          text <> String.slice(current_line, col..-1//1)

      new_lines = List.replace_at(lines, row, new_line)
      new_col = col + String.length(text)

      %{
        state
        | lines: new_lines,
          value: Enum.join(new_lines, "\n"),
          cursor_pos: {row, new_col}
      }
    end
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
