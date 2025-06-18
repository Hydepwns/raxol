defmodule Raxol.Terminal.ANSI.CharacterSets.HandlerTest do
  use ExUnit.Case
  alias Raxol.Terminal.ANSI.CharacterSets.Handler
  alias Raxol.Terminal.ANSI.CharacterSets.StateManager

  describe "handle_sequence/2" do
    test 'handles G0 character set designation' do
      state = StateManager.new()
      # US ASCII
      state = Handler.handle_sequence(state, [?/, ?B])
      assert StateManager.get_gset(state, :g0) == :us_ascii

      # DEC Special Graphics
      state = Handler.handle_sequence(state, [?/, ?0])
      assert StateManager.get_gset(state, :g0) == :dec_special_graphics
    end

    test 'handles G1 character set designation' do
      state = StateManager.new()
      # US ASCII
      state = Handler.handle_sequence(state, [?), ?B])
      assert StateManager.get_gset(state, :g1) == :us_ascii

      # UK
      state = Handler.handle_sequence(state, [?), ?A])
      assert StateManager.get_gset(state, :g1) == :uk
    end

    test 'handles G2 character set designation' do
      state = StateManager.new()
      # US ASCII
      state = Handler.handle_sequence(state, [?*, ?B])
      assert StateManager.get_gset(state, :g2) == :us_ascii

      # German
      state = Handler.handle_sequence(state, [?*, ?F])
      assert StateManager.get_gset(state, :g2) == :german
    end

    test 'handles G3 character set designation' do
      state = StateManager.new()
      # US ASCII
      state = Handler.handle_sequence(state, [?+, ?B])
      assert StateManager.get_gset(state, :g3) == :us_ascii

      # French
      state = Handler.handle_sequence(state, [?+, ?D])
      assert StateManager.get_gset(state, :g3) == :french
    end

    test 'handles locking shift sequences' do
      state = StateManager.new()

      # Locking Shift G0
      state = Handler.handle_sequence(state, [?N])
      assert StateManager.get_gl(state) == :g0

      # Locking Shift G1
      state = Handler.handle_sequence(state, [?O])
      assert StateManager.get_gl(state) == :g1

      # Locking Shift G2
      state = Handler.handle_sequence(state, [?P])
      assert StateManager.get_gl(state) == :g2

      # Locking Shift G3
      state = Handler.handle_sequence(state, [?Q])
      assert StateManager.get_gl(state) == :g3
    end

    test 'handles single shift sequences' do
      state = StateManager.new()

      # Single Shift G2
      state = Handler.handle_sequence(state, [?R])

      assert StateManager.get_single_shift(state) ==
               StateManager.get_gset(state, :g2)

      # Single Shift G3
      state = Handler.handle_sequence(state, [?S])

      assert StateManager.get_single_shift(state) ==
               StateManager.get_gset(state, :g3)
    end

    test 'handles invoke sequences' do
      state = StateManager.new()

      # Invoke G0
      state = Handler.handle_sequence(state, [?T])
      assert StateManager.get_gl(state) == :g0

      # Invoke G1
      state = Handler.handle_sequence(state, [?U])
      assert StateManager.get_gl(state) == :g1

      # Invoke G2
      state = Handler.handle_sequence(state, [?V])
      assert StateManager.get_gl(state) == :g2

      # Invoke G3
      state = Handler.handle_sequence(state, [?W])
      assert StateManager.get_gl(state) == :g3
    end

    test 'ignores unknown sequences' do
      state = StateManager.new()
      original_state = state
      state = Handler.handle_sequence(state, [?X])
      assert state == original_state
    end
  end

  describe "designate_charset/3" do
    test 'designates valid character sets' do
      state = StateManager.new()

      # Designate US ASCII to G0
      state = Handler.designate_charset(state, 0, ?B)
      assert StateManager.get_gset(state, :g0) == :us_ascii

      # Designate DEC Special Graphics to G1
      state = Handler.designate_charset(state, 1, ?0)
      assert StateManager.get_gset(state, :g1) == :dec_special_graphics

      # Designate UK to G2
      state = Handler.designate_charset(state, 2, ?A)
      assert StateManager.get_gset(state, :g2) == :uk

      # Designate French to G3
      state = Handler.designate_charset(state, 3, ?D)
      assert StateManager.get_gset(state, :g3) == :french
    end

    test 'ignores invalid character set codes' do
      state = StateManager.new()
      original_state = state
      state = Handler.designate_charset(state, 0, ?X)
      assert state == original_state
    end

    test 'ignores invalid G-set indices' do
      state = StateManager.new()
      original_state = state
      state = Handler.designate_charset(state, 4, ?B)
      assert state == original_state
    end
  end

  describe "set_locking_shift/2" do
    test 'sets GL to specified G-set' do
      state = StateManager.new()

      # Set GL to G0
      state = Handler.set_locking_shift(state, :g0)
      assert StateManager.get_gl(state) == :g0

      # Set GL to G1
      state = Handler.set_locking_shift(state, :g1)
      assert StateManager.get_gl(state) == :g1

      # Set GL to G2
      state = Handler.set_locking_shift(state, :g2)
      assert StateManager.get_gl(state) == :g2

      # Set GL to G3
      state = Handler.set_locking_shift(state, :g3)
      assert StateManager.get_gl(state) == :g3
    end
  end

  describe "set_single_shift/2" do
    test 'sets single shift to specified G-set's charset' do
      state = StateManager.new()

      # Set single shift to G2's charset
      state = Handler.set_single_shift(state, :g2)

      assert StateManager.get_single_shift(state) ==
               StateManager.get_gset(state, :g2)

      # Set single shift to G3's charset
      state = Handler.set_single_shift(state, :g3)

      assert StateManager.get_single_shift(state) ==
               StateManager.get_gset(state, :g3)
    end
  end

  describe "invoke_charset/2" do
    test 'invokes specified G-set into GL' do
      state = StateManager.new()

      # Invoke G0
      state = Handler.invoke_charset(state, :g0)
      assert StateManager.get_gl(state) == :g0

      # Invoke G1
      state = Handler.invoke_charset(state, :g1)
      assert StateManager.get_gl(state) == :g1

      # Invoke G2
      state = Handler.invoke_charset(state, :g2)
      assert StateManager.get_gl(state) == :g2

      # Invoke G3
      state = Handler.invoke_charset(state, :g3)
      assert StateManager.get_gl(state) == :g3
    end
  end
end
