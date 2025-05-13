defmodule Raxol.UI.Components.Input.MultiLineInput.RenderHelper do
  @moduledoc """
  Helper functions for rendering lines, cursors, and selections in MultiLineInput.
  """

  # alias Raxol.UI.Components.Input.MultiLineInput # May need state struct definition
  # Need normalize_selection
  alias Raxol.UI.Components.Input.MultiLineInput
  alias Raxol.UI.Components.Input.MultiLineInput.TextHelper
  alias Raxol.UI.Components.Input.MultiLineInput.NavigationHelper
  require Logger
  # Add require for macros
  require Raxol.View.Elements

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

    visible_range_end =
      min(scroll_row + state.height - 1, max(0, length(state.lines) - 1))

    visible_rows = scroll_row..visible_range_end

    # Extract style from theme
    default_style =
      theme.components[:multi_line_input] ||
        %{
          text_color: :white,
          selection_color: :blue,
          cursor_color: :white,
          line_number_color: :cyan,
          line_numbers: false,
          line_number_padding: 2
        }

    # Map the rows to grid cells with proper styling
    cells =
      for row <- visible_rows, col <- 0..(state.width - 1), into: %{} do
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
        # Empty space beyond text
        " "
      end
    else
      # Empty space beyond text
      " "
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
      state.focused && state.selection_start != nil &&
        state.selection_end != nil &&
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

  def render_line(line_index, line, state, theme) do
    default_style =
      theme.components[:multi_line_input] ||
        %{
          text_color: :white,
          selection_color: :blue,
          cursor_color: :white,
          line_number_color: :cyan,
          line_numbers: false,
          line_number_padding: 2
        }

    line_number_text =
      if default_style.line_numbers do
        padding = String.duplicate(" ", default_style.line_number_padding)

        Raxol.View.Elements.label(
          content: padding <> " ",
          style: [color: default_style.line_number_color]
        )
      else
        nil
      end

    {cursor_row, _cursor_col} = state.cursor_pos

    line_content_element =
      cond do
        state.focused and state.selection_start != nil and
          state.selection_end != nil and
            NavigationHelper.is_line_in_selection?(
              line_index,
              state.selection_start,
              state.selection_end
            ) ->
          render_line_with_selection(line_index, line, state, theme)

        state.focused and line_index == cursor_row ->
          render_line_with_cursor(line, state, theme)

        true ->
          Raxol.View.Elements.label(
            content: line,
            style: [color: default_style.text_color]
          )
      end

    elements =
      if default_style.line_numbers do
        [line_number_text, line_content_element] |> Enum.reject(&is_nil/1)
      else
        [line_content_element]
      end

    Raxol.View.Elements.row [] do
      elements
    end
  end

  def render_line_with_cursor(line, state, theme) do
    default_style =
      theme.components[:multi_line_input] ||
        %{
          text_color: :white,
          selection_color: :blue,
          cursor_color: :white,
          line_number_color: :cyan,
          line_numbers: false,
          line_number_padding: 2
        }

    before_cursor = String.slice(line, 0, state.cursor_col)
    after_cursor = String.slice(line, state.cursor_col, String.length(line))
    padding = String.pad_leading(Integer.to_string(state.cursor_row + 1), 3)

    line_num_element =
      Raxol.View.Elements.label(
        content: padding <> " ",
        style: [color: default_style.line_number_color]
      )

    before_element =
      Raxol.View.Elements.label(
        content: before_cursor,
        style: [color: default_style.text_color]
      )

    cursor_element =
      Raxol.View.Elements.label(
        content: "│",
        style: [color: default_style.cursor_color]
      )

    after_element =
      Raxol.View.Elements.label(
        content: after_cursor,
        style: [color: default_style.text_color]
      )

    [line_num_element, before_element, cursor_element, after_element]
  end

  def render_line_with_selection(line_index, line, state, theme) do
    default_style =
      theme.components[:multi_line_input] ||
        %{
          text_color: :white,
          selection_color: :blue,
          cursor_color: :white,
          line_number_color: :cyan,
          line_numbers: false,
          line_number_padding: 2
        }

    {start_pos, end_pos} = NavigationHelper.normalize_selection(state)
    {start_row, start_col} = start_pos
    {end_row, end_col} = end_pos

    cond do
      line_index == start_row and line_index == end_row ->
        before_selection = String.slice(line, 0, start_col)
        selected = String.slice(line, start_col, end_col - start_col)
        after_selection = String.slice(line, end_col, String.length(line))
        padding = String.pad_leading(Integer.to_string(line_index + 1), 3)

        line_num_element =
          Raxol.View.Elements.label(
            content: padding <> " ",
            style: [color: default_style.line_number_color]
          )

        [
          line_num_element,
          Raxol.View.Elements.label(
            content: before_selection,
            style: [color: default_style.text_color]
          ),
          Raxol.View.Elements.label(
            content: selected,
            style: [
              color: default_style.text_color,
              background: default_style.selection_color
            ]
          ),
          Raxol.View.Elements.label(
            content: after_selection,
            style: [color: default_style.text_color]
          )
        ]

      line_index == start_row ->
        before_selection = String.slice(line, 0, start_col)
        selected = String.slice(line, start_col, String.length(line))
        padding = String.pad_leading(Integer.to_string(line_index + 1), 3)

        line_num_element =
          Raxol.View.Elements.label(
            content: padding <> " ",
            style: [color: default_style.line_number_color]
          )

        [
          line_num_element,
          Raxol.View.Elements.label(
            content: before_selection,
            style: [color: default_style.text_color]
          ),
          Raxol.View.Elements.label(
            content: selected,
            style: [
              color: default_style.text_color,
              background: default_style.selection_color
            ]
          )
        ]

      line_index == end_row ->
        selected = String.slice(line, 0, end_col)
        after_selection = String.slice(line, end_col, String.length(line))
        padding = String.pad_leading(Integer.to_string(line_index + 1), 3)

        line_num_element =
          Raxol.View.Elements.label(
            content: padding <> " ",
            style: [color: default_style.line_number_color]
          )

        [
          line_num_element,
          Raxol.View.Elements.label(
            content: selected,
            style: [
              color: default_style.text_color,
              background: default_style.selection_color
            ]
          ),
          Raxol.View.Elements.label(
            content: after_selection,
            style: [color: default_style.text_color]
          )
        ]

      true ->
        padding = String.pad_leading(Integer.to_string(line_index + 1), 3)

        line_num_element =
          Raxol.View.Elements.label(
            content: padding <> " ",
            style: [color: default_style.line_number_color]
          )

        [
          line_num_element,
          Raxol.View.Elements.label(
            content: line,
            style: [
              color: default_style.text_color,
              background: default_style.selection_color
            ]
          )
        ]
    end
  end
end
