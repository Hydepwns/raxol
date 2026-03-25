defmodule Raxol.Terminal.ANSI.CharacterSets.Handler do
  @moduledoc """
  Handles character set control sequences and state changes.
  """

  @compile {:no_warn_undefined, Raxol.Terminal.ANSI.CharacterSets.StateManager}

  alias Raxol.Terminal.ANSI.CharacterSets.StateManager

  @doc """
  Handles a character set control sequence.
  """
  def handle_sequence(state, sequence) do
    case sequence do
      # Designate G-sets
      [?/, code] ->
        handle_designation(state, 0, code)

      [?), code] ->
        handle_designation(state, 1, code)

      [?*, code] ->
        handle_designation(state, 2, code)

      [?+, code] ->
        handle_designation(state, 3, code)

      # Locking shifts
      [char] when char in [?N, ?O, ?P, ?Q] ->
        handle_locking_shift(state, char)

      # Single shifts
      [char] when char in [?R, ?S] ->
        handle_single_shift(state, char)

      # Invoke charsets
      [char] when char in [?T, ?U, ?V, ?W] ->
        handle_invoke(state, char)

      # Unknown sequence
      _ ->
        state
    end
  end

  defp handle_designation(state, gset_index, code) do
    designate_charset(state, gset_index, code)
  end

  defp handle_locking_shift(state, char) do
    case char do
      # SI/LS0 - Shift In (Locking Shift G0)
      ?N -> StateManager.set_gl(state, :g0)
      # SO/LS1 - Shift Out (Locking Shift G1)
      ?O -> StateManager.set_gl(state, :g1)
      # LS2 - Locking Shift G2
      ?P -> StateManager.set_gl(state, :g2)
      # LS3 - Locking Shift G3
      ?Q -> StateManager.set_gl(state, :g3)
    end
  end

  defp handle_single_shift(state, char) do
    case char do
      # SS2 - Single Shift G2
      ?R -> StateManager.set_single_shift(state, :g2)
      # SS3 - Single Shift G3
      ?S -> StateManager.set_single_shift(state, :g3)
    end
  end

  defp handle_invoke(state, char) do
    case char do
      # Invoke G0 into GL
      ?T -> StateManager.set_gl(state, :g0)
      # Invoke G1 into GL
      ?U -> StateManager.set_gl(state, :g1)
      # Invoke G2 into GL
      ?V -> StateManager.set_gl(state, :g2)
      # Invoke G3 into GL
      ?W -> StateManager.set_gl(state, :g3)
    end
  end

  @doc """
  Designates a character set to a specific G-set.
  """
  def designate_charset(state, gset_index, code) do
    charset = code_to_charset(code)

    case gset_index do
      0 -> StateManager.set_g0(state, charset)
      1 -> StateManager.set_g1(state, charset)
      2 -> StateManager.set_g2(state, charset)
      3 -> StateManager.set_g3(state, charset)
      _ -> state
    end
  end

  defp code_to_charset(code) do
    case code do
      ?B -> :us_ascii
      ?0 -> :dec_special_graphics
      ?A -> :uk
      ?C -> :finnish
      ?D -> :french
      ?R -> :french
      ?Q -> :french_canadian
      ?K -> :german
      # F is also German character set
      ?F -> :german
      ?Y -> :italian
      ?E -> :norwegian_danish
      ?6 -> :portuguese
      ?Z -> :spanish
      ?H -> :swedish
      ?= -> :swiss
      _ -> :us_ascii
    end
  end

  @doc """
  Sets the locking shift for GL to the specified G-set.
  """
  def set_locking_shift(state, gset) do
    StateManager.set_gl(state, gset)
  end

  @doc """
  Sets the single shift to the specified G-set.
  """
  def set_single_shift(state, gset) do
    StateManager.set_single_shift(state, gset)
  end

  @doc """
  Invokes a character set into GL.
  """
  def invoke_charset(state, gset) do
    StateManager.set_gl(state, gset)
  end
end
