defmodule Raxol.Terminal.Cache.System do
  @moduledoc """
  Unified caching system for the Raxol terminal emulator.
  This module provides a centralized caching mechanism that consolidates all caching
  operations across the terminal system, including:
  - Buffer caching
  - Animation caching
  - Scroll caching
  - Clipboard caching
  - General purpose caching
  """

  use GenServer
  alias Raxol.Terminal.Cache.EvictionHelpers

  @type namespace :: :buffer | :animation | :scroll | :clipboard | :general
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
  Starts the unified cache system.

  ## Options
    * `:max_size` - Maximum cache size in bytes (default: 100MB)
    * `:default_ttl` - Default time-to-live in seconds (default: 3600)
    * `:eviction_policy` - Cache eviction policy (:lru, :lfu, :fifo) (default: :lru)
    * `:compression_enabled` - Whether to enable compression (default: true)
    * `:namespace_configs` - Configuration for specific namespaces
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets a value from the cache.

  ## Parameters
    * `key` - The cache key
    * `opts` - Get options
      * `:namespace` - Cache namespace (default: :general)
  """
  def get(key, opts \\ []) do
    namespace = Keyword.get(opts, :namespace, :general)
    GenServer.call(__MODULE__, {:get, namespace, key})
  end

  @doc """
  Puts a value in the cache.

  ## Parameters
    * `key` - The cache key
    * `value` - The value to cache
    * `opts` - Put options
      * `:namespace` - Cache namespace (default: :general)
      * `:ttl` - Time-to-live in seconds
      * `:metadata` - Additional metadata
  """
  def put(key, value, opts \\ []) do
    namespace = Keyword.get(opts, :namespace, :general)
    ttl = Keyword.get(opts, :ttl)
    metadata = Keyword.get(opts, :metadata, %{})
    GenServer.call(__MODULE__, {:put, namespace, key, value, ttl, metadata})
  end

  @doc """
  Invalidates a cache entry.

  ## Parameters
    * `key` - The cache key
    * `opts` - Invalidate options
      * `:namespace` - Cache namespace (default: :general)
  """
  def invalidate(key, opts \\ []) do
    namespace = Keyword.get(opts, :namespace, :general)
    GenServer.call(__MODULE__, {:invalidate, namespace, key})
  end

  @doc """
  Gets cache statistics.

  ## Parameters
    * `opts` - Stats options
      * `:namespace` - Cache namespace (default: :general)
  """
  def stats(opts \\ []) do
    namespace = Keyword.get(opts, :namespace, :general)
    GenServer.call(__MODULE__, {:stats, namespace})
  end

  @doc """
  Clears the cache.

  ## Parameters
    * `opts` - Clear options
      * `:namespace` - Cache namespace (default: :general)
  """
  def clear(opts \\ []) do
    namespace = Keyword.get(opts, :namespace, :general)
    GenServer.call(__MODULE__, {:clear, namespace})
  end

  @doc """
  Returns the current monotonic time in milliseconds.
  This is used for cache expiration and timing operations.
  """
  @spec monotonic_time() :: integer()
  def monotonic_time do
    System.monotonic_time(:millisecond)
  end

  def init(opts) do
    max_size = Keyword.get(opts, :max_size, 100 * 1024 * 1024)
    default_ttl = Keyword.get(opts, :default_ttl, 3600)
    eviction_policy = Keyword.get(opts, :eviction_policy, :lru)
    compression_enabled = Keyword.get(opts, :compression_enabled, true)
    namespace_configs = Keyword.get(opts, :namespace_configs, %{})

    namespaces = initialize_namespaces(namespace_configs, max_size)

    state = %{
      namespaces: namespaces,
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
    case get_namespace(state, namespace) do
      nil ->
        {:reply, {:error, :namespace_not_found}, state}

      namespace_state ->
        entry_size = calculate_size(value)

        {updated_cache, updated_size} =
          if namespace_state.size + entry_size > namespace_state.max_size do
            File.write!(
              "tmp/eviction_debug.log",
              "[CacheSystem] Eviction needed. current_size=#{namespace_state.size}, entry_size=#{entry_size}, max_size=#{namespace_state.max_size}\n",
              [:append]
            )

            {cache_after_eviction, size_after_eviction} =
              evict_entries(
                namespace_state.cache,
                namespace_state.size,
                entry_size,
                state.eviction_policy,
                namespace_state.max_size
              )

            File.write!(
              "tmp/eviction_debug.log",
              "[CacheSystem] After eviction: cache_size=#{map_size(cache_after_eviction)}, total_size=#{size_after_eviction}, cache_keys=#{inspect(Map.keys(cache_after_eviction))}\n",
              [:append]
            )

            {cache_after_eviction, size_after_eviction}
          else
            File.write!(
              "tmp/eviction_debug.log",
              "[CacheSystem] No eviction needed. current_size=#{namespace_state.size}, entry_size=#{entry_size}, max_size=#{namespace_state.max_size}\n",
              [:append]
            )

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
          update_namespace(state, namespace, %{
            namespace_state
            | cache: updated_cache,
              size: updated_size
          })

        {:reply, :ok, updated_state}
    end
  end

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
              update_namespace(state, namespace, %{
                namespace_state
                | cache: updated_cache,
                  size: updated_size
              })

            {:reply, :ok, updated_state}
        end
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
          update_namespace(state, namespace, %{
            namespace_state
            | cache: %{},
              size: 0
          })

        {:reply, :ok, updated_state}
    end
  end

  defp handle_cache_entry(namespace_state, key, state, namespace) do
    case Map.get(namespace_state.cache, key) do
      nil ->
        updated_state =
          update_namespace(state, namespace, %{
            namespace_state
            | miss_count: namespace_state.miss_count + 1
          })

        {:reply, {:error, :not_found}, updated_state}

      entry ->
        if expired?(entry) do
          handle_expired_entry(entry, key, namespace_state, state, namespace)
        else
          handle_valid_entry(entry, key, namespace_state, state, namespace)
        end
    end
  end

  defp handle_expired_entry(entry, key, namespace_state, state, namespace) do
    updated_cache = Map.delete(namespace_state.cache, key)
    updated_size = namespace_state.size - entry.size

    updated_state =
      update_namespace(state, namespace, %{
        namespace_state
        | cache: updated_cache,
          size: updated_size,
          miss_count: namespace_state.miss_count + 1
      })

    {:reply, {:error, :expired}, updated_state}
  end

  defp handle_valid_entry(entry, key, namespace_state, state, namespace) do
    updated_entry = %{
      entry
      | last_access: System.system_time(:second),
        access_count: entry.access_count + 1
    }

    updated_cache = Map.put(namespace_state.cache, key, updated_entry)

    updated_state =
      update_namespace(state, namespace, %{
        namespace_state
        | cache: updated_cache,
          hit_count: namespace_state.hit_count + 1
      })

    {:reply, {:ok, entry.value}, updated_state}
  end

  defp initialize_namespaces(configs, default_max_size) do
    default_namespace = %{
      cache: %{},
      size: 0,
      max_size: default_max_size,
      hit_count: 0,
      miss_count: 0,
      eviction_count: 0
    }

    [:buffer, :animation, :scroll, :clipboard, :general]
    |> Enum.reduce(%{}, fn namespace, acc ->
      config = Map.get(configs, namespace, %{})
      max_size = Map.get(config, :max_size, default_max_size)
      namespace_state = Map.put(default_namespace, :namespace, namespace)
      Map.put(acc, namespace, %{namespace_state | max_size: max_size})
    end)
  end

  defp get_namespace(state, namespace) do
    Map.get(state.namespaces, namespace)
  end

  defp update_namespace(state, namespace, namespace_state) do
    %{state | namespaces: Map.put(state.namespaces, namespace, namespace_state)}
  end

  defp expired?(entry) do
    case entry.ttl do
      nil -> false
      ttl -> System.system_time(:second) - entry.created_at > ttl
    end
  end

  defp calculate_size(value) do
    size = :erlang.external_size(value)

    File.write!(
      "tmp/eviction_debug.log",
      "[CacheSystem] Calculating size for value, size=#{size}\n",
      [:append]
    )

    size
  end

  defp calculate_hit_ratio(namespace_state) do
    total = namespace_state.hit_count + namespace_state.miss_count
    if total > 0, do: namespace_state.hit_count / total, else: 0.0
  end

  defp evict_entries(cache, current_size, needed_size, policy, max_size) do
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
