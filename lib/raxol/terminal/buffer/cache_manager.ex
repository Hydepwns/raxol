defmodule Raxol.Terminal.Buffer.CacheManager do
  @moduledoc """
  Manages caching for the terminal buffer system.
  Provides efficient caching mechanisms for frequently accessed buffer regions.
  """

  @type cache_key ::
          {non_neg_integer(), non_neg_integer(), non_neg_integer(),
           non_neg_integer()}
  @type cache_entry :: %{
          data: term(),
          last_access: integer(),
          access_count: non_neg_integer()
        }
  @type t :: %__MODULE__{
          cache: %{cache_key() => cache_entry()},
          max_size: non_neg_integer(),
          current_size: non_neg_integer(),
          hit_count: non_neg_integer(),
          miss_count: non_neg_integer()
        }

  defstruct cache: %{},
            max_size: 1000,
            current_size: 0,
            hit_count: 0,
            miss_count: 0

  @doc """
  Creates a new cache manager with the specified maximum size.

  ## Parameters
    * `max_size` - Maximum number of cache entries (default: 1000)

  ## Returns
    * A new cache manager instance
  """
  def new(max_size \\ 1000) do
    %__MODULE__{max_size: max_size}
  end

  @doc """
  Gets a value from the cache.

  ## Parameters
    * `cache` - The cache manager instance
    * `key` - The cache key

  ## Returns
    * `{:ok, value}` - The cached value if found
    * `:miss` - If the value is not in cache
  """
  def get(%__MODULE__{} = cache, key) do
    case Map.get(cache.cache, key) do
      nil ->
        %{cache | miss_count: cache.miss_count + 1}

      entry ->
        updated_entry = %{
          entry
          | last_access: System.monotonic_time(),
            access_count: entry.access_count + 1
        }

        updated_cache = %{
          cache
          | cache: Map.put(cache.cache, key, updated_entry),
            hit_count: cache.hit_count + 1
        }

        {:ok, entry.data, updated_cache}
    end
  end

  @doc """
  Puts a value in the cache.

  ## Parameters
    * `cache` - The cache manager instance
    * `key` - The cache key
    * `value` - The value to cache

  ## Returns
    * Updated cache manager instance
  """
  def put(%__MODULE__{} = cache, key, value) do
    cache =
      case cache.current_size >= cache.max_size do
        true ->
          # Evict least recently used entry
          evict_lru(cache)

        false ->
          cache
      end

    entry = %{
      data: value,
      last_access: System.monotonic_time(),
      access_count: 1
    }

    %{
      cache
      | cache: Map.put(cache.cache, key, entry),
        current_size: cache.current_size + 1
    }
  end

  @doc """
  Invalidates a cache entry.

  ## Parameters
    * `cache` - The cache manager instance
    * `key` - The cache key to invalidate

  ## Returns
    * Updated cache manager instance
  """
  def invalidate(%__MODULE__{} = cache, key) do
    case Map.pop(cache.cache, key) do
      {nil, _} ->
        cache

      {_, new_cache} ->
        %{cache | cache: new_cache, current_size: cache.current_size - 1}
    end
  end

  @doc """
  Gets cache statistics.

  ## Parameters
    * `cache` - The cache manager instance

  ## Returns
    * Map containing cache statistics
  """
  def stats(%__MODULE__{} = cache) do
    %{
      size: cache.current_size,
      max_size: cache.max_size,
      hit_count: cache.hit_count,
      miss_count: cache.miss_count,
      hit_ratio: calculate_hit_ratio(cache)
    }
  end

  # Private Functions

  defp evict_lru(%__MODULE__{} = cache) do
    {key_to_evict, _} =
      cache.cache
      |> Enum.min_by(fn {_, entry} -> entry.last_access end)

    invalidate(cache, key_to_evict)
  end

  defp calculate_hit_ratio(%__MODULE__{} = cache) do
    total = cache.hit_count + cache.miss_count

    case total > 0 do
      true -> cache.hit_count / total
      false -> 0.0
    end
  end
end
