defmodule Raxol.Core.Accessibility.Mock do
  @moduledoc """
  Mock implementation for Raxol.Core.Accessibility.

  This module provides manual definitions for functions expected to be
  called during tests when Raxol.Core.Accessibility is replaced
  using Mox.stub_with/2.
  """

  # Define the functions needed for tests directly.
  # Mox.expect/3 will be used in the test to set expectations on these.
  def announce(_message, _opts \\ []) do
    # Default implementation, can be overridden by Mox.expect
    :ok
  end

  # Add other function definitions here if needed for other
  # Accessibility functions called in tests.
  # Example:
  # def set_high_contrast(_enabled), do: :ok
end
