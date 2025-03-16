defmodule Raxol.Cloud.EdgeComputing do
  @moduledoc """
  Edge computing support for Raxol applications.
  
  This module provides functionality for optimizing Raxol applications
  at the edge, allowing for improved performance, reduced latency,
  and offline capabilities.
  
  Features:
  * Edge processing configuration
  * Offline mode and data synchronization
  * Resource optimization for edge devices
  * Automatic failover between edge and cloud
  * Edge-specific monitoring and diagnostics
  * Edge-to-cloud data streaming
  """
  
  alias Raxol.Cloud.EdgeComputing.{Cache, Queue, SyncManager}
  
  # Edge computing state
  defmodule State do
    @moduledoc false
    defstruct [
      :mode,
      :config,
      :edge_status,
      :cloud_status,
      :sync_status,
      :resources,
      :metrics
    ]
    
    def new do
      %__MODULE__{
        mode: :hybrid,
        config: %{
          connection_check_interval: 5000,
          sync_interval: 30000,
          retry_limit: 5,
          compression_enabled: true,
          offline_cache_size: 100_000_000, # 100MB
          priority_functions: []
        },
        edge_status: :initialized,
        cloud_status: :unknown,
        sync_status: :idle,
        resources: %{
          cpu_available: 0,
          memory_available: 0,
          storage_available: 0,
          bandwidth_available: 0
        },
        metrics: %{
          edge_requests: 0,
          cloud_requests: 0,
          sync_operations: 0,
          sync_failures: 0,
          last_successful_sync: nil
        }
      }
    end
  end
  
  # Process dictionary key for edge computing state
  @edge_key :raxol_edge_computing_state
  
  @doc """
  Initializes the edge computing system.
  
  ## Options
  
  * `:mode` - Operation mode (:edge_only, :cloud_only, :hybrid) (default: :hybrid)
  * `:connection_check_interval` - Time in ms between connection checks (default: 5000)
  * `:sync_interval` - Time in ms between cloud syncs (default: 30000)
  * `:retry_limit` - Number of retry attempts for operations (default: 5)
  * `:compression_enabled` - Whether to compress data for transfer (default: true)
  * `:offline_cache_size` - Maximum size in bytes for offline cache (default: 100MB)
  * `:priority_functions` - List of functions that should prioritize edge execution
  
  ## Examples
  
      iex> init(mode: :hybrid)
      :ok
  """
  def init(opts \\ []) do
    state = State.new()
    
    # Override defaults with provided options
    config = Keyword.take(opts, [
      :mode,
      :connection_check_interval,
      :sync_interval,
      :retry_limit,
      :compression_enabled,
      :offline_cache_size,
      :priority_functions
    ])
    
    # Update state with provided config
    state = update_config(state, config)
    
    # Initialize resources information
    state = %{state | resources: get_resource_info()}
    
    # Store state
    Process.put(@edge_key, state)
    
    # Initialize cache, queue and sync manager
    Cache.init(state.config)
    Queue.init(state.config)
    SyncManager.init(state.config)
    
    # Start connection monitoring
    schedule_connection_check(state.config.connection_check_interval)
    
    :ok
  end
  
  @doc """
  Updates the edge computing configuration.
  """
  def update_config(state \\ nil, config) do
    with_state(state, fn s ->
      # Merge new config with existing config
      updated_config = 
        s.config
        |> Map.merge(Map.new(config))
        
      # Update mode if specified
      updated_state = case Keyword.get(config, :mode) do
        nil -> s
        mode when mode in [:edge_only, :cloud_only, :hybrid] ->
          %{s | mode: mode}
        _ -> s
      end
      
      %{updated_state | config: updated_config}
    end)
  end
  
  @doc """
  Executes a function at the edge or in the cloud based on current mode and conditions.
  
  ## Options
  
  * `:force_edge` - Force execution at the edge even in hybrid mode (default: false)
  * `:force_cloud` - Force execution in the cloud even in hybrid mode (default: false)
  * `:fallback_fn` - Function to execute if primary execution fails (default: nil)
  * `:timeout` - Timeout in milliseconds for the operation (default: 5000)
  * `:retry` - Number of retry attempts (default: from config)
  
  ## Examples
  
      iex> execute(fn -> process_data(data) end)
      {:ok, result}
  """
  def execute(func, opts \\ []) when is_function(func, 0) do
    state = get_state()
    
    execute_location = determine_execution_location(state, opts)
    
    case execute_location do
      :edge ->
        execute_at_edge(func, opts)
        
      :cloud ->
        execute_in_cloud(func, opts)
        
      :hybrid ->
        # Try edge first, fallback to cloud
        case execute_at_edge(func, opts) do
          {:ok, result} -> {:ok, result}
          {:error, reason} -> 
            # Log the edge failure
            record_metric(:edge_failure)
            # Try cloud as fallback
            execute_in_cloud(func, opts)
        end
    end
  end
  
  @doc """
  Synchronizes data between edge and cloud.
  
  ## Options
  
  * `:force` - Force immediate synchronization (default: false)
  * `:selective` - List of data types to synchronize (default: all)
  * `:direction` - Sync direction (:both, :to_cloud, :from_cloud) (default: :both)
  * `:conflict_resolution` - Strategy for resolving conflicts (default: :latest_wins)
  
  ## Examples
  
      iex> sync(force: true)
      {:ok, %{status: :completed, synced_items: 5}}
  """
  def sync(opts \\ []) do
    state = get_state()
    
    if state.cloud_status == :connected or Keyword.get(opts, :force, false) do
      # Update sync status
      with_state(fn s -> %{s | sync_status: :syncing} end)
      
      # Delegate to sync manager
      result = SyncManager.sync(opts)
      
      # Update metrics
      record_metric(:sync_operation)
      
      case result do
        {:ok, sync_results} ->
          # Update last successful sync time
          with_state(fn s -> 
            metrics = Map.put(s.metrics, :last_successful_sync, DateTime.utc_now())
            %{s | sync_status: :idle, metrics: metrics}
          end)
          
          {:ok, sync_results}
          
        {:error, reason} ->
          # Record sync failure
          record_metric(:sync_failure)
          
          # Update state
          with_state(fn s -> %{s | sync_status: :failed} end)
          
          {:error, reason}
      end
    else
      # Queue sync for later when we have connection
      Queue.enqueue_operation(:sync, opts)
      {:ok, %{status: :queued}}
    end
  end
  
  @doc """
  Checks if the system is currently operating in offline mode.
  """
  def offline?() do
    state = get_state()
    state.cloud_status != :connected
  end
  
  @doc """
  Gets the current status of the edge computing system.
  """
  def status() do
    state = get_state()
    
    %{
      mode: state.mode,
      edge_status: state.edge_status,
      cloud_status: state.cloud_status,
      sync_status: state.sync_status,
      metrics: state.metrics,
      resources: state.resources,
      queued_operations: Queue.pending_count(),
      cache_usage: Cache.usage()
    }
  end
  
  @doc """
  Manually checks the cloud connection status and updates the system state.
  """
  def check_connection() do
    state = get_state()
    
    # Skip if in edge-only mode
    if state.mode != :edge_only do
      # Perform actual connection check
      connection_result = perform_connection_check()
      
      # Update state with connection result
      with_state(fn s ->
        %{s | cloud_status: if(connection_result, do: :connected, else: :disconnected)}
      end)
      
      # Process queued operations if we're connected
      if connection_result do
        process_pending_operations()
      end
      
      # Reschedule the check
      schedule_connection_check(state.config.connection_check_interval)
      
      connection_result
    else
      # In edge-only mode, we don't care about cloud connection
      false
    end
  end
  
  @doc """
  Forces the system into a specific mode.
  """
  def force_mode(mode) when mode in [:edge_only, :cloud_only, :hybrid] do
    with_state(fn state ->
      %{state | mode: mode}
    end)
    
    :ok
  end
  
  @doc """
  Gets metrics for the edge computing system.
  """
  def get_metrics() do
    state = get_state()
    state.metrics
  end
  
  @doc """
  Clears the edge cache.
  """
  def clear_cache() do
    Cache.clear()
    :ok
  end
  
  # Private functions
  
  defp with_state(arg1, arg2 \\ nil) do
    {state, fun} = if is_function(arg1) do
      {get_state(), arg1}
    else
      {arg1 || get_state(), arg2}
    end
    
    result = fun.(state)
    
    if is_map(result) and Map.has_key?(result, :mode) do
      # If a state map is returned, update the state
      Process.put(@edge_key, result)
      result
    else
      # Otherwise just return the result
      result
    end
  end
  
  defp get_state() do
    Process.get(@edge_key) || State.new()
  end
  
  defp determine_execution_location(state, opts) do
    force_edge = Keyword.get(opts, :force_edge, false)
    force_cloud = Keyword.get(opts, :force_cloud, false)
    
    cond do
      # Check forced options
      force_edge -> :edge
      force_cloud -> :cloud
      
      # Check configured mode
      state.mode == :edge_only -> :edge
      state.mode == :cloud_only -> :cloud
      
      # If hybrid, check cloud status
      state.mode == :hybrid and state.cloud_status != :connected -> :edge
      
      # If hybrid, check if function is prioritized for edge
      state.mode == :hybrid and is_prioritized_for_edge?(opts[:function_name]) -> :edge
      
      # If hybrid, check resource availability for optimal execution
      state.mode == :hybrid -> :hybrid
      
      # Default to edge
      true -> :edge
    end
  end
  
  defp is_prioritized_for_edge?(function_name) do
    state = get_state()
    
    function_name && function_name in state.config.priority_functions
  end
  
  defp execute_at_edge(func, opts) do
    # Record metric
    record_metric(:edge_request)
    
    # Execute with timeout
    timeout = Keyword.get(opts, :timeout, 5000)
    
    task = Task.async(func)
    
    try do
      result = Task.await(task, timeout)
      {:ok, result}
    catch
      :exit, {:timeout, _} ->
        Task.shutdown(task)
        {:error, :timeout}
      kind, reason ->
        Task.shutdown(task)
        {:error, {kind, reason}}
    end
  end
  
  defp execute_in_cloud(func, opts) do
    # Record metric
    record_metric(:cloud_request)
    
    state = get_state()
    
    # Check if we're connected to the cloud
    if state.cloud_status == :connected do
      # In a real implementation, this would make an API call to a cloud service
      # For now, we'll just simulate it
      simulate_cloud_execution(func, opts)
    else
      # We're offline, queue the operation for later
      operation_id = Queue.enqueue_operation(:function, %{function: func, options: opts})
      
      # Return queued status
      {:ok, %{status: :queued, operation_id: operation_id}}
    end
  end
  
  defp simulate_cloud_execution(func, opts) do
    # Simulate network latency
    Process.sleep(50)
    
    # Execute the function
    try do
      result = func.()
      {:ok, result}
    rescue
      e -> {:error, e}
    end
  end
  
  defp process_pending_operations() do
    # Process operations in the queue
    Queue.process_pending()
  end
  
  defp perform_connection_check() do
    # In a real implementation, this would check actual network connectivity
    # For now, just simulate with a high success rate
    :rand.uniform(100) <= 95
  end
  
  defp schedule_connection_check(interval) do
    # This would set up a timer in a real implementation
    # For demo purposes, we'll just use a simple spawn
    spawn(fn ->
      Process.sleep(interval)
      check_connection()
    end)
  end
  
  defp get_resource_info() do
    # In a real implementation, this would check actual system resources
    %{
      cpu_available: 80, # percentage
      memory_available: 500_000_000, # bytes
      storage_available: 1_000_000_000, # bytes
      bandwidth_available: 1_000_000 # bytes/s
    }
  end
  
  defp record_metric(metric_type) do
    with_state(fn state ->
      updated_metrics = case metric_type do
        :edge_request ->
          Map.update!(state.metrics, :edge_requests, &(&1 + 1))
        :cloud_request ->
          Map.update!(state.metrics, :cloud_requests, &(&1 + 1))
        :sync_operation ->
          Map.update!(state.metrics, :sync_operations, &(&1 + 1))
        :sync_failure ->
          Map.update!(state.metrics, :sync_failures, &(&1 + 1))
        :edge_failure ->
          state.metrics
        _ ->
          state.metrics
      end
      
      %{state | metrics: updated_metrics}
    end)
  end
end

# Cache implementation for edge computing
defmodule Raxol.Cloud.EdgeComputing.Cache do
  @moduledoc false
  
  # Process dictionary key for cache
  @cache_key :raxol_edge_cache
  
  def init(config) do
    cache = %{
      items: %{},
      size: 0,
      max_size: config.offline_cache_size
    }
    
    Process.put(@cache_key, cache)
    :ok
  end
  
  def put(key, value, opts \\ []) do
    cache = get_cache()
    
    # Calculate size of data (simplified)
    data_size = :erlang.term_to_binary(value) |> byte_size()
    
    # Check if we have space
    if cache.size + data_size > cache.max_size do
      # Need to evict something
      evict(data_size)
    end
    
    # Add the item
    item = %{
      value: value,
      size: data_size,
      created_at: DateTime.utc_now(),
      ttl: Keyword.get(opts, :ttl),
      metadata: Keyword.get(opts, :metadata, %{})
    }
    
    updated_items = Map.put(cache.items, key, item)
    updated_size = cache.size + data_size
    
    # Update cache
    Process.put(@cache_key, %{cache | items: updated_items, size: updated_size})
    
    :ok
  end
  
  def get(key) do
    cache = get_cache()
    
    case Map.get(cache.items, key) do
      nil -> nil
      item -> 
        # Check TTL
        if item.ttl && DateTime.diff(DateTime.utc_now(), item.created_at) > item.ttl do
          # Item expired
          delete(key)
          nil
        else
          item.value
        end
    end
  end
  
  def delete(key) do
    cache = get_cache()
    
    case Map.get(cache.items, key) do
      nil -> :ok
      item ->
        # Update cache
        updated_items = Map.delete(cache.items, key)
        updated_size = cache.size - item.size
        
        Process.put(@cache_key, %{cache | items: updated_items, size: updated_size})
        
        :ok
    end
  end
  
  def clear() do
    cache = get_cache()
    
    # Reset cache
    Process.put(@cache_key, %{cache | items: %{}, size: 0})
    
    :ok
  end
  
  def usage() do
    cache = get_cache()
    
    %{
      item_count: map_size(cache.items),
      size: cache.size,
      max_size: cache.max_size,
      percentage_used: cache.size / cache.max_size * 100
    }
  end
  
  # Private helpers
  
  defp get_cache() do
    Process.get(@cache_key) || %{items: %{}, size: 0, max_size: 100_000_000}
  end
  
  defp evict(needed_size) do
    cache = get_cache()
    
    if map_size(cache.items) == 0 do
      :ok
    else
      # Simple LRU eviction strategy
      # Sort by creation time (oldest first)
      sorted_items = cache.items
      |> Enum.sort_by(fn {_, item} -> item.created_at end, DateTime)
      
      # Start evicting until we have enough space
      {updated_items, updated_size} = evict_items(sorted_items, cache.items, cache.size, needed_size)
      
      # Update cache
      Process.put(@cache_key, %{cache | items: updated_items, size: updated_size})
      
      :ok
    end
  end
  
  defp evict_items([], items, size, _) do
    # Nothing left to evict
    {items, size}
  end
  
  defp evict_items([{key, item} | rest], items, size, needed_size) do
    # Remove this item
    updated_items = Map.delete(items, key)
    updated_size = size - item.size
    
    # Check if we have enough space now
    if size - updated_size >= needed_size do
      # We've freed enough space
      {updated_items, updated_size}
    else
      # Need to evict more
      evict_items(rest, updated_items, updated_size, needed_size)
    end
  end
end

# Queue implementation for edge computing
defmodule Raxol.Cloud.EdgeComputing.Queue do
  @moduledoc false
  
  # Process dictionary key for queue
  @queue_key :raxol_edge_queue
  
  def init(_config) do
    queue = %{
      operations: [],
      next_id: 1
    }
    
    Process.put(@queue_key, queue)
    :ok
  end
  
  def enqueue_operation(type, data) do
    queue = get_queue()
    
    operation = %{
      id: queue.next_id,
      type: type,
      data: data,
      created_at: DateTime.utc_now(),
      attempts: 0
    }
    
    # Add operation to queue
    updated_operations = queue.operations ++ [operation]
    
    # Update queue
    Process.put(@queue_key, %{queue | operations: updated_operations, next_id: queue.next_id + 1})
    
    operation.id
  end
  
  def process_pending() do
    queue = get_queue()
    
    # Process each pending operation
    {processed, failed} = Enum.reduce(queue.operations, {0, 0}, fn op, {processed, failed} ->
      case process_operation(op) do
        :ok -> {processed + 1, failed}
        :retry -> {processed, failed}
        :failed -> {processed, failed + 1}
      end
    end)
    
    # Remove processed operations
    updated_operations = Enum.filter(queue.operations, fn op ->
      op.attempts > 0 && process_operation(op) == :retry
    end)
    
    # Update queue
    Process.put(@queue_key, %{queue | operations: updated_operations})
    
    %{processed: processed, failed: failed, remaining: length(updated_operations)}
  end
  
  def pending_count() do
    queue = get_queue()
    length(queue.operations)
  end
  
  # Private helpers
  
  defp get_queue() do
    Process.get(@queue_key) || %{operations: [], next_id: 1}
  end
  
  defp process_operation(operation) do
    # Increment attempt counter
    operation = %{operation | attempts: operation.attempts + 1}
    
    # Process based on type
    case operation.type do
      :function ->
        # Execute the function in the cloud
        func = operation.data.function
        opts = operation.data.options
        
        try do
          # Simulate cloud execution
          _result = func.()
          :ok
        rescue
          _ ->
            if operation.attempts >= 3 do
              :failed
            else
              :retry
            end
        end
        
      :sync ->
        # Attempt to sync
        try do
          # Delegate to sync manager
          SyncManager.sync(operation.data)
          :ok
        rescue
          _ ->
            if operation.attempts >= 3 do
              :failed
            else
              :retry
            end
        end
        
      _ ->
        :failed
    end
  end
end

# Sync manager implementation for edge computing
defmodule Raxol.Cloud.EdgeComputing.SyncManager do
  @moduledoc false
  
  # Process dictionary key for sync state
  @sync_key :raxol_edge_sync_state
  
  def init(config) do
    sync_state = %{
      last_sync: nil,
      config: config,
      pending_changes: %{},
      conflict_strategy: :latest_wins
    }
    
    Process.put(@sync_key, sync_state)
    :ok
  end
  
  def sync(opts \\ []) do
    sync_state = get_sync_state()
    
    # Record the sync attempt
    updated_sync_state = %{sync_state | last_sync: DateTime.utc_now()}
    Process.put(@sync_key, updated_sync_state)
    
    # Simulate sync
    # In a real implementation, this would communicate with a cloud service
    Process.sleep(100)
    
    # Return success with some stats
    {:ok, %{
      status: :completed,
      synced_items: map_size(sync_state.pending_changes),
      timestamp: DateTime.utc_now()
    }}
  end
  
  # Private helpers
  
  defp get_sync_state() do
    Process.get(@sync_key) || %{
      last_sync: nil,
      config: %{},
      pending_changes: %{},
      conflict_strategy: :latest_wins
    }
  end
end 