defmodule Raxol.UI.Layout.ScrollContent do
  @moduledoc """
  Behaviour for content sources that support cursor-based streaming.

  Inspired by Pretext's `layoutNextLine()` cursor-based API, this behaviour
  allows scrollable containers (Viewport, Table) to request only the visible
  slice of content instead of materializing the full list.

  Implementations can wrap in-memory lists, ETS tables, database queries,
  or streaming sources. The Viewport component uses this to render only
  visible elements without holding the entire dataset in memory.
  """

  @doc "Returns the total number of items in the content source."
  @callback total_count(state :: term()) :: non_neg_integer()

  @doc "Returns a slice of items starting at `offset` with at most `count` items."
  @callback slice(
              state :: term(),
              offset :: non_neg_integer(),
              count :: pos_integer()
            ) :: [map()]

  @doc "Returns the height (in rows) of the item at `index`. Defaults to 1."
  @callback item_height(state :: term(), index :: non_neg_integer()) ::
              pos_integer()

  @optional_callbacks [item_height: 2]
end
