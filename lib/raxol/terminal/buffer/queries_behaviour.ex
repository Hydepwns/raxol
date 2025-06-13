defmodule Raxol.Terminal.Buffer.Queries.Behaviour do
  @moduledoc """
  Behaviour for terminal buffer querying operations.
  This module defines the callbacks required for querying the state of the screen buffer,
  including dimensions, content, and selection state.
  """

  alias Raxol.Terminal.Cell

  @callback get_dimensions(term()) :: {non_neg_integer(), non_neg_integer()}
  @callback get_width(term()) :: non_neg_integer()
  @callback get_height(term()) :: non_neg_integer()
  @callback get_content(term()) :: list(list(Cell.t()))
  @callback get_line(term(), non_neg_integer()) :: list(Cell.t())
  @callback get_cell(term(), non_neg_integer(), non_neg_integer()) :: Cell.t()
  @callback get_text(term()) :: String.t()
  @callback get_line_text(term(), non_neg_integer()) :: String.t()
  @callback in_bounds?(term(), non_neg_integer(), non_neg_integer()) :: boolean()
  @callback is_empty?(term()) :: boolean()
  @callback get_char(term(), non_neg_integer(), non_neg_integer()) :: String.t()
end
