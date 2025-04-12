defmodule Raxol.Terminal.ANSI.TerminalStateTest do
  use ExUnit.Case
  alias Raxol.Terminal.ANSI.{TerminalState, CharacterSets, ScreenModes}

  describe "new/0" do
    test "creates a new empty terminal state stack" do
      stack = TerminalState.new()
      assert stack == []
      assert TerminalState.empty?(stack) == true
      assert TerminalState.count(stack) == 0
    end
  end

  describe "save_state/2" do
    test "saves terminal state to the stack" do
      stack = TerminalState.new()

      state = %{
        cursor: {10, 5},
        attributes: %{foreground: :red, background: :black},
        charset_state: CharacterSets.new(),
        mode_state: ScreenModes.new(),
        scroll_region: {5, 15}
      }

      stack = TerminalState.save_state(stack, state)
      assert TerminalState.empty?(stack) == false
      assert TerminalState.count(stack) == 1

      [saved_state | _] = stack
      assert saved_state.cursor == {10, 5}
      assert saved_state.attributes == %{foreground: :red, background: :black}
      assert saved_state.charset_state == CharacterSets.new()
      assert saved_state.mode_state == ScreenModes.new()
      assert saved_state.scroll_region == {5, 15}
    end

    test "saves multiple states to the stack" do
      stack = TerminalState.new()

      state1 = %{
        cursor: {10, 5},
        attributes: %{foreground: :red},
        charset_state: CharacterSets.new(),
        mode_state: ScreenModes.new(),
        scroll_region: {5, 15}
      }

      state2 = %{
        cursor: {20, 10},
        attributes: %{foreground: :blue},
        charset_state: CharacterSets.new(),
        mode_state: ScreenModes.new(),
        scroll_region: nil
      }

      stack = TerminalState.save_state(stack, state1)
      stack = TerminalState.save_state(stack, state2)
      assert TerminalState.count(stack) == 2

      [saved_state2, saved_state1 | _] = stack
      assert saved_state2.cursor == {20, 10}
      assert saved_state2.attributes == %{foreground: :blue}
      assert saved_state1.cursor == {10, 5}
      assert saved_state1.attributes == %{foreground: :red}
    end
  end

  describe "restore_state/1" do
    test "restores the most recently saved state" do
      stack = TerminalState.new()

      state = %{
        cursor: {10, 5},
        attributes: %{foreground: :red},
        charset_state: CharacterSets.new(),
        mode_state: ScreenModes.new(),
        scroll_region: {5, 15}
      }

      stack = TerminalState.save_state(stack, state)
      {stack, restored_state} = TerminalState.restore_state(stack)

      assert TerminalState.empty?(stack) == true
      assert restored_state.cursor == {10, 5}
      assert restored_state.attributes == %{foreground: :red}
      assert restored_state.scroll_region == {5, 15}
    end

    test "returns nil when restoring from an empty stack" do
      stack = TerminalState.new()
      {stack, restored_state} = TerminalState.restore_state(stack)

      assert stack == []
      assert restored_state == nil
    end

    test "restores states in LIFO order" do
      stack = TerminalState.new()

      state1 = %{
        cursor: {10, 5},
        attributes: %{foreground: :red},
        charset_state: CharacterSets.new(),
        mode_state: ScreenModes.new(),
        scroll_region: {5, 15}
      }

      state2 = %{
        cursor: {20, 10},
        attributes: %{foreground: :blue},
        charset_state: CharacterSets.new(),
        mode_state: ScreenModes.new(),
        scroll_region: nil
      }

      stack = TerminalState.save_state(stack, state1)
      stack = TerminalState.save_state(stack, state2)

      {stack, restored_state2} = TerminalState.restore_state(stack)
      assert restored_state2.cursor == {20, 10}
      assert restored_state2.attributes == %{foreground: :blue}

      {stack, restored_state1} = TerminalState.restore_state(stack)
      assert restored_state1.cursor == {10, 5}
      assert restored_state1.attributes == %{foreground: :red}

      assert TerminalState.empty?(stack) == true
    end
  end

  describe "clear_state/1" do
    test "clears the terminal state stack" do
      stack = TerminalState.new()

      state = %{
        cursor: {10, 5},
        attributes: %{foreground: :red},
        charset_state: CharacterSets.new(),
        mode_state: ScreenModes.new(),
        scroll_region: {5, 15}
      }

      stack = TerminalState.save_state(stack, state)
      assert TerminalState.empty?(stack) == false

      stack = TerminalState.clear_state(stack)
      assert TerminalState.empty?(stack) == true
      assert TerminalState.count(stack) == 0
    end
  end

  describe "get_state_stack/1" do
    test "returns the current terminal state stack" do
      stack = TerminalState.new()

      state = %{
        cursor: {10, 5},
        attributes: %{foreground: :red},
        charset_state: CharacterSets.new(),
        mode_state: ScreenModes.new(),
        scroll_region: {5, 15}
      }

      stack = TerminalState.save_state(stack, state)
      retrieved_stack = TerminalState.get_state_stack(stack)

      assert retrieved_stack == stack
      assert length(retrieved_stack) == 1
    end
  end
end
