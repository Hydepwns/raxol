defmodule Raxol.Terminal.Graphics.ImageCache do
  @moduledoc """
  High-performance caching system for processed images and graphics data.

  Provides intelligent caching with:
  * LRU (Least Recently Used) eviction policy
  * Memory usage monitoring and limits
  * Cache key generation and management
  * Batch cache operations
  * Cache warming and preloading
  * Performance metrics and monitoring

  ## Cache Strategies

  * **Memory Cache** - Fast in-memory storage for frequently accessed images
  * **Disk Cache** - Persistent storage for large images and processed variants
  * **Distributed Cache** - Shared cache across multiple processes (future)

  ## Usage

      # Start cache server
      {:ok, _pid} = ImageCache.start_link(%{
        max_memory: 100_000_000,  # 100MB
        max_entries: 1000,
        ttl: 3600  # 1 hour
      })
      
      # Cache processed image
      :ok = ImageCache.put("image_key_300x200", processed_image_data)
      
      # Retrieve cached image
      {:ok, data} = ImageCache.get("image_key_300x200")
      
      # Generate cache key
      key = ImageCache.generate_key(image_data, processing_options)
  """

  use GenServer
  require Logger

  @type cache_key :: String.t()
  @type cache_entry :: %{
          data: binary(),
          metadata: map(),
          accessed_at: integer(),
          created_at: integer(),
          size: non_neg_integer(),
          hit_count: non_neg_integer()
        }

  @type cache_config :: %{
          optional(:max_memory) => non_neg_integer(),
          optional(:max_entries) => non_neg_integer(),
          optional(:ttl) => non_neg_integer(),
          optional(:enable_disk_cache) => boolean(),
          optional(:disk_cache_dir) => String.t(),
          optional(:cleanup_interval) => non_neg_integer(),
          optional(:metrics_enabled) => boolean()
        }

  @type cache_stats :: %{
          entries: non_neg_integer(),
          memory_usage: non_neg_integer(),
          hit_rate: float(),
          total_hits: non_neg_integer(),
          total_misses: non_neg_integer(),
          evictions: non_neg_integer()
        }

  # Default configuration
  @default_config %{
    # 50MB
    max_memory: 50_000_000,
    # Maximum number of entries
    max_entries: 500,
    # 30 minutes
    ttl: 1800,
    enable_disk_cache: true,
    # Will use system temp dir
    disk_cache_dir: nil,
    # 5 minutes
    cleanup_interval: 300_000,
    metrics_enabled: true
  }

  # Cache state structure
  defstruct [
    :config,
    :entries,
    :access_order,
    :memory_usage,
    :stats,
    :cleanup_timer
  ]

  @doc """
  Starts the image cache server.

  ## Parameters

  * `config` - Cache configuration options

  ## Returns

  * `{:ok, pid}` - Successfully started cache server
  * `{:error, reason}` - Failed to start
  """
  @spec start_link(cache_config()) :: GenServer.on_start()
  def start_link(config \\ %{}) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @doc """
  Retrieves a cached image by key.

  ## Parameters

  * `key` - Cache key to lookup

  ## Returns

  * `{:ok, data}` - Found cached data
  * `{:error, :not_found}` - Key not in cache
  * `{:error, :expired}` - Entry has expired
  """
  @spec get(cache_key()) :: {:ok, binary()} | {:error, :not_found | :expired}
  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  @doc """
  Stores an image in the cache.

  ## Parameters

  * `key` - Cache key
  * `data` - Image data to cache
  * `metadata` - Optional metadata about the image

  ## Returns

  * `:ok` - Successfully cached
  * `{:error, reason}` - Failed to cache
  """
  @spec put(cache_key(), binary(), map()) :: :ok | {:error, term()}
  def put(key, data, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:put, key, data, metadata})
  end

  @doc """
  Removes an entry from the cache.

  ## Parameters

  * `key` - Cache key to remove

  ## Returns

  * `:ok` - Successfully removed or key didn't exist
  """
  @spec delete(cache_key()) :: :ok
  def delete(key) do
    GenServer.call(__MODULE__, {:delete, key})
  end

  @doc """
  Clears all entries from the cache.

  ## Returns

  * `:ok` - Cache cleared successfully
  """
  @spec clear() :: :ok
  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  @doc """
  Gets current cache statistics.

  ## Returns

  * Cache statistics map with performance metrics
  """
  @spec get_stats() :: cache_stats()
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Generates a cache key from image data and processing options.

  Uses SHA-256 hashing for consistent, collision-resistant keys.

  ## Parameters

  * `image_data` - Source image data
  * `options` - Processing options that affect output

  ## Returns

  * Cache key string
  """
  @spec generate_key(binary(), map()) :: cache_key()
  def generate_key(image_data, options \\ %{}) do
    # Create deterministic hash from image data and options
    data_hash = :crypto.hash(:sha256, image_data)
    options_hash = :crypto.hash(:sha256, :erlang.term_to_binary(options))

    combined_hash =
      :crypto.hash(:sha256, <<data_hash::binary, options_hash::binary>>)

    Base.encode16(combined_hash, case: :lower)
  end

  @doc """
  Performs batch cache operations for improved performance.

  ## Parameters

  * `operations` - List of cache operations: `{:get, key}`, `{:put, key, data}`, etc.

  ## Returns

  * `{:ok, results}` - List of operation results
  * `{:error, reason}` - Batch operation failed
  """
  @spec batch([tuple()]) :: {:ok, [term()]} | {:error, term()}
  def batch(operations) do
    GenServer.call(__MODULE__, {:batch, operations})
  end

  @doc """
  Preloads cache with commonly used images.

  ## Parameters

  * `image_specs` - List of `{key, image_data, metadata}` tuples

  ## Returns

  * `:ok` - Preloading completed
  """
  @spec preload([{cache_key(), binary(), map()}]) :: :ok
  def preload(image_specs) do
    GenServer.cast(__MODULE__, {:preload, image_specs})
  end

  # GenServer Callbacks

  @impl true
  def init(config) do
    merged_config = Map.merge(@default_config, config)

    # Setup disk cache directory
    disk_cache_dir = setup_disk_cache_dir(merged_config)
    final_config = Map.put(merged_config, :disk_cache_dir, disk_cache_dir)

    # Schedule cleanup
    cleanup_timer = schedule_cleanup(final_config.cleanup_interval)

    initial_state = %__MODULE__{
      config: final_config,
      entries: %{},
      access_order: [],
      memory_usage: 0,
      stats: %{
        total_hits: 0,
        total_misses: 0,
        evictions: 0
      },
      cleanup_timer: cleanup_timer
    }

    Logger.info("ImageCache started with config: #{inspect(final_config)}")
    {:ok, initial_state}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    case Map.get(state.entries, key) do
      nil ->
        # Check disk cache if enabled
        case get_from_disk_cache(key, state.config) do
          {:error, :not_found} ->
            final_state = update_stats(state, :miss)
            {:reply, {:error, :not_found}, final_state}
        end

      entry ->
        case is_expired?(entry, state.config.ttl) do
          true ->
            new_state = remove_entry(key, state)
            final_state = update_stats(new_state, :miss)
            {:reply, {:error, :expired}, final_state}

          false ->
            # Update access time and order
            updated_entry = %{
              entry
              | accessed_at: System.system_time(:second),
                hit_count: entry.hit_count + 1
            }

            updated_entries = Map.put(state.entries, key, updated_entry)
            updated_access_order = move_to_front(state.access_order, key)

            new_state = %{
              state
              | entries: updated_entries,
                access_order: updated_access_order
            }

            final_state = update_stats(new_state, :hit)
            {:reply, {:ok, entry.data}, final_state}
        end
    end
  end

  @impl true
  def handle_call({:put, key, data, metadata}, _from, state) do
    {new_state, result} = put_entry(key, data, metadata, state)
    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:delete, key}, _from, state) do
    new_state = remove_entry(key, state)
    remove_from_disk_cache(key, state.config)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    # Clear disk cache if enabled
    clear_disk_cache(state.config)

    new_state = %{state | entries: %{}, access_order: [], memory_usage: 0}

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = calculate_cache_stats(state)
    {:reply, stats, state}
  end

  @impl true
  def handle_call({:batch, operations}, _from, state) do
    {final_state, results} = process_batch_operations(operations, state)
    {:reply, {:ok, results}, final_state}
  end

  @impl true
  def handle_cast({:preload, image_specs}, state) do
    final_state =
      Enum.reduce(image_specs, state, fn {key, data, metadata}, acc_state ->
        {new_state, _result} = put_entry(key, data, metadata, acc_state)
        new_state
      end)

    {:noreply, final_state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    new_state = perform_cleanup(state)
    new_timer = schedule_cleanup(state.config.cleanup_interval)
    {:noreply, %{new_state | cleanup_timer: new_timer}}
  end

  @impl true
  def terminate(_reason, state) do
    case state.cleanup_timer do
      nil -> :ok
      timer -> Process.cancel_timer(timer)
    end

    :ok
  end

  # Private Functions

  defp setup_disk_cache_dir(%{enable_disk_cache: false}), do: nil

  defp setup_disk_cache_dir(%{enable_disk_cache: true, disk_cache_dir: nil}) do
    cache_dir = Path.join(System.tmp_dir(), "raxol_image_cache")
    File.mkdir_p!(cache_dir)
    cache_dir
  end

  defp setup_disk_cache_dir(%{enable_disk_cache: true, disk_cache_dir: dir}) do
    File.mkdir_p!(dir)
    dir
  end

  defp schedule_cleanup(interval) do
    Process.send_after(self(), :cleanup, interval)
  end

  defp put_entry(key, data, metadata, state) do
    data_size = byte_size(data)

    # Check if we need to make space
    state_after_eviction = ensure_space_available(state, data_size)

    # Create new entry
    entry = %{
      data: data,
      metadata: metadata,
      accessed_at: System.system_time(:second),
      created_at: System.system_time(:second),
      size: data_size,
      hit_count: 0
    }

    # Update state
    new_entries = Map.put(state_after_eviction.entries, key, entry)

    new_access_order = [
      key | List.delete(state_after_eviction.access_order, key)
    ]

    new_memory_usage = state_after_eviction.memory_usage + data_size

    new_state = %{
      state_after_eviction
      | entries: new_entries,
        access_order: new_access_order,
        memory_usage: new_memory_usage
    }

    # Write to disk cache if enabled
    write_to_disk_cache(key, data, metadata, state.config)

    {new_state, :ok}
  end

  defp remove_entry(key, state) do
    case Map.get(state.entries, key) do
      nil ->
        state

      entry ->
        new_entries = Map.delete(state.entries, key)
        new_access_order = List.delete(state.access_order, key)
        new_memory_usage = state.memory_usage - entry.size

        %{
          state
          | entries: new_entries,
            access_order: new_access_order,
            memory_usage: new_memory_usage
        }
    end
  end

  defp ensure_space_available(state, required_size) do
    case needs_eviction?(state, required_size) do
      false -> state
      true -> perform_eviction(state, required_size)
    end
  end

  defp needs_eviction?(state, required_size) do
    projected_memory = state.memory_usage + required_size
    projected_entries = map_size(state.entries) + 1

    projected_memory > state.config.max_memory or
      projected_entries > state.config.max_entries
  end

  defp perform_eviction(state, required_size) do
    target_memory = state.config.max_memory - required_size
    target_entries = state.config.max_entries - 1

    evict_lru_entries(state, target_memory, target_entries)
  end

  defp evict_lru_entries(state, target_memory, target_entries) do
    # Evict from the end of access_order list (least recently used)
    keys_to_evict =
      determine_eviction_candidates(state, target_memory, target_entries)

    final_state =
      Enum.reduce(keys_to_evict, state, fn key, acc_state ->
        remove_entry(key, acc_state)
      end)

    eviction_count = length(keys_to_evict)

    updated_stats =
      Map.update(
        final_state.stats,
        :evictions,
        eviction_count,
        &(&1 + eviction_count)
      )

    %{final_state | stats: updated_stats}
  end

  defp determine_eviction_candidates(state, target_memory, target_entries) do
    # Get candidates from least recently used end
    candidates = Enum.reverse(state.access_order)

    {_final_memory, _final_entries, evict_keys} =
      Enum.reduce_while(
        candidates,
        {state.memory_usage, map_size(state.entries), []},
        fn key, {memory, entries, evict_list} ->
          case Map.get(state.entries, key) do
            nil ->
              {:cont, {memory, entries, evict_list}}

            entry ->
              new_memory = memory - entry.size
              new_entries = entries - 1
              new_evict_list = [key | evict_list]

              case new_memory <= target_memory and new_entries <= target_entries do
                true -> {:halt, {new_memory, new_entries, new_evict_list}}
                false -> {:cont, {new_memory, new_entries, new_evict_list}}
              end
          end
        end
      )

    evict_keys
  end

  defp move_to_front(access_order, key) do
    [key | List.delete(access_order, key)]
  end

  defp is_expired?(entry, ttl) do
    current_time = System.system_time(:second)
    current_time - entry.created_at > ttl
  end

  defp update_stats(state, :hit) do
    new_stats = Map.update(state.stats, :total_hits, 1, &(&1 + 1))
    %{state | stats: new_stats}
  end

  defp update_stats(state, :miss) do
    new_stats = Map.update(state.stats, :total_misses, 1, &(&1 + 1))
    %{state | stats: new_stats}
  end

  defp calculate_cache_stats(state) do
    total_requests = state.stats.total_hits + state.stats.total_misses

    hit_rate =
      case total_requests > 0 do
        true -> state.stats.total_hits / total_requests
        false -> 0.0
      end

    %{
      entries: map_size(state.entries),
      memory_usage: state.memory_usage,
      hit_rate: hit_rate,
      total_hits: state.stats.total_hits,
      total_misses: state.stats.total_misses,
      evictions: Map.get(state.stats, :evictions, 0)
    }
  end

  defp process_batch_operations(operations, state) do
    Enum.reduce(operations, {state, []}, fn operation, {acc_state, results} ->
      case operation do
        {:get, key} ->
          case handle_get_operation(key, acc_state) do
            {new_state, result} -> {new_state, [result | results]}
          end

        {:put, key, data, metadata} ->
          {new_state, result} = put_entry(key, data, metadata, acc_state)
          {new_state, [result | results]}

        {:delete, key} ->
          new_state = remove_entry(key, acc_state)
          {new_state, [:ok | results]}

        _ ->
          {acc_state, [{:error, :invalid_operation} | results]}
      end
    end)
    |> then(fn {final_state, results} ->
      {final_state, Enum.reverse(results)}
    end)
  end

  defp handle_get_operation(key, state) do
    # Similar to handle_call({:get, key}, ...) but returns tuple format for batch
    case Map.get(state.entries, key) do
      nil ->
        {update_stats(state, :miss), {:error, :not_found}}

      entry ->
        case is_expired?(entry, state.config.ttl) do
          true ->
            new_state = remove_entry(key, state) |> update_stats(:miss)
            {new_state, {:error, :expired}}

          false ->
            # Update access statistics
            updated_entry = %{
              entry
              | accessed_at: System.system_time(:second),
                hit_count: entry.hit_count + 1
            }

            new_state =
              %{
                state
                | entries: Map.put(state.entries, key, updated_entry),
                  access_order: move_to_front(state.access_order, key)
              }
              |> update_stats(:hit)

            {new_state, {:ok, entry.data}}
        end
    end
  end

  defp perform_cleanup(state) do
    current_time = System.system_time(:second)
    ttl = state.config.ttl

    # Find expired entries
    expired_keys =
      Enum.filter(Map.keys(state.entries), fn key ->
        case Map.get(state.entries, key) do
          nil -> false
          entry -> current_time - entry.created_at > ttl
        end
      end)

    # Remove expired entries
    Enum.reduce(expired_keys, state, fn key, acc_state ->
      remove_entry(key, acc_state)
    end)
  end

  # Disk cache operations (stubbed for now)
  defp get_from_disk_cache(_key, %{enable_disk_cache: false}),
    do: {:error, :not_found}

  defp get_from_disk_cache(_key, _config), do: {:error, :not_found}

  defp write_to_disk_cache(_key, _data, _metadata, %{enable_disk_cache: false}),
    do: :ok

  defp write_to_disk_cache(_key, _data, _metadata, _config), do: :ok

  defp remove_from_disk_cache(_key, %{enable_disk_cache: false}), do: :ok
  defp remove_from_disk_cache(_key, _config), do: :ok

  defp clear_disk_cache(%{enable_disk_cache: false}), do: :ok
  defp clear_disk_cache(_config), do: :ok
end
