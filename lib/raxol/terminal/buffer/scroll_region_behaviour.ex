defmodule Raxol.Terminal.Buffer.ScrollRegion.Behaviour do
  @moduledoc """
  Behaviour for terminal scroll region buffer.
  """

  @callback new() :: any()
  @callback set_region(any(), {integer(), integer()}) :: any()
  @callback get_region(any()) :: {integer(), integer()}
  # Add more callbacks as needed for your implementation
end
