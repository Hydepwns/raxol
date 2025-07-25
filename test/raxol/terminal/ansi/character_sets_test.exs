defmodule Raxol.Terminal.ANSI.CharacterSetsTestV2 do
  use ExUnit.Case

  alias Raxol.Terminal.ANSI.CharacterSets
  alias Raxol.Terminal.ANSI.CharacterSets.{StateManager, Translator}

  describe "CharacterSets" do
    test ~c"translates characters using active character set" do
      state = StateManager.new()
      {value, _} = CharacterSets.translate_char(?a, state)
      assert value == ?a
      {value, _} = CharacterSets.translate_char(?_, state)
      assert value == ?_

      state = StateManager.set_active(state, :dec_special_graphics)
      {value, _} = CharacterSets.translate_char(?_, state)
      assert value == ?─
      {value, _} = CharacterSets.translate_char(?`, state)
      assert value == ?◆
    end

    test ~c"translates strings using active character set" do
      state = StateManager.new()
      assert CharacterSets.translate_string("Hello", state) == "Hello"

      state = StateManager.set_active(state, :dec_special_graphics)
      assert CharacterSets.translate_string("_`", state) == "─◆"
    end

    test ~c"handles single shift character sets" do
      state = StateManager.new()
      state = StateManager.set_single_shift(state, :dec_special_graphics)
      {value, new_state} = CharacterSets.translate_char(95, state)
      assert value == 9472
      {value, _} = CharacterSets.translate_char(97, new_state)
      assert value == 97
    end

    test ~c"clears single shift after use" do
      state = StateManager.new()
      state = StateManager.set_single_shift(state, :dec_special_graphics)
      {_, new_state} = CharacterSets.translate_char(?_, state)
      assert StateManager.get_single_shift(new_state) == nil
    end
  end

  describe "StateManager" do
    test ~c"creates new state with default values" do
      state = StateManager.new()
      assert state.active == :us_ascii
      assert state.single_shift == nil
      assert state.g0 == :us_ascii
      assert state.g1 == :us_ascii
      assert state.g2 == :us_ascii
      assert state.g3 == :us_ascii
      assert state.gl == :g0
      assert state.gr == :g2
    end

    test ~c"sets and gets active character set" do
      state = StateManager.new()
      assert StateManager.get_active(state) == :us_ascii
      state = StateManager.set_active(state, :dec_special_graphics)
      assert StateManager.get_active(state) == :dec_special_graphics
    end

    test ~c"sets and gets single shift character set" do
      state = StateManager.new()
      assert StateManager.get_single_shift(state) == nil
      state = StateManager.set_single_shift(state, :dec_special_graphics)
      assert StateManager.get_single_shift(state) == :dec_special_graphics
      state = StateManager.clear_single_shift(state)
      assert StateManager.get_single_shift(state) == nil
    end

    test ~c"sets and gets G-set character sets" do
      state = StateManager.new()
      state = StateManager.set_gset(state, :g0, :dec_special_graphics)
      assert StateManager.get_gset(state, :g0) == :dec_special_graphics
    end

    test ~c"sets and gets GL/GR character sets" do
      state = StateManager.new()
      state = StateManager.set_gl(state, :g1)
      assert StateManager.get_gl(state) == :g1
      state = StateManager.set_gr(state, :g3)
      assert StateManager.get_gr(state) == :g3
    end

    test ~c"gets active G-set character set" do
      state = StateManager.new()
      state = StateManager.set_gset(state, :g1, :dec_special_graphics)
      state = StateManager.set_gl(state, :g1)
      assert StateManager.get_active_gset(state) == :dec_special_graphics
    end

    test ~c"converts character set codes to atoms" do
      assert StateManager.charset_code_to_atom(?0) == :dec_special_graphics
      assert StateManager.charset_code_to_atom(?A) == :uk
      assert StateManager.charset_code_to_atom(?B) == :us_ascii
      assert StateManager.charset_code_to_atom(?X) == nil
    end

    test ~c"converts G-set indices to atoms" do
      assert StateManager.index_to_gset(0) == :g0
      assert StateManager.index_to_gset(1) == :g1
      assert StateManager.index_to_gset(2) == :g2
      assert StateManager.index_to_gset(3) == :g3
    end
  end

  describe "Translator" do
    test ~c"translates DEC Special Graphics characters" do
      assert Translator.translate_char(?_, :dec_special_graphics, nil) == ?─
      assert Translator.translate_char(?`, :dec_special_graphics, nil) == ?◆
      assert Translator.translate_char(?a, :dec_special_graphics, nil) == ?▒
    end

    test ~c"translates UK characters" do
      assert Translator.translate_char(?#, :uk, nil) == ?£
      assert Translator.translate_char(?a, :uk, nil) == ?a
    end

    test ~c"translates French characters" do
      assert Translator.translate_char(?#, :french, nil) == ?£
      assert Translator.translate_char(?@, :french, nil) == ?à
      assert Translator.translate_char(?[, :french, nil) == ?°
    end

    test ~c"translates German characters" do
      assert Translator.translate_char(?#, :german, nil) == ?§
      assert Translator.translate_char(?@, :german, nil) == ?§
      assert Translator.translate_char(?[, :german, nil) == ?Ä
    end

    test ~c"translates Spanish characters" do
      assert Translator.translate_char(?#, :spanish, nil) == ?ñ
      assert Translator.translate_char(?@, :spanish, nil) == ?¿
      assert Translator.translate_char(?[, :spanish, nil) == ?¡
    end

    test ~c"translates strings" do
      assert Translator.translate_string("_`", :dec_special_graphics, nil) ==
               "─◆"

      assert Translator.translate_string("#@[", :french, nil) == "£à°"
      assert Translator.translate_string("#@[", :german, nil) == "§§Ä"
    end
  end
end
