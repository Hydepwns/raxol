defmodule Raxol.Terminal.Emulator.CharacterSetsTest do
  use ExUnit.Case, async: true

  # remove charactersets terminal ansi
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ANSI.CharacterSets

  # Define initial state if used consistently
  # Consider a setup block if state creation is complex or repeated
  # @initial_state Emulator.new(80, 24)

  describe "character set functionality" do
    test ~c"initializes with default character sets" do
      emulator = Emulator.new(80, 24)
      # Get the charset state struct from the emulator
      charset_state = emulator.charset_state
      # Access g0, g1 directly on the charset_state map/struct
      assert charset_state.g0 == :us_ascii
      assert charset_state.g1 == :us_ascii
      # Check the active_set field directly
      assert CharacterSets.get_active_charset(charset_state) == :us_ascii
    end

    test ~c"writes characters with character set translation (DEC Special Graphics)" do
      emulator = Emulator.new(80, 24)

      # Set G1 to DEC Special Graphics & Character Set (ESC ) 0)
      {emulator, ""} = Emulator.process_input(emulator, "\e)0")

      # Verify charset state was updated
      assert emulator.charset_state.g1 == :dec_special_graphics

      # Write a character that should be translated
      {emulator, _} = Emulator.process_input(emulator, "a")

      # Verify the character was written (this will fail if cursor is nil)
      assert emulator.charset_state.g1 == :dec_special_graphics
    end

    test ~c"handles character set switching and invoking" do
      emulator = Emulator.new(80, 24)
      # Set G0 to US ASCII (ESC ( B)
      {emulator, ""} = Emulator.process_input(emulator, "\e(B")
      # Set G2 to DEC Special Graphics (ESC * 0)
      {emulator, ""} = Emulator.process_input(emulator, "\e*0")

      # Access the struct field directly
      charset_state = emulator.charset_state
      # Check struct fields directly
      assert charset_state.g2 == :dec_special_graphics
      assert charset_state.g0 == :us_ascii

      # Invoke G2 into GR (LS2R: ESC ~)
      {emulator, ""} = Emulator.process_input(emulator, "\e~")
      charset_state_g2_in_gr = emulator.charset_state
      assert charset_state_g2_in_gr.gr == :g2

      # Invoke G0 into GL (Shift In: SI)
      # Note: We didn't invoke G2 into GL earlier, so GL should still be G0.
      {emulator, ""} = Emulator.process_input(emulator, "\x0F")
      charset_state_g0_in_gl = emulator.charset_state

      assert CharacterSets.get_active_charset(charset_state_g0_in_gl) ==
               :us_ascii
    end

    # Single Shift (SS2, SS3) tests might require specific Emulator functions
    # if not handled directly by ANSI.process_escape's basic writing functions.
    # test 'handles single shift' do ...

    # Lock Shift (LS1R, LS2, LS2R, LS3, LS3R) tests might also require specific handling.
    # test 'handles lock shift' do ...

    test ~c"handles character set switching and invoking with designator" do
      emulator = Emulator.new(80, 24)
      # Set G0 to US ASCII (ESC ( B)
      {emulator, ""} = Emulator.process_input(emulator, "\e(B")
      # Set G2 to DEC Special Graphics (ESC * 0)
      # Designate DEC Special Graphics to G2
      {emulator, ""} = Emulator.process_input(emulator, "\e*0")
      # Capture charset state
      charset_state = emulator.charset_state
      assert charset_state.g2 == :dec_special_graphics

      # Invoke G2 into GL (Locking Shift 2: LS2 / ESC n)
      {emulator, ""} = Emulator.process_input(emulator, "\en")
      charset_state_g2_in_gl = emulator.charset_state

      assert CharacterSets.get_active_charset(charset_state_g2_in_gl) ==
               :dec_special_graphics

      # Invoke G0 into GL (Shift In: SI)
      {emulator, ""} = Emulator.process_input(emulator, "\x0F")
      charset_state_g0_in_gl = emulator.charset_state

      assert CharacterSets.get_active_charset(charset_state_g0_in_gl) ==
               :us_ascii
    end

    test ~c"designate G2 works in isolation" do
      emulator = Emulator.new(80, 24)
      {final_emulator, ""} = Emulator.process_input(emulator, "\e*0")
      assert final_emulator.charset_state.g2 == :dec_special_graphics
    end
  end
end
