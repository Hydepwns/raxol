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
      # Designate G-sets
      [?/, code] -> handle_designation(state, 0, code)
      [?), code] -> handle_designation(state, 1, code)
      [?*, code] -> handle_designation(state, 2, code)
      [?+, code] -> handle_designation(state, 3, code)
      # Locking shifts
      [char] when char in [?N, ?O, ?P, ?Q] -> handle_locking_shift(state, char)
      # Single shifts  
      [char] when char in [?R, ?S] -> handle_single_shift(state, char)
      # Invoke charsets
      [char] when char in [?T, ?U, ?V, ?W] -> handle_invoke(state, char)
      # Unknown sequence
      _ -> state
    end
  end

  defp handle_designation(state, gset_index, code) do
    designate_charset(state, gset_index, code)
  end

  defp handle_locking_shift(state, char) do
    gset =
      case char do
        ?N -> :g0
        ?O -> :g1
        ?P -> :g2
        ?Q -> :g3
      end

    set_locking_shift(state, gset)
  end

  defp handle_single_shift(state, char) do
    gset =
      case char do
        ?R -> :g2
        ?S -> :g3
      end

    set_single_shift(state, gset)
  end

  defp handle_invoke(state, char) do
    gset =
      case char do
        ?T -> :g0
        ?U -> :g1
        ?V -> :g2
        ?W -> :g3
      end

    invoke_charset(state, gset)
  end

  @doc """
  Designates a character set for a specific G-set.
  """
  def designate_charset(state, gset_index, code) do
    case StateManager.charset_code_to_atom(code) do
      nil ->
        state

      charset ->
        # If gset_index is already an atom (g0, g1, g2, g3), use it directly
        # If it's an integer, convert it
        gset = case gset_index do
          :g0 -> :g0
          :g1 -> :g1
          :g2 -> :g2
          :g3 -> :g3
          index when is_integer(index) ->
            StateManager.index_to_gset(index)
          _ -> nil
        end
        
        case gset do
          nil -> state
          _ -> StateManager.set_gset(state, gset, charset)
        end
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
