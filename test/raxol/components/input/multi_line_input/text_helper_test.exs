defmodule Raxol.UI.Components.Input.MultiLineInput.TextHelperTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Components.Input.MultiLineInput
  alias Raxol.UI.Components.Input.MultiLineInput.TextHelper

  # Helper to create initial state
  defp create_state(lines, cursor_pos) do
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
    test ~c"inserts a character at the cursor position" do
      # Cursor at end of "world"
      state = create_state(["hello", "world"], {1, 5})
      new_state = TextHelper.insert_char(state, ?!)

      assert new_state.lines == ["hello", "world!"]
      assert new_state.cursor_pos == {1, 6}
    end

    test ~c"inserts a character in the middle of a line" do
      # Cursor after 'e' in "hello"
      state = create_state(["hello", "world"], {0, 2})
      new_state = TextHelper.insert_char(state, ?x)

      assert new_state.lines == ["hexllo", "world"]
      assert new_state.cursor_pos == {0, 3}
    end

    test ~c"inserts a character at the beginning of a line" do
      # Cursor at start of "world"
      state = create_state(["hello", "world"], {1, 0})
      new_state = TextHelper.insert_char(state, ?>)

      assert new_state.lines == ["hello", ">world"]
      assert new_state.cursor_pos == {1, 1}
    end

    test ~c"inserts a newline character" do
      # Cursor in middle of "hello"
      state = create_state(["hello", "world"], {0, 3})
      # newline
      new_state = TextHelper.insert_char(state, 10)

      assert new_state.lines == ["hel", "lo", "world"]
      assert new_state.cursor_pos == {1, 0}
    end

    test ~c"inserts a string instead of a character" do
      # Cursor at end of "hello"
      state = create_state(["hello", "world"], {0, 5})
      new_state = TextHelper.insert_char(state, " there")

      assert new_state.lines == ["hello there", "world"]
      assert new_state.cursor_pos == {0, 11}
    end

    test ~c"handles invalid input gracefully" do
      # Cursor at end of "hello"
      state = create_state(["hello", "world"], {0, 5})
      new_state = TextHelper.insert_char(state, :invalid)

      # Should not change the state
      assert new_state.lines == ["hello", "world"]
      assert new_state.cursor_pos == {0, 5}
    end
  end

  describe "handle_backspace_no_selection/1" do
    test ~c"deletes character before cursor" do
      # Cursor after 'l' in "hello"
      state = create_state(["hello", "world"], {0, 3})
      new_state = TextHelper.handle_backspace_no_selection(state)

      assert new_state.lines == ["helo", "world"]
      assert new_state.cursor_pos == {0, 2}
    end

    test ~c"joins lines when deleting at the beginning of a line" do
      # Cursor at start of "world"
      state = create_state(["hello", "world"], {1, 0})
      new_state = TextHelper.handle_backspace_no_selection(state)

      assert new_state.lines == ["helloworld"]
      # Cursor moves to end of the joined line
      assert new_state.cursor_pos == {0, 5}
    end

    test ~c"does nothing at the beginning of the document" do
      # Cursor at start of document
      state = create_state(["hello", "world"], {0, 0})
      new_state = TextHelper.handle_backspace_no_selection(state)

      assert new_state.lines == ["hello", "world"]
      assert new_state.cursor_pos == {0, 0}
    end

    test ~c"deletes newline when at start of line" do
      # Cursor at start of second line
      state = create_state(["hello", "world"], {1, 0})
      new_state = TextHelper.handle_backspace_no_selection(state)

      assert new_state.lines == ["helloworld"]
      assert new_state.cursor_pos == {0, 5}
    end
  end

  describe "handle_delete_no_selection/1" do
    test ~c"deletes character at cursor" do
      # Cursor before 'l' in "hello"
      state = create_state(["hello", "world"], {0, 2})
      new_state = TextHelper.handle_delete_no_selection(state)

      assert new_state.lines == ["helo", "world"]
      # Cursor stays
      assert new_state.cursor_pos == {0, 2}
    end

    test ~c"joins lines when deleting at the end of a line" do
      # Cursor at end of "hello"
      state = create_state(["hello", "world"], {0, 5})
      new_state = TextHelper.handle_delete_no_selection(state)

      assert new_state.lines == ["helloworld"]
      # Cursor stays
      assert new_state.cursor_pos == {0, 5}
    end

    test ~c"does nothing at the end of the document" do
      # Cursor at end of document
      state = create_state(["hello", "world"], {1, 5})
      new_state = TextHelper.handle_delete_no_selection(state)

      assert new_state.lines == ["hello", "world"]
      assert new_state.cursor_pos == {1, 5}
    end

    test ~c"deletes newline when at end of line" do
      # Cursor at end of first line
      state = create_state(["hello", "world"], {0, 5})
      new_state = TextHelper.handle_delete_no_selection(state)

      assert new_state.lines == ["helloworld"]
      assert new_state.cursor_pos == {0, 5}
    end

    test ~c"handles out of bounds row gracefully" do
      # Cursor at invalid row
      state = create_state(["hello", "world"], {5, 0})
      new_state = TextHelper.handle_delete_no_selection(state)

      # Should return unchanged state
      assert new_state.lines == ["hello", "world"]
      assert new_state.cursor_pos == {5, 0}
    end
  end

  describe "delete_selection/1" do
    test ~c"deletes selected text" do
      # Select "ell" in "hello"
      state = create_state(["hello", "world"], {0, 3})
      state = %{state | selection_start: {0, 1}, selection_end: {0, 4}}

      {new_state, deleted_text} = TextHelper.delete_selection(state)

      assert new_state.lines == ["ho", "world"]
      assert deleted_text == "ell"
      assert new_state.cursor_pos == {0, 1}
      assert new_state.selection_start == nil
      assert new_state.selection_end == nil
    end

    test ~c"deletes multi-line selection" do
      # Select from "ell" in "hello" to "or" in "world"
      state = create_state(["hello", "world"], {0, 3})
      state = %{state | selection_start: {0, 1}, selection_end: {1, 2}}

      {new_state, deleted_text} = TextHelper.delete_selection(state)

      assert new_state.lines == ["ho", "ld"]
      assert deleted_text == "ell\nwo"
      assert new_state.cursor_pos == {0, 1}
    end

    test ~c"handles invalid selection gracefully" do
      # Invalid selection (only start, no end)
      state = create_state(["hello", "world"], {0, 3})
      state = %{state | selection_start: {0, 1}, selection_end: nil}

      {new_state, deleted_text} = TextHelper.delete_selection(state)

      # Should return unchanged state and empty deleted text
      assert new_state.lines == ["hello", "world"]
      assert deleted_text == ""
    end

    test ~c"handles reversed selection" do
      # Selection end before start
      state = create_state(["hello", "world"], {0, 3})
      state = %{state | selection_start: {0, 4}, selection_end: {0, 1}}

      {new_state, deleted_text} = TextHelper.delete_selection(state)

      assert new_state.lines == ["ho", "world"]
      assert deleted_text == "ell"
      assert new_state.cursor_pos == {0, 1}
    end
  end

  describe "replace_text_range/4" do
    test ~c"replaces text within a line" do
      lines = ["hello", "world"]
      start_pos = {0, 1}
      end_pos = {0, 4}
      replacement = "ey"

      {new_text, replaced_text} =
        TextHelper.replace_text_range(lines, start_pos, end_pos, replacement)

      assert new_text == "hey\nworld"
      assert replaced_text == "ell"
    end

    test ~c"replaces text across multiple lines" do
      lines = ["hello", "world", "test"]
      start_pos = {0, 2}
      end_pos = {1, 3}
      replacement = "xyz"

      {new_text, replaced_text} =
        TextHelper.replace_text_range(lines, start_pos, end_pos, replacement)

      assert new_text == "hexyzld\ntest"
      assert replaced_text == "llo\nwo"
    end

    test ~c"inserts text at cursor position" do
      lines = ["hello", "world"]
      start_pos = {0, 3}
      # Same position for insertion
      end_pos = {0, 3}
      replacement = "xyz"

      {new_text, replaced_text} =
        TextHelper.replace_text_range(lines, start_pos, end_pos, replacement)

      assert new_text == "helxyzlo\nworld"
      assert replaced_text == ""
    end

    test ~c"handles out of bounds positions" do
      lines = ["hello", "world"]
      # Beyond line length
      start_pos = {0, 10}
      end_pos = {0, 15}
      replacement = "xyz"

      {new_text, replaced_text} =
        TextHelper.replace_text_range(lines, start_pos, end_pos, replacement)

      assert new_text == "hello\nworld"
      assert replaced_text == ""
    end

    test ~c"handles reversed positions" do
      lines = ["hello", "world"]
      start_pos = {0, 4}
      end_pos = {0, 1}
      replacement = "xyz"

      {new_text, replaced_text} =
        TextHelper.replace_text_range(lines, start_pos, end_pos, replacement)

      assert new_text == "hxyzo\nworld"
      assert replaced_text == "ell"
    end
  end

  describe "pos_to_index/2" do
    test ~c"converts position to index within a line" do
      lines = ["hello", "world"]
      pos = {0, 3}

      index = TextHelper.pos_to_index(lines, pos)

      assert index == 3
    end

    test ~c"converts position across multiple lines" do
      lines = ["hello", "world"]
      pos = {1, 2}

      index = TextHelper.pos_to_index(lines, pos)

      # "hello\nwo" = 5 + 1 + 2
      assert index == 8
    end

    test ~c"handles out of bounds row" do
      lines = ["hello", "world"]
      pos = {5, 0}

      index = TextHelper.pos_to_index(lines, pos)

      # Should clamp to last line
      assert index == 11
    end

    test ~c"handles out of bounds column" do
      lines = ["hello", "world"]
      pos = {0, 10}

      index = TextHelper.pos_to_index(lines, pos)

      # Should clamp to line length
      assert index == 5
    end

    test ~c"handles empty lines" do
      lines = ["", "world"]
      pos = {0, 0}

      index = TextHelper.pos_to_index(lines, pos)

      assert index == 0
    end
  end

  describe "split_into_lines/3" do
    test ~c"splits text with newlines" do
      text = "hello\nworld\ntest"
      width = 10
      wrap = :none

      lines = TextHelper.split_into_lines(text, width, wrap)

      assert lines == ["hello", "world", "test"]
    end

    test ~c"handles empty text" do
      text = ""
      width = 10
      wrap = :none

      lines = TextHelper.split_into_lines(text, width, wrap)

      assert lines == [""]
    end

    test ~c"wraps text by character" do
      text = "hello world"
      width = 5
      wrap = :char

      lines = TextHelper.split_into_lines(text, width, wrap)

      assert lines == ["hello", " worl", "d"]
    end

    test ~c"wraps text by word" do
      text = "hello world test"
      width = 8
      wrap = :word

      lines = TextHelper.split_into_lines(text, width, wrap)

      assert lines == ["hello", "world", "test"]
    end
  end

  describe "calculate_new_position/3" do
    test ~c"calculates position for single line insertion" do
      row = 0
      col = 3
      inserted_text = "xyz"

      {new_row, new_col} =
        TextHelper.calculate_new_position(row, col, inserted_text)

      assert new_row == 0
      assert new_col == 6
    end

    test ~c"calculates position for multi-line insertion" do
      row = 0
      col = 3
      inserted_text = "x\ny\nz"

      {new_row, new_col} =
        TextHelper.calculate_new_position(row, col, inserted_text)

      assert new_row == 2
      assert new_col == 1
    end

    test ~c"handles empty insertion" do
      row = 0
      col = 3
      inserted_text = ""

      {new_row, new_col} =
        TextHelper.calculate_new_position(row, col, inserted_text)

      assert new_row == 0
      assert new_col == 3
    end
  end

  describe "clamp/3" do
    test ~c"clamps value within range" do
      assert TextHelper.clamp(5, 0, 10) == 5
      assert TextHelper.clamp(-1, 0, 10) == 0
      assert TextHelper.clamp(15, 0, 10) == 10
    end

    test ~c"handles edge cases" do
      assert TextHelper.clamp(0, 0, 10) == 0
      assert TextHelper.clamp(10, 0, 10) == 10
    end
  end
end
