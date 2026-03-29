defmodule Raxol.UI.Layout.StreamScrollContent do
  @moduledoc """
  ScrollContent adapter for lazy/streaming data sources.

  Takes a fetch function `(offset, count) -> [element]` and caches a sliding
  window of elements around the current scroll position. Enables viewport
  rendering of arbitrarily large datasets without materializing them all.

  The total count must be known upfront (or estimated) for scrollbar rendering.
  """

  @behaviour Raxol.UI.Layout.ScrollContent

  defstruct [
    :fetch_fn,
    :total,
    :cache_start,
    :cache_items,
    cache_size: 100
  ]

  @type t :: %__MODULE__{
          fetch_fn: (non_neg_integer(), pos_integer() -> [map()]),
          total: non_neg_integer(),
          cache_start: non_neg_integer() | nil,
          cache_items: [map()] | nil,
          cache_size: pos_integer()
        }

  @doc """
  Creates a new streaming scroll content source.

  ## Options

  - `fetch_fn` - `fn offset, count -> [element]` that retrieves a slice
  - `total` - total number of items (for scrollbar calculation)
  - `cache_size` - number of items to cache around the viewport (default: 100)
  """
  @spec new(keyword()) :: t()
  def new(opts) do
    %__MODULE__{
      fetch_fn: Keyword.fetch!(opts, :fetch_fn),
      total: Keyword.fetch!(opts, :total),
      cache_size: Keyword.get(opts, :cache_size, 100)
    }
  end

  @impl true
  def total_count(%__MODULE__{total: total}), do: total

  @impl true
  def slice(%__MODULE__{} = state, offset, count) do
    case cache_hit?(state, offset, count) do
      true ->
        cache_offset = offset - state.cache_start
        Enum.slice(state.cache_items, cache_offset, count)

      false ->
        # Cache miss: fetch a window centered on the requested range
        fetch_and_cache(state, offset, count)
    end
  end

  @impl true
  def item_height(_state, _index), do: 1

  @doc """
  Fetches and caches a window of items, returning the requested slice.

  Also returns the updated state with the new cache for the caller to store.
  Use `fetch_and_update/3` if you need the updated state back.
  """
  @spec fetch_and_update(t(), non_neg_integer(), pos_integer()) ::
          {[map()], t()}
  def fetch_and_update(%__MODULE__{} = state, offset, count) do
    # Center the cache window around the requested range
    half_cache = div(state.cache_size, 2)
    cache_start = max(0, offset - half_cache)
    fetch_count = min(state.cache_size, state.total - cache_start)

    items = state.fetch_fn.(cache_start, fetch_count)

    new_state = %{state | cache_start: cache_start, cache_items: items}
    cache_offset = offset - cache_start
    slice = Enum.slice(items, cache_offset, count)

    {slice, new_state}
  end

  defp cache_hit?(%{cache_start: nil}, _offset, _count), do: false
  defp cache_hit?(%{cache_items: nil}, _offset, _count), do: false

  defp cache_hit?(state, offset, count) do
    offset >= state.cache_start and
      offset + count <= state.cache_start + length(state.cache_items)
  end

  defp fetch_and_cache(state, offset, count) do
    {slice, _new_state} = fetch_and_update(state, offset, count)
    slice
  end
end
