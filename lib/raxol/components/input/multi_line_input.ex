defmodule Raxol.Components.Input.MultiLineInput do
  @moduledoc """
  A multi-line input component with line wrapping, vertical scrolling, and text manipulation.

  ## Props
    * `:value` - Current text value (default: "")
    * `:placeholder` - Placeholder text when empty (default: "")
    * `:width` - Width of the input field (default: 40)
    * `:height` - Height of the input field (default: 10)
    * `:style` - Style map for customizing appearance
      * `:text_color` - Color of the text (default: :white)
      * `:placeholder_color` - Color of placeholder text (default: :gray)
      * `:selection_color` - Color of selected text (default: :blue)
      * `:cursor_color` - Color of the cursor (default: :white)
      * `:line_numbers` - Whether to show line numbers (default: false)
      * `:line_number_color` - Color of line numbers (default: :gray)
    * `:wrap` - Line wrapping mode (default: :word)
      * `:none` - No wrapping
      * `:char` - Wrap at character boundaries
      * `:word` - Wrap at word boundaries
    * `:on_change` - Function called when text changes
  """

  use Raxol.Component
  alias Raxol.View.Components
  alias Raxol.View.Layout
  alias Raxol.Core.Events.Event

  @default_width 40
  @default_height 10
  @default_style %{
    text_color: :white,
    placeholder_color: :gray,
    selection_color: :blue,
    cursor_color: :white,
    line_numbers: false,
    line_number_color: :gray
  }

  @impl true
  def init(props) do
    %{
      value: props[:value] || "",
      placeholder: props[:placeholder] || "",
      width: props[:width] || @default_width,
      height: props[:height] || @default_height,
      style: Map.merge(@default_style, props[:style] || %{}),
      wrap: props[:wrap] || :word,
      cursor_row: 0,
      cursor_col: 0,
      scroll_offset: 0,
      selection_start: nil,
      selection_end: nil,
      focused: false,
      on_change: props[:on_change]
    }
  end

  @impl true
  def update({:set_value, value}, state) do
    _lines = split_into_lines(value, state.width, state.wrap)

    %{
      state
      | value: value,
        cursor_row: 0,
        cursor_col: 0,
        scroll_offset: 0,
        selection_start: nil,
        selection_end: nil
    }
  end

  def update({:move_cursor, row, col}, state) do
    lines = split_into_lines(state.value, state.width, state.wrap)
    max_row = length(lines) - 1

    max_col =
      if row >= 0 and row <= max_row,
        do: String.length(Enum.at(lines, row)),
        else: 0

    new_row = clamp(row, 0, max_row)
    new_col = clamp(col, 0, max_col)

    # Adjust scroll if cursor would be outside visible area
    new_scroll = adjust_scroll(new_row, state.scroll_offset, state.height)

    %{
      state
      | cursor_row: new_row,
        cursor_col: new_col,
        scroll_offset: new_scroll,
        selection_start: nil,
        selection_end: nil
    }
  end

  def update({:select, start_row, start_col, end_row, end_col}, state) do
    lines = split_into_lines(state.value, state.width, state.wrap)
    max_row = length(lines) - 1

    start_row = clamp(start_row, 0, max_row)
    end_row = clamp(end_row, 0, max_row)

    start_col = clamp(start_col, 0, String.length(Enum.at(lines, start_row)))
    end_col = clamp(end_col, 0, String.length(Enum.at(lines, end_row)))

    %{
      state
      | selection_start: {start_row, start_col},
        selection_end: {end_row, end_col},
        cursor_row: end_row,
        cursor_col: end_col
    }
  end

  def update(:scroll_up, state) do
    new_scroll = max(0, state.scroll_offset - 1)
    %{state | scroll_offset: new_scroll}
  end

  def update(:scroll_down, state) do
    lines = split_into_lines(state.value, state.width, state.wrap)
    max_scroll = max(0, length(lines) - state.height)
    new_scroll = min(max_scroll, state.scroll_offset + 1)
    %{state | scroll_offset: new_scroll}
  end

  def update(:focus, state), do: %{state | focused: true}
  def update(:blur, state), do: %{state | focused: false}
  def update(_msg, state), do: state

  @impl true
  def render(state) do
    dsl_result =
      if state.value == "" and not state.focused do
        render_placeholder(state)
      else
        render_content(state)
      end

    # Convert the DSL map structure to the expected Element struct
    Raxol.View.to_element(dsl_result)
  end

  defp render_placeholder(state) do
    Components.text(
      content: state.placeholder,
      color: state.style.placeholder_color
    )
  end

  defp render_content(state) do
    lines = split_into_lines(state.value, state.width, state.wrap)
    visible_lines = Enum.slice(lines, state.scroll_offset, state.height)

    line_number_width =
      if state.style.line_numbers do
        String.length(Integer.to_string(length(lines)))
      else
        0
      end

    Layout.column do
      for {line, index} <- Enum.with_index(visible_lines) do
        row_index = index + state.scroll_offset

        row do
          if state.style.line_numbers do
            Components.text(
              content:
                String.pad_leading(
                  Integer.to_string(row_index + 1),
                  line_number_width
                ),
              color: state.style.line_number_color
            )

            Components.text(content: " ")
          end

          render_line(line, row_index, state)
        end
      end
    end
  end

  defp render_line(line, row_index, state) do
    cond do
      has_selection?(state) and line_in_selection?(row_index, state) ->
        render_line_with_selection(line, row_index, state)

      row_index == state.cursor_row and state.focused ->
        render_line_with_cursor(line, state)

      true ->
        Components.text(content: line, color: state.style.text_color)
    end
  end

  defp render_line_with_cursor(line, state) do
    before_cursor = String.slice(line, 0, state.cursor_col)
    after_cursor = String.slice(line, state.cursor_col, String.length(line))

    [
      Components.text(content: before_cursor, color: state.style.text_color),
      Components.text(content: "│", color: state.style.cursor_color),
      Components.text(content: after_cursor, color: state.style.text_color)
    ]
  end

  defp render_line_with_selection(line, row_index, state) do
    {start_row, start_col} = state.selection_start
    {end_row, end_col} = state.selection_end

    cond do
      row_index == start_row and row_index == end_row ->
        # Selection within single line
        before_selection = String.slice(line, 0, start_col)
        selected = String.slice(line, start_col, end_col - start_col)
        after_selection = String.slice(line, end_col, String.length(line))

        [
          Components.text(
            content: before_selection,
            color: state.style.text_color
          ),
          Components.text(
            content: selected,
            color: state.style.text_color,
            background: state.style.selection_color
          ),
          Components.text(
            content: after_selection,
            color: state.style.text_color
          )
        ]

      row_index == start_row ->
        # First line of selection
        before_selection = String.slice(line, 0, start_col)
        selected = String.slice(line, start_col, String.length(line))

        [
          Components.text(
            content: before_selection,
            color: state.style.text_color
          ),
          Components.text(
            content: selected,
            color: state.style.text_color,
            background: state.style.selection_color
          )
        ]

      row_index == end_row ->
        # Last line of selection
        selected = String.slice(line, 0, end_col)
        after_selection = String.slice(line, end_col, String.length(line))

        [
          Components.text(
            content: selected,
            color: state.style.text_color,
            background: state.style.selection_color
          ),
          Components.text(
            content: after_selection,
            color: state.style.text_color
          )
        ]

      true ->
        # Middle line of selection
        Components.text(
          content: line,
          color: state.style.text_color,
          background: state.style.selection_color
        )
    end
  end

  @impl true
  def handle_event(%Event{type: :key, data: data} = _event, state) do
    msg =
      case data do
        %{key: key} when is_binary(key) and byte_size(key) == 1 -> {:input, key}
        %{key: :enter} -> {:enter}
        %{key: :backspace} -> {:backspace}
        %{key: :delete} -> {:delete}
        %{key: :left} -> {:move_cursor, state.cursor_row, state.cursor_col - 1}
        %{key: :right} -> {:move_cursor, state.cursor_row, state.cursor_col + 1}
        %{key: :up} -> {:move_cursor, state.cursor_row - 1, state.cursor_col}
        %{key: :down} -> {:move_cursor, state.cursor_row + 1, state.cursor_col}
        _ -> nil
      end

    if msg do
      {update(msg, state), []}
    else
      {state, []}
    end
  end

  @impl true
  def handle_event(%Event{type: :click}, state) do
    {update(:focus, state), []}
  end

  @impl true
  def handle_event(%Event{type: :blur}, state) do
    {update(:blur, state), []}
  end

  @impl true
  def handle_event(%Event{type: :scroll, data: %{direction: :up}}, state) do
    {update(:scroll_up, state), []}
  end

  @impl true
  def handle_event(%Event{type: :scroll, data: %{direction: :down}}, state) do
    {update(:scroll_down, state), []}
  end

  # Helper functions
  defp clamp(value, min, max) do
    value |> max(min) |> min(max)
  end

  defp has_selection?(%{selection_start: start, selection_end: end_pos}) do
    start != nil and end_pos != nil and start != end_pos
  end

  defp line_in_selection?(row_index, %{
         selection_start: {start_row, _},
         selection_end: {end_row, _}
       }) do
    row_index >= min(start_row, end_row) and
      row_index <= max(start_row, end_row)
  end

  defp split_into_lines(text, width, wrap_mode) do
    lines = String.split(text, "\n")

    case wrap_mode do
      :none -> lines
      :char -> Enum.flat_map(lines, &wrap_line_by_char(&1, width))
      :word -> Enum.flat_map(lines, &wrap_line_by_word(&1, width))
    end
  end

  defp wrap_line_by_char(line, width) do
    line
    |> String.graphemes()
    |> Enum.chunk_every(width)
    |> Enum.map(&Enum.join/1)
  end

  defp wrap_line_by_word(line, width) do
    words = String.split(line, " ")
    do_wrap_words(words, width, [], "")
  end

  defp do_wrap_words([], _width, lines, current_line) do
    Enum.reverse([String.trim(current_line) | lines])
  end

  defp do_wrap_words([word | rest], width, lines, current_line) do
    new_line =
      if current_line == "", do: word, else: current_line <> " " <> word

    if String.length(new_line) <= width do
      do_wrap_words(rest, width, lines, new_line)
    else
      do_wrap_words(
        [word | rest],
        width,
        [String.trim(current_line) | lines],
        ""
      )
    end
  end

  defp adjust_scroll(cursor_row, scroll_offset, height) do
    cond do
      cursor_row < scroll_offset ->
        cursor_row

      cursor_row >= scroll_offset + height ->
        cursor_row - height + 1

      true ->
        scroll_offset
    end
  end
end
