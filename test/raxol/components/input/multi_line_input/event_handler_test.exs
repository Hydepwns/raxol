defmodule Raxol.UI.Components.Input.MultiLineInput.EventHandlerTest do
  use ExUnit.Case, async: true

  alias Raxol.Components.Input.MultiLineInput
  alias Raxol.Components.Input.MultiLineInput.EventHandler
  alias Raxol.Core.Events.Event

  # Helper to create initial state
  defp create_state(lines \\ [""], cursor_pos \\ {0, 0}, selection \\ nil) do
    # Use the main MultiLineInput module struct
    sel_start = if selection, do: elem(selection, 0), else: nil
    sel_end = if selection, do: elem(selection, 1), else: nil
    %MultiLineInput{
      lines: lines,
      cursor_pos: cursor_pos,
      selection_start: sel_start, # Use correct fields
      selection_end: sel_end,
      id: "test_input",
      scroll_offset: {0, 0}
    }
  end

  describe "handle_event/2" do
    # --- Character Input ---
    test "handles character input event" do
      state = create_state(["abc"], {0, 3})
      # Use Event.key/1 helper to create the event struct
      event = Event.key("a")

      # Call handle_event directly on the helper module
      {:update, {:input, "a"}, _new_state} = EventHandler.handle_event(event, state)
    end

    test "handles newline event" do
      state = create_state(["hello", "world"], {0, 5}) # Cursor at end of first line
      # Use Event.key helper
      event = Event.key(:enter)

      {:update, {:enter}, _new_state} = EventHandler.handle_event(event, state)
    end

    # --- Deletion ---
    test "handles backspace event" do
      state = create_state(["hello"], {0, 3}) # Cursor after 'l' in "hello"
      # Use Event.key helper
      event = Event.key(:backspace)

      {:update, {:backspace}, _new_state} = EventHandler.handle_event(event, state)
    end

    test "handles delete event" do
      state = create_state(["hello"], {0, 2})
      # Use Event.key/1 helper
      event = Event.key(:delete)
      {:noreply, new_state, _cmd} = EventHandler.handle_event(event, state)

      assert new_state.lines == ["helo"]
      assert new_state.cursor_pos == {0, 2}
    end

    # --- Basic Navigation ---
    test "handles arrow left event" do
      state = create_state(["hello"], {0, 3})
      # Use Event.key/1 helper
      event = Event.key(:left)
      {:noreply, new_state, _cmd} = EventHandler.handle_event(event, state)

      assert new_state.cursor_pos == {0, 2}
    end

    test "handles arrow right event" do
      state = create_state(["hello"], {0, 3})
      # Use Event.key/1 helper
      event = Event.key(:right)
      {:noreply, new_state, _cmd} = EventHandler.handle_event(event, state)

      assert new_state.cursor_pos == {0, 4}
    end

     test "handles arrow up event" do
      state = create_state(["line1", "line2"], {1, 3})
      # Use Event.key/1 helper
      event = Event.key(:up)
      {:noreply, new_state, _cmd} = EventHandler.handle_event(event, state)

      assert new_state.cursor_pos == {0, 3}
    end

    test "handles arrow down event" do
      state = create_state(["line1", "line2"], {0, 3})
      # Use Event.key/1 helper
      event = Event.key(:down)
      {:noreply, new_state, _cmd} = EventHandler.handle_event(event, state)

      assert new_state.cursor_pos == {1, 3}
    end

    # --- Advanced Navigation ---
    test "handles home event" do
      state = create_state(["hello"], {0, 4})
      # Use Event.key/1 helper
      event = Event.key(:home)
      {:noreply, new_state, _cmd} = EventHandler.handle_event(event, state)

      assert new_state.cursor_pos == {0, 0}
    end

    test "handles end event" do
      state = create_state(["hello"], {0, 1})
      # Use Event.key/1 helper
      event = Event.key(:end)
      {:noreply, new_state, _cmd} = EventHandler.handle_event(event, state)

      assert new_state.cursor_pos == {0, 5}
    end

     test "handles pageup event" do
      state = create_state(Enum.map(0..10, &"line #{&1}"), {10, 3})
      # Use Event.key/1 helper
      event = Event.key(:pageup)
      {:noreply, new_state, _cmd} = EventHandler.handle_event(event, state)

      # Assumes default dimensions height of 5
      assert new_state.cursor_pos == {5, 3}
    end

    test "handles pagedown event" do
      state = create_state(Enum.map(0..10, &"line #{&1}"), {1, 3})
      # Use Event.key/1 helper
      event = Event.key(:pagedown)
      {:noreply, new_state, _cmd} = EventHandler.handle_event(event, state)

      # Assumes default dimensions height of 5
      assert new_state.cursor_pos == {6, 3}
    end

    # --- Selection Handling (Basic - just clears selection on basic move) ---
    test "clears selection when moving cursor normally" do
       state = create_state(["hello"], {0, 3}, {{0, 1}, {0, 4}})
       # Use Event.key/1 helper
       event = Event.key(:left)
       {:noreply, new_state, _cmd} = EventHandler.handle_event(event, state)

       assert new_state.cursor_pos == {0, 2}
       assert new_state.selection_start == nil
       assert new_state.selection_end == nil
    end

    # --- Selection with Shift ---
    # TODO: Test shift + arrow keys to extend selection
    # TODO: Test shift + home/end/pageup/pagedown
    # TODO: Test character input replaces selection
    # TODO: Test backspace/delete deletes selection

    # --- Clipboard ---
    # TODO: Test Ctrl+C (Copy)
    # TODO: Test Ctrl+X (Cut)
    # TODO: Test Ctrl+V (Paste)

    # --- Other Events ---
    test "ignores unknown keydown events" do
      state = create_state(["hello"], {0, 1})
      # Use Event.key/1 helper
      event = Event.key(:f1)
      {:noreply, new_state, _cmd} = EventHandler.handle_event(event, state)

      assert new_state == state # State should be unchanged
    end

    test "ignores non-keydown events" do
      state = create_state(["hello"], {0, 1})
      # Use Event.mouse/2 helper
      event = Event.mouse(:left, {1, 1})
       {:noreply, new_state, _cmd} = EventHandler.handle_event(event, state)
      # Note: Current implementation *does* handle mouse events. Update test if needed.
      # For now, assuming it passes through if not specifically handled by keys
      assert new_state == state # Assuming no mouse logic implemented yet
    end

    # TODO: Add tests for mouse events (click to move cursor, drag to select)

  end
end
