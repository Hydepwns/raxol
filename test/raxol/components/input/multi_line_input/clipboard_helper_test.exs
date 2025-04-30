defmodule Raxol.UI.Components.Input.MultiLineInput.ClipboardHelperTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Components.Input.MultiLineInput.{State, ClipboardHelper, TextHelper, NavigationHelper}
  alias Raxol.Core.Runtime.Command
  alias Raxol.History

  # Helper to create a minimal state for testing
  defp create_state(lines, cursor = {0, 0}, selection = nil) do
    sel_start = if selection, do: elem(selection, 0), else: nil
    sel_end = if selection, do: elem(selection, 1), else: nil

    %State{
      lines: lines,
      cursor_pos: cursor,
      scroll_offset: {0, 0},
      dimensions: {10, 5},
      selection_start: sel_start,
      selection_end: sel_end,
      history: History.new(), # Use real history for testing potential interactions
      clipboard: nil, # Clipboard content comes via command result
      id: "test_mle",
      value: Enum.join(lines, "\n") # Needed by helpers
    }
  end

  describe "copy_selection/1" do
    test "returns :clipboard_write command with selected text" do
      # Select "ell" in "hello"
      state = create_state(["hello", "world"], {0, 4}, {{0, 1}, {0, 4}})
      {:noreply, ^state, cmd} = ClipboardHelper.copy_selection(state)

      expected_cmd = Command.clipboard_write("ell")
      assert cmd == expected_cmd
    end

     test "returns :clipboard_write command with selected text across lines" do
      # Select "llo\nwo"
      state = create_state(["hello", "world"], {1, 2}, {{0, 2}, {1, 2}})
      {:noreply, ^state, cmd} = ClipboardHelper.copy_selection(state)

      expected_cmd = Command.clipboard_write("llo\nwo")
      assert cmd == expected_cmd
    end

    test "returns no command if no selection" do
      state = create_state(["hello"], {0, 1})
      {:noreply, ^state, cmd} = ClipboardHelper.copy_selection(state)
      assert cmd == nil
    end

    test "handles reversed selection" do
      state = create_state(["hello", "world"], {0, 0}, {{1, 2}, {0, 2}}) # Reversed selection
      {:noreply, ^state, cmd} = ClipboardHelper.copy_selection(state)
      expected_cmd = Command.clipboard_write("llo\nwo")
      assert cmd == expected_cmd
    end
  end

  describe "cut_selection/1" do
    test "returns state with deleted text and :clipboard_write command" do
      # Select "ell" in "hello"
      state = create_state(["hello", "world"], {0, 4}, {{0, 1}, {0, 4}})
      {:noreply, new_state, cmd} = ClipboardHelper.cut_selection(state)

      # Text should be deleted
      assert new_state.lines == ["ho", "world"]
      # Cursor should move to start of deleted selection
      assert new_state.cursor_pos == {0, 1}
      # Selection should be cleared
      assert new_state.selection_start == nil
      # Clipboard command should be issued
      expected_cmd = Command.clipboard_write("ell")
      assert cmd == expected_cmd
    end

     test "cuts text across lines" do
      # Select "llo\nwo"
      state = create_state(["hello", "world"], {1, 2}, {{0, 2}, {1, 2}})
      {:noreply, new_state, cmd} = ClipboardHelper.cut_selection(state)

      assert new_state.lines == ["herld"]
      assert new_state.cursor_pos == {0, 2}
      assert new_state.selection_start == nil
      expected_cmd = Command.clipboard_write("llo\nwo")
      assert cmd == expected_cmd
    end

    test "returns original state and no command if no selection" do
      state = create_state(["hello"], {0, 1})
      {:noreply, new_state, cmd} = ClipboardHelper.cut_selection(state)
      assert new_state == state
      assert cmd == nil
    end
  end

  describe "paste_clipboard/1" do
    test "returns :clipboard_read command" do
      state = create_state(["hello"], {0, 2})
      {:noreply, ^state, cmd} = ClipboardHelper.paste_clipboard(state)
      expected_cmd = Command.clipboard_read()
      assert cmd == expected_cmd
    end
  end

  describe "handle_clipboard_content/2" do
    test "inserts clipboard text at cursor position" do
      state = create_state(["hello", "world"], {0, 2}) # Cursor in "hello"
      clipboard_content = "_inserted_"
      {:noreply, new_state, _cmd} = ClipboardHelper.handle_clipboard_content(clipboard_content, state)

      assert new_state.lines == ["he_inserted_llo", "world"]
      # Cursor moves to end of inserted text
      assert new_state.cursor_pos == {0, 2 + String.length(clipboard_content)}
    end

    test "replaces selection with clipboard text" do
      # Select "ell" in "hello"
      state = create_state(["hello", "world"], {0, 4}, {{0, 1}, {0, 4}})
      clipboard_content = "PASTE"
      {:noreply, new_state, _cmd} = ClipboardHelper.handle_clipboard_content(clipboard_content, state)

      assert new_state.lines == ["hPASTEo", "world"]
      # Cursor moves to end of pasted text
      assert new_state.cursor_pos == {0, 1 + String.length(clipboard_content)}
      # Selection is cleared
      assert new_state.selection_start == nil
    end

    test "inserts multi-line clipboard text" do
       state = create_state(["hello", "world"], {0, 5}) # Cursor at end of first line
       clipboard_content = " one\ntwo "
       {:noreply, new_state, _cmd} = ClipboardHelper.handle_clipboard_content(clipboard_content, state)

       assert new_state.lines == ["hello one", "two ", "world"]
       # Cursor moves to end of last inserted line
       assert new_state.cursor_pos == {1, 4} # End of "two "
    end

    test "replaces selection with multi-line clipboard text" do
      # Select "llo\nwo"
      state = create_state(["hello", "world"], {1, 2}, {{0, 2}, {1, 2}})
      clipboard_content = "REPLACED\nWITH\nTHIS"
      {:noreply, new_state, _cmd} = ClipboardHelper.handle_clipboard_content(clipboard_content, state)

      assert new_state.lines == ["heREPLACED", "WITH", "THISrld"]
      # Cursor moves to end of last inserted line
      assert new_state.cursor_pos == {2, 4} # End of "THIS"
    end

    test "does nothing if clipboard content is nil or empty" do
      state = create_state(["hello"], {0, 2})
      {:noreply, new_state_nil, _cmd} = ClipboardHelper.handle_clipboard_content(nil, state)
      {:noreply, new_state_empty, _cmd} = ClipboardHelper.handle_clipboard_content("", state)

      assert new_state_nil == state
      assert new_state_empty == state
    end
  end
end
