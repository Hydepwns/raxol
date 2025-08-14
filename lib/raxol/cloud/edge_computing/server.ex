defmodule Raxol.Cloud.EdgeComputing.Server do
  @moduledoc """
  GenServer implementation for Edge Computing functionality.
  
  This server manages edge computing state including:
  - Cache management with LRU eviction
  - Operation queue for offline/cloud synchronization
  - Sync state tracking
  - Connection monitoring
  
  All Process dictionary usage has been eliminated in favor of
  supervised GenServer state management.
  """
  
  use GenServer
  require Logger
  
  # Client API
  
  @doc """
  Starts the EdgeComputing server.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Returns a child specification for this server.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end
  
  # Cache operations
  
  def cache_put(key, value, opts \\ []) do
    GenServer.call(__MODULE__, {:cache_put, key, value, opts})
  end
  
  def cache_get(key) do
    GenServer.call(__MODULE__, {:cache_get, key})
  end
  
  def cache_delete(key) do
    GenServer.call(__MODULE__, {:cache_delete, key})
  end
  
  def cache_clear do
    GenServer.call(__MODULE__, :cache_clear)
  end
  
  def cache_usage do
    GenServer.call(__MODULE__, :cache_usage)
  end
  
  # Queue operations
  
  def enqueue_operation(type, data) do
    GenServer.call(__MODULE__, {:enqueue_operation, type, data})
  end
  
  def pending_count do
    GenServer.call(__MODULE__, :pending_count)
  end
  
  def process_pending do
    GenServer.call(__MODULE__, :process_pending, 30_000)
  end
  
  # Sync operations
  
  def sync(opts \\ []) do
    GenServer.call(__MODULE__, {:sync, opts}, 30_000)
  end
  
  def get_last_sync do
    GenServer.call(__MODULE__, :get_last_sync)
  end
  
  def get_sync_state do
    GenServer.call(__MODULE__, :get_sync_state)
  end
  
  def update_sync_state(updates) do
    GenServer.call(__MODULE__, {:update_sync_state, updates})
  end
  
  # Configuration
  
  def update_config(config) do
    GenServer.call(__MODULE__, {:update_config, config})
  end
  
  def get_config do
    GenServer.call(__MODULE__, :get_config)
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    config = %{
      offline_cache_size: Keyword.get(opts, :offline_cache_size, 100_000_000),
      sync_interval: Keyword.get(opts, :sync_interval, 30_000),
      conflict_strategy: Keyword.get(opts, :conflict_strategy, :latest_wins),
      retry_limit: Keyword.get(opts, :retry_limit, 5)
    }
    
    state = %{
      # Cache state
      cache: %{
        items: %{},
        size: 0,
        max_size: config.offline_cache_size
      },
      # Queue state
      queue: %{
        operations: [],
        next_id: 1
      },
      # Sync state
      sync: %{
        last_sync: nil,
        pending_changes: %{},
        conflict_strategy: config.conflict_strategy
      },
      # Configuration
      config: config
    }
    
    {:ok, state}
  end
  
  # Cache handlers
  
  @impl true
  def handle_call({:cache_put, key, value, opts}, _from, state) do
    data_size = :erlang.term_to_binary(value) |> byte_size()
    
    # Check if we need to evict
    state = 
      if state.cache.size + data_size > state.cache.max_size do
        evict_cache_items(state, data_size)
      else
        state
      end
    
    # Create cache item
    item = %{
      value: value,
      size: data_size,
      created_at: DateTime.utc_now(),
      ttl: Keyword.get(opts, :ttl),
      metadata: Keyword.get(opts, :metadata, %{})
    }
    
    # Update cache
    updated_cache = %{
      state.cache
      | items: Map.put(state.cache.items, key, item),
        size: state.cache.size + data_size
    }
    
    {:reply, :ok, %{state | cache: updated_cache}}
  end
  
  @impl true
  def handle_call({:cache_get, key}, _from, state) do
    case Map.get(state.cache.items, key) do
      nil ->
        {:reply, nil, state}
      
      item ->
        # Check TTL
        if item.ttl && DateTime.diff(DateTime.utc_now(), item.created_at) > item.ttl do
          # Item expired, remove it
          updated_cache = %{
            state.cache
            | items: Map.delete(state.cache.items, key),
              size: state.cache.size - item.size
          }
          {:reply, nil, %{state | cache: updated_cache}}
        else
          {:reply, item.value, state}
        end
    end
  end
  
  @impl true
  def handle_call({:cache_delete, key}, _from, state) do
    case Map.get(state.cache.items, key) do
      nil ->
        {:reply, :ok, state}
      
      item ->
        updated_cache = %{
          state.cache
          | items: Map.delete(state.cache.items, key),
            size: state.cache.size - item.size
        }
        {:reply, :ok, %{state | cache: updated_cache}}
    end
  end
  
  @impl true
  def handle_call(:cache_clear, _from, state) do
    updated_cache = %{state.cache | items: %{}, size: 0}
    {:reply, :ok, %{state | cache: updated_cache}}
  end
  
  @impl true
  def handle_call(:cache_usage, _from, state) do
    usage = %{
      item_count: map_size(state.cache.items),
      size: state.cache.size,
      max_size: state.cache.max_size,
      percentage_used: state.cache.size / state.cache.max_size * 100
    }
    {:reply, usage, state}
  end
  
  # Queue handlers
  
  @impl true
  def handle_call({:enqueue_operation, type, data}, _from, state) do
    operation = %{
      id: state.queue.next_id,
      type: type,
      data: data,
      created_at: DateTime.utc_now(),
      attempts: 0
    }
    
    updated_queue = %{
      state.queue
      | operations: state.queue.operations ++ [operation],
        next_id: state.queue.next_id + 1
    }
    
    {:reply, operation.id, %{state | queue: updated_queue}}
  end
  
  @impl true
  def handle_call(:pending_count, _from, state) do
    {:reply, length(state.queue.operations), state}
  end
  
  @impl true
  def handle_call(:process_pending, _from, state) do
    {processed, remaining} = process_queue_operations(state.queue.operations, state.config)
    
    updated_queue = %{state.queue | operations: remaining}
    
    {:reply, length(processed), %{state | queue: updated_queue}}
  end
  
  # Sync handlers
  
  @impl true
  def handle_call({:sync, opts}, _from, state) do
    # Update last sync time
    updated_sync = %{state.sync | last_sync: DateTime.utc_now()}
    
    # Simulate sync (in real implementation, this would communicate with cloud)
    Process.sleep(100)
    
    result = {:ok, %{
      status: :completed,
      synced_items: map_size(state.sync.pending_changes),
      timestamp: DateTime.utc_now()
    }}
    
    # Clear pending changes after successful sync
    updated_sync = %{updated_sync | pending_changes: %{}}
    
    {:reply, result, %{state | sync: updated_sync}}
  end
  
  @impl true
  def handle_call(:get_last_sync, _from, state) do
    {:reply, state.sync.last_sync, state}
  end
  
  @impl true
  def handle_call(:get_sync_state, _from, state) do
    {:reply, state.sync, state}
  end
  
  @impl true
  def handle_call({:update_sync_state, updates}, _from, state) do
    updated_sync = Map.merge(state.sync, updates)
    {:reply, :ok, %{state | sync: updated_sync}}
  end
  
  # Configuration handlers
  
  @impl true
  def handle_call({:update_config, config}, _from, state) do
    updated_config = Map.merge(state.config, config)
    
    # Update cache max size if changed
    updated_cache = 
      if config[:offline_cache_size] do
        %{state.cache | max_size: config[:offline_cache_size]}
      else
        state.cache
      end
    
    {:reply, :ok, %{state | config: updated_config, cache: updated_cache}}
  end
  
  @impl true
  def handle_call(:get_config, _from, state) do
    {:reply, state.config, state}
  end
  
  # Private helper functions
  
  defp evict_cache_items(state, needed_size) do
    if map_size(state.cache.items) == 0 do
      state
    else
      # Sort by creation time (oldest first) for LRU eviction
      sorted_items =
        state.cache.items
        |> Enum.sort_by(fn {_, item} -> item.created_at end, DateTime)
      
      # Evict until we have enough space
      {remaining_items, new_size} = 
        do_evict_items(sorted_items, state.cache.items, state.cache.size, needed_size)
      
      %{state | cache: %{state.cache | items: remaining_items, size: new_size}}
    end
  end
  
  defp do_evict_items([], items, size, _needed) do
    {items, size}
  end
  
  defp do_evict_items([{key, item} | rest], items, size, needed_size) do
    updated_items = Map.delete(items, key)
    updated_size = size - item.size
    
    if size - updated_size >= needed_size do
      {updated_items, updated_size}
    else
      do_evict_items(rest, updated_items, updated_size, needed_size)
    end
  end
  
  defp process_queue_operations(operations, config) do
    Enum.split_with(operations, fn operation ->
      result = process_single_operation(operation, config)
      result == :ok || result == :failed
    end)
  end
  
  defp process_single_operation(operation, config) do
    operation = %{operation | attempts: operation.attempts + 1}
    
    case operation.type do
      :function ->
        try do
          func = operation.data.function
          _result = func.()
          :ok
        rescue
          _ ->
            if operation.attempts >= config.retry_limit do
              :failed
            else
              :retry
            end
        end
      
      :sync ->
        # In real implementation, this would call actual sync logic
        :ok
      
      _ ->
        :failed
    end
  end
end