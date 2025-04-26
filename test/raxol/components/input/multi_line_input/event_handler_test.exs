defmodule Raxol.UI.Components.Input.MultiLineInput.EventHandlerTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Components.Input.MultiLineInput.{State, EventHandler, TextHelper, NavigationHelper}
  alias Raxol.Event

  # Helper to create a minimal state for testing
  defp create_state(lines, cursor \ {0, 0}, selection \ nil) do
    sel_start = if selection, do: elem(selection, 0), else: nil
    sel_end = if selection, do: elem(selection, 1), else: nil

    %State{
      lines: lines,
      cursor_pos: cursor,
      scroll_offset: {0, 0},
      dimensions: {10, 5},
      selection_start: sel_start,
      selection_end: sel_end,
      history: Raxol.History.new(),
      clipboard: nil,
      id: "test_mle"
    }
  end

  describe "handle_event/2" do
    # --- Character Input ---
    test "handles character input event" do
      state = create_state(["hello"], {0, 2})
      event = %Event.KeyDown{key: "a"}
      {:noreply, new_state, _cmd} = EventHandler.handle_event(event, state)

      assert new_state.lines == ["heallo"]
      assert new_state.cursor_pos == {0, 3}
    end

    test "handles newline event" do
      state = create_state(["hello"], {0, 2})
      event = %Event.KeyDown{key: :enter}
      {:noreply, new_state, _cmd} = EventHandler.handle_event(event, state)

      assert new_state.lines == ["he", "llo"]
      assert new_state.cursor_pos == {1, 0}
    end

    # --- Deletion ---
    test "handles backspace event" do
      state = create_state(["hello"], {0, 3})
      event = %Event.KeyDown{key: :backspace}
      {:noreply, new_state, _cmd} = EventHandler.handle_event(event, state)

      assert new_state.lines == ["helo"]
      assert new_state.cursor_pos == {0, 2}
    end

    test "handles delete event" do
      state = create_state(["hello"], {0, 2})
      event = %Event.KeyDown{key: :delete}
      {:noreply, new_state, _cmd} = EventHandler.handle_event(event, state)

      assert new_state.lines == ["helo"]
      assert new_state.cursor_pos == {0, 2}
    end

    # --- Basic Navigation ---
    test "handles arrow left event" do
      state = create_state(["hello"], {0, 3})
      event = %Event.KeyDown{key: :left}
      {:noreply, new_state, _cmd} = EventHandler.handle_event(event, state)

      assert new_state.cursor_pos == {0, 2}
    end

    test "handles arrow right event" do
      state = create_state(["hello"], {0, 3})
      event = %Event.KeyDown{key: :right}
      {:noreply, new_state, _cmd} = EventHandler.handle_event(event, state)

      assert new_state.cursor_pos == {0, 4}
    end

     test "handles arrow up event" do
      state = create_state(["line1", "line2"], {1, 3})
      event = %Event.KeyDown{key: :up}
      {:noreply, new_state, _cmd} = EventHandler.handle_event(event, state)

      assert new_state.cursor_pos == {0, 3}
    end

    test "handles arrow down event" do
      state = create_state(["line1", "line2"], {0, 3})
      event = %Event.KeyDown{key: :down}
      {:noreply, new_state, _cmd} = EventHandler.handle_event(event, state)

      assert new_state.cursor_pos == {1, 3}
    end

    # --- Advanced Navigation ---
    test "handles home event" do
      state = create_state(["hello"], {0, 4})
      event = %Event.KeyDown{key: :home}
      {:noreply, new_state, _cmd} = EventHandler.handle_event(event, state)

      assert new_state.cursor_pos == {0, 0}
    end

    test "handles end event" do
      state = create_state(["hello"], {0, 1})
      event = %Event.KeyDown{key: :end}
      {:noreply, new_state, _cmd} = EventHandler.handle_event(event, state)

      assert new_state.cursor_pos == {0, 5}
    end

     test "handles pageup event" do
      state = create_state(Enum.map(0..10, &"line #{&1}"), {10, 3})
      event = %Event.KeyDown{key: :pageup}
      {:noreply, new_state, _cmd} = EventHandler.handle_event(event, state)

      # Assumes default dimensions height of 5
      assert new_state.cursor_pos == {5, 3}
    end

    test "handles pagedown event" do
      state = create_state(Enum.map(0..10, &"line #{&1}"), {1, 3})
      event = %Event.KeyDown{key: :pagedown}
      {:noreply, new_state, _cmd} = EventHandler.handle_event(event, state)

      # Assumes default dimensions height of 5
      assert new_state.cursor_pos == {6, 3}
    end

    # --- Selection Handling (Basic - just clears selection on basic move) ---
    test "clears selection when moving cursor normally" do
       state = create_state(["hello"], {0, 3}, {{0, 1}, {0, 4}})
       event = %Event.KeyDown{key: :left}
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
      event = %Event.KeyDown{key: :f1}
      {:noreply, new_state, _cmd} = EventHandler.handle_event(event, state)

      assert new_state == state # State should be unchanged
    end

    test "ignores non-keydown events" do
      state = create_state(["hello"], {0, 1})
      event = %Event.MouseClick{x: 1, y: 1, button: :left}
       {:noreply, new_state, _cmd} = EventHandler.handle_event(event, state)
      # Note: Current implementation *does* handle mouse events. Update test if needed.
      # For now, assuming it passes through if not specifically handled by keys
      assert new_state == state # Assuming no mouse logic implemented yet
    end

    # TODO: Add tests for mouse events (click to move cursor, drag to select)

  end
end
