defmodule Raxol.Terminal.ANSI.InterlacingTest do
  use ExUnit.Case
  alias Raxol.Terminal.{ANSI, Emulator}

  setup do
    # Create a terminal emulator with default dimensions (80x24)
    terminal = Emulator.new(80, 24)
    %{terminal: terminal}
  end

  describe "interlacing mode" do
    test "switching interlacing mode on", %{terminal: terminal} do
      # Process the CSI sequence for interlacing mode on
      new_terminal = ANSI.process_escape_sequence(terminal, "\x1b[?9h")

      # Check that interlacing mode is enabled
      assert Raxol.Terminal.ANSI.ScreenModes.get_interlacing_mode(
               new_terminal.mode_state
             ) == true
    end

    test "switching interlacing mode off", %{terminal: terminal} do
      # First switch interlacing mode on
      terminal = ANSI.process_escape_sequence(terminal, "\x1b[?9h")

      # Then switch interlacing mode off
      new_terminal = ANSI.process_escape_sequence(terminal, "\x1b[?9l")

      # Check that interlacing mode is disabled
      assert Raxol.Terminal.ANSI.ScreenModes.get_interlacing_mode(
               new_terminal.mode_state
             ) == false
    end

    test "interlacing mode is saved and restored when switching screen modes",
         %{terminal: terminal} do
      # First switch interlacing mode on
      terminal = ANSI.process_escape_sequence(terminal, "\x1b[?9h")

      # Switch to alternate mode (saves state)
      terminal = ANSI.process_escape_sequence(terminal, "\x1b[?1049h")

      # Check that interlacing mode is still enabled
      assert Raxol.Terminal.ANSI.ScreenModes.get_interlacing_mode(
               terminal.mode_state
             ) == true

      # Switch back to normal mode (restores state)
      terminal = ANSI.process_escape_sequence(terminal, "\x1b[?1049l")

      # Check that interlacing mode is still enabled
      assert Raxol.Terminal.ANSI.ScreenModes.get_interlacing_mode(
               terminal.mode_state
             ) == true
    end
  end
end
