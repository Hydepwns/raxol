defmodule Raxol.Terminal.Cache.EvictionHelpers do
  @moduledoc '''
  Helper functions for cache eviction strategies.
  Provides shared implementations for LRU, LFU, and FIFO eviction policies.
  '''

  @doc '''
  Evicts entries using the Least Recently Used (LRU) policy.
  '''
  def evict_lru(cache, current_size, needed_size) do
    evict_by(cache, current_size, needed_size, fn {_, entry} -> entry.last_access end)
  end

  @doc '''
  Evicts entries using the Least Frequently Used (LFU) policy.
  '''
  def evict_lfu(cache, current_size, needed_size) do
    evict_by(cache, current_size, needed_size, fn {_, entry} -> entry.access_count end)
  end

  @doc '''
  Evicts entries using the First In First Out (FIFO) policy.
  '''
  def evict_fifo(cache, current_size, needed_size) do
    evict_by(cache, current_size, needed_size, fn {_, entry} -> entry.created_at end)
  end

  defp evict_by(cache, current_size, needed_size, sort_fn) do
    cache
    |> Enum.sort_by(sort_fn)
    |> Enum.reduce_while({cache, current_size}, fn {key, entry}, {acc_cache, acc_size} ->
      if acc_size + needed_size <= current_size do
        {:halt, {acc_cache, acc_size}}
      else
        new_cache = Map.delete(acc_cache, key)
        new_size = acc_size - entry.size
        {:cont, {new_cache, new_size}}
      end
    end)
  end
end
