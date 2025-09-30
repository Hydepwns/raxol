defmodule Raxol.Terminal.ANSI.CharacterSetsTest do
  use ExUnit.Case, async: false
  alias Raxol.Terminal.ANSI.CharacterSets

  describe "new/0" do
    test ~c"creates a new character set state with default values" do
      state = CharacterSets.new()
      assert state.g0 == Raxol.Terminal.ANSI.CharacterSets.ASCII
      assert state.g1 == Raxol.Terminal.ANSI.CharacterSets.DEC
      assert state.g2 == Raxol.Terminal.ANSI.CharacterSets.UK
      assert state.g3 == Raxol.Terminal.ANSI.CharacterSets.UK
      assert state.current == Raxol.Terminal.ANSI.CharacterSets.ASCII
      assert state.gl == :g0
      assert state.gr == :g1
      assert state.single_shift == nil
      assert state.locked_shift == false
    end
  end

  describe "set_single_shift/2" do
    test ~c"sets SS2 shift to G2 character set" do
      state = CharacterSets.new()
      state = CharacterSets.set_single_shift(state, :ss2)
      assert state.single_shift == state.g2
    end

    test ~c"sets SS3 shift to G3 character set" do
      state = CharacterSets.new()
      state = CharacterSets.set_single_shift(state, :ss3)
      assert state.single_shift == state.g3
    end
  end

  describe "clear_single_shift/1" do
    test ~c"clears active single shift" do
      state = CharacterSets.new()
      state = CharacterSets.set_single_shift(state, :ss2)
      assert state.single_shift != nil
      state = CharacterSets.clear_single_shift(state)
      assert state.single_shift == nil
    end
  end

  describe "switch_charset/3" do
    test ~c"switches G0 character set" do
      state = CharacterSets.new()

      new_state =
        CharacterSets.switch_charset(
          state,
          :g0,
          Raxol.Terminal.ANSI.CharacterSets.DEC
        )

      assert new_state.g0 == Raxol.Terminal.ANSI.CharacterSets.DEC
    end

    test ~c"switches G1 character set" do
      state = CharacterSets.new()

      new_state =
        CharacterSets.switch_charset(
          state,
          :g1,
          Raxol.Terminal.ANSI.CharacterSets.ASCII
        )

      assert new_state.g1 == Raxol.Terminal.ANSI.CharacterSets.ASCII
    end
  end

  describe "set_gl/2 and set_gr/2" do
    test ~c"sets GL to G0" do
      state = CharacterSets.new()
      new_state = CharacterSets.set_gl(state, :g0)
      assert new_state.gl == :g0
    end

    test ~c"sets GR to G2" do
      state = CharacterSets.new()
      new_state = CharacterSets.set_gr(state, :g2)
      assert new_state.gr == :g2
    end
  end

  describe "get_active_charset/1" do
    test ~c"returns single shift charset when active" do
      state = CharacterSets.new()
      state = CharacterSets.set_single_shift(state, :ss2)
      assert CharacterSets.get_active_charset(state) == state.g2
    end

    test ~c"returns GR charset when locked shift is active" do
      state = CharacterSets.new()
      state = %{state | locked_shift: true}
      assert CharacterSets.get_active_charset(state) == state.g1
    end

    test ~c"returns GL charset by default" do
      state = CharacterSets.new()
      assert CharacterSets.get_active_charset(state) == state.g0
    end
  end

  describe "translate_char/2" do
    @tag :skip
    test ~c"translates character using active charset" do
      state = CharacterSets.new()
      # Test ASCII translation (no change)
      {value, _} = CharacterSets.translate_char(?A, state)
      assert value == ?A

      # Test DEC Special Graphics translation
      state =
        CharacterSets.switch_charset(
          state,
          :g0,
          Raxol.Terminal.ANSI.CharacterSets.DEC
        )

      {value, _} = CharacterSets.translate_char(?_, state)
      assert value == 9472
    end

    @tag :skip
    test ~c"handles single shift translation" do
      state = CharacterSets.new()
      # Set G2 to DEC Special Graphics for the test
      state =
        CharacterSets.switch_charset(
          state,
          :g2,
          Raxol.Terminal.ANSI.CharacterSets.DEC
        )

      state = CharacterSets.set_single_shift(state, :ss2)
      # Test DEC Special Graphics translation with single shift
      {value, _} = CharacterSets.translate_char(?_, state)
      assert value == 9472
    end
  end

  describe "translate_string/2" do
    @tag :skip
    test ~c"translates string using active charset" do
      state = CharacterSets.new()
      # Test ASCII translation (no change)
      assert CharacterSets.translate_string("Hello", state) == "Hello"

      # Test DEC Special Graphics translation
      state =
        CharacterSets.switch_charset(
          state,
          :g0,
          Raxol.Terminal.ANSI.CharacterSets.DEC
        )

      # Note: DEC charset should translate "_" to box drawing character (codepoint 9472)
      translated = CharacterSets.translate_string("_", state)
      assert translated == <<9472::utf8>>
    end
  end

  describe "charset_code_to_module/1" do
    test ~c"maps ASCII code to ASCII module" do
      assert CharacterSets.charset_code_to_module(?B) ==
               Raxol.Terminal.ANSI.CharacterSets.ASCII
    end

    test ~c"maps DEC Special Graphics code to DEC module" do
      assert CharacterSets.charset_code_to_module(?0) ==
               Raxol.Terminal.ANSI.CharacterSets.DEC
    end

    test ~c"maps UK code to UK module" do
      assert CharacterSets.charset_code_to_module(?A) ==
               Raxol.Terminal.ANSI.CharacterSets.UK
    end

    test ~c"returns nil for unknown codes" do
      assert CharacterSets.charset_code_to_module(?X) == nil
    end
  end

  describe "index_to_gset/1" do
    test ~c"maps valid indices to gset names" do
      assert CharacterSets.index_to_gset(0) == :g0
      assert CharacterSets.index_to_gset(1) == :g1
      assert CharacterSets.index_to_gset(2) == :g2
      assert CharacterSets.index_to_gset(3) == :g3
    end

    test ~c"returns nil for invalid indices" do
      assert CharacterSets.index_to_gset(4) == nil
      assert CharacterSets.index_to_gset(-1) == nil
    end
  end
end
