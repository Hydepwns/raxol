defmodule Raxol.Terminal.Emulator.ScreenModesTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer

  describe "screen mode functionality" do
    test "initializes with default screen modes" do
      emulator = Emulator.new(80, 24)

      # Expected defaults based on ScreenModes.new()
      expected_default_modes = %{
        mode: :normal,
        cursor_visible: true,
        auto_wrap: true,
        origin_mode: false,
        insert_mode: false,
        line_feed_mode: false,
        column_width_mode: :normal,
        auto_repeat_mode: false,
        interlacing_mode: false,
        saved_state: nil
      }

      # Use getter and assert correct map
      # Access mode_state field directly
      assert emulator.mode_state == expected_default_modes
    end

    test "switches between normal and alternate screen buffer" do
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

      # Switch to alternate buffer (DECSET ?1049h)
      # Use process_input
      {emulator, ""} = Emulator.process_input(emulator, "\\e[?1049h")
      # Access mode_state field directly
      mode_state_alt = emulator.mode_state
      # Assumes ScreenModes struct uses this key
      assert mode_state_alt[:alternate_screen] == true
      # Check active buffer is now the alternate one (if getter exists)
      # assert Emulator.get_active_buffer_type(emulator) == :alternate
      # Check the alternate buffer is empty
      # Check alternate buffer
      assert ScreenBuffer.is_empty?(Emulator.get_active_buffer(emulator))

      # Write content to alternate buffer
      {emulator, _} = Emulator.process_input(emulator, "xy")
      # Access alternate_screen_buffer field directly
      buffer_alt = Emulator.get_active_buffer(emulator)
      cell_x = ScreenBuffer.get_cell_at(buffer_alt, 0, 0)
      cell_y = ScreenBuffer.get_cell_at(buffer_alt, 1, 0)
      # Access :char field
      assert cell_x.char == "x"
      # Access :char field
      assert cell_y.char == "y"

      # Switch back to normal buffer (DECRST ?1049l)
      # Use process_input
      {emulator, ""} = Emulator.process_input(emulator, "\\e[?1049l")
      # Access mode_state field directly
      mode_state_normal = emulator.mode_state

      # Check mode state key again
      assert mode_state_normal[:alternate_screen] == nil or
               mode_state_normal[:alternate_screen] == false

      # Check active buffer is main
      # assert Emulator.get_active_buffer_type(emulator) == :main
      # Check that main buffer content is restored, access field directly
      assert Emulator.get_active_buffer(emulator) == main_buffer_content
    end

    test "switches between normal and alternate screen buffer (DEC mode 1047 - no clear)" do
      emulator = Emulator.new(80, 24)

      # Write to main buffer
      {emulator, _} = Emulator.process_input(emulator, "main")
      main_buffer_content_snapshot = Emulator.get_active_buffer(emulator)

      # Switch to alternate buffer (DECSET ?1047h)
      {emulator, ""} = Emulator.process_input(emulator, "\\\\e[?1047h")
      assert emulator.active_buffer_type == :alternate
      # Write something to alternate buffer
      {emulator, _} = Emulator.process_input(emulator, "alt")
      alt_buffer_content_snapshot = Emulator.get_active_buffer(emulator)
      refute ScreenBuffer.is_empty?(alt_buffer_content_snapshot)
      cell_a = ScreenBuffer.get_cell_at(alt_buffer_content_snapshot, 0, 0)
      assert cell_a.char == "a"

      # Switch back to main buffer (DECRST ?1047l)
      {emulator, ""} = Emulator.process_input(emulator, "\\\\e[?1047l")
      assert emulator.active_buffer_type == :main
      # Verify main buffer content is restored
      assert Emulator.get_active_buffer(emulator) ==
               main_buffer_content_snapshot

      # Switch back to alternate buffer (DECSET ?1047h) AGAIN
      {emulator, ""} = Emulator.process_input(emulator, "\\\\e[?1047h")
      assert emulator.active_buffer_type == :alternate

      # *** Verify alternate buffer content was NOT cleared and still matches previous alt content ***
      assert Emulator.get_active_buffer(emulator) == alt_buffer_content_snapshot
    end

    test "sets and resets screen modes (Insert Mode - IRM)" do
      emulator = Emulator.new(80, 24)

      # Set insert mode (SM IRM - CSI 4 h)
      # Use process_input
      {emulator, ""} = Emulator.process_input(emulator, "\\e[4h")
      # Access mode_state field directly
      assert emulator.mode_state[:insert_mode] == true

      # Reset insert mode (RM IRM - CSI 4 l)
      # Use process_input
      {emulator, ""} = Emulator.process_input(emulator, "\\e[4l")
      # Access mode_state field directly
      assert emulator.mode_state[:insert_mode] == nil or
               emulator.mode_state[:insert_mode] == false
    end

    test "sets and resets screen modes (Origin Mode - DECOM)" do
      emulator = Emulator.new(80, 24)

      # Set origin mode (DECSET ?6h)
      # Use process_input
      {emulator, ""} = Emulator.process_input(emulator, "\\e[?6h")
      # Access mode_state field directly
      assert emulator.mode_state[:origin_mode] == true

      # Reset origin mode (DECRST ?6l)
      # Use process_input
      {emulator, ""} = Emulator.process_input(emulator, "\\e[?6l")
      # Access mode_state field directly
      assert emulator.mode_state[:origin_mode] == nil or
               emulator.mode_state[:origin_mode] == false
    end

    test "handles cursor visibility (DECTCEM)" do
      emulator = Emulator.new(80, 24)
      # Check state directly as getter `get_cursor_visible` returns bool
      assert emulator.cursor.state == :visible

      # Hide cursor (DECRST ?25l)
      # Use process_input
      {emulator, ""} = Emulator.process_input(emulator, "\\e[?25l")
      # Check state directly
      assert emulator.cursor.state == :hidden

      # Show cursor (DECSET ?25h)
      # Use process_input
      {emulator, ""} = Emulator.process_input(emulator, "\\e[?25h")
      # Check state directly
      assert emulator.cursor.state == :visible
    end

    test "handles application keypad mode (DECKPAM/DECKPNM)" do
      emulator = Emulator.new(80, 24)
      # Access mode_state field directly
      mode_state_initial = emulator.mode_state
      # Access key directly
      assert mode_state_initial[:application_keypad] == nil or
               mode_state_initial[:application_keypad] == false

      # Set application keypad mode (DECKPAM - CSI = ?1h - Note: CSI = is often mapped to ESC =)
      # Using ESC = as per vttest
      # Use process_input
      {emulator, ""} = Emulator.process_input(emulator, "\\e=")
      # Access mode_state field directly
      assert emulator.mode_state[:application_keypad] == true

      # Reset application keypad mode (DECKPNM - CSI = ?1l or ESC >)
      # Using ESC > as per vttest
      # Use process_input
      {emulator, ""} = Emulator.process_input(emulator, "\\e>")
      # Access mode_state field directly
      assert emulator.mode_state[:application_keypad] == nil or
               emulator.mode_state[:application_keypad] == false
    end

    test "handles terminal modes (standard modes like IRM)" do
      emulator = Emulator.new(80, 24)
      # Insert mode (Set Standard Mode 4)
      {state_after_set, _} = Emulator.process_input(emulator, "\e[4h")
      # Access mode_state directly
      assert state_after_set.mode_state[:insert_mode] == true

      # Normal mode (Reset Standard Mode 4)
      {state_after_reset, _} = Emulator.process_input(state_after_set, "\e[4l")
      # Access mode_state directly
      assert state_after_reset.mode_state[:insert_mode] == nil or
               state_after_reset.mode_state[:insert_mode] == false
    end
  end
end
