defmodule Raxol.UI.Components.Input.MultiLineInput.RenderHelper do
  @moduledoc """
  Rendering helper functions for MultiLineInput component.
  """

  alias Raxol.UI.Components.Input.MultiLineInput

  @doc """
  Renders a single line with proper styling for cursor and selection.
  """
  @spec render_line(integer(), String.t(), MultiLineInput.t(), map()) :: list()
  def render_line(line_index, line_content, state, theme) do
    # Get theme styles
    text_style =
      get_theme_style(theme, [:components, :multi_line_input, :text_style], %{})

    cursor_style =
      get_theme_style(theme, [:components, :multi_line_input, :cursor_style], %{
        background: :red
      })

    selection_style =
      get_theme_style(
        theme,
        [:components, :multi_line_input, :selection_style],
        %{background: :blue}
      )

    # Check if this line has cursor
    {cursor_row, cursor_col} = state.cursor_pos
    has_cursor = line_index == cursor_row and state.focused

    # Check if this line has selection
    {selection_start, selection_end} = normalize_selection(state)

    line_has_selection =
      line_in_selection?(line_index, selection_start, selection_end)

    # Build line content with styles
    if line_has_selection do
      render_line_with_selection(
        line_content,
        line_index,
        state,
        text_style,
        selection_style,
        cursor_style,
        has_cursor,
        cursor_col
      )
    else
      render_line_simple(
        line_content,
        text_style,
        cursor_style,
        has_cursor,
        cursor_col
      )
    end
  end

  defp render_line_simple(
         line_content,
         text_style,
         cursor_style,
         has_cursor,
         cursor_col
       ) do
    line_length = String.length(line_content)

    if has_cursor and cursor_col <= line_length do
      # Split line at cursor position
      {before_cursor, at_and_after} = String.split_at(line_content, cursor_col)

      {cursor_char, after_cursor} =
        case at_and_after do
          # Show cursor at end of line
          "" -> {" ", ""}
          rest -> String.split_at(rest, 1)
        end

      [
        if(before_cursor != "",
          do: {:text, before_cursor, text_style},
          else: nil
        ),
        {:text, cursor_char, cursor_style},
        if(after_cursor != "", do: {:text, after_cursor, text_style}, else: nil)
      ]
      |> Enum.filter(&(&1 != nil))
    else
      # No cursor on this line
      if line_content != "" do
        [{:text, line_content, text_style}]
      else
        # Empty line placeholder
        [{:text, " ", text_style}]
      end
    end
  end

  defp render_line_with_selection(
         line_content,
         line_index,
         state,
         text_style,
         selection_style,
         cursor_style,
         has_cursor,
         cursor_col
       ) do
    {selection_start, selection_end} = normalize_selection(state)
    {start_row, start_col} = selection_start
    {end_row, end_col} = selection_end

    line_length = String.length(line_content)

    # Determine selection bounds for this line
    sel_start = if line_index == start_row, do: start_col, else: 0
    sel_end = if line_index == end_row, do: end_col, else: line_length

    # Ensure bounds are valid
    sel_start = max(0, min(sel_start, line_length))
    sel_end = max(sel_start, min(sel_end, line_length))

    parts = []

    # Before selection
    parts =
      if sel_start > 0 do
        before_sel = String.slice(line_content, 0, sel_start)
        [{:text, before_sel, text_style} | parts]
      else
        parts
      end

    # Selection
    parts =
      if sel_end > sel_start do
        selected_text =
          String.slice(line_content, sel_start, sel_end - sel_start)

        [{:text, selected_text, selection_style} | parts]
      else
        parts
      end

    # After selection
    parts =
      if sel_end < line_length do
        after_sel = String.slice(line_content, sel_end, line_length - sel_end)
        [{:text, after_sel, text_style} | parts]
      else
        parts
      end

    # Add cursor if on this line
    parts =
      if has_cursor do
        add_cursor_to_parts_reversed(parts, cursor_col, cursor_style)
      else
        parts
      end

    parts_final = Enum.reverse(parts)

    if parts_final == [] do
      # Empty line placeholder
      [{:text, " ", text_style}]
    else
      parts_final
    end
  end

  defp add_cursor_to_parts_reversed(parts, _cursor_col, cursor_style) do
    # This is a simplified implementation
    # In a full implementation, you'd need to carefully insert the cursor
    # at the correct position within the styled parts
    # Note: parts is in reverse order here
    [{:text, " ", cursor_style} | parts]
  end

  defp normalize_selection(state) do
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

  defp line_in_selection?(_line_index, nil, _), do: false
  defp line_in_selection?(_line_index, _, nil), do: false

  defp line_in_selection?(line_index, {start_row, _}, {end_row, _}) do
    line_index >= start_row and line_index <= end_row
  end

  defp pos_to_index({row, col}, state) do
    # Calculate linear position in text
    lines_before = Enum.take(state.lines, row)
    # +1 for newline
    chars_before = Enum.sum(Enum.map(lines_before, &(String.length(&1) + 1)))
    chars_before + col
  end

  defp get_theme_style(theme, path, default) do
    case get_in(theme, path) do
      nil -> default
      style -> style
    end
  end
end
