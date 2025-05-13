defmodule Raxol.UI.Components.Input.MultiLineInput.ClipboardHelperTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Components.Input.MultiLineInput
  alias Raxol.UI.Components.Input.MultiLineInput.ClipboardHelper
  alias Raxol.UI.Components.Input.MultiLineInput.TextHelper
  alias Raxol.Core.Runtime.Command
  import Raxol.Test.ClipboardHelpers

  describe "copy_selection/1" do
    test "returns state and :clipboard_write command with selected text" do
      # Select "ell" in "hello"
      state = create_state("hello\nworld", {0, 4}, {{0, 1}, {0, 4}})
      {new_state, commands} = ClipboardHelper.copy_selection(state)

      # State shouldn't change on copy
      assert new_state == state
      assert_clipboard_write(commands, "ell")
    end

    test "returns state and :clipboard_write command with selected text across lines" do
      # Select "llo\nwo"
      state = create_state("hello\nworld", {1, 2}, {{0, 2}, {1, 2}})
      {new_state, commands} = ClipboardHelper.copy_selection(state)

      assert new_state == state
      assert_clipboard_write(commands, "llo\nwo")
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
      assert_clipboard_write(commands, "llo\nwo")
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
      assert_clipboard_write(commands, "ell")
    end

    test "cuts text across lines" do
      # Select "llo\nwo"
      state = create_state("hello\nworld", {1, 2}, {{0, 2}, {1, 2}})
      {new_state, commands} = ClipboardHelper.cut_selection(state)

      assert new_state.value == "herld"
      assert new_state.cursor_pos == {0, 2}
      assert new_state.selection_start == nil
      assert_clipboard_write(commands, "llo\nwo")
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
      assert_clipboard_read(commands)
    end
  end
end
