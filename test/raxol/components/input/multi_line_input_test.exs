defmodule Raxol.Components.Input.MultiLineInputTest do
  use ExUnit.Case
  alias Raxol.Components.Input.MultiLineInput
  alias Raxol.Core.Events.Event

  describe "init/1" do
    test "initializes with default values when no props provided" do
      state = MultiLineInput.init(%{})
      assert state.value == ""
      assert state.placeholder == ""
      assert state.width == 40
      assert state.height == 10
      assert state.wrap == :word
      assert state.cursor_row == 0
      assert state.cursor_col == 0
      assert state.scroll_offset == 0
      assert state.selection_start == nil
      assert state.selection_end == nil
      assert state.focused == false
      assert state.on_change == nil
    end

    test "initializes with provided values" do
      on_change = fn _ -> nil end

      props = %{
        value: "test\ntext",
        placeholder: "Enter text",
        width: 30,
        height: 5,
        style: %{text_color: :red},
        wrap: :char,
        on_change: on_change
      }

      state = MultiLineInput.init(props)
      assert state.value == "test\ntext"
      assert state.placeholder == "Enter text"
      assert state.width == 30
      assert state.height == 5
      assert state.wrap == :char
      assert state.style.text_color == :red
      assert state.on_change == on_change
    end
  end

  describe "update/2" do
    setup do
      {:ok, state: MultiLineInput.init(%{value: "test\ntext"})}
    end

    test "sets value and resets cursor", %{state: state} do
      new_state = MultiLineInput.update({:set_value, "new\nvalue"}, state)
      assert new_state.value == "new\nvalue"
      assert new_state.cursor_row == 0
      assert new_state.cursor_col == 0
      assert new_state.scroll_offset == 0
      assert new_state.selection_start == nil
      assert new_state.selection_end == nil
    end

    test "moves cursor within bounds", %{state: state} do
      new_state = MultiLineInput.update({:move_cursor, 1, 2}, state)
      assert new_state.cursor_row == 1
      assert new_state.cursor_col == 2

      new_state = MultiLineInput.update({:move_cursor, -1, 0}, state)
      assert new_state.cursor_row == 0
      assert new_state.cursor_col == 0

      new_state = MultiLineInput.update({:move_cursor, 100, 100}, state)
      assert new_state.cursor_row == 1
      assert new_state.cursor_col == 4
    end

    test "sets selection", %{state: state} do
      new_state = MultiLineInput.update({:select, 0, 1, 1, 2}, state)
      assert new_state.selection_start == {0, 1}
      assert new_state.selection_end == {1, 2}
      assert new_state.cursor_row == 1
      assert new_state.cursor_col == 2
    end

    test "handles scrolling", %{state: state} do
      # Set up state with scroll offset
      state = %{state | scroll_offset: 5}

      # Scroll up
      new_state = MultiLineInput.update(:scroll_up, state)
      assert new_state.scroll_offset == 4

      # Scroll down
      new_state = MultiLineInput.update(:scroll_down, state)
      assert new_state.scroll_offset == 5
    end

    test "handles focus and blur", %{state: state} do
      new_state = MultiLineInput.update(:focus, state)
      assert new_state.focused == true

      new_state = MultiLineInput.update(:blur, new_state)
      assert new_state.focused == false
    end
  end

  describe "handle_event/2" do
    setup do
      state = MultiLineInput.init(%{value: "test\ntext"})
      {:ok, state: %{state | focused: true}}
    end

    test "handles character input", %{state: state} do
      event = %Event{type: :key, key: "a"}
      {new_state, _} = MultiLineInput.handle_event(event, state)
      assert new_state.value == "testa\ntext"
      assert new_state.cursor_col == 5
    end

    test "handles Enter key", %{state: state} do
      event = %Event{type: :key, key: "Enter"}
      {new_state, _} = MultiLineInput.handle_event(event, state)
      assert new_state.value == "test\n\ntext"
      assert new_state.cursor_row == 1
      assert new_state.cursor_col == 0
    end

    test "handles backspace", %{state: state} do
      event = %Event{type: :key, key: "Backspace"}

      {new_state, _} =
        MultiLineInput.handle_event(event, %{
          state
          | cursor_row: 1,
            cursor_col: 0
        })

      assert new_state.value == "testtext"
      assert new_state.cursor_row == 0
      assert new_state.cursor_col == 4
    end

    test "handles delete", %{state: state} do
      event = %Event{type: :key, key: "Delete"}

      {new_state, _} =
        MultiLineInput.handle_event(event, %{
          state
          | cursor_row: 0,
            cursor_col: 4
        })

      assert new_state.value == "testtext"
      assert new_state.cursor_row == 0
      assert new_state.cursor_col == 4
    end

    test "handles cursor movement", %{state: state} do
      # Up
      event = %Event{type: :key, key: "Up"}

      {new_state, _} =
        MultiLineInput.handle_event(event, %{state | cursor_row: 1})

      assert new_state.cursor_row == 0

      # Down
      event = %Event{type: :key, key: "Down"}
      {new_state, _} = MultiLineInput.handle_event(event, state)
      assert new_state.cursor_row == 1

      # Left at line start
      event = %Event{type: :key, key: "Left"}

      {new_state, _} =
        MultiLineInput.handle_event(event, %{
          state
          | cursor_row: 1,
            cursor_col: 0
        })

      assert new_state.cursor_row == 0
      assert new_state.cursor_col == 4

      # Right at line end
      event = %Event{type: :key, key: "Right"}

      {new_state, _} =
        MultiLineInput.handle_event(event, %{
          state
          | cursor_row: 0,
            cursor_col: 4
        })

      assert new_state.cursor_row == 1
      assert new_state.cursor_col == 0
    end

    test "handles word movement", %{state: state} do
      state = %{state | value: "hello world\ntest text"}

      # Left by word
      event = %Event{type: :key, key: "Left", ctrl?: true}

      {new_state, _} =
        MultiLineInput.handle_event(event, %{
          state
          | cursor_row: 0,
            cursor_col: 11
        })

      assert new_state.cursor_col == 6

      # Right by word
      event = %Event{type: :key, key: "Right", ctrl?: true}

      {new_state, _} =
        MultiLineInput.handle_event(event, %{
          state
          | cursor_row: 1,
            cursor_col: 0
        })

      assert new_state.cursor_col == 4
    end

    test "handles selection deletion", %{state: state} do
      state = %{state | selection_start: {0, 1}, selection_end: {1, 2}}

      event = %Event{type: :key, key: "Backspace"}
      {new_state, _} = MultiLineInput.handle_event(event, state)
      assert new_state.value == "txt"
      assert new_state.cursor_row == 0
      assert new_state.cursor_col == 1
      assert new_state.selection_start == nil
      assert new_state.selection_end == nil
    end

    test "calls on_change when text changes", %{state: state} do
      test_pid = self()

      state = %{
        state
        | on_change: fn value -> send(test_pid, {:changed, value}) end
      }

      event = %Event{type: :key, key: "a"}
      MultiLineInput.handle_event(event, state)

      assert_received {:changed, "testa\ntext"}
    end
  end

  describe "line wrapping" do
    test "wraps text by character" do
      state =
        MultiLineInput.init(%{
          value: "This is a long line of text",
          width: 10,
          wrap: :char
        })

      lines =
        state.value
        |> String.split("\n")
        |> Enum.flat_map(&MultiLineInput.wrap_line_by_char(&1, state.width))

      assert length(lines) == 3
      assert Enum.at(lines, 0) == "This is a "
      assert Enum.at(lines, 1) == "long line "
      assert Enum.at(lines, 2) == "of text"
    end

    test "wraps text by word" do
      state =
        MultiLineInput.init(%{
          value: "This is a long line of text",
          width: 10,
          wrap: :word
        })

      lines =
        state.value
        |> String.split("\n")
        |> Enum.flat_map(&MultiLineInput.wrap_line_by_word(&1, state.width))

      assert length(lines) == 4
      assert Enum.at(lines, 0) == "This is a"
      assert Enum.at(lines, 1) == "long line"
      assert Enum.at(lines, 2) == "of text"
    end
  end
end
