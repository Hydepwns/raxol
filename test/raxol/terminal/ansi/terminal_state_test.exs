defmodule Raxol.Terminal.ANSI.TerminalStateTest do
  use ExUnit.Case
  # remove charactersets terminal ansi
  alias Raxol.Terminal.ModeManager
  alias Raxol.Terminal.ANSI.TerminalState
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Cursor.Manager

  defp create_test_emulator(
         cursor_pos,
         style,
         scroll_region \\ nil,
         cursor_style \\ :blinking_block
       ) do
    %Emulator{
      cursor: %Manager{position: cursor_pos},
      style: style,
      charset_state: CharacterSets.new(),
      mode_manager: ModeManager.new(),
      scroll_region: scroll_region,
      cursor_style: cursor_style
    }
  end

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

      initial_style =
        TextFormatting.new()
        |> TextFormatting.set_foreground(:red)
        |> TextFormatting.set_background(:black)

      emulator_state = create_test_emulator({10, 5}, initial_style, {5, 15})

      stack = TerminalState.save_state(stack, emulator_state)
      assert TerminalState.empty?(stack) == false
      assert TerminalState.count(stack) == 1

      [saved_state | _] = stack
      assert saved_state.cursor == %Manager{position: {10, 5}}
      assert saved_state.style == initial_style
      assert saved_state.charset_state == CharacterSets.new()
      assert saved_state.mode_manager == ModeManager.new()
      assert saved_state.scroll_region == {5, 15}
      assert saved_state.cursor_style == :blinking_block
    end

    test "saves multiple states to the stack" do
      stack = TerminalState.new()

      style1 = TextFormatting.new() |> TextFormatting.set_foreground(:red)
      emulator_state1 = create_test_emulator({10, 5}, style1, {5, 15})

      style2 = TextFormatting.new() |> TextFormatting.set_foreground(:blue)

      emulator_state2 =
        create_test_emulator({20, 10}, style2, nil, :steady_block)

      stack = TerminalState.save_state(stack, emulator_state1)
      stack = TerminalState.save_state(stack, emulator_state2)
      assert TerminalState.count(stack) == 2

      [saved_state2, saved_state1 | _] = stack
      assert saved_state2.cursor == %Manager{position: {20, 10}}
      assert saved_state2.style == style2
      assert saved_state2.cursor_style == :steady_block
      assert saved_state1.cursor == %Manager{position: {10, 5}}
      assert saved_state1.style == style1
      assert saved_state1.cursor_style == :blinking_block
    end
  end

  describe "restore_state/1" do
    test "restores the most recently saved state" do
      stack = TerminalState.new()

      initial_style =
        TextFormatting.new() |> TextFormatting.set_foreground(:red)

      emulator_state = create_test_emulator({10, 5}, initial_style, {5, 15})

      stack = TerminalState.save_state(stack, emulator_state)
      {stack, restored_state} = TerminalState.restore_state(stack)

      assert TerminalState.empty?(stack) == true
      assert restored_state.cursor == %Manager{position: {10, 5}}
      assert restored_state.style == initial_style
      assert restored_state.scroll_region == {5, 15}
      assert restored_state.cursor_style == :blinking_block
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
      emulator_state1 = create_test_emulator({10, 5}, style1, {5, 15})

      style2 = TextFormatting.new() |> TextFormatting.set_foreground(:blue)

      emulator_state2 =
        create_test_emulator({20, 10}, style2, nil, :steady_block)

      stack = TerminalState.save_state(stack, emulator_state1)
      stack = TerminalState.save_state(stack, emulator_state2)

      {stack, restored_state2} = TerminalState.restore_state(stack)
      assert restored_state2.cursor == %Manager{position: {20, 10}}
      assert restored_state2.style == style2
      assert restored_state2.cursor_style == :steady_block

      {stack, restored_state1} = TerminalState.restore_state(stack)
      assert restored_state1.cursor == %Manager{position: {10, 5}}
      assert restored_state1.style == style1
      assert restored_state1.cursor_style == :blinking_block

      assert TerminalState.empty?(stack) == true
    end
  end

  describe "clear_state/1" do
    test "clears the terminal state stack" do
      stack = TerminalState.new()

      initial_style =
        TextFormatting.new() |> TextFormatting.set_foreground(:red)

      emulator_state = create_test_emulator({10, 5}, initial_style, {5, 15})

      stack = TerminalState.save_state(stack, emulator_state)
      assert TerminalState.empty?(stack) == false

      stack = TerminalState.clear_state(stack)
      assert TerminalState.empty?(stack) == true
      assert TerminalState.count(stack) == 0
    end
  end

  describe "get_state_stack/1" do
    test "returns the current terminal state stack" do
      stack = TerminalState.new()

      initial_style =
        TextFormatting.new() |> TextFormatting.set_foreground(:red)

      emulator_state = create_test_emulator({10, 5}, initial_style, {5, 15})

      stack = TerminalState.save_state(stack, emulator_state)
      retrieved_stack = TerminalState.get_state_stack(stack)

      assert retrieved_stack == stack
      assert length(retrieved_stack) == 1
    end
  end
end
