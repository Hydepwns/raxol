defmodule Raxol.UI.Components.Input.MultiLineInput.TextHelperTest do
  use ExUnit.Case, async: true

  alias Raxol.Components.Input.MultiLineInput
  alias Raxol.Components.Input.MultiLineInput.TextHelper

  # Helper to create initial state
  defp create_state(lines \\ [""], cursor_pos \\ {0, 0}) do
    # Create a default struct first
    default_state = %MultiLineInput{}
    # Then override the necessary fields for the test
    %MultiLineInput{
      default_state # Use default state as base
      | lines: lines,
        cursor_pos: cursor_pos,
        id: "test_input", # Set a consistent ID for tests
        # Explicitly initialize history as its default is nil
        history: Raxol.Terminal.Commands.History.new(10)
        # Other fields will use their defaults from defstruct
    }
  end

  describe "insert_char/2" do
    test "inserts a character at the cursor position" do
      state = create_state(["hello", "world"], {1, 5}) # Cursor at end of "world"
      new_state = TextHelper.insert_char(state, ?! )

      assert new_state.lines == ["hello", "world!"]
      assert new_state.cursor_pos == {1, 6}
    end

    test "inserts a character in the middle of a line" do
      state = create_state(["hello", "world"], {0, 2}) # Cursor after 'e' in "hello"
      new_state = TextHelper.insert_char(state, ?x)

      assert new_state.lines == ["hexllo", "world"]
      assert new_state.cursor_pos == {0, 3}
    end

    test "inserts a character at the beginning of a line" do
      state = create_state(["hello", "world"], {1, 0}) # Cursor at start of "world"
      new_state = TextHelper.insert_char(state, ?>)

      assert new_state.lines == ["hello", ">world"]
      assert new_state.cursor_pos == {1, 1}
    end
  end

  describe "handle_backspace_no_selection/1" do
    test "deletes character before cursor" do
      state = create_state(["hello", "world"], {0, 3}) # Cursor after 'l' in "hello"
      new_state = TextHelper.handle_backspace_no_selection(state)

      assert new_state.lines == ["helo", "world"]
      assert new_state.cursor_pos == {0, 2}
    end

    test "joins lines when deleting at the beginning of a line" do
      state = create_state(["hello", "world"], {1, 0}) # Cursor at start of "world"
      new_state = TextHelper.handle_backspace_no_selection(state)

      assert new_state.lines == ["helloworld"]
      assert new_state.cursor_pos == {0, 5} # Cursor moves to end of the joined line
    end

    test "does nothing at the beginning of the document" do
      state = create_state(["hello", "world"], {0, 0}) # Cursor at start of document
      new_state = TextHelper.handle_backspace_no_selection(state)

      assert new_state.lines == ["hello", "world"]
      assert new_state.cursor_pos == {0, 0}
    end
  end

  describe "handle_delete_no_selection/1" do
    test "deletes character at cursor" do
      state = create_state(["hello", "world"], {0, 2}) # Cursor before 'l' in "hello"
      new_state = TextHelper.handle_delete_no_selection(state)

      assert new_state.lines == ["helo", "world"]
      assert new_state.cursor_pos == {0, 2} # Cursor stays
    end

    test "joins lines when deleting at the end of a line" do
      state = create_state(["hello", "world"], {0, 5}) # Cursor at end of "hello"
      new_state = TextHelper.handle_delete_no_selection(state)

      assert new_state.lines == ["helloworld"]
      assert new_state.cursor_pos == {0, 5} # Cursor stays
    end

    test "does nothing at the end of the document" do
      state = create_state(["hello", "world"], {1, 5}) # Cursor at end of document
      new_state = TextHelper.handle_delete_no_selection(state)

      assert new_state.lines == ["hello", "world"]
      assert new_state.cursor_pos == {1, 5}
    end
  end

  # TODO: Add tests for other TextHelper functions (e.g., word deletion, line manipulation)
end
