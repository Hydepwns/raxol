defmodule Raxol.Terminal.Cache.UnifiedCache do
  @moduledoc """
  Unified caching system for the Raxol terminal emulator.
  This module provides a centralized caching mechanism for all terminal operations,
  including buffer operations, animations, scroll operations, and edge computing.
  """

  use GenServer
  alias Raxol.Terminal.Cache.EvictionHelpers

  @type cache_key :: term()
  @type cache_value :: term()
  @type cache_entry :: %{
          value: cache_value(),
          size: non_neg_integer(),
          created_at: integer(),
          last_access: integer(),
          access_count: non_neg_integer(),
          ttl: integer() | nil,
          metadata: map()
        }
  @type cache_stats :: %{
          size: non_neg_integer(),
          max_size: non_neg_integer(),
          hit_count: non_neg_integer(),
          miss_count: non_neg_integer(),
          hit_ratio: float(),
          eviction_count: non_neg_integer()
        }

  @doc """
  Starts the unified cache manager.

  ## Options
    * `:max_size` - Maximum cache size in bytes (default: 100MB)
    * `:default_ttl` - Default time-to-live in seconds (default: 3600)
    * `:eviction_policy` - Cache eviction policy (:lru, :lfu, :fifo) (default: :lru)
    * `:compression_enabled` - Whether to enable compression (default: true)
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets a value from the cache.

  ## Parameters
    * `key` - The cache key
    * `opts` - Get options
      * `:namespace` - Cache namespace (default: :default)
  """
  def get(key, opts \\ []) do
    namespace = Keyword.get(opts, :namespace, :default)
    GenServer.call(__MODULE__, {:get, namespace, key})
  end

  @doc """
  Puts a value in the cache.

  ## Parameters
    * `key` - The cache key
    * `value` - The value to cache
    * `opts` - Put options
      * `:namespace` - Cache namespace (default: :default)
      * `:ttl` - Time-to-live in seconds
      * `:metadata` - Additional metadata
  """
  def put(key, value, opts \\ []) do
    namespace = Keyword.get(opts, :namespace, :default)
    ttl = Keyword.get(opts, :ttl)
    metadata = Keyword.get(opts, :metadata, %{})
    GenServer.call(__MODULE__, {:put, namespace, key, value, ttl, metadata})
  end

  @doc """
  Invalidates a cache entry.

  ## Parameters
    * `key` - The cache key
    * `opts` - Invalidate options
      * `:namespace` - Cache namespace (default: :default)
  """
  def invalidate(key, opts \\ []) do
    namespace = Keyword.get(opts, :namespace, :default)
    GenServer.call(__MODULE__, {:invalidate, namespace, key})
  end

  @doc """
  Gets cache statistics.

  ## Parameters
    * `opts` - Stats options
      * `:namespace` - Cache namespace (default: :default)
  """
  def stats(opts \\ []) do
    namespace = Keyword.get(opts, :namespace, :default)
    GenServer.call(__MODULE__, {:stats, namespace})
  end

  @doc """
  Clears the cache.

  ## Parameters
    * `opts` - Clear options
      * `:namespace` - Cache namespace (default: :default)
  """
  def clear(opts \\ []) do
    namespace = Keyword.get(opts, :namespace, :default)
    GenServer.call(__MODULE__, {:clear, namespace})
  end

  @impl true
  def init(opts) do
    max_size = Keyword.get(opts, :max_size, 100 * 1024 * 1024)
    default_ttl = Keyword.get(opts, :default_ttl, 3600)
    eviction_policy = Keyword.get(opts, :eviction_policy, :lru)
    compression_enabled = Keyword.get(opts, :compression_enabled, true)

    state = %{
      namespaces: %{
        :default => %{
          cache: %{},
          size: 0,
          max_size: max_size,
          hit_count: 0,
          miss_count: 0,
          eviction_count: 0
        }
      },
      default_ttl: default_ttl,
      eviction_policy: eviction_policy,
      compression_enabled: compression_enabled
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:get, namespace, key}, _from, state) do
    case get_namespace(state, namespace) do
      nil ->
        {:reply, {:error, :namespace_not_found}, state}

      namespace_state ->
        handle_cache_entry(namespace_state, key, state, namespace)
    end
  end

  @impl true
  def handle_call({:put, namespace, key, value, ttl, metadata}, _from, state) do
    case get_namespace(state, namespace) do
      nil ->
        {:reply, {:error, :namespace_not_found}, state}

      namespace_state ->
        entry_size = calculate_size(value)

        {updated_cache, updated_size} =
          if namespace_state.size + entry_size > namespace_state.max_size do
            evict_entries(
              namespace_state.cache,
              namespace_state.size,
              entry_size,
              state.eviction_policy
            )
          else
            {namespace_state.cache, namespace_state.size}
          end

        entry = %{
          value: value,
          size: entry_size,
          created_at: System.system_time(:second),
          last_access: System.system_time(:second),
          access_count: 1,
          ttl: ttl || state.default_ttl,
          metadata: metadata
        }

        updated_cache = Map.put(updated_cache, key, entry)
        updated_size = updated_size + entry_size

        updated_state =
          update_namespace_state(state, namespace, namespace_state, %{
            cache: updated_cache,
            size: updated_size
          })

        {:reply, :ok, updated_state}
    end
  end

  @impl true
  def handle_call({:invalidate, namespace, key}, _from, state) do
    case get_namespace(state, namespace) do
      nil ->
        {:reply, {:error, :namespace_not_found}, state}

      namespace_state ->
        case Map.pop(namespace_state.cache, key) do
          {nil, _} ->
            {:reply, :ok, state}

          {entry, updated_cache} ->
            updated_size = namespace_state.size - entry.size

            updated_state =
              update_namespace_state(state, namespace, namespace_state, %{
                cache: updated_cache,
                size: updated_size
              })

            {:reply, :ok, updated_state}
        end
    end
  end

  @impl true
  def handle_call({:stats, namespace}, _from, state) do
    case get_namespace(state, namespace) do
      nil ->
        {:reply, {:error, :namespace_not_found}, state}

      namespace_state ->
        stats = %{
          size: namespace_state.size,
          max_size: namespace_state.max_size,
          hit_count: namespace_state.hit_count,
          miss_count: namespace_state.miss_count,
          hit_ratio: calculate_hit_ratio(namespace_state),
          eviction_count: namespace_state.eviction_count
        }

        {:reply, {:ok, stats}, state}
    end
  end

  @impl true
  def handle_call({:clear, namespace}, _from, state) do
    case get_namespace(state, namespace) do
      nil ->
        {:reply, {:error, :namespace_not_found}, state}

      namespace_state ->
        updated_state =
          update_namespace_state(state, namespace, namespace_state, %{
            cache: %{},
            size: 0
          })

        {:reply, :ok, updated_state}
    end
  end

  defp handle_cache_entry(namespace_state, key, state, namespace) do
    case Map.get(namespace_state.cache, key) do
      nil ->
        updated_state =
          update_namespace_state(state, namespace, namespace_state, %{
            miss_count: namespace_state.miss_count + 1
          })

        {:reply, {:error, :not_found}, updated_state}

      entry ->
        if expired?(entry) do
          handle_expired_entry(entry, namespace_state, state, namespace, key)
        else
          handle_valid_entry(entry, namespace_state, state, namespace, key)
        end
    end
  end

  defp handle_expired_entry(entry, namespace_state, state, namespace, key) do
    {updated_cache, updated_size} =
      remove_expired_entry(namespace_state.cache, entry, namespace_state, key)

    updated_state =
      update_namespace_state(state, namespace, namespace_state, %{
        cache: updated_cache,
        size: updated_size,
        miss_count: namespace_state.miss_count + 1
      })

    {:reply, {:error, :expired}, updated_state}
  end

  defp remove_expired_entry(cache, entry, namespace_state, key) do
    updated_cache = Map.delete(cache, key)
    updated_size = namespace_state.size - entry.size
    {updated_cache, updated_size}
  end

  defp handle_valid_entry(entry, namespace_state, state, namespace, key) do
    updated_entry = update_entry_access(entry)

    updated_cache =
      update_cache_with_entry(namespace_state.cache, key, updated_entry)

    updated_state =
      update_namespace_state(state, namespace, namespace_state, %{
        cache: updated_cache,
        hit_count: namespace_state.hit_count + 1
      })

    {:reply, {:ok, entry.value}, updated_state}
  end

  defp update_entry_access(entry) do
    %{
      entry
      | last_access: System.system_time(:second),
        access_count: entry.access_count + 1
    }
  end

  defp update_cache_with_entry(cache, key, entry) do
    Map.put(cache, key, entry)
  end

  defp get_namespace(state, namespace) do
    Map.get(state.namespaces, namespace)
  end

  defp update_namespace(state, namespace, namespace_state) do
    %{state | namespaces: Map.put(state.namespaces, namespace, namespace_state)}
  end

  defp update_namespace_state(state, namespace, namespace_state, updates) do
    update_namespace(state, namespace, Map.merge(namespace_state, updates))
  end

  defp expired?(entry) do
    case entry.ttl do
      nil -> false
      ttl -> System.system_time(:second) - entry.created_at > ttl
    end
  end

  defp calculate_size(value) do
    :erlang.term_to_binary(value) |> byte_size()
  end

  defp calculate_hit_ratio(namespace_state) do
    total = namespace_state.hit_count + namespace_state.miss_count
    if total > 0, do: namespace_state.hit_count / total, else: 0.0
  end

  defp evict_entries(cache, current_size, needed_size, policy) do
    case policy do
      :lru -> EvictionHelpers.evict_lru(cache, current_size, needed_size)
      :lfu -> EvictionHelpers.evict_lfu(cache, current_size, needed_size)
      :fifo -> EvictionHelpers.evict_fifo(cache, current_size, needed_size)
    end
  end
end
