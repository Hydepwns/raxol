defmodule Raxol.Terminal.Cache.EvictionHelpers do
  @moduledoc """
  Helper functions for cache eviction strategies.
  Provides shared implementations for LRU, LFU, and FIFO eviction policies.
  """

  @doc """
  Evicts entries using the Least Recently Used (LRU) policy.
  """
  def evict_lru(cache, current_size, needed_size, max_size) do
    evict_by(
      cache,
      current_size,
      needed_size,
      max_size,
      fn {_, entry} -> entry.last_access end,
      :asc,
      :lru
    )
  end

  @doc """
  Evicts entries using the Least Frequently Used (LFU) policy.
  """
  def evict_lfu(cache, current_size, needed_size, max_size) do
    evict_by(
      cache,
      current_size,
      needed_size,
      max_size,
      fn {_, entry} -> {entry.access_count, entry.last_access} end,
      :asc,
      :lfu
    )
  end

  @doc """
  Evicts entries using the First In First Out (FIFO) policy.
  """
  def evict_fifo(cache, current_size, needed_size, max_size) do
    evict_by(
      cache,
      current_size,
      needed_size,
      max_size,
      fn {_, entry} -> entry.created_at end,
      :asc,
      :fifo
    )
  end

  defp evict_by(
         cache,
         current_size,
         needed_size,
         max_size,
         sort_fn,
         order,
         policy
       ) do
    do_evict_by(
      cache,
      current_size,
      needed_size,
      max_size,
      sort_fn,
      order,
      policy
    )
  end

  defp do_evict_by(cache, size, needed_size, max_size, sort_fn, order, policy) do
    log_file = "tmp/eviction_debug.log"

    File.write!(
      log_file,
      "[EvictionHelpers] do_evict_by called. size=#{size}, needed_size=#{needed_size}, max_size=#{max_size}\n",
      [:append]
    )

    if size + needed_size <= max_size do
      File.write!(
        log_file,
        "[EvictionHelpers] Done evicting. Final size: #{size}\n",
        [:append]
      )

      {cache, size}
    else
      cache_list = Map.to_list(cache)
      sorted = sort_cache_entries(cache_list, policy, sort_fn, order)

      case sorted do
        [] ->
          File.write!(
            log_file,
            "[EvictionHelpers] No more entries to evict. Returning as is.\n",
            [:append]
          )

          {cache, size}

        [{key, entry} | _rest] ->
          File.write!(
            log_file,
            "[EvictionHelpers] Evicting key: #{inspect(key)}, entry size: #{entry.size}, current size: #{size}, needed size: #{needed_size}, max size: #{max_size}\n",
            [:append]
          )

          new_cache = Map.delete(cache, key)
          new_size = size - entry.size

          do_evict_by(
            new_cache,
            new_size,
            needed_size,
            max_size,
            sort_fn,
            order,
            policy
          )
      end
    end
  end

  defp sort_cache_entries(cache_list, :lfu, _sort_fn, _order) do
    Enum.sort(cache_list, fn {_ka, a}, {_kb, b} ->
      if a.access_count == b.access_count do
        a.last_access < b.last_access
      else
        a.access_count < b.access_count
      end
    end)
  end

  defp sort_cache_entries(cache_list, _policy, sort_fn, order) do
    Enum.sort_by(cache_list, sort_fn, order)
  end
end
