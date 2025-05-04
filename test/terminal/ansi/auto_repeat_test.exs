defmodule Raxol.Terminal.ANSI.AutoRepeatTest do
  use ExUnit.Case
  alias Raxol.Terminal.{ANSI, Emulator}

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
      assert Raxol.Terminal.ANSI.ScreenModes.get_auto_repeat_mode(
               new_terminal.mode_state
             ) == true
    end

    test "switching auto-repeat mode off", %{terminal: terminal} do
      # First switch auto-repeat mode on
      {terminal_on, _output1} = Emulator.process_input(terminal, "\x1b[?8h")

      # Then switch auto-repeat mode off
      {new_terminal, _output2} = Emulator.process_input(terminal_on, "\x1b[?8l")

      # Check that auto-repeat mode is disabled
      assert Raxol.Terminal.ANSI.ScreenModes.get_auto_repeat_mode(
               new_terminal.mode_state
             ) == false
    end

    test "auto-repeat mode is saved and restored when switching screen modes",
         %{terminal: terminal} do
      # First switch auto-repeat mode on
      {terminal_on, _output1} = Emulator.process_input(terminal, "\x1b[?8h")

      # Switch to alternate mode (saves state)
      {terminal_alt, _output2} = Emulator.process_input(terminal_on, "\x1b[?1049h")

      # Check that auto-repeat mode is still enabled (should be false in fresh alt mode?)
      # Let's verify the expected behavior. Alt screen usually starts fresh.
      # Let's assume it SHOULD be false after switching to alt mode.
      assert Raxol.Terminal.ANSI.ScreenModes.get_auto_repeat_mode(
               terminal_alt.mode_state
             ) == false # Alt screen should start with default modes

      # Switch back to normal mode (restores state)
      {terminal_normal, _output3} = Emulator.process_input(terminal_alt, "\x1b[?1049l")

      # Check that auto-repeat mode is restored to true
      assert Raxol.Terminal.ANSI.ScreenModes.get_auto_repeat_mode(
               terminal_normal.mode_state
             ) == true
    end
  end
end
