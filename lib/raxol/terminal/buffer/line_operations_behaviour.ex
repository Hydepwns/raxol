defmodule Raxol.Terminal.Buffer.LineOperations.Behaviour do
  @moduledoc '''
  Behaviour for terminal buffer line operations.
  This module defines the callbacks required for manipulating lines in the screen buffer.
  '''

  alias Raxol.Terminal.{
    Cell
  }

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell

  @callback insert_lines(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
              ScreenBuffer.t()
  @callback delete_lines(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
              ScreenBuffer.t()
  @callback prepend_lines(ScreenBuffer.t(), non_neg_integer()) ::
              ScreenBuffer.t()
  @callback pop_top_lines(ScreenBuffer.t(), non_neg_integer()) ::
              ScreenBuffer.t()
  @callback get_line(ScreenBuffer.t(), non_neg_integer()) :: list(Cell.t())
  @callback set_line(ScreenBuffer.t(), non_neg_integer(), list(Cell.t())) ::
              ScreenBuffer.t()
  @callback delete_lines(map(), integer(), integer(), integer(), integer()) ::
              map()
end
