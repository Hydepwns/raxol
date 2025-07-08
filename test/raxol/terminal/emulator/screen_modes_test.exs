defmodule Raxol.Terminal.Emulator.ScreenModesTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.ModeManager
  alias Raxol.Terminal.Modes.ModeStateManager

  describe "screen mode functionality" do
    test ~c"initializes with default screen modes" do
      emulator = Emulator.new(80, 24)
      mode_manager = Emulator.get_mode_manager_struct(emulator)
      assert mode_manager == ModeManager.new()
    end

    test ~c"switches between normal and alternate screen buffer" do
      emulator = Emulator.new(80, 24)

      # Write some content to normal buffer
      {emulator, _} = Emulator.process_input(emulator, "ab")
      # Access screen_buffer field directly -> use main_screen_buffer
      buffer_before = Emulator.get_active_buffer(emulator)
      cell_a = ScreenBuffer.get_cell_at(buffer_before, 0, 0)
      cell_b = ScreenBuffer.get_cell_at(buffer_before, 1, 0)
      # Access :char field
      assert cell_a.char == "a"
      # Access :char field
      assert cell_b.char == "b"

      # Save for later comparison, access field directly -> use main_screen_buffer
      main_buffer_content = Emulator.get_active_buffer(emulator)

      # Switch to alternate buffer (DECSET ?1047h)
      {emulator_alt, _} = Emulator.process_input(emulator, "\e[?1047h")

      # Write content to alternate buffer
      {emulator_alt, _} = Emulator.process_input(emulator_alt, "xy")

      # Get the mode manager to check if the mode is set
      mode_manager = Emulator.get_mode_manager_struct(emulator_alt)

      assert ModeManager.mode_enabled?(mode_manager, :dec_alt_screen_save) ==
               true

      # Switch back to main buffer (DECRST ?1047l)
      {emulator_after, _} = Emulator.process_input(emulator_alt, "\e[?1047l")

      # Verify that main buffer content is preserved
      buffer_after = Emulator.get_active_buffer(emulator_after)
      cell_a_after = ScreenBuffer.get_cell_at(buffer_after, 0, 0)
      cell_b_after = ScreenBuffer.get_cell_at(buffer_after, 1, 0)
      assert cell_a_after.char == "a"
      assert cell_b_after.char == "b"

      # Verify that alternate buffer content is preserved
      alt_buffer_after = emulator_after.alternate_screen_buffer
      cell_x = ScreenBuffer.get_cell_at(alt_buffer_after, 0, 0)
      cell_y = ScreenBuffer.get_cell_at(alt_buffer_after, 1, 0)
      assert cell_x.char == "x"
      assert cell_y.char == "y"
    end

    test ~c"switches between normal and alternate screen buffer (DEC mode 1047 - no clear)" do
      emulator = Emulator.new(80, 24)

      # Write to main buffer
      {emulator, _} = Emulator.process_input(emulator, "main")
      main_buffer_content_snapshot = Emulator.get_active_buffer(emulator)

      # Switch to alternate buffer (DECSET ?1047h)
      {emulator, ""} = Emulator.process_input(emulator, "\e[?1047h")
      assert emulator.active_buffer_type == :alternate
      # Write something to alternate buffer
      {emulator, _} = Emulator.process_input(emulator, "alt")
      alt_buffer_content_snapshot = Emulator.get_active_buffer(emulator)
      refute ScreenBuffer.empty?(alt_buffer_content_snapshot)
      cell_a = ScreenBuffer.get_cell_at(alt_buffer_content_snapshot, 0, 0)
      assert cell_a.char == "a"

      # Switch back to main buffer (DECRST ?1047l)
      {emulator, ""} = Emulator.process_input(emulator, "\e[?1047l")
      assert emulator.active_buffer_type == :main
      # Verify main buffer content is restored
      assert Emulator.get_active_buffer(emulator) ==
               main_buffer_content_snapshot

      # Switch back to alternate buffer (DECSET ?1047h) AGAIN
      {emulator, ""} = Emulator.process_input(emulator, "\e[?1047h")
      assert emulator.active_buffer_type == :alternate

      # *** Verify alternate buffer content was NOT cleared and still matches previous alt content ***
      assert Emulator.get_active_buffer(emulator) == alt_buffer_content_snapshot
    end

    test ~c"sets and resets screen modes (Insert Mode - IRM)" do
      emulator = Emulator.new(80, 24)

      # Set insert mode (SM 4)
      {emulator_insert, ""} = Emulator.process_input(emulator, "\e[4h")

      mode_manager = Emulator.get_mode_manager_struct(emulator_insert)
      IO.inspect(mode_manager, label: "ModeManager after set IRM")

      assert ModeManager.mode_enabled?(mode_manager, :irm) ==
               true

      # Reset insert mode (RM 4)
      {emulator_reset, ""} = Emulator.process_input(emulator_insert, "\e[4l")

      mode_manager = Emulator.get_mode_manager_struct(emulator_reset)
      IO.inspect(mode_manager, label: "ModeManager after reset IRM")

      assert ModeManager.mode_enabled?(mode_manager, :irm) ==
               false
    end

    test ~c"sets and resets screen modes (Origin Mode - DECOM)" do
      emulator = Emulator.new(80, 24)

      # Set origin mode (DECSET ?6h)
      {emulator_origin, ""} = Emulator.process_input(emulator, "\e[?6h")

      mode_manager = Emulator.get_mode_manager_struct(emulator_origin)
      IO.inspect(mode_manager, label: "ModeManager after set DECOM")

      assert ModeManager.mode_enabled?(mode_manager, :decom) ==
               true

      # Reset origin mode (DECRST ?6l)
      {emulator_reset, ""} = Emulator.process_input(emulator_origin, "\e[?6l")

      mode_manager = Emulator.get_mode_manager_struct(emulator_reset)
      IO.inspect(mode_manager, label: "ModeManager after reset DECOM")

      assert ModeManager.mode_enabled?(mode_manager, :decom) ==
               false
    end

    test ~c"handles cursor visibility (DECTCEM)" do
      emulator = Emulator.new(80, 24)
      cursor = Emulator.get_cursor_struct(emulator)
      assert cursor.state == :visible

      # Hide cursor (DECRST ?25l)
      # Use process_input
      {emulator, ""} = Emulator.process_input(emulator, "\e[?25l")
      mode_manager = Emulator.get_mode_manager_struct(emulator)
      assert ModeManager.mode_enabled?(mode_manager, :dectcem) == false
      cursor = Emulator.get_cursor_struct(emulator)
      assert cursor.state == :hidden

      # Show cursor (DECSET ?25h)
      # Use process_input
      {emulator, ""} = Emulator.process_input(emulator, "\e[?25h")
      mode_manager = Emulator.get_mode_manager_struct(emulator)
      assert ModeManager.mode_enabled?(mode_manager, :dectcem) == true
      cursor = Emulator.get_cursor_struct(emulator)
      assert cursor.state == :visible
    end

    test ~c"handles application keypad mode (DECKPAM/DECKPNM)" do
      emulator = Emulator.new(80, 24)
      mode_manager = Emulator.get_mode_manager_struct(emulator)
      assert ModeManager.mode_enabled?(mode_manager, :decckm) == false

      # Set application keypad mode (DECKPAM - CSI = ?1h - Note: CSI = is often mapped to ESC =)
      # Using ESC = as per vttest
      # Use process_input
      {emulator_app, ""} = Emulator.process_input(emulator, "\e=")

      mode_manager = Emulator.get_mode_manager_struct(emulator_app)
      IO.inspect(mode_manager, label: "ModeManager after set DECKPAM")

      assert ModeManager.mode_enabled?(mode_manager, :decckm) ==
               true

      # Reset application keypad mode (DECKPNM - CSI = ?1l or ESC >)
      # Using ESC > as per vttest
      # Use process_input
      {emulator_norm, ""} = Emulator.process_input(emulator_app, "\e>")

      mode_manager = Emulator.get_mode_manager_struct(emulator_norm)
      IO.inspect(mode_manager, label: "ModeManager after reset DECKPAM")

      assert ModeManager.mode_enabled?(mode_manager, :decckm) ==
               false
    end

    test ~c"handles terminal modes (standard modes like IRM)" do
      emulator = Emulator.new(80, 24)
      # Insert mode (Set Standard Mode 4)
      {state_after_set, _} = Emulator.process_input(emulator, "\e[4h")

      mode_manager = Emulator.get_mode_manager_struct(state_after_set)
      IO.inspect(mode_manager, label: "ModeManager after set IRM (standard)")

      assert ModeManager.mode_enabled?(mode_manager, :irm) ==
               true

      # Normal mode (Reset Standard Mode 4)
      {state_after_reset, _} = Emulator.process_input(state_after_set, "\e[4l")

      mode_manager = Emulator.get_mode_manager_struct(state_after_reset)
      IO.inspect(mode_manager, label: "ModeManager after reset IRM (standard)")

      assert ModeManager.mode_enabled?(mode_manager, :irm) ==
               false
    end
  end
end
