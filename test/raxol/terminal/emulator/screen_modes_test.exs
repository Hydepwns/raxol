defmodule Raxol.Terminal.Emulator.ScreenModesTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ModeManager
  alias Raxol.Terminal.ScreenBuffer
  # alias Raxol.Terminal.Modes.ModeStateManager

  describe "screen mode functionality" do
    test ~c"initializes with default screen modes" do
      emulator = Emulator.new(80, 24)
      mode_manager = Emulator.get_mode_manager(emulator)
      assert mode_manager == ModeManager.new()
    end

    @tag timeout: 120_000
    test ~c"switches between normal and alternate screen buffer" do
      emulator = Emulator.new(80, 24)

      # Write some content to normal buffer
      {emulator, _} = Emulator.process_input(emulator, "ab")

      # Check buffer state immediately after writing
      buffer_after_write = Emulator.get_screen_buffer(emulator)
      cell_a_after_write = ScreenBuffer.get_cell_at(buffer_after_write, 0, 0)
      cell_b_after_write = ScreenBuffer.get_cell_at(buffer_after_write, 1, 0)

      IO.puts("DEBUG: After writing 'ab':")
      IO.puts("  cell_a.char = #{inspect(cell_a_after_write.char)}")
      IO.puts("  cell_b.char = #{inspect(cell_b_after_write.char)}")

      IO.puts(
        "  buffer_after_write type: #{inspect(buffer_after_write.__struct__)}"
      )

      IO.puts(
        "  emulator.main_screen_buffer type: #{inspect(emulator.main_screen_buffer.__struct__)}"
      )

      IO.puts(
        "  emulator.active_buffer_type: #{inspect(emulator.active_buffer_type)}"
      )

      # Access :char field
      assert cell_a_after_write.char == "a"
      # Access :char field
      assert cell_b_after_write.char == "b"

      # Access screen_buffer field directly -> use main_screen_buffer
      buffer_before = Emulator.get_screen_buffer(emulator)
      _cell_a = ScreenBuffer.get_cell_at(buffer_before, 0, 0)
      _cell_b = ScreenBuffer.get_cell_at(buffer_before, 1, 0)

      # Save for later comparison, access field directly -> use main_screen_buffer
      _main_buffer_content = Emulator.get_screen_buffer(emulator)

      # Switch to alternate screen buffer
      {emulator, _} = Emulator.process_input(emulator, "\e[?1047h")

      # Write some content to alternate buffer
      {emulator, _} = Emulator.process_input(emulator, "xy")

      # Check that alternate buffer has the new content
      alternate_buffer = Emulator.get_screen_buffer(emulator)
      cell_x = ScreenBuffer.get_cell_at(alternate_buffer, 0, 0)
      cell_y = ScreenBuffer.get_cell_at(alternate_buffer, 1, 0)
      # Access :char field
      assert cell_x.char == "x"
      # Access :char field
      assert cell_y.char == "y"

      # Switch back to main screen buffer
      {emulator, _} = Emulator.process_input(emulator, "\e[?1047l")

      # Check that main buffer still has original content
      main_buffer = Emulator.get_screen_buffer(emulator)
      cell_a_after = ScreenBuffer.get_cell_at(main_buffer, 0, 0)
      cell_b_after = ScreenBuffer.get_cell_at(main_buffer, 1, 0)
      # Access :char field
      assert cell_a_after.char == "a"
      # Access :char field
      assert cell_b_after.char == "b"

      # Check that alternate buffer still has its content
      alternate_buffer_after = emulator.alternate_screen_buffer
      cell_x_after = ScreenBuffer.get_cell_at(alternate_buffer_after, 0, 0)
      cell_y_after = ScreenBuffer.get_cell_at(alternate_buffer_after, 1, 0)
      # Access :char field
      assert cell_x_after.char == "x"
      # Access :char field
      assert cell_y_after.char == "y"
    end

    @tag timeout: 120_000
    test ~c"switches between normal and alternate screen buffer (DEC mode 1047 - no clear)" do
      emulator = Emulator.new(80, 24)

      # Write to main buffer
      {emulator, _} = Emulator.process_input(emulator, "main")
      main_buffer_content_snapshot = Emulator.get_screen_buffer(emulator)

      # Switch to alternate buffer (DECSET ?1047h)
      {emulator, ""} = Emulator.process_input(emulator, "\e[?1047h")
      assert emulator.active_buffer_type == :alternate
      # Write something to alternate buffer
      {emulator, _} = Emulator.process_input(emulator, "alt")
      alt_buffer_content_snapshot = Emulator.get_screen_buffer(emulator)
      refute ScreenBuffer.empty?(alt_buffer_content_snapshot)
      cell_a = ScreenBuffer.get_cell_at(alt_buffer_content_snapshot, 0, 0)
      assert cell_a.char == "a"

      # Switch back to main buffer (DECRST ?1047l)
      {emulator, ""} = Emulator.process_input(emulator, "\e[?1047l")
      assert emulator.active_buffer_type == :main
      # Verify main buffer content is restored
      assert Emulator.get_screen_buffer(emulator) ==
               main_buffer_content_snapshot

      # Switch back to alternate buffer (DECSET ?1047h) AGAIN
      {emulator, ""} = Emulator.process_input(emulator, "\e[?1047h")
      assert emulator.active_buffer_type == :alternate

      # *** Verify alternate buffer content was NOT cleared and still matches previous alt content ***
      assert Emulator.get_screen_buffer(emulator) == alt_buffer_content_snapshot
    end

    test ~c"sets and resets screen modes (Insert Mode - IRM)" do
      emulator = Emulator.new(80, 24)

      # Set insert mode (SM 4)
      {emulator_insert, ""} = Emulator.process_input(emulator, "\e[4h")

      mode_manager = Emulator.get_mode_manager(emulator_insert)

      assert ModeManager.mode_enabled?(mode_manager, :irm) ==
               true

      # Reset insert mode (RM 4)
      {emulator_reset, ""} = Emulator.process_input(emulator_insert, "\e[4l")

      mode_manager = Emulator.get_mode_manager(emulator_reset)

      assert ModeManager.mode_enabled?(mode_manager, :irm) ==
               false
    end

    test ~c"sets and resets screen modes (Origin Mode - DECOM)" do
      emulator = Emulator.new(80, 24)

      # Set origin mode (DECSET ?6h)
      {emulator_origin, ""} = Emulator.process_input(emulator, "\e[?6h")

      mode_manager = Emulator.get_mode_manager(emulator_origin)

      assert ModeManager.mode_enabled?(mode_manager, :decom) ==
               true

      # Reset origin mode (DECRST ?6l)
      {emulator_reset, ""} = Emulator.process_input(emulator_origin, "\e[?6l")

      mode_manager = Emulator.get_mode_manager(emulator_reset)

      assert ModeManager.mode_enabled?(mode_manager, :decom) ==
               false
    end

    test ~c"handles cursor visibility (DECTCEM)" do
      emulator = Emulator.new(80, 24)
      assert Emulator.cursor_visible?(emulator) == true

      # Hide cursor (DECRST ?25l)
      # Use process_input
      {emulator, ""} = Emulator.process_input(emulator, "\e[?25l")
      mode_manager = Emulator.get_mode_manager(emulator)
      assert ModeManager.mode_enabled?(mode_manager, :dectcem) == false
      assert Emulator.cursor_visible?(emulator) == false

      # Show cursor (DECSET ?25h)
      # Use process_input
      {emulator, ""} = Emulator.process_input(emulator, "\e[?25h")
      mode_manager = Emulator.get_mode_manager(emulator)
      assert ModeManager.mode_enabled?(mode_manager, :dectcem) == true
      assert Emulator.cursor_visible?(emulator) == true
    end

    test ~c"handles application keypad mode (DECKPAM/DECKPNM)" do
      emulator = Emulator.new(80, 24)
      mode_manager = Emulator.get_mode_manager(emulator)
      assert ModeManager.mode_enabled?(mode_manager, :decckm) == false

      # Set application keypad mode (DECKPAM - CSI = ?1h - Note: CSI = is often mapped to ESC =)
      # Using ESC = as per vttest
      # Use process_input
      {emulator_app, ""} = Emulator.process_input(emulator, "\e=")

      mode_manager = Emulator.get_mode_manager(emulator_app)

      assert ModeManager.mode_enabled?(mode_manager, :decckm) ==
               true

      # Reset application keypad mode (DECKPNM - CSI = ?1l or ESC >)
      # Using ESC > as per vttest
      # Use process_input
      {emulator_norm, ""} = Emulator.process_input(emulator_app, "\e>")

      mode_manager = Emulator.get_mode_manager(emulator_norm)

      assert ModeManager.mode_enabled?(mode_manager, :decckm) ==
               false
    end

    test ~c"handles terminal modes (standard modes like IRM)" do
      emulator = Emulator.new(80, 24)
      # Insert mode (Set Standard Mode 4)
      {state_after_set, _} = Emulator.process_input(emulator, "\e[4h")

      mode_manager = Emulator.get_mode_manager(state_after_set)

      assert ModeManager.mode_enabled?(mode_manager, :irm) ==
               true

      # Normal mode (Reset Standard Mode 4)
      {state_after_reset, _} = Emulator.process_input(state_after_set, "\e[4l")

      mode_manager = Emulator.get_mode_manager(state_after_reset)

      assert ModeManager.mode_enabled?(mode_manager, :irm) ==
               false
    end
  end
end
