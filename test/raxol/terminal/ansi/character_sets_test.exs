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

  describe "set_single_shift/2" do
    test "sets and clears the single shift character set" do
      state = CharacterSets.new()
      state = CharacterSets.set_single_shift(state, :g2)

      assert state.single_shift == :g2
      state = CharacterSets.set_single_shift(state, nil)

      assert state.single_shift == nil
    end
  end

  describe "get_active_charset/1" do
    test "returns the correct active character set" do
      state = CharacterSets.new()
      state = CharacterSets.switch_charset(state, :g0, :french)
      state = CharacterSets.switch_charset(state, :g1, :german)
      state = CharacterSets.set_gl(state, :g0)
      assert CharacterSets.get_active_charset(state) == :french
      state = CharacterSets.set_gl(state, :g1)
      assert CharacterSets.get_active_charset(state) == :german
      state = CharacterSets.set_single_shift(state, :g0)
      assert CharacterSets.get_active_charset(state) == :french
      state = %{state | locked_shift: true}
      assert CharacterSets.get_active_charset(state) == :german
    end
  end

  describe "translate_char/2" do
    test "translates characters according to the active character set" do
      state = CharacterSets.new()
      state = CharacterSets.switch_charset(state, :g0, :french)
      state = CharacterSets.set_gl(state, :g0)
      assert CharacterSets.translate_char(state, 0x23) == ?£
      assert CharacterSets.translate_char(state, ?a) == ?a
    end
  end

  describe "translate_string/2" do
    test "translates strings according to the active character set" do
      state = CharacterSets.new()
      state = CharacterSets.switch_charset(state, :g0, :french)
      state = CharacterSets.set_gl(state, :g0)
      assert CharacterSets.translate_string(state, "Hello") == "Hello"
      assert CharacterSets.translate_string(state, "café") == "café"
    end
  end
end
