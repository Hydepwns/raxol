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
    case Process.whereis(__MODULE__) do
      nil ->
        GenServer.start_link(__MODULE__, opts, name: __MODULE__)

      _pid ->
        {:error, {:already_started, _pid}}
    end
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

  def handle_call({:get, namespace, key}, _from, state) do
    case get_namespace(state, namespace) do
      nil ->
        {:reply, {:error, :namespace_not_found}, state}

      namespace_state ->
        handle_cache_entry(namespace_state, key, state, namespace)
    end
  end

  def handle_call({:put, namespace, key, value, ttl, metadata}, _from, state) do
    namespace_state = get_or_create_namespace(state, namespace)
    entry_size = calculate_size(value)

    IO.inspect(namespace_state.size,
      label: "[DEBUG] Cache size before eviction"
    )

    IO.inspect(
      Enum.map(namespace_state.cache, fn {k, v} -> {k, v.access_count} end),
      label: "[DEBUG] Cache before eviction"
    )

    {evicted_cache, evicted_size} =
      if namespace_state.size + entry_size > namespace_state.max_size do
        evict_entries(
          namespace_state.cache,
          namespace_state.size,
          entry_size,
          namespace_state.max_size,
          state.eviction_policy
        )
      else
        {namespace_state.cache, namespace_state.size}
      end

    IO.inspect(evicted_size, label: "[DEBUG] Cache size after eviction")

    IO.inspect(Enum.map(evicted_cache, fn {k, v} -> {k, v.access_count} end),
      label: "[DEBUG] Cache after eviction"
    )

    # Only add the entry if there's enough space after eviction
    if evicted_size + entry_size <= namespace_state.max_size do
      entry = %{
        value: value,
        size: entry_size,
        created_at: System.system_time(:second),
        last_access: System.system_time(:second),
        access_count: 1,
        ttl: ttl || state.default_ttl,
        metadata: metadata
      }

      new_cache = Map.put(evicted_cache, key, entry)
      new_size = evicted_size + entry_size

      IO.inspect(new_size, label: "[DEBUG] Cache size after adding new entry")

      IO.inspect(Enum.map(new_cache, fn {k, v} -> {k, v.access_count} end),
        label: "[DEBUG] Cache after adding new entry"
      )

      updated_state =
        update_namespace_state(state, namespace, namespace_state, %{
          cache: new_cache,
          size: new_size
        })

      {:reply, :ok, updated_state}
    else
      # Not enough space even after eviction
      {:reply, {:error, :insufficient_space}, state}
    end
  end

  def handle_call({:invalidate, namespace, key}, _from, state) do
    namespace_state = get_or_create_namespace(state, namespace)

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

  def handle_cast({:set_eviction_policy, policy}, state) do
    {:noreply, %{state | eviction_policy: policy}}
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
          handle_valid_entry(entry, namespace_state, key, state, namespace)
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

  defp handle_valid_entry(entry, namespace_state, key, state, namespace) do
    IO.inspect(entry.access_count, label: "[DEBUG] access_count before update")
    updated_entry = update_entry_access(entry)

    IO.inspect(updated_entry.access_count,
      label: "[DEBUG] access_count after update"
    )

    updated_cache = Map.put(namespace_state.cache, key, updated_entry)

    IO.inspect(Enum.map(updated_cache, fn {k, v} -> {k, v.access_count} end),
      label: "[DEBUG] Cache after updating entry"
    )

    updated_size =
      Enum.reduce(updated_cache, 0, fn {_k, v}, acc -> acc + v.size end)

    updated_namespace_state = %{
      namespace_state
      | cache: updated_cache,
        size: updated_size,
        hit_count: namespace_state.hit_count + 1
    }

    updated_state = put_namespace(state, namespace, updated_namespace_state)
    {:reply, {:ok, entry.value}, updated_state}
  end

  defp update_entry_access(entry) do
    %{
      entry
      | access_count: entry.access_count + 1,
        last_access: System.system_time(:second)
    }
  end

  defp put_namespace(state, namespace, updated_namespace_state) do
    %{
      state
      | namespaces:
          Map.put(state.namespaces, namespace, updated_namespace_state)
    }
  end

  defp get_namespace(state, namespace) do
    Map.get(state.namespaces, namespace)
  end

  defp get_or_create_namespace(state, namespace) do
    case get_namespace(state, namespace) do
      nil ->
        # Create new namespace with default settings
        %{
          cache: %{},
          size: 0,
          max_size: get_default_namespace_max_size(state),
          hit_count: 0,
          miss_count: 0,
          eviction_count: 0
        }

      namespace_state ->
        namespace_state
    end
  end

  defp get_default_namespace_max_size(state) do
    # Use the max_size from the default namespace
    case get_namespace(state, :default) do
      # Default 100MB
      nil -> 100 * 1024 * 1024
      default_ns -> default_ns.max_size
    end
  end

  defp update_namespace(state, namespace, namespace_state) do
    %{state | namespaces: Map.put(state.namespaces, namespace, namespace_state)}
  end

  defp update_namespace_state(state, namespace, namespace_state, updates) do
    update_namespace(state, namespace, Map.merge(namespace_state, updates))
  end

  defp expired?(entry) do
    case entry.ttl do
      nil ->
        false

      ttl ->
        current_time = System.system_time(:second)
        current_time - entry.created_at >= ttl
    end
  end

  defp calculate_size(value) do
    :erlang.term_to_binary(value) |> byte_size()
  end

  defp calculate_hit_ratio(namespace_state) do
    total = namespace_state.hit_count + namespace_state.miss_count
    if total > 0, do: namespace_state.hit_count / total, else: 0.0
  end

  defp evict_entries(cache, current_size, needed_size, max_size, policy) do
    case policy do
      :lru ->
        EvictionHelpers.evict_lru(cache, current_size, needed_size, max_size)

      :lfu ->
        EvictionHelpers.evict_lfu(cache, current_size, needed_size, max_size)

      :fifo ->
        EvictionHelpers.evict_fifo(cache, current_size, needed_size, max_size)
    end
  end
end
