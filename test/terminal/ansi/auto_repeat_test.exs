defmodule Raxol.Terminal.ANSI.AutoRepeatTest do
  use ExUnit.Case
  alias Raxol.Terminal.Emulator

  setup do
    # Create a terminal emulator with default dimensions (80x24)
    terminal = Emulator.new(80, 24)
    %{terminal: terminal}
  end

  describe "auto-repeat mode" do
    test "switching auto-repeat mode on", %{terminal: terminal} do
      # Process the CSI sequence for auto-repeat mode on
      {new_terminal, _output} = Emulator.process_input(terminal, "\x1b[?8h")

      # Check that auto-repeat mode is enabled
      assert Raxol.Terminal.ModeManager.mode_enabled?(
               new_terminal.mode_manager,
               :decarm
             ) == true
    end

    test "switching auto-repeat mode off", %{terminal: terminal} do
      # First switch auto-repeat mode on
      {terminal_on, _output1} = Emulator.process_input(terminal, "\x1b[?8h")

      # Then switch auto-repeat mode off
      {new_terminal, _output2} = Emulator.process_input(terminal_on, "\x1b[?8l")

      # Check that auto-repeat mode is disabled
      assert Raxol.Terminal.ModeManager.mode_enabled?(
               new_terminal.mode_manager,
               :decarm
             ) == false
    end

    test "auto-repeat mode is saved and restored when switching screen modes",
         %{terminal: terminal} do
      # First switch auto-repeat mode on
      {terminal_on, _output1} = Emulator.process_input(terminal, "\x1b[?8h")

      # Switch to alternate mode (saves state)
      {terminal_alt, _output2} =
        Emulator.process_input(terminal_on, "\x1b[?1049h")

      # Check that auto-repeat mode has default value in alternate screen
      # The alternate screen starts with fresh/default modes
      # Default for auto_repeat_mode is true
      assert Raxol.Terminal.ModeManager.mode_enabled?(
               terminal_alt.mode_manager,
               :decarm
             ) == true

      # Switch back to normal mode (restores state)
      {terminal_normal, _output3} =
        Emulator.process_input(terminal_alt, "\x1b[?1049l")

      # Check that auto-repeat mode is restored to true
      assert Raxol.Terminal.ModeManager.mode_enabled?(
               terminal_normal.mode_manager,
               :decarm
             ) == true
    end
  end
end
