defmodule Raxol.Components.Input.MultiLineInputTest do
  use ExUnit.Case
  alias Raxol.Components.Input.MultiLineInput
  alias Raxol.Core.Events.Event
  alias Raxol.Components.Input.TextWrapping

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
        value: "test\\ntext",
        placeholder: "Enter text",
        width: 30,
        height: 5,
        style: %{text_color: :red},
        wrap: :char,
        on_change: on_change
      }

      state = MultiLineInput.init(props)
      assert state.value == "test\\ntext"
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
      new_state = MultiLineInput.update({:set_value, "new\\nvalue"}, state)
      assert new_state.value == "new\\nvalue"
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
      assert new_state.scroll_offset == 0
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
      {:ok, state: %MultiLineInput{state | focused: true}}
    end

    test "handles character input", %{state: state} do
      # Set initial cursor position for the test using struct syntax
      state = %MultiLineInput{state | cursor_row: 0, cursor_col: 4}
      event = Event.key("a")
      {new_state, _} = MultiLineInput.handle_event(event, state)
      assert new_state.value == "testa\ntext"
      assert new_state.cursor_col == 5
    end

    test "handles Enter key", %{state: state} do
      event = Event.key("Enter")
      # Use struct syntax
      state = %MultiLineInput{state | cursor_row: 0, cursor_col: 4}
      {new_state, _} = MultiLineInput.handle_event(event, state)
      assert new_state.value == "test\n\ntext"
      assert new_state.cursor_row == 1
      assert new_state.cursor_col == 0
    end

    test "handles input (simplified)" do
      # Use the struct to get default values
      initial_state = %MultiLineInput{
        value: "abc\ndef",
        cursor_row: 0,
        # Cursor between a and b
        cursor_col: 1,
        # Use defaults from defstruct for other fields
        # width: 10, # Let it use default
        # height: 5, # Let it use default
        focused: true,
        # No callback for simplicity
        on_change: nil
        # id: "test_input" # Let it use default
        # Ensure all necessary fields from the struct are present or defaulted
      }

      # Input character 'X'
      event = Event.key("X")
      {new_state, _commands} = MultiLineInput.handle_event(event, initial_state)

      expected_state = %{
        initial_state
        | # Text updated
          value: "aXbc\ndef",
          cursor_row: 0,
          # Cursor moved after X
          cursor_col: 2
      }

      # Assert the relevant parts of the state changed correctly
      assert new_state.value == expected_state.value
      assert new_state.cursor_row == expected_state.cursor_row
      assert new_state.cursor_col == expected_state.cursor_col
      assert new_state.selection_start == nil
      assert new_state.selection_end == nil
    end

    test "handles delete", %{state: state} do
      event = Event.key("Delete")

      # Use struct syntax
      {new_state, _} =
        MultiLineInput.handle_event(event, %MultiLineInput{
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
      event = Event.key("Up")
      # Use struct syntax
      {new_state_up, _} =
        MultiLineInput.handle_event(event, %MultiLineInput{
          state
          | cursor_row: 1
        })

      assert new_state_up.cursor_row == 0

      # Down
      event = Event.key("Down")
      # Use original state (which is a struct)
      {new_state_down, _} = MultiLineInput.handle_event(event, state)
      assert new_state_down.cursor_row == 1

      # Left at line start
      event = Event.key("Left")
      # Use struct syntax
      {new_state_left, _} =
        MultiLineInput.handle_event(event, %MultiLineInput{
          state
          | cursor_row: 1,
            cursor_col: 0
        })

      assert new_state_left.cursor_row == 1
      assert new_state_left.cursor_col == 0

      # Right at line end
      event = Event.key("Right")
      # Use struct syntax
      {new_state_right, _} =
        MultiLineInput.handle_event(event, %MultiLineInput{
          state
          | cursor_row: 0,
            cursor_col: 4
        })

      assert new_state_right.cursor_row == 0
      assert new_state_right.cursor_col == 4
    end

    test "handles word movement", %{state: state} do
      # Use struct syntax
      state = %MultiLineInput{state | value: "hello world\ntest text"}

      # Left by word
      event = Event.key_event(:left, :pressed, [:ctrl])
      # Use struct syntax
      {new_state_left, _} =
        MultiLineInput.handle_event(event, %MultiLineInput{
          state
          | cursor_row: 0,
            cursor_col: 11
        })

      assert new_state_left.cursor_col == 6

      # Right by word
      event = Event.key_event(:right, :pressed, [:ctrl])
      # Use struct syntax
      {new_state_right, _} =
        MultiLineInput.handle_event(event, %MultiLineInput{
          state
          | cursor_row: 1,
            cursor_col: 0
        })

      assert new_state_right.cursor_col == 5
    end

    test "handles selection deletion", %{state: state} do
      # Use struct syntax
      state = %MultiLineInput{
        state
        | selection_start: {0, 1},
          selection_end: {1, 2},
          value: "test\ntext"
      }

      event = Event.key("Backspace")
      {new_state, _} = MultiLineInput.handle_event(event, state)
      # this MUST be "tt"
      assert new_state.value == "tt"
      assert new_state.cursor_row == 0
      assert new_state.cursor_col == 1
      assert new_state.selection_start == nil
      assert new_state.selection_end == nil
    end

    test "calls on_change when text changes", %{state: state} do
      test_pid = self()
      # Use struct syntax (already correct)
      state = %MultiLineInput{
        state
        | cursor_row: 0,
          cursor_col: 4,
          on_change: fn value -> send(test_pid, {:changed, value}) end
      }

      event = Event.key("a")
      MultiLineInput.handle_event(event, state)
      assert_received {:changed, "testa\ntext"}
    end
  end

  describe "update/2 direct call test" do
    test "update({:enter}, state) returns correct state directly" do
      initial_state = %MultiLineInput{
        value: "test\ntext",
        cursor_row: 0,
        cursor_col: 4,
        # Fill in other necessary fields from defstruct with defaults
        placeholder: "",
        width: 40,
        height: 10,
        style: %{
          text_color: :white,
          placeholder_color: :gray,
          selection_color: :blue,
          cursor_color: :white,
          line_numbers: false,
          line_number_color: :gray
        },
        wrap: :word,
        scroll_offset: 0,
        selection_start: nil,
        selection_end: nil,
        # Assume focused for update logic
        focused: true,
        # No callback for simplicity
        on_change: nil,
        id: nil
      }

      # Directly call update/2 for the :enter message
      new_state = MultiLineInput.update({:enter}, initial_state)

      # Assert the expected outcome
      assert new_state.value == "test\n\ntext"
      assert new_state.cursor_row == 1
      assert new_state.cursor_col == 0
    end
  end

  describe "update/2 direct call test for selection deletion" do
    test "update({:backspace}, state_with_selection) returns correct state" do
      initial_state = %MultiLineInput{
        value: "test\ntext",
        # Doesn't matter for deletion, but set for completeness
        cursor_row: 1,
        cursor_col: 2,
        selection_start: {0, 1},
        selection_end: {1, 2},
        # Fill in other necessary fields from defstruct with defaults
        placeholder: "",
        width: 40,
        height: 10,
        style: %{
          text_color: :white,
          placeholder_color: :gray,
          selection_color: :blue,
          cursor_color: :white,
          line_numbers: false,
          line_number_color: :gray
        },
        wrap: :word,
        scroll_offset: 0,
        # Assume focused for update logic
        focused: true,
        # No callback for simplicity
        on_change: nil,
        id: nil
      }

      # Directly call update/2 for the :backspace message
      new_state = MultiLineInput.update({:backspace}, initial_state)

      # MUST be "tt"
      assert new_state.value == "tt"
      # Start of deleted range
      assert new_state.cursor_row == 0
      # Start of deleted range
      assert new_state.cursor_col == 1
      assert new_state.selection_start == nil
      assert new_state.selection_end == nil
    end
  end

  describe "line wrapping" do
    test "wrap_line_by_char handles long word correctly (simpler)" do
      # 100 chars
      value = String.duplicate("0123456789", 10)
      width = 20
      lines = TextWrapping.wrap_line_by_char(value, width)
      expected_line = "01234567890123456789"

      assert length(lines) == 5
      assert Enum.all?(lines, &(&1 == expected_line))
    end

    test "wrap_line_by_char handles long word correctly" do
      value =
        "Lopadotemachoselachogaleokranioleipsanodrimhypotrimmatosilphioparaomelitokatakechymenokichlepikossyphophattoperisteralektryonoptekephalliokigklopeleiolagoiosiraiobaphetraganopterygon"

      width = 20

      # Inspect the input string and its graphemes
      IO.inspect(value, label: "Test Input String")
      IO.inspect(String.graphemes(value), label: "Input String Graphemes")
      IO.inspect(length(String.graphemes(value)), label: "Input Grapheme Count")

      lines = TextWrapping.wrap_line_by_char(value, width)

      assert length(lines) == 10
      assert Enum.at(lines, 0) == "Lopadotemachoselacho"
      assert Enum.at(lines, 1) == "galeokranioleipsanod"
      assert Enum.at(lines, 2) == "rimhypotrimmatosilphi"
      assert Enum.at(lines, 3) == "oparaomelitokatakec"
      assert Enum.at(lines, 4) == "hymenokichlepikossy"
      assert Enum.at(lines, 5) == "phophattoperisterale"
      assert Enum.at(lines, 6) == "ktryonoptekephallio"
      assert Enum.at(lines, 7) == "kigklopeleiolagoios"
      assert Enum.at(lines, 8) == "iraiobaphetraganopt"
      assert Enum.at(lines, 9) == "erygon"
    end

    test "wraps text by character" do
      value = "This is a long line of text"
      width = 10

      # Call the public function directly
      lines = TextWrapping.wrap_line_by_char(value, width)

      assert lines == ["This is a ", "long line ", "of text"]
      assert length(lines) == 3
    end

    test "wraps text by word" do
      value = "This is a long line of text"
      width = 10

      # Call the public function directly
      lines = TextWrapping.wrap_line_by_word(value, width)

      # Assert the expected output for word wrap
      assert lines == ["This is a", "long line", "of text"]
      assert length(lines) == 3
    end

    # @tag :skip # Temporarily skip word wrap test
    test "wraps text by word with long word" do
      value =
        "Lopadotemachoselachogaleokranioleipsanodrimhypotrimmatosilphioparaomelitokatakechymenokichlepikossyphophattoperisteralektryonoptekephalliokigklopeleiolagoiosiraiobaphetraganopterygon"

      width = 20
      lines = TextWrapping.wrap_line_by_word(value, width)
      # IO.inspect(lines, label: "Wrapped Lines") # Debug print removed

      assert length(lines) == 10
      assert Enum.at(lines, 0) == "Lopadotemachoselacho"
      assert Enum.at(lines, 1) == "galeokranioleipsanod"
      assert Enum.at(lines, 2) == "rimhypotrimmatosilphi"
      assert Enum.at(lines, 3) == "oparaomelitokatakec"
      assert Enum.at(lines, 4) == "hymenokichlepikossy"
      assert Enum.at(lines, 5) == "phophattoperisterale"
      assert Enum.at(lines, 6) == "ktryonoptekephallio"
      assert Enum.at(lines, 7) == "kigklopeleiolagoios"
      assert Enum.at(lines, 8) == "iraiobaphetraganopt"
      assert Enum.at(lines, 9) == "erygon"
    end

    test "wraps text by word basic" do
      value = "This is a long line of text"
      width = 10

      # Call the public function directly
      lines = TextWrapping.wrap_line_by_word(value, width)

      # Assert the expected output for word wrap
      assert lines == ["This is a", "long line", "of text"]
      assert length(lines) == 3
    end
  end
end
