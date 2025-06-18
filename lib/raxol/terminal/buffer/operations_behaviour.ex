defmodule Raxol.Terminal.Buffer.OperationsBehaviour do
  @moduledoc '''
  Defines the behaviour for terminal buffer operations.
  '''

  @type buffer :: list(list(Raxol.Terminal.Buffer.Cell.t()))
  @type style :: map()

  @callback resize(buffer, non_neg_integer(), non_neg_integer()) :: buffer
  @callback maybe_scroll(buffer) :: buffer
  @callback next_line(buffer) :: buffer
  @callback reverse_index(buffer) :: buffer
  @callback index(buffer) :: buffer
  @callback scroll_up(buffer, pos_integer(), non_neg_integer(), non_neg_integer()) :: {buffer, non_neg_integer(), non_neg_integer()}
  @callback scroll_down(buffer, pos_integer(), non_neg_integer(), non_neg_integer()) :: {buffer, non_neg_integer(), non_neg_integer()}
  @callback insert_lines(buffer, pos_integer(), non_neg_integer(), non_neg_integer()) :: {buffer, non_neg_integer(), non_neg_integer()}
  @callback insert_lines(buffer, pos_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: {buffer, non_neg_integer(), non_neg_integer()}
  @callback delete_lines(buffer, pos_integer(), non_neg_integer(), non_neg_integer()) :: {buffer, non_neg_integer(), non_neg_integer()}
  @callback delete_lines(buffer, pos_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: {buffer, non_neg_integer(), non_neg_integer()}
  @callback erase_in_line(buffer, 0..2, non_neg_integer(), non_neg_integer()) :: {buffer, non_neg_integer(), non_neg_integer()}
  @callback erase_in_display(buffer, 0..2, non_neg_integer(), non_neg_integer()) :: {buffer, non_neg_integer(), non_neg_integer()}
  @callback write_char(buffer, non_neg_integer(), non_neg_integer(), binary(), style()) :: {buffer, non_neg_integer(), non_neg_integer()}
end
