defmodule Raxol.Terminal.ANSI.CharacterSets.HandlerTest do
  use ExUnit.Case
  # remove charactersets terminal ansi.{Handler, StateManager}

  describe "handle_sequence/2" do
    test "handles G0 character set designation" do
      state = StateManager.new()
      state = Handler.handle_sequence(state, [?/, ?B])  # US ASCII
      assert StateManager.get_gset(state, :g0) == :us_ascii

      state = Handler.handle_sequence(state, [?/, ?0])  # DEC Special Graphics
      assert StateManager.get_gset(state, :g0) == :dec_special_graphics
    end

    test "handles G1 character set designation" do
      state = StateManager.new()
      state = Handler.handle_sequence(state, [?), ?B])  # US ASCII
      assert StateManager.get_gset(state, :g1) == :us_ascii

      state = Handler.handle_sequence(state, [?), ?A])  # UK
      assert StateManager.get_gset(state, :g1) == :uk
    end

    test "handles G2 character set designation" do
      state = StateManager.new()
      state = Handler.handle_sequence(state, [?*, ?B])  # US ASCII
      assert StateManager.get_gset(state, :g2) == :us_ascii

      state = Handler.handle_sequence(state, [?*, ?F])  # German
      assert StateManager.get_gset(state, :g2) == :german
    end

    test "handles G3 character set designation" do
      state = StateManager.new()
      state = Handler.handle_sequence(state, [?+, ?B])  # US ASCII
      assert StateManager.get_gset(state, :g3) == :us_ascii

      state = Handler.handle_sequence(state, [?+, ?D])  # French
      assert StateManager.get_gset(state, :g3) == :french
    end

    test "handles locking shift sequences" do
      state = StateManager.new()
      state = Handler.handle_sequence(state, [?N])  # Locking Shift G0
      assert StateManager.get_gl(state) == :g0

      state = Handler.handle_sequence(state, [?O])  # Locking Shift G1
      assert StateManager.get_gl(state) == :g1

      state = Handler.handle_sequence(state, [?P])  # Locking Shift G2
      assert StateManager.get_gl(state) == :g2

      state = Handler.handle_sequence(state, [?Q])  # Locking Shift G3
      assert StateManager.get_gl(state) == :g3
    end

    test "handles single shift sequences" do
      state = StateManager.new()
      state = StateManager.set_gset(state, :g2, :german)
      state = StateManager.set_gset(state, :g3, :french)

      state = Handler.handle_sequence(state, [?R])  # Single Shift G2
      assert StateManager.get_single_shift(state) == :german

      state = Handler.handle_sequence(state, [?S])  # Single Shift G3
      assert StateManager.get_single_shift(state) == :french
    end

    test "handles invoke sequences" do
      state = StateManager.new()
      state = Handler.handle_sequence(state, [?T])  # Invoke G0
      assert StateManager.get_gl(state) == :g0

      state = Handler.handle_sequence(state, [?U])  # Invoke G1
      assert StateManager.get_gl(state) == :g1

      state = Handler.handle_sequence(state, [?V])  # Invoke G2
      assert StateManager.get_gl(state) == :g2

      state = Handler.handle_sequence(state, [?W])  # Invoke G3
      assert StateManager.get_gl(state) == :g3
    end

    test "ignores unknown sequences" do
      state = StateManager.new()
      original_state = state
      state = Handler.handle_sequence(state, [?X])  # Unknown sequence
      assert state == original_state
    end
  end

  describe "designate_charset/3" do
    test "designates character sets correctly" do
      state = StateManager.new()
      state = Handler.designate_charset(state, 0, ?B)  # US ASCII
      assert StateManager.get_gset(state, :g0) == :us_ascii

      state = Handler.designate_charset(state, 1, ?A)  # UK
      assert StateManager.get_gset(state, :g1) == :uk

      state = Handler.designate_charset(state, 2, ?F)  # German
      assert StateManager.get_gset(state, :g2) == :german

      state = Handler.designate_charset(state, 3, ?D)  # French
      assert StateManager.get_gset(state, :g3) == :french
    end

    test "ignores invalid character set codes" do
      state = StateManager.new()
      original_state = state
      state = Handler.designate_charset(state, 0, ?X)  # Invalid code
      assert state == original_state
    end
  end

  describe "set_locking_shift/2" do
    test "sets locking shift correctly" do
      state = StateManager.new()
      state = Handler.set_locking_shift(state, :g0)
      assert StateManager.get_gl(state) == :g0

      state = Handler.set_locking_shift(state, :g1)
      assert StateManager.get_gl(state) == :g1

      state = Handler.set_locking_shift(state, :g2)
      assert StateManager.get_gl(state) == :g2

      state = Handler.set_locking_shift(state, :g3)
      assert StateManager.get_gl(state) == :g3
    end
  end

  describe "set_single_shift/2" do
    test "sets single shift correctly" do
      state = StateManager.new()
      state = StateManager.set_gset(state, :g2, :german)
      state = Handler.set_single_shift(state, :g2)
      assert StateManager.get_single_shift(state) == :german

      state = StateManager.set_gset(state, :g3, :french)
      state = Handler.set_single_shift(state, :g3)
      assert StateManager.get_single_shift(state) == :french
    end
  end

  describe "invoke_charset/2" do
    test "invokes character sets correctly" do
      state = StateManager.new()
      state = Handler.invoke_charset(state, :g0)
      assert StateManager.get_gl(state) == :g0

      state = Handler.invoke_charset(state, :g1)
      assert StateManager.get_gl(state) == :g1

      state = Handler.invoke_charset(state, :g2)
      assert StateManager.get_gl(state) == :g2

      state = Handler.invoke_charset(state, :g3)
      assert StateManager.get_gl(state) == :g3
    end
  end
end
