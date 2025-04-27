defmodule Raxol.Components.Input.MultiLineInput.RenderHelper do
  @moduledoc """
  Helper functions for rendering lines, cursors, and selections in MultiLineInput.
  """

  # alias Raxol.Components.Input.MultiLineInput # May need state struct definition
  alias Raxol.Components.Input.MultiLineInput.NavigationHelper # Need normalize_selection
  require Logger
  require Raxol.View.Elements # Add require for macros

  def render_line(line_index, line, state) do
    line_number_text =
      if state.style.line_numbers do
        line_no_str = Integer.to_string(line_index + 1)
        padding = String.pad_leading(line_no_str, 3)
        # Use label macro
        line_number_text = Raxol.View.Elements.label(content: padding <> " ", style: [color: state.style.line_number_color])
      else
        nil # No line number element if disabled
      end

    # Render based on focus and selection state
    line_content_element =
      cond do
        state.focused and state.selection_start != nil and state.selection_end != nil and
            NavigationHelper.is_line_in_selection?(line_index, state.selection_start, state.selection_end) ->
          # Selection rendering logic (needs state as arg)
          render_line_with_selection(line_index, line, state)

        state.focused and line_index == state.cursor_row ->
          # Line with cursor rendering logic
          render_line_with_cursor(line, state)

        true ->
          # Normal line rendering
          # Use label macro
          Raxol.View.Elements.label(content: line, style: [color: state.style.text_color])
      end

    elements = if state.style.line_numbers do
      [line_number_text, line_content_element] |> Enum.reject(&is_nil/1)
    else
      [line_content_element]
    end

    Raxol.View.Elements.row [] do
      elements
    end
  end

  def render_line_with_cursor(line, state) do
    before_cursor = String.slice(line, 0, state.cursor_col)
    after_cursor = String.slice(line, state.cursor_col, String.length(line))

    padding = String.pad_leading(Integer.to_string(state.cursor_row + 1), 3)
    # Use label macro
    line_num_element = Raxol.View.Elements.label(content: padding <> " ", style: [color: state.style.line_number_color])
    # Use label macro
    before_element = Raxol.View.Elements.label(content: before_cursor, style: state.style)
    # Use label macro
    cursor_element = Raxol.View.Elements.label(content: "│", style: state.style.cursor)
    # Use label macro
    after_element = Raxol.View.Elements.label(content: after_cursor, style: state.style)

    [
      line_num_element,
      before_element,
      cursor_element,
      after_element
    ]
  end

  def render_line_with_selection(line_index, line, state) do
    # Use normalized selection
    {start_pos, end_pos} = NavigationHelper.normalize_selection(state)
    {start_row, start_col} = start_pos
    {end_row, end_col} = end_pos

    cond do
      line_index == start_row and line_index == end_row ->
        # Selection within single line
        before_selection = String.slice(line, 0, start_col)
        selected = String.slice(line, start_col, end_col - start_col)
        after_selection = String.slice(line, end_col, String.length(line))

        padding = String.pad_leading(Integer.to_string(line_index + 1), 3)
        # Use label macro
        line_num_element = Raxol.View.Elements.label(content: padding <> " ", style: [color: state.style.line_number_color])

        [
          line_num_element,
          Raxol.View.Elements.label(content: before_selection, style: [color: state.style.text_color]),
          Raxol.View.Elements.label(content: selected, style: [color: state.style.text_color, background: state.style.selection_color]),
          Raxol.View.Elements.label(content: after_selection, style: [color: state.style.text_color])
        ]

      line_index == start_row ->
        # First line of selection
        before_selection = String.slice(line, 0, start_col)
        selected = String.slice(line, start_col, String.length(line))

        padding = String.pad_leading(Integer.to_string(line_index + 1), 3)
        # Use label macro
        line_num_element = Raxol.View.Elements.label(content: padding <> " ", style: [color: state.style.line_number_color])

        [
          line_num_element,
          Raxol.View.Elements.label(content: before_selection, style: [color: state.style.text_color]),
          Raxol.View.Elements.label(content: selected, style: [color: state.style.text_color, background: state.style.selection_color])
        ]

      line_index == end_row ->
        # Last line of selection
        selected = String.slice(line, 0, end_col)
        after_selection = String.slice(line, end_col, String.length(line))

        padding = String.pad_leading(Integer.to_string(line_index + 1), 3)
        # Use label macro
        line_num_element = Raxol.View.Elements.label(content: padding <> " ", style: [color: state.style.line_number_color])

        [
          line_num_element,
          Raxol.View.Elements.label(content: selected, style: [color: state.style.text_color, background: state.style.selection_color]),
          Raxol.View.Elements.label(content: after_selection, style: [color: state.style.text_color])
        ]

      true -> # Middle line of selection (between start_row and end_row)
        padding = String.pad_leading(Integer.to_string(line_index + 1), 3)
        # Use label macro
        line_num_element = Raxol.View.Elements.label(content: padding <> " ", style: [color: state.style.line_number_color])

        # Entire line is selected
        [
          line_num_element,
          Raxol.View.Elements.label(content: line, style: [color: state.style.text_color, background: state.style.selection_color])
        ]
    end
  end

end
