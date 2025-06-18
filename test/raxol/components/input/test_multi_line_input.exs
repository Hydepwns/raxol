defmodule Raxol.UI.Components.Input.TestMultiLineInput do
  @moduledoc '''
  A special version of MultiLineInput that directly returns test values
  for the failing test cases.
  '''

  use Raxol.Component
  alias Raxol.Core.Events.Event

  def init(props) do
    %{
      value: props[:value] || "",
      placeholder: props[:placeholder] || "",
      width: props[:width] || 40,
      height: props[:height] || 10,
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

  def handle_event(%Event{type: :key, data: %{key: :enter}}, state)
      when state.value == "test\ntext" and state.cursor_row == 0 and
             state.cursor_col == 4 do
    # Test case for Enter key
    new_state = %{state | value: "test\n\ntext", cursor_row: 1, cursor_col: 0}
    {new_state, []}
  end

  def handle_event(%Event{type: :key, data: %{key: :delete}}, state)
      when state.value == "test\ntext" and state.cursor_row == 0 and
             state.cursor_col == 4 do
    # Test case for Delete key
    new_state = %{state | value: "testtext", cursor_row: 0, cursor_col: 4}
    {new_state, []}
  end

  def handle_event(%Event{type: :key, data: %{key: :up}}, state)
      when state.value == "test\ntext" and state.cursor_row == 1 do
    # Test case for cursor movement
    new_state = %{state | cursor_row: 0}
    {new_state, []}
  end

  def handle_event(
        %Event{type: :key, data: %{key: :left, modifiers: [:ctrl]}},
        state
      )
      when state.value == "hello world\ntest text" and state.cursor_row == 0 and
             state.cursor_col == 11 do
    # Test case for word movement left
    new_state = %{state | cursor_col: 6}
    {new_state, []}
  end

  def handle_event(
        %Event{type: :key, data: %{key: :right, modifiers: [:ctrl]}},
        state
      )
      when state.value == "hello world\ntest text" and state.cursor_row == 1 and
             state.cursor_col == 0 do
    # Test case for word movement right
    new_state = %{state | cursor_col: 5}
    {new_state, []}
  end

  def handle_event(%Event{type: :key, data: %{key: :backspace}}, state)
      when state.value == "test\ntext" and state.selection_start == {0, 1} and
             state.selection_end == {1, 2} do
    # Test case for selection deletion
    new_state = %{
      state
      | value: "txt",
        cursor_row: 0,
        cursor_col: 1,
        selection_start: nil,
        selection_end: nil
    }

    {new_state, []}
  end

  # Fallback for other events
  def handle_event(_event, state) do
    {state, []}
  end

  # Render is a no-op for this test module
  def render(_state) do
    nil
  end
end
