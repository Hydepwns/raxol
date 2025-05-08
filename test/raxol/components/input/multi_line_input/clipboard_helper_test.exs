defmodule Raxol.UI.Components.Input.MultiLineInput.ClipboardHelperTest do
  use ExUnit.Case, async: true

  alias Raxol.Components.Input.MultiLineInput
  alias Raxol.Components.Input.MultiLineInput.ClipboardHelper
  alias Raxol.Components.Input.MultiLineInput.TextHelper
  alias Raxol.Core.Runtime.Command

  # Helper to create initial state
  defp create_state(value \\ "", cursor_pos \\ {0, 0}, selection \\ nil) do
    # Use the main MultiLineInput module struct
    sel_start = if selection, do: elem(selection, 0), else: nil
    sel_end = if selection, do: elem(selection, 1), else: nil

    # Calculate lines from value (assuming default width/wrap for simplicity)
    # Might need adjustment if tests rely on specific wrapping
    # Use default width/wrap
    lines = TextHelper.split_into_lines(value, 40, :word)

    %MultiLineInput{
      # Primarily use value
      value: value,
      # Keep lines cache updated
      lines: lines,
      cursor_pos: cursor_pos,
      selection_start: sel_start,
      selection_end: sel_end,
      id: "test_input",
      # Provide defaults for calculation
      width: 40,
      height: 10,
      wrap: :word,
      scroll_offset: {0, 0},
      # Assuming history not needed for clipboard tests
      history: nil
    }
  end

  describe "copy_selection/1" do
    test "returns state and :clipboard_write command with selected text" do
      # Select "ell" in "hello"
      state = create_state("hello\nworld", {0, 4}, {{0, 1}, {0, 4}})
      {new_state, commands} = ClipboardHelper.copy_selection(state)

      # State shouldn't change on copy
      assert new_state == state
      expected_cmd = Command.clipboard_write("ell")
      assert commands == [expected_cmd]
    end

    test "returns state and :clipboard_write command with selected text across lines" do
      # Select "llo\nwo"
      state = create_state("hello\nworld", {1, 2}, {{0, 2}, {1, 2}})
      {new_state, commands} = ClipboardHelper.copy_selection(state)

      assert new_state == state
      expected_cmd = Command.clipboard_write("llo\nwo")
      assert commands == [expected_cmd]
    end

    test "returns original state and empty command list if no selection" do
      state = create_state("hello", {0, 1})
      {new_state, commands} = ClipboardHelper.copy_selection(state)
      assert new_state == state
      assert commands == []
    end

    test "handles reversed selection" do
      # Reversed selection
      state = create_state("hello\nworld", {0, 0}, {{1, 2}, {0, 2}})
      {new_state, commands} = ClipboardHelper.copy_selection(state)
      assert new_state == state
      expected_cmd = Command.clipboard_write("llo\nwo")
      assert commands == [expected_cmd]
    end
  end

  describe "cut_selection/1" do
    test "returns state with deleted text and :clipboard_write command" do
      # Select "ell" in "hello"
      state = create_state("hello\nworld", {0, 4}, {{0, 1}, {0, 4}})
      {new_state, commands} = ClipboardHelper.cut_selection(state)

      # Text should be deleted
      assert new_state.value == "ho\nworld"
      # Cursor should move to start of deleted selection
      assert new_state.cursor_pos == {0, 1}
      # Selection should be cleared
      assert new_state.selection_start == nil
      # Clipboard command should be issued
      expected_cmd = Command.clipboard_write("ell")
      assert commands == [expected_cmd]
    end

    test "cuts text across lines" do
      # Select "llo\nwo"
      state = create_state("hello\nworld", {1, 2}, {{0, 2}, {1, 2}})
      {new_state, commands} = ClipboardHelper.cut_selection(state)

      assert new_state.value == "herld"
      assert new_state.cursor_pos == {0, 2}
      assert new_state.selection_start == nil
      expected_cmd = Command.clipboard_write("llo\nwo")
      assert commands == [expected_cmd]
    end

    test "returns original state and empty command list if no selection" do
      state = create_state("hello", {0, 1})
      {new_state, commands} = ClipboardHelper.cut_selection(state)
      assert new_state == state
      assert commands == []
    end
  end

  # Renamed from paste_clipboard
  describe "paste/1" do
    test "returns state and :clipboard_read command" do
      state = create_state("hello", {0, 2})
      # Call paste/1
      {new_state, commands} = ClipboardHelper.paste(state)
      # State doesn't change yet
      assert new_state == state
      expected_cmd = Command.clipboard_read()
      assert commands == [expected_cmd]
    end
  end
end
