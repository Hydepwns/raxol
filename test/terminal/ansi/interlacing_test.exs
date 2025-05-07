defmodule Raxol.Terminal.ANSI.InterlacingTest do
  use ExUnit.Case
  alias Raxol.Terminal.Emulator

  setup do
    # Create a terminal emulator with default dimensions (80x24)
    terminal = Emulator.new(80, 24)
    %{terminal: terminal}
  end

  describe "interlacing mode" do
    test "switching interlacing mode on", %{terminal: terminal} do
      # Process the CSI sequence for interlacing mode on using Emulator.process_input
      {new_terminal, _output} = Emulator.process_input(terminal, "\x1b[?9h")

      # Check that interlacing mode is enabled
      # Assuming mode_state is directly accessible, adjust if it moved
      assert Raxol.Terminal.ModeManager.mode_enabled?(
               new_terminal.mode_manager,
               :decinlm
             ) == true
    end

    test "switching interlacing mode off", %{terminal: terminal} do
      # First switch interlacing mode on
      {terminal_on, _} = Emulator.process_input(terminal, "\x1b[?9h")

      # Then switch interlacing mode off
      {new_terminal, _} = Emulator.process_input(terminal_on, "\x1b[?9l")

      # Check that interlacing mode is disabled
      assert Raxol.Terminal.ModeManager.mode_enabled?(
               new_terminal.mode_manager,
               :decinlm
             ) == false
    end

    test "interlacing mode is saved and restored when switching screen modes",
         %{terminal: terminal} do
      # First switch interlacing mode on
      {terminal_on, _} = Emulator.process_input(terminal, "\x1b[?9h")

      # Switch to alternate mode (saves state)
      {terminal_alt, _} = Emulator.process_input(terminal_on, "\x1b[?1049h")

      # Check that interlacing mode is still enabled in alt buffer state
      assert Raxol.Terminal.ModeManager.mode_enabled?(
               terminal_alt.mode_manager,
               :decinlm
             ) == true

      # Switch back to normal mode (restores state)
      {terminal_normal, _} = Emulator.process_input(terminal_alt, "\x1b[?1049l")

      # Check that interlacing mode is still enabled (restored)
      assert Raxol.Terminal.ModeManager.mode_enabled?(
               terminal_normal.mode_manager,
               :decinlm
             ) == true
    end
  end
end
