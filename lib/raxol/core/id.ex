defmodule Raxol.Core.ID do
  @moduledoc '''
  Provides functions for generating unique identifiers.
  '''

  @doc '''
  Generates a unique string identifier.

  Uses Erlang's `make_ref` and converts it to a string representation.
  While unique within the runtime, refs are not guaranteed universally unique
  like UUIDs.
  '''
  @spec generate() :: String.t()
  def generate() do
    :erlang.make_ref()
    # Convert ref to charlist
    |> :erlang.ref_to_list()
    # Convert charlist to string
    |> List.to_string()
  end
end
