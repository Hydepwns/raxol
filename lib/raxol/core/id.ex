defmodule Raxol.Core.ID do
  @moduledoc """
  Provides functions for generating unique identifiers.
  """

  @doc """
  Generates a unique string identifier.

  Uses `System.unique_integer([:positive])` and converts it to a string.
  While unique within the runtime, these are not guaranteed universally unique like UUIDs.
  """
  @spec generate() :: String.t()
  def generate() do
    System.unique_integer([:positive])
    |> Integer.to_string()
  end
end
