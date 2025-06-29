defmodule Raxol.Terminal.Buffer.Manager.Behaviour do
  @moduledoc """
  Behaviour for terminal buffer management.
  """

  @callback initialize_buffers(
              pid :: pid(),
              width :: non_neg_integer(),
              height :: non_neg_integer(),
              opts :: keyword()
            ) :: map()
  @callback write(pid :: pid(), data :: term(), opts :: keyword()) :: :ok
  @callback read(pid :: pid(), opts :: keyword()) :: term()
  @callback resize(
              pid :: pid(),
              size :: {non_neg_integer(), non_neg_integer()},
              opts :: keyword()
            ) :: :ok
  @callback scroll(pid :: pid(), lines :: integer()) :: :ok
  @callback set_cell(
              pid :: pid(),
              x :: non_neg_integer(),
              y :: non_neg_integer(),
              cell :: term()
            ) :: :ok
  @callback get_cell(pid :: pid(), x :: non_neg_integer(), y :: non_neg_integer()) :: term()
  @callback clear_damage(pid :: pid()) :: :ok
  @callback get_memory_usage(pid :: pid()) :: non_neg_integer()
  @callback get_scrollback_count(pid :: pid()) :: non_neg_integer()
  @callback get_metrics(pid :: pid()) :: map()
end
