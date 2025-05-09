defmodule Raxol.Terminal.ANSI.CharacterSetsTest do
  use ExUnit.Case
  alias Raxol.Terminal.ANSI.CharacterSets

  describe "new/0" do
    test "creates a new character set state with default values" do
      state = CharacterSets.new()

      assert state.g0 == :us_ascii
      assert state.g1 == :us_ascii
      assert state.g2 == :us_ascii
      assert state.g3 == :us_ascii
      assert state.gl == :g0
      assert state.gr == :g1
      assert state.single_shift == nil
      assert state.locked_shift == false
    end
  end

  describe "switch_charset/3" do
    test "switches the specified character set" do
      state = CharacterSets.new()
      state = CharacterSets.switch_charset(state, :g0, :french)

      assert state.g0 == :french
      assert state.g1 == :us_ascii
      assert state.g2 == :us_ascii
      assert state.g3 == :us_ascii
    end
  end

  describe "set_gl/2" do
    test "sets the GL character set" do
      state = CharacterSets.new()
      state = CharacterSets.set_gl(state, :g1)

      assert state.gl == :g1
      assert state.gr == :g1
    end
  end

  describe "set_gr/2" do
    test "sets the GR character set" do
      state = CharacterSets.new()
      state = CharacterSets.set_gr(state, :g2)

      assert state.gl == :g0
      assert state.gr == :g2
    end
  end

  # Skip: set_single_shift/2 function does not exist in the current API
  # @tag :skip
  describe "set_single_shift/2" do
    test "sets and clears the single shift character set using SS2 and SS3" do
      state = CharacterSets.new()
      # Designate a specific charset to G2 and G3 for clarity
      state = CharacterSets.switch_charset(state, :g2, :german)
      state = CharacterSets.switch_charset(state, :g3, :french)

      # Test SS2
      state_ss2_active = CharacterSets.set_single_shift(state, :ss2)
      assert state_ss2_active.single_shift == :german # G2 charset

      # Test clearing single_shift
      state_ss_cleared = CharacterSets.clear_single_shift(state_ss2_active)
      assert state_ss_cleared.single_shift == nil

      # Test SS3
      state_ss3_active = CharacterSets.set_single_shift(state, :ss3)
      assert state_ss3_active.single_shift == :french # G3 charset

      # Test clearing again
      state_ss3_cleared = CharacterSets.clear_single_shift(state_ss3_active)
      assert state_ss3_cleared.single_shift == nil
    end
  end

  describe "get_active_charset/1" do
    # Skip: Test relies on set_single_shift/2 which does not exist
    # @tag :skip
    test "returns the correct active character set, including single shift" do
      state = CharacterSets.new()
      state = CharacterSets.switch_charset(state, :g0, :us_ascii) # Explicitly set G0
      state = CharacterSets.switch_charset(state, :g1, :uk)
      state = CharacterSets.switch_charset(state, :g2, :german) # For SS2 testing
      state = CharacterSets.switch_charset(state, :g3, :french) # For SS3 testing

      # Default to GL (G0)
      state = CharacterSets.set_gl(state, :g0)
      assert CharacterSets.get_active_charset(state) == :us_ascii

      # Switch GL to G1
      state = CharacterSets.set_gl(state, :g1)
      assert CharacterSets.get_active_charset(state) == :uk

      # Activate single shift SS2 (to G2 - german)
      state_ss2_active = CharacterSets.set_single_shift(state, :ss2)
      assert CharacterSets.get_active_charset(state_ss2_active) == :german
      # Verify original GL is still G1 if single shift wasn't consumed from state
      assert state_ss2_active.gl == :g1

      # Activate single shift SS3 (to G3 - french)
      state_ss3_active = CharacterSets.set_single_shift(state, :ss3)
      assert CharacterSets.get_active_charset(state_ss3_active) == :french

      # Test locked shift (GR should be G1 - uk)
      state_locked = %{state | locked_shift: true, gr: :g1} # Ensure GR is set before locking
      assert CharacterSets.get_active_charset(state_locked) == :uk

      # Test precedence: single_shift > locked_shift > gl
      state_complex = CharacterSets.set_gl(%{state | locked_shift: true, gr: :g1}, :g0) # GL=g0, GR=g1, locked
      assert CharacterSets.get_active_charset(state_complex) == :uk # Locked shift (GR) active
      state_complex_ss2 = CharacterSets.set_single_shift(state_complex, :ss2) # SS2 to G2 (german)
      assert CharacterSets.get_active_charset(state_complex_ss2) == :german # Single shift takes precedence
    end
  end

  describe "translate_char/2" do
    test "translates characters according to the active character set" do
      state = CharacterSets.new()
      state = CharacterSets.switch_charset(state, :g0, :french)
      state = CharacterSets.set_gl(state, :g0)
      # In :french, 0x23 (#) -> £ (163)
      assert CharacterSets.translate_char(state, 0x23) == {163, state}
      # In :french, 'a' (0x61) -> 'a' (0x61) (no specific mapping, stays US ASCII like)
      assert CharacterSets.translate_char(state, ?a) == {?a, state}

      # Test with single shift consumption
      state = CharacterSets.switch_charset(state, :g0, :us_ascii) # GL defaults to US ASCII
      state = CharacterSets.set_gl(state, :g0)
      state_g2_german = CharacterSets.switch_charset(state, :g2, :german) # G2 is German

      state_ss2_active = CharacterSets.set_single_shift(state_g2_german, :ss2)

      # Test with '{' (0x7B):
      # In :german, 0x7B ('{') -> 'ä' (228)
      {translated_char_german, state_after_ss2} = CharacterSets.translate_char(state_ss2_active, 0x7B)
      assert translated_char_german == 228 # Should be 'ä' from German charset
      assert state_after_ss2.single_shift == nil # Single shift should be consumed
      # Active charset should revert to G0 (:us_ascii) after SS2 is consumed
      assert CharacterSets.get_active_charset(state_after_ss2) == :us_ascii

      # Translate '{' again, should now use :us_ascii (0x7B -> 0x7B)
      {translated_char_us_ascii, _final_state} = CharacterSets.translate_char(state_after_ss2, 0x7B)
      assert translated_char_us_ascii == 0x7B # Should be '{' from US ASCII
    end
  end

  describe "translate_string/2" do
    test "translates strings according to the active character set and consumes single shift" do
      state = CharacterSets.new()
      state_french_g0 = CharacterSets.switch_charset(state, :g0, :french)
      state_french_g0 = CharacterSets.set_gl(state_french_g0, :g0)
      # "#a" -> French: "£a"
      assert CharacterSets.translate_string(state_french_g0, "#a") == {"£a", state_french_g0}
      assert CharacterSets.translate_string(state_french_g0, "café") == {"café", state_french_g0}

      # Test with single shift consumption for the first character
      state = CharacterSets.switch_charset(state, :g0, :us_ascii) # G0 is US ASCII
      state = CharacterSets.switch_charset(state, :g2, :german)   # G2 is German
      state = CharacterSets.set_gl(state, :g0)

      state_ss2_active = CharacterSets.set_single_shift(state, :ss2) # Activate SS2 (G2 - German)

      # String: "{BC"
      # Expected: '{'(0x7B) via G2 German -> 'ä' (228)
      #           'B'(0x42) via G0 US ASCII (SS2 consumed) -> 'B' (0x42)
      #           'C'(0x43) via G0 US ASCII -> 'C' (0x43)
      # Result: "äBC"
      {translated_string, state_after_ss2} = CharacterSets.translate_string(state_ss2_active, "{BC")

      assert translated_string == "äBC" # Changed from <<228>> <> "BC"
      assert state_after_ss2.single_shift == nil # Single shift consumed
      assert CharacterSets.get_active_charset(state_after_ss2) == :us_ascii # Next active is G0 US ASCII
    end
  end
end
