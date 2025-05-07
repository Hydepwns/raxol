defmodule Raxol.Components.Input.MultiLineInput.RenderHelper do
  @moduledoc """
  Helper functions for rendering lines, cursors, and selections in MultiLineInput.
  """

  # alias Raxol.Components.Input.MultiLineInput # May need state struct definition
  alias Raxol.Components.Input.MultiLineInput.NavigationHelper # Need normalize_selection
  require Logger
  require Raxol.View.Elements # Add require for macros

  @doc """
  Renders the multi-line input component with proper styling based on the state.
  Returns a grid of cell data for the visible portion of text.

  ## Parameters
  - state: The MultiLineInput state
  - context: The render context
  - theme: The theme containing style information
  """
  def render(state, _context, theme) do
    # Calculate visible range based on scroll offset and height
    {scroll_row, _scroll_col} = state.scroll_offset
    visible_range_end = min(scroll_row + state.height - 1, max(0, length(state.lines) - 1))
    visible_rows = scroll_row..visible_range_end

    # Map the rows to grid cells with proper styling
    cells =
      for row <- visible_rows, col <- 0..(state.width - 1), into: %{} do
        # Default styling from theme
        default_style = theme.components[:multi_line_input] || %{
          text_color: state.style.text_color || :white,
          selection_color: state.style.selection_color || :blue,
          cursor_color: state.style.cursor_color || :white
        }

        pos = {row, col}
        cell_content = get_cell_content(state, row, col)
        cell_style = get_cell_style(state, row, col, default_style)

        {pos, %{content: cell_content, style: cell_style}}
      end

    cells
  end

  # Get the character at the specified position or empty string if outside text bounds
  defp get_cell_content(state, row, col) do
    if row < length(state.lines) do
      line = Enum.at(state.lines, row)
      if col < String.length(line) do
        String.at(line, col)
      else
        " " # Empty space beyond text
      end
    else
      " " # Empty space beyond text
    end
  end

  # Determine the appropriate style for the cell based on selection and cursor state
  defp get_cell_style(state, row, col, default_style) do
    cursor_pos = state.cursor_pos

    cond do
      # Cell has cursor - highest priority
      state.focused && cursor_pos == {row, col} ->
        %{
          foreground: default_style.text_color,
          background: default_style.cursor_color
        }

      # Cell is in selection range
      state.focused && state.selection_start != nil && state.selection_end != nil &&
      is_position_in_selection?(state, row, col) ->
        %{
          foreground: default_style.text_color,
          background: default_style.selection_color
        }

      # Regular text styling
      true ->
        %{foreground: default_style.text_color}
    end
  end

  # Check if a position is within the current selection range
  defp is_position_in_selection?(state, row, col) do
    if state.selection_start != nil && state.selection_end != nil do
      {start_pos, end_pos} = NavigationHelper.normalize_selection(state)
      {start_row, start_col} = start_pos
      {end_row, end_col} = end_pos

      cond do
        # Single line selection
        start_row == end_row && row == start_row ->
          col >= start_col && col < end_col

        # First line of multi-line selection
        row == start_row ->
          col >= start_col

        # Last line of multi-line selection
        row == end_row ->
          col < end_col

        # Complete line in middle of selection
        row > start_row && row < end_row ->
          true

        # Not in selection
        true ->
          false
      end
    else
      false
    end
  end

  def render_line(line_index, line, state) do
    line_number_text =
      if state.style.line_numbers do
        # Assuming state.style.line_number_padding >= 0
        padding = String.duplicate(" ", state.style.line_number_padding)
        Raxol.View.Elements.label(content: padding <> " ", style: [color: state.style.line_number_color])
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
