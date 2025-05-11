defmodule Raxol.Terminal.ANSI.CharacterSets.Handler do
  @moduledoc """
  Handles character set control sequences and state changes.
  """

  alias Raxol.Terminal.ANSI.CharacterSets.StateManager

  @doc """
  Handles a character set control sequence.
  """
  def handle_sequence(state, sequence) do
    case sequence do
      # Designate G0 character set
      [?/, code] -> designate_charset(state, 0, code)
      # Designate G1 character set
      [?), code] -> designate_charset(state, 1, code)
      # Designate G2 character set
      [?*, code] -> designate_charset(state, 2, code)
      # Designate G3 character set
      [?+, code] -> designate_charset(state, 3, code)
      # Locking Shift G0
      [?N] -> set_locking_shift(state, :g0)
      # Locking Shift G1
      [?O] -> set_locking_shift(state, :g1)
      # Locking Shift G2
      [?P] -> set_locking_shift(state, :g2)
      # Locking Shift G3
      [?Q] -> set_locking_shift(state, :g3)
      # Single Shift G2
      [?R] -> set_single_shift(state, :g2)
      # Single Shift G3
      [?S] -> set_single_shift(state, :g3)
      # Invoke G0
      [?T] -> invoke_charset(state, :g0)
      # Invoke G1
      [?U] -> invoke_charset(state, :g1)
      # Invoke G2
      [?V] -> invoke_charset(state, :g2)
      # Invoke G3
      [?W] -> invoke_charset(state, :g3)
      # Unknown sequence
      _ -> state
    end
  end

  @doc """
  Designates a character set for a specific G-set.
  """
  def designate_charset(state, gset_index, code) do
    case StateManager.charset_code_to_atom(code) do
      nil -> state
      charset -> StateManager.set_gset(state, StateManager.index_to_gset(gset_index), charset)
    end
  end

  @doc """
  Sets a locking shift character set.
  """
  def set_locking_shift(state, gset) do
    StateManager.set_gl(state, gset)
  end

  @doc """
  Sets a single shift character set.
  """
  def set_single_shift(state, gset) do
    StateManager.set_single_shift(state, StateManager.get_gset(state, gset))
  end

  @doc """
  Invokes a character set.
  """
  def invoke_charset(state, gset) do
    StateManager.set_gl(state, gset)
  end
end
