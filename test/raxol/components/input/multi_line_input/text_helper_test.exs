defmodule Raxol.UI.Components.Input.MultiLineInput.TextHelperTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Components.Input.MultiLineInput.State
  alias Raxol.UI.Components.Input.MultiLineInput.TextHelper

  # Helper to create a minimal state for testing
  defp create_state(lines, cursor \ {0, 0}) do
    %State{
      lines: lines,
      cursor_pos: cursor,
      scroll_offset: {0, 0},
      dimensions: {10, 5}, # Example dimensions
      selection_start: nil,
      history: Raxol.History.new(),
      clipboard: nil,
      id: "test_mle"
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

  describe "insert_newline/1" do
    test "inserts a newline and splits the current line" do
      state = create_state(["hello world"], {0, 5}) # Cursor after 'o' in "hello"
      new_state = TextHelper.insert_newline(state)

      assert new_state.lines == ["hello", " world"]
      assert new_state.cursor_pos == {1, 0}
    end

    test "inserts a newline at the end of a line" do
      state = create_state(["hello", "world"], {0, 5}) # Cursor at end of "hello"
      new_state = TextHelper.insert_newline(state)

      assert new_state.lines == ["hello", "", "world"]
      assert new_state.cursor_pos == {1, 0}
    end

     test "inserts a newline at the beginning of a line" do
      state = create_state(["hello", "world"], {1, 0}) # Cursor at start of "world"
      new_state = TextHelper.insert_newline(state)

      assert new_state.lines == ["hello", "", "world"]
      assert new_state.cursor_pos == {1, 0} # Cursor moves to the start of the new empty line
    end

    test "inserts a newline in an empty document" do
      state = create_state([""], {0, 0})
      new_state = TextHelper.insert_newline(state)

      assert new_state.lines == ["", ""]
      assert new_state.cursor_pos == {1, 0}
    end
  end

  describe "delete_backward/1" do
    test "deletes character before cursor" do
      state = create_state(["hello", "world"], {0, 3}) # Cursor after 'l' in "hello"
      new_state = TextHelper.delete_backward(state)

      assert new_state.lines == ["helo", "world"]
      assert new_state.cursor_pos == {0, 2}
    end

    test "joins lines when deleting at the beginning of a line" do
      state = create_state(["hello", "world"], {1, 0}) # Cursor at start of "world"
      new_state = TextHelper.delete_backward(state)

      assert new_state.lines == ["helloworld"]
      assert new_state.cursor_pos == {0, 5} # Cursor moves to end of the joined line
    end

    test "does nothing at the beginning of the document" do
      state = create_state(["hello", "world"], {0, 0}) # Cursor at start of document
      new_state = TextHelper.delete_backward(state)

      assert new_state.lines == ["hello", "world"]
      assert new_state.cursor_pos == {0, 0}
    end
  end

  describe "delete_forward/1" do
    test "deletes character at cursor" do
      state = create_state(["hello", "world"], {0, 2}) # Cursor before 'l' in "hello"
      new_state = TextHelper.delete_forward(state)

      assert new_state.lines == ["helo", "world"]
      assert new_state.cursor_pos == {0, 2} # Cursor stays
    end

    test "joins lines when deleting at the end of a line" do
      state = create_state(["hello", "world"], {0, 5}) # Cursor at end of "hello"
      new_state = TextHelper.delete_forward(state)

      assert new_state.lines == ["helloworld"]
      assert new_state.cursor_pos == {0, 5} # Cursor stays
    end

    test "does nothing at the end of the document" do
      state = create_state(["hello", "world"], {1, 5}) # Cursor at end of document
      new_state = TextHelper.delete_forward(state)

      assert new_state.lines == ["hello", "world"]
      assert new_state.cursor_pos == {1, 5}
    end
  end

  # TODO: Add tests for other TextHelper functions (e.g., word deletion, line manipulation)
end
