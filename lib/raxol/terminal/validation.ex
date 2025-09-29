defmodule Raxol.Terminal.Validation do
  @moduledoc """
  Stub module for terminal input validation.

  This module provides basic validation functionality for terminal input.
  Currently implemented as a stub for test compatibility.
  """

  @doc """
  Validates input at the specified position in the buffer.

  This is a stub implementation that always returns success.
  """
  @spec validate_input(any(), non_neg_integer(), non_neg_integer(), String.t()) ::
          {:ok, :valid}
  def validate_input(_buffer, _x, _y, _input) do
    # Stub implementation - always returns valid
    {:ok, :valid}
  end
end