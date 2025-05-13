defmodule Raxol.UI.Components.Input.MultiLineInput.TextHelperTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Components.Input.MultiLineInput
  alias Raxol.UI.Components.Input.MultiLineInput.TextHelper

  # Helper to create initial state
  defp create_state(lines \\ [""], cursor_pos \\ {0, 0}) do
    # Create a default struct first
    default_state = %MultiLineInput{}
    # Then override the necessary fields for the test
    %MultiLineInput{
      default_state
      | # Use default state as base
        lines: lines,
        cursor_pos: cursor_pos,
        # Set a consistent ID for tests
        id: "test_input",
        # Explicitly initialize history as its default is nil
        history: Raxol.Terminal.Commands.History.new(10)
        # Other fields will use their defaults from defstruct
    }
  end

  describe "insert_char/2" do
    test "inserts a character at the cursor position" do
      # Cursor at end of "world"
      state = create_state(["hello", "world"], {1, 5})
      new_state = TextHelper.insert_char(state, ?!)

      assert new_state.lines == ["hello", "world!"]
      assert new_state.cursor_pos == {1, 6}
    end

    test "inserts a character in the middle of a line" do
      # Cursor after 'e' in "hello"
      state = create_state(["hello", "world"], {0, 2})
      new_state = TextHelper.insert_char(state, ?x)

      assert new_state.lines == ["hexllo", "world"]
      assert new_state.cursor_pos == {0, 3}
    end

    test "inserts a character at the beginning of a line" do
      # Cursor at start of "world"
      state = create_state(["hello", "world"], {1, 0})
      new_state = TextHelper.insert_char(state, ?>)

      assert new_state.lines == ["hello", ">world"]
      assert new_state.cursor_pos == {1, 1}
    end
  end

  describe "handle_backspace_no_selection/1" do
    test "deletes character before cursor" do
      # Cursor after 'l' in "hello"
      state = create_state(["hello", "world"], {0, 3})
      new_state = TextHelper.handle_backspace_no_selection(state)

      assert new_state.lines == ["helo", "world"]
      assert new_state.cursor_pos == {0, 2}
    end

    test "joins lines when deleting at the beginning of a line" do
      # Cursor at start of "world"
      state = create_state(["hello", "world"], {1, 0})
      new_state = TextHelper.handle_backspace_no_selection(state)

      assert new_state.lines == ["helloworld"]
      # Cursor moves to end of the joined line
      assert new_state.cursor_pos == {0, 5}
    end

    test "does nothing at the beginning of the document" do
      # Cursor at start of document
      state = create_state(["hello", "world"], {0, 0})
      new_state = TextHelper.handle_backspace_no_selection(state)

      assert new_state.lines == ["hello", "world"]
      assert new_state.cursor_pos == {0, 0}
    end
  end

  describe "handle_delete_no_selection/1" do
    test "deletes character at cursor" do
      # Cursor before 'l' in "hello"
      state = create_state(["hello", "world"], {0, 2})
      new_state = TextHelper.handle_delete_no_selection(state)

      assert new_state.lines == ["helo", "world"]
      # Cursor stays
      assert new_state.cursor_pos == {0, 2}
    end

    test "joins lines when deleting at the end of a line" do
      # Cursor at end of "hello"
      state = create_state(["hello", "world"], {0, 5})
      new_state = TextHelper.handle_delete_no_selection(state)

      assert new_state.lines == ["helloworld"]
      # Cursor stays
      assert new_state.cursor_pos == {0, 5}
    end

    test "does nothing at the end of the document" do
      # Cursor at end of document
      state = create_state(["hello", "world"], {1, 5})
      new_state = TextHelper.handle_delete_no_selection(state)

      assert new_state.lines == ["hello", "world"]
      assert new_state.cursor_pos == {1, 5}
    end
  end

  # TODO: Add tests for other TextHelper functions (e.g., word deletion, line manipulation)
end
