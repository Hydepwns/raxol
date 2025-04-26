defmodule Raxol.Terminal.Emulator.StateStackTest do
  use ExUnit.Case

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Cursor.Manager
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.ANSI.TextFormatting
  # Note: CharacterSets alias might be needed if asserting charset_state fields directly
  alias Raxol.Terminal.ANSI.CharacterSets

  describe "Emulator State Stack (push/pop)" do
    # These tests check the side effects of ANSI sequences handled by Emulator/Parser
    # that utilize the internal state stack (managed by TerminalState).

    test "DECSC/DECRC saves and restores state (ESC 7/8)" do
      emulator = Emulator.new(80, 24)

      # State 1: pos=(1,1), bold=true, G1=DEC Special Graphics
      emulator1 = %{emulator | cursor: Manager.move_to(emulator.cursor, 1, 1)}
      # Update style directly
      emulator1 = %{emulator1 | style: %{emulator1.style | bold: true}}
      # Designate G1 (ESC ) 0)
      {emulator1, ""} = Emulator.process_input(emulator1, "\e)0")
      mode_state1 = emulator1.mode_state
      charset_state1 = emulator1.charset_state # Capture charset state

      # Save state (DECSC - ESC 7)
      {emulator_saved1, ""} = Emulator.process_input(emulator1, "\e7")

      # State 2: pos=(2,2), underline=true, G1=US ASCII (different from state 1)
      emulator2 = %{
        emulator_saved1
        | cursor: Manager.move_to(emulator_saved1.cursor, 2, 2)
      }

      # Reset style before setting new one
      emulator2 = %{emulator2 | style: TextFormatting.new()}
      # Update style directly
      emulator2 = %{emulator2 | style: %{emulator2.style | underline: true}}
      # Designate G1 back to ASCII (ESC ) B)
      {emulator2, ""} = Emulator.process_input(emulator2, "\e)B")
      mode_state2 = emulator2.mode_state
      charset_state2 = emulator2.charset_state # Capture charset state

      # Check stack count (indirectly, by testing restore)

      # Restore state (DECRC - ESC 8)
      {emulator_restored1, ""} = Emulator.process_input(emulator2, "\e8")

      # Check state restored to State 1's values
      assert emulator_restored1.cursor.position == {1, 1}
      # Check style directly
      assert emulator_restored1.style.bold == true
      assert emulator_restored1.style.underline == false
      # Check charset restored
      assert emulator_restored1.charset_state == charset_state1
      assert emulator_restored1.charset_state.g1 == :dec_special_graphics # Verify specific field if needed
      # Check mode state restored
      assert emulator_restored1.mode_state == mode_state1

      # Restore again (should do nothing if stack empty)
      initial_state_before_second_restore = emulator_restored1

      {emulator_restored_again, ""} =
        Emulator.process_input(emulator_restored1, "\e8")

      # Assert no change if stack was empty
      assert emulator_restored_again.cursor ==
               initial_state_before_second_restore.cursor

      assert emulator_restored_again.style ==
               initial_state_before_second_restore.style

      assert emulator_restored_again.charset_state ==
               initial_state_before_second_restore.charset_state

      assert emulator_restored_again.mode_state ==
               initial_state_before_second_restore.mode_state
    end

    test "DEC mode 1048 saves/restores state WITH alternate buffer switch" do
      emulator = Emulator.new(80, 24)

      # 1. Setup state on main buffer
      {emulator, _} = Emulator.process_input(emulator, "MainBuf")
      emulator = %{emulator | cursor: Manager.move_to(emulator.cursor, 10, 5)}
      # Bold (CSI 1 m)
      {emulator, ""} = Emulator.process_input(emulator, "\e[1m")
      main_buffer_snapshot = Emulator.get_active_buffer(emulator)
      cursor_snapshot = emulator.cursor
      style_snapshot = emulator.style

      # 2. Save state and switch to alternate buffer (DECSET ?1048h)
      {emulator, ""} = Emulator.process_input(emulator, "\e[?1048h")

      # Verify switch to alternate buffer (should be empty initially)
      assert emulator.active_buffer_type == :alternate
      assert ScreenBuffer.is_empty?(Emulator.get_active_buffer(emulator))

      # Cursor typically resets to 0,0 on switch
      assert emulator.cursor.position == {0, 0}
      # Style usually resets on switch
      assert emulator.style == TextFormatting.new()

      # 3. Modify state on alternate buffer
      {emulator, _} = Emulator.process_input(emulator, "AltBuf")
      emulator = %{emulator | cursor: Manager.move_to(emulator.cursor, 20, 15)}
      # Underline (CSI 4 m)
      {emulator, ""} = Emulator.process_input(emulator, "\e[4m")

      # 4. Restore state and switch back to main buffer (DECRST ?1048l)
      {emulator, ""} = Emulator.process_input(emulator, "\e[?1048l")

      # Verify back on main buffer
      assert emulator.active_buffer_type == :main
      # Verify main buffer content is restored
      assert Emulator.get_active_buffer(emulator) == main_buffer_snapshot
      # Verify cursor position is restored
      assert emulator.cursor == cursor_snapshot
      # Verify style is restored
      assert emulator.style == style_snapshot

      # 5. Verify stack is empty/correct - cannot directly check state_stack
      # Instead, perform another DECRC (ESC 8) and ensure no change
      initial_state_after_1048_restore = emulator
      {emulator_after_extra_decrc, ""} = Emulator.process_input(emulator, "\e8")
      assert emulator_after_extra_decrc == initial_state_after_1048_restore
    end
  end
end
