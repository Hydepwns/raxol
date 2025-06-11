defmodule Raxol.UI.Components.Input.MultiLineInput.RenderHelper do
  @moduledoc """
  UI adapter for MultiLineInput's RenderHelper. Delegates to the implementation in
  Raxol.UI.Components.Input.MultiLineInput.RenderHelper.
  """

  alias Raxol.UI.Components.Input.MultiLineInput.RenderHelper,
    as: ComponentRenderHelper

  @doc """
  Renders the multi-line input component with proper styling based on the state.
  Returns a grid of cell data for the visible portion of text.

  Delegates to the implementation in Raxol.UI.Components.Input.MultiLineInput.RenderHelper.

  ## Parameters
  - state: The MultiLineInput state
  - context: The render context
  - theme: The theme containing style information
  """
  def render(state, context, theme) do
    ComponentRenderHelper.render(state, context, theme)
  end

  @doc """
  Renders a single line of the multi-line input, applying selection and cursor styles as needed.
  Returns a list of label components for the segments of the line.
  """
  def render_line(line_index, line_content, state, theme) do
    require Raxol.View.Components
    alias Raxol.View.Components
    alias Raxol.UI.Components.Input.MultiLineInput.NavigationHelper

    # Theme extraction helpers
    merged_theme =
      theme[:components][:multi_line_input] || theme[:multi_line_input] || %{}
    selection_style = Map.get(merged_theme, :selection_style, %{inverse: true})
    cursor_style = Map.get(merged_theme, :cursor_style, %{inverse: true})
    text_style = Map.get(merged_theme, :text_style, %{})

    {cursor_row, cursor_col} = state.cursor_pos
    focused = Map.get(state, :focused, false)

    {sel_start, sel_end} = NavigationHelper.normalize_selection(state)

    line_len = String.length(line_content)
    safe_cursor_col =
      cond do
        is_integer(cursor_col) and cursor_col < 0 -> 0
        is_integer(cursor_col) and cursor_col > line_len -> line_len
        true -> cursor_col
      end

    # Helper: get selection range for this line (col_start, col_end) or nil
    selection_range =
      cond do
        sel_start == nil or sel_end == nil -> nil
        true ->
          {{start_row, start_col}, {end_row, end_col}} = {sel_start, sel_end}
          min_row = min(start_row, end_row)
          max_row = max(start_row, end_row)
          if line_index < min_row or line_index > max_row do
            nil
          else
            # Always compute left/right based on actual selection direction
            {left, right} =
              cond do
                start_row == end_row ->
                  {min(start_col, end_col), max(start_col, end_col)}
                line_index == start_row ->
                  {start_col, line_len}
                line_index == end_row ->
                  {0, end_col}
                true ->
                  {0, line_len}
              end
            # Clamp to valid range
            {min(max(left, 0), line_len), min(max(right, 0), line_len)}
          end
      end

    # Helper: is cursor on this line?
    cursor_on_this_line = focused and cursor_row == line_index

    # Safe slice helper
    safe_slice = fn str, start, len ->
      start = min(max(start, 0), line_len)
      len = max(0, len)
      String.slice(str, start, len)
    end

    # Now, split the line into segments for rendering
    segments =
      cond do
        selection_range && cursor_on_this_line ->
          {sel_start_col, sel_end_col} = selection_range
          # Clamp selection to valid range
          sel_start_col = min(max(sel_start_col, 0), line_len)
          sel_end_col = min(max(sel_end_col, 0), line_len)
          # Cursor may be inside or outside selection
          cursor_in_selection = safe_cursor_col >= sel_start_col and safe_cursor_col < sel_end_col
          if cursor_in_selection do
            before_sel = safe_slice.(line_content, 0, sel_start_col)
            sel_before_cursor = safe_slice.(line_content, sel_start_col, safe_cursor_col - sel_start_col)
            cursor_char = safe_slice.(line_content, safe_cursor_col, 1)
            sel_after_cursor = safe_slice.(line_content, safe_cursor_col + 1, sel_end_col - safe_cursor_col - 1)
            after_sel = safe_slice.(line_content, sel_end_col, line_len - sel_end_col)

            [
              {before_sel, text_style},
              {sel_before_cursor, selection_style},
              {cursor_char, Map.merge(selection_style, cursor_style)},
              {sel_after_cursor, selection_style},
              {after_sel, text_style}
            ]
          else
            # Cursor outside selection: before selection, selection, after selection, cursor
            before_sel = safe_slice.(line_content, 0, sel_start_col)
            selection = safe_slice.(line_content, sel_start_col, sel_end_col - sel_start_col)
            after_sel = safe_slice.(line_content, sel_end_col, line_len - sel_end_col)
            if safe_cursor_col < sel_start_col do
              before_cursor = safe_slice.(line_content, 0, safe_cursor_col)
              cursor_char = safe_slice.(line_content, safe_cursor_col, 1)
              after_cursor = safe_slice.(line_content, safe_cursor_col + 1, sel_start_col - safe_cursor_col - 1)
              [
                {before_cursor, text_style},
                {cursor_char, cursor_style},
                {after_cursor, text_style},
                {selection, selection_style},
                {after_sel, text_style}
              ]
            else
              # Cursor after selection
              after_sel_before_cursor = safe_slice.(line_content, sel_end_col, safe_cursor_col - sel_end_col)
              cursor_char = safe_slice.(line_content, safe_cursor_col, 1)
              after_cursor = safe_slice.(line_content, safe_cursor_col + 1, line_len - safe_cursor_col - 1)
              [
                {before_sel, text_style},
                {selection, selection_style},
                {after_sel_before_cursor, text_style},
                {cursor_char, cursor_style},
                {after_cursor, text_style}
              ]
            end
          end
        selection_range ->
          {left, right} = selection_range
          before_sel = safe_slice.(line_content, 0, left)
          selection = safe_slice.(line_content, left, right - left)
          after_sel = safe_slice.(line_content, right, line_len - right)
          selection_style_with_bg = Map.put_new(selection_style, :background, :blue)
          [
            {before_sel, text_style},
            {selection, selection_style_with_bg},
            {after_sel, text_style}
          ]
        cursor_on_this_line ->
          before_cursor = safe_slice.(line_content, 0, safe_cursor_col)
          cursor_char = safe_slice.(line_content, safe_cursor_col, 1)
          after_cursor = safe_slice.(line_content, safe_cursor_col + 1, line_len - safe_cursor_col - 1)
          [
            {before_cursor, text_style},
            {cursor_char, cursor_style},
            {after_cursor, text_style}
          ]
        true ->
          [{line_content, text_style}]
      end

    # Filter out empty segments
    segments = Enum.filter(segments, fn {text, _} -> text != nil and text != "" end)

    # For empty lines, return [] (or a single label with empty content if needed)
    if line_content == "" and segments == [] do
      []
    else
      Enum.map(segments, fn {text, style} ->
        Components.label(text, style: style)
      end)
    end
  end
end
