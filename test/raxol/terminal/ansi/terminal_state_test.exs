defmodule Raxol.Terminal.ANSI.TerminalStateTest do
  use ExUnit.Case
  alias Raxol.Terminal.ANSI.CharacterSets
  alias Raxol.Terminal.ANSI.ScreenModes
  alias Raxol.Terminal.ANSI.TerminalState
  alias Raxol.Terminal.ANSI.TextFormatting

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

      initial_style = TextFormatting.new() |> TextFormatting.set_foreground(:red) |> TextFormatting.set_background(:black)
      state = %{
        cursor: {10, 5},
        style: initial_style,
        charset_state: CharacterSets.new(),
        mode_state: ScreenModes.new(),
        scroll_region: {5, 15}
      }

      stack = TerminalState.save_state(stack, state)
      assert TerminalState.empty?(stack) == false
      assert TerminalState.count(stack) == 1

      [saved_state | _] = stack
      assert saved_state.cursor == {10, 5}
      assert saved_state.style == initial_style
      assert saved_state.charset_state == CharacterSets.new()
      assert saved_state.mode_state == ScreenModes.new()
      assert saved_state.scroll_region == {5, 15}
    end

    test "saves multiple states to the stack" do
      stack = TerminalState.new()

      style1 = TextFormatting.new() |> TextFormatting.set_foreground(:red)
      state1 = %{
        cursor: {10, 5},
        style: style1,
        charset_state: CharacterSets.new(),
        mode_state: ScreenModes.new(),
        scroll_region: {5, 15}
      }

      style2 = TextFormatting.new() |> TextFormatting.set_foreground(:blue)
      state2 = %{
        cursor: {20, 10},
        style: style2,
        charset_state: CharacterSets.new(),
        mode_state: ScreenModes.new(),
        scroll_region: nil
      }

      stack = TerminalState.save_state(stack, state1)
      stack = TerminalState.save_state(stack, state2)
      assert TerminalState.count(stack) == 2

      [saved_state2, saved_state1 | _] = stack
      assert saved_state2.cursor == {20, 10}
      assert saved_state2.style == style2
      assert saved_state1.cursor == {10, 5}
      assert saved_state1.style == style1
    end
  end

  describe "restore_state/1" do
    test "restores the most recently saved state" do
      stack = TerminalState.new()

      initial_style = TextFormatting.new() |> TextFormatting.set_foreground(:red)
      state = %{
        cursor: {10, 5},
        style: initial_style,
        charset_state: CharacterSets.new(),
        mode_state: ScreenModes.new(),
        scroll_region: {5, 15}
      }

      stack = TerminalState.save_state(stack, state)
      {stack, restored_state} = TerminalState.restore_state(stack)

      assert TerminalState.empty?(stack) == true
      assert restored_state.cursor == {10, 5}
      assert restored_state.style == initial_style
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

      style1 = TextFormatting.new() |> TextFormatting.set_foreground(:red)
      state1 = %{
        cursor: {10, 5},
        style: style1,
        charset_state: CharacterSets.new(),
        mode_state: ScreenModes.new(),
        scroll_region: {5, 15}
      }

      style2 = TextFormatting.new() |> TextFormatting.set_foreground(:blue)
      state2 = %{
        cursor: {20, 10},
        style: style2,
        charset_state: CharacterSets.new(),
        mode_state: ScreenModes.new(),
        scroll_region: nil
      }

      stack = TerminalState.save_state(stack, state1)
      stack = TerminalState.save_state(stack, state2)

      {stack, restored_state2} = TerminalState.restore_state(stack)
      assert restored_state2.cursor == {20, 10}
      assert restored_state2.style == style2

      {stack, restored_state1} = TerminalState.restore_state(stack)
      assert restored_state1.cursor == {10, 5}
      assert restored_state1.style == style1

      assert TerminalState.empty?(stack) == true
    end
  end

  describe "clear_state/1" do
    test "clears the terminal state stack" do
      stack = TerminalState.new()

      initial_style = TextFormatting.new() |> TextFormatting.set_foreground(:red)
      state = %{
        cursor: {10, 5},
        style: initial_style,
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

      initial_style = TextFormatting.new() |> TextFormatting.set_foreground(:red)
      state = %{
        cursor: {10, 5},
        style: initial_style,
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
