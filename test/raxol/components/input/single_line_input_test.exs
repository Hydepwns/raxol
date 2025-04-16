defmodule Raxol.Components.Input.SingleLineInputTest do
  use ExUnit.Case
  alias Raxol.Components.Input.SingleLineInput
  alias Raxol.Core.Events.Event

  describe "init/1" do
    test "initializes with default values when no props provided" do
      state = SingleLineInput.init(%{})
      assert state.value == ""
      assert state.placeholder == ""
      assert state.width == 20
      assert state.cursor_pos == 0
      assert state.selection_start == nil
      assert state.selection_end == nil
      assert state.focused == false
      assert state.on_change == nil
      assert state.on_submit == nil
    end

    test "initializes with provided values" do
      on_change = fn _ -> nil end
      on_submit = fn _ -> nil end

      props = %{
        value: "test",
        placeholder: "Enter text",
        width: 30,
        style: %{text_color: :red},
        on_change: on_change,
        on_submit: on_submit
      }

      state = SingleLineInput.init(props)
      assert state.value == "test"
      assert state.placeholder == "Enter text"
      assert state.width == 30
      assert state.cursor_pos == 4
      assert state.style.text_color == :red
      assert state.on_change == on_change
      assert state.on_submit == on_submit
    end
  end

  describe "update/2" do
    setup do
      {:ok, state: SingleLineInput.init(%{value: "test"})}
    end

    test "sets value and updates cursor position", %{state: state} do
      new_state = SingleLineInput.update({:set_value, "new value"}, state)
      assert new_state.value == "new value"
      assert new_state.cursor_pos == 9
      assert new_state.selection_start == nil
      assert new_state.selection_end == nil
    end

    test "moves cursor within bounds", %{state: state} do
      new_state = SingleLineInput.update({:move_cursor, 2}, state)
      assert new_state.cursor_pos == 2

      new_state = SingleLineInput.update({:move_cursor, -1}, state)
      assert new_state.cursor_pos == 0

      new_state = SingleLineInput.update({:move_cursor, 100}, state)
      assert new_state.cursor_pos == 4
    end

    test "sets selection", %{state: state} do
      new_state = SingleLineInput.update({:select, 1, 3}, state)
      assert new_state.selection_start == 1
      assert new_state.selection_end == 3
      assert new_state.cursor_pos == 3
    end

    test "handles focus and blur", %{state: state} do
      new_state = SingleLineInput.update(:focus, state)
      assert new_state.focused == true

      new_state = SingleLineInput.update(:blur, new_state)
      assert new_state.focused == false
    end
  end

  describe "handle_event/2" do
    setup do
      state = SingleLineInput.init(%{value: "test"})
      {:ok, state: %{state | focused: true}}
    end

    test "handles character input", %{state: state} do
      event = Event.key("a")
      {new_state, _} = SingleLineInput.handle_event(event, state)
      assert new_state.value == "testa"
      assert new_state.cursor_pos == 5
    end

    test "handles backspace", %{state: state} do
      event = Event.key("Backspace")
      {new_state, _} = SingleLineInput.handle_event(event, state)
      assert new_state.value == "tes"
      assert new_state.cursor_pos == 3
    end

    test "handles delete", %{state: state} do
      state = %{state | cursor_pos: 1}
      event = Event.key("Delete")
      {new_state, _} = SingleLineInput.handle_event(event, state)
      assert new_state.value == "tst"
      assert new_state.cursor_pos == 1
    end

    test "handles cursor movement", %{state: state} do
      # Left
      event = Event.key("Left")
      {new_state, _} = SingleLineInput.handle_event(event, state)
      assert new_state.cursor_pos == 3

      # Right
      event = Event.key("Right")
      {new_state, _} = SingleLineInput.handle_event(event, state)
      assert new_state.cursor_pos == 4

      # Home
      event = Event.key("Home")
      {new_state, _} = SingleLineInput.handle_event(event, state)
      assert new_state.cursor_pos == 0

      # End
      event = Event.key("End")
      {new_state, _} = SingleLineInput.handle_event(event, state)
      assert new_state.cursor_pos == 4
    end

    test "handles word movement", %{state: state} do
      state = %{state | value: "hello world"}

      # Left by word
      event = Event.key_event("Left", :pressed, [:ctrl])

      {new_state, _} =
        SingleLineInput.handle_event(event, %{state | cursor_pos: 8})

      assert new_state.cursor_pos == 6

      # Right by word
      event = Event.key_event("Right", :pressed, [:ctrl])

      {new_state, _} =
        SingleLineInput.handle_event(event, %{state | cursor_pos: 2})

      assert new_state.cursor_pos == 5
    end

    test "handles selection deletion", %{state: state} do
      state = %{state | selection_start: 1, selection_end: 3}
      event = Event.key("Backspace")
      {new_state, _} = SingleLineInput.handle_event(event, state)
      assert new_state.value == "tt"
      assert new_state.cursor_pos == 1
      assert new_state.selection_start == nil
      assert new_state.selection_end == nil
    end

    test "calls on_submit when Enter is pressed", %{state: state} do
      test_pid = self()

      state = %{
        state
        | on_submit: fn value -> send(test_pid, {:submitted, value}) end
      }

      event = Event.key("Enter")
      SingleLineInput.handle_event(event, state)

      assert_received {:submitted, "test"}
    end

    test "calls on_change when text changes", %{state: state} do
      test_pid = self()

      state = %{
        state
        | on_change: fn value -> send(test_pid, {:changed, value}) end
      }

      event = Event.key("a")
      SingleLineInput.handle_event(event, state)

      assert_received {:changed, "testa"}
    end
  end
end
