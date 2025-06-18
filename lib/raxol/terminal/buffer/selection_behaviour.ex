defmodule Raxol.Terminal.Buffer.Selection.Behaviour do
  @moduledoc '''
  Behaviour for terminal selection buffer.
  '''

  @callback new() :: any()
  @callback set_selection(any(), {integer(), integer()}, {integer(), integer()}) ::
              any()
  @callback get_selection(any()) ::
              {{integer(), integer()}, {integer(), integer()}}
  # Add more callbacks as needed for your implementation
end
