defmodule Raxol.UI.Components.Input.MultiLineInput.RenderHelper do
  @moduledoc """
  UI adapter for MultiLineInput's RenderHelper. Delegates to the implementation in
  Raxol.UI.Components.Input.MultiLineInput.RenderHelper.
  """

  alias Raxol.UI.Components.Input.MultiLineInput.RenderHelper,
    as: ComponentRenderHelper

  alias Raxol.View.Components

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

    {merged_theme, cursor_pos, focused, sel_start, sel_end, line_len,
     safe_cursor_col} =
      extract_render_data(state, theme, line_content)

    selection_range =
      calculate_selection_range(sel_start, sel_end, line_index, line_len)

    cursor_on_this_line = focused and elem(cursor_pos, 0) == line_index
    safe_slice = create_safe_slice(line_len)

    text_style = merged_theme[:text_style] || %{}
    cursor_style = merged_theme[:cursor_style] || %{}

    segments =
      create_segments(
        selection_range,
        cursor_on_this_line,
        line_content,
        text_style,
        cursor_style,
        safe_cursor_col,
        safe_slice,
        line_len
      )

    if is_list(segments) and match?([%{type: :label} | _], segments) do
      segments
    else
      process_segments(segments, line_content)
    end
  end

  defp extract_render_data(state, theme, line_content) do
    merged_theme =
      theme[:components][:multi_line_input] || theme[:multi_line_input] || %{}

    cursor_pos = state.cursor_pos
    focused = Map.get(state, :focused, false)

    {sel_start, sel_end} =
      Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.normalize_selection(
        state
      )

    line_len = String.length(line_content)
    safe_cursor_col = cursor_pos |> elem(1) |> max(0) |> min(line_len)

    {merged_theme, cursor_pos, focused, sel_start, sel_end, line_len,
     safe_cursor_col}
  end

  defp create_safe_slice(line_len) do
    fn str, start, len ->
      start = min(max(start, 0), line_len)
      len = max(0, len)
      String.slice(str, start, len)
    end
  end

  defp process_segments(segments, line_content) do
    segments =
      Enum.filter(segments, fn {text, _} -> text != nil and text != "" end)

    if line_content == "" and segments == [] do
      []
    else
      Enum.map(segments, fn {text, style} ->
        Components.label(text, style: style)
      end)
    end
  end

  defp calculate_selection_range(nil, _sel_end, _line_index, _line_len), do: nil

  defp calculate_selection_range(_sel_start, nil, _line_index, _line_len),
    do: nil

  defp calculate_selection_range(sel_start, sel_end, line_index, line_len) do
    {{start_row, start_col}, {end_row, end_col}} = {sel_start, sel_end}
    min_row = min(start_row, end_row)
    max_row = max(start_row, end_row)

    if line_index < min_row or line_index > max_row do
      nil
    else
      {left, right} =
        calculate_selection_bounds(
          start_row,
          start_col,
          end_row,
          end_col,
          line_index,
          line_len
        )

      {min(max(left, 0), line_len), min(max(right, 0), line_len)}
    end
  end

  defp calculate_selection_bounds(
         start_row,
         start_col,
         end_row,
         end_col,
         line_index,
         line_len
       )

  defp calculate_selection_bounds(
         start_row,
         start_col,
         end_row,
         end_col,
         _line_index,
         _line_len
       )
       when start_row == end_row do
    {min(start_col, end_col), max(start_col, end_col)}
  end

  defp calculate_selection_bounds(
         start_row,
         start_col,
         _end_row,
         _end_col,
         line_index,
         line_len
       )
       when line_index == start_row do
    {start_col, line_len}
  end

  defp calculate_selection_bounds(
         _start_row,
         _start_col,
         end_row,
         end_col,
         line_index,
         _line_len
       )
       when line_index == end_row do
    {0, end_col}
  end

  defp calculate_selection_bounds(
         _start_row,
         _start_col,
         _end_row,
         _end_col,
         _line_index,
         line_len
       ) do
    {0, line_len}
  end

  defp create_segments(
         selection_range,
         cursor_on_this_line,
         line_content,
         text_style,
         cursor_style,
         safe_cursor_col,
         safe_slice,
         line_len
       )

  defp create_segments(
         selection_range,
         true,
         line_content,
         text_style,
         _cursor_style,
         _safe_cursor_col,
         _safe_slice,
         _line_len
       )
       when not is_nil(selection_range) do
    [{line_content, text_style}]
  end

  defp create_segments(
         selection_range,
         false,
         line_content,
         text_style,
         _cursor_style,
         _safe_cursor_col,
         _safe_slice,
         _line_len
       )
       when not is_nil(selection_range) do
    [{line_content, text_style}]
  end

  defp create_segments(
         nil,
         true,
         line_content,
         text_style,
         cursor_style,
         safe_cursor_col,
         safe_slice,
         line_len
       )
       when safe_cursor_col >= line_len do
    [{line_content, text_style}]
  end

  defp create_segments(
         nil,
         true,
         line_content,
         text_style,
         cursor_style,
         safe_cursor_col,
         safe_slice,
         line_len
       ) do
    before_cursor = safe_slice.(line_content, 0, safe_cursor_col)
    cursor_char = safe_slice.(line_content, safe_cursor_col, 1)

    after_cursor =
      safe_slice.(
        line_content,
        safe_cursor_col + 1,
        line_len - safe_cursor_col - 1
      )

    [
      {before_cursor, text_style},
      {cursor_char, cursor_style},
      {after_cursor, text_style}
    ]
  end

  defp create_segments(
         nil,
         false,
         line_content,
         text_style,
         _cursor_style,
         _safe_cursor_col,
         _safe_slice,
         _line_len
       ) do
    [{line_content, text_style}]
  end
end
