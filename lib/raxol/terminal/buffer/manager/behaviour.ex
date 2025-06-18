defmodule Raxol.Terminal.Buffer.Manager.Behaviour do
  @moduledoc '''
  Behaviour for terminal buffer management.
  '''

  @callback initialize_buffers(
              width :: non_neg_integer(),
              height :: non_neg_integer(),
              opts :: keyword()
            ) :: map()
  @callback write(data :: term(), opts :: keyword()) :: :ok
  @callback read(opts :: keyword()) :: term()
  @callback resize(
              size :: {non_neg_integer(), non_neg_integer()},
              opts :: keyword()
            ) :: :ok
  @callback scroll(lines :: integer()) :: :ok
  @callback set_cell(
              x :: non_neg_integer(),
              y :: non_neg_integer(),
              cell :: term()
            ) :: :ok
  @callback get_cell(x :: non_neg_integer(), y :: non_neg_integer()) :: term()
  @callback clear_damage() :: :ok
  @callback get_memory_usage() :: non_neg_integer()
  @callback get_scrollback_count() :: non_neg_integer()
  @callback get_metrics() :: map()
end
