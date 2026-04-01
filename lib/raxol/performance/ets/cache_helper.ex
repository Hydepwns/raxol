defmodule Raxol.Performance.ETS.CacheHelper do
  @moduledoc """
  Shared helpers for ETS-backed LRU and simple caches.
  """

  @doc """
  LRU lookup: returns `{:ok, value}` if found (updating the access timestamp),
  or `:miss` on cache miss.

  Expects entries stored as `{key, value, timestamp}`.
  """
  @spec get_lru(atom(), term()) :: {:ok, term()} | :miss
  def get_lru(table, key) do
    case :ets.lookup(table, key) do
      [{^key, value, _ts}] ->
        _ = :ets.update_element(table, key, {3, System.monotonic_time()})
        {:ok, value}

      [] ->
        :miss
    end
  end

  @doc """
  LRU insert: stores `{key, value, now}` and evicts oldest entries
  when the table exceeds `max_entries`.
  """
  @spec put_lru(atom(), term(), term(), pos_integer()) :: :ok
  def put_lru(table, key, value, max_entries) do
    _ = :ets.insert(table, {key, value, System.monotonic_time()})
    enforce_limit(table, max_entries)
  end

  @doc """
  Simple cache lookup: returns the cached value or calls `compute_fn`
  on miss, caching the result. No TTL or LRU tracking.

  Expects entries stored as `{key, value}`.
  """
  @spec get_or_compute(atom(), term(), (-> term())) :: term()
  def get_or_compute(table, key, compute_fn) do
    case :ets.lookup(table, key) do
      [{^key, value}] ->
        value

      [] ->
        value = compute_fn.()
        :ets.insert(table, {key, value})
        value
    end
  end

  @doc """
  Evicts the oldest entries (by timestamp in element position 3)
  when the table exceeds `max_entries`.
  """
  @spec enforce_limit(atom(), pos_integer()) :: :ok
  def enforce_limit(table, max_entries) do
    case :ets.info(table, :size) do
      size when is_integer(size) and size > max_entries ->
        evict_count = div(size - max_entries, 2) + 1

        entries =
          :ets.tab2list(table)
          |> Enum.sort_by(fn {_key, _value, timestamp} -> timestamp end)
          |> Enum.take(evict_count)

        Enum.each(entries, fn {key, _, _} -> :ets.delete(table, key) end)
        :ok

      _ ->
        :ok
    end
  end
end
