defmodule Raxol.Core.StateManager do
  @moduledoc """
  Shared utilities for managing process-local state.
  """

  @doc """
  Executes a function with the current state, updating it if the function returns a tuple.
  """
  def with_state(state_key, fun) do
    state = Process.get(state_key) || %{}

    case fun.(state) do
      {new_state, result} ->
        Process.put(state_key, new_state)
        result

      new_state ->
        Process.put(state_key, new_state)
        nil
    end
  end
end
