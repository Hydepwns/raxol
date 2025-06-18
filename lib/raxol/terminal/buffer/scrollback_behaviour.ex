defmodule Raxol.Terminal.Buffer.Scrollback.Behaviour do
  @moduledoc '''
  Behaviour for terminal scrollback buffer.
  '''

  @callback new() :: any()
  @callback add_line(any(), String.t()) :: any()
  @callback get_lines(any()) :: [String.t()]
end
