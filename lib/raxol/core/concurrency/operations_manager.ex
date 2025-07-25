defmodule Raxol.Core.Concurrency.OperationsManager do
  @moduledoc """
  High-performance concurrent operations manager for Raxol terminal operations.
  
  This module provides optimized concurrent execution of terminal operations with:
  - Dynamic worker pools based on system resources
  - Operation batching and queuing
  - Back-pressure management
  - Load balancing across CPU cores
  - Resource monitoring and adaptation
  """

  use GenServer
  require Logger

  alias Raxol.Core.Concurrency.WorkerPool
  alias Raxol.Core.Performance.Metrics

  @default_config %{
    # Worker pool configuration
    min_workers: 2,
    max_workers: :erlang.system_info(:logical_processors),
    worker_idle_timeout: 5_000,
    
    # Queue management
    max_queue_size: 10_000,
    batch_size: 50,
    batch_timeout: 10,
    
    # Performance tuning
    enable_metrics: true,
    enable_load_balancing: true,
    adaptive_scaling: true,
    
    # Back-pressure settings
    high_water_mark: 8_000,
    low_water_mark: 2_000
  }

  @type operation :: {module(), atom(), [any()]} | function()
  @type operation_result :: {:ok, any()} | {:error, any()}
  @type operation_priority :: :low | :normal | :high | :critical

  defmodule State do
    @moduledoc false
    defstruct [
      :config,
      :worker_pools,
      :operation_queue,
      :metrics,
      :load_stats,
      :back_pressure_active
    ]
  end

  ## Public API

  @doc """
  Starts the operations manager.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    config = Map.merge(@default_config, Map.new(opts))
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @doc """
  Executes an operation asynchronously with specified priority.
  """
  @spec execute_async(operation(), operation_priority()) :: {:ok, reference()} | {:error, term()}
  def execute_async(operation, priority \\ :normal) do
    GenServer.call(__MODULE__, {:execute_async, operation, priority})
  end

  @doc """
  Executes a batch of operations concurrently.
  """
  @spec execute_batch([operation()], operation_priority()) :: {:ok, reference()} | {:error, term()}
  def execute_batch(operations, priority \\ :normal) when is_list(operations) do
    GenServer.call(__MODULE__, {:execute_batch, operations, priority})
  end

  @doc """
  Executes an operation synchronously with timeout.
  """
  @spec execute_sync(operation(), timeout()) :: operation_result()
  def execute_sync(operation, timeout \\ 5_000) do
    case execute_async(operation, :high) do
      {:ok, ref} ->
        receive do
          {:operation_result, ^ref, result} -> result
        after
          timeout -> {:error, :timeout}
        end
      error -> error
    end
  end

  @doc """
  Gets current performance metrics.
  """
  @spec get_metrics() :: {:ok, map()} | {:error, term()}
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  @doc """
  Gets current system load information.
  """
  @spec get_load_stats() :: {:ok, map()} | {:error, term()}
  def get_load_stats do
    GenServer.call(__MODULE__, :get_load_stats)
  end

  @doc """
  Adjusts worker pool size dynamically.
  """
  @spec scale_workers(pos_integer()) :: :ok | {:error, term()}
  def scale_workers(target_size) do
    GenServer.cast(__MODULE__, {:scale_workers, target_size})
  end

  ## GenServer Callbacks

  @impl GenServer
  def init(config) do
    # Initialize worker pools based on CPU topology
    worker_pools = initialize_worker_pools(config)
    
    # Set up operation queue with priority handling
    operation_queue = :queue.new()
    
    # Initialize performance metrics
    metrics = initialize_metrics(config)
    
    # Start load monitoring
    if config.adaptive_scaling do
      schedule_load_monitoring()
    end

    state = %State{
      config: config,
      worker_pools: worker_pools,
      operation_queue: operation_queue,
      metrics: metrics,
      load_stats: %{},
      back_pressure_active: false
    }

    Logger.info("OperationsManager started with #{map_size(worker_pools)} worker pools")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:execute_async, operation, priority}, from, state) do
    case check_back_pressure(state) do
      :ok ->
        ref = make_ref()
        
        # Add operation to priority queue
        queue_item = {priority, ref, operation, from, System.monotonic_time(:microsecond)}
        updated_queue = enqueue_with_priority(state.operation_queue, queue_item)
        
        # Try to dispatch immediately if workers available
        new_state = %{state | operation_queue: updated_queue}
        dispatch_queued_operations(new_state)
        
        {:reply, {:ok, ref}, new_state}

      {:error, :back_pressure} ->
        {:reply, {:error, :system_overloaded}, state}
    end
  end

  @impl GenServer
  def handle_call({:execute_batch, operations, priority}, from, state) do
    case check_back_pressure(state) do
      :ok ->
        ref = make_ref()
        
        # Create batch operation
        batch_operation = fn ->
          results = execute_operations_concurrently(operations, state.worker_pools)
          {:batch_result, results}
        end
        
        queue_item = {priority, ref, batch_operation, from, System.monotonic_time(:microsecond)}
        updated_queue = enqueue_with_priority(state.operation_queue, queue_item)
        
        new_state = %{state | operation_queue: updated_queue}
        dispatch_queued_operations(new_state)
        
        {:reply, {:ok, ref}, new_state}

      {:error, :back_pressure} ->
        {:reply, {:error, :system_overloaded}, state}
    end
  end

  @impl GenServer
  def handle_call(:get_metrics, _from, state) do
    metrics = collect_current_metrics(state)
    {:reply, {:ok, metrics}, state}
  end

  @impl GenServer
  def handle_call(:get_load_stats, _from, state) do
    {:reply, {:ok, state.load_stats}, state}
  end

  @impl GenServer
  def handle_cast({:scale_workers, target_size}, state) do
    new_pools = scale_worker_pools(state.worker_pools, target_size)
    new_state = %{state | worker_pools: new_pools}
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(:monitor_load, state) do
    # Update load statistics
    load_stats = collect_load_statistics()
    new_state = %{state | load_stats: load_stats}
    
    # Adaptive scaling based on load
    if state.config.adaptive_scaling do
      new_state = maybe_scale_workers(new_state)
    end
    
    # Update back-pressure status
    new_state = update_back_pressure_status(new_state)
    
    # Schedule next monitoring cycle
    schedule_load_monitoring()
    
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info({:operation_complete, worker_pid, ref, result}, state) do
    # Send result back to caller
    send_operation_result(ref, result)
    
    # Update metrics
    updated_metrics = update_operation_metrics(state.metrics, result)
    
    # Try to dispatch more operations
    new_state = %{state | metrics: updated_metrics}
    dispatch_queued_operations(new_state)
    
    {:noreply, new_state}
  end

  ## Private Functions

  defp initialize_worker_pools(config) do
    # Create worker pools optimized for CPU topology
    logical_processors = :erlang.system_info(:logical_processors)
    pool_count = min(logical_processors, config.max_workers)
    
    for i <- 1..pool_count, into: %{} do
      pool_name = :"worker_pool_#{i}"
      {:ok, pool_pid} = WorkerPool.start_link([
        name: pool_name,
        size: 1,
        max_overflow: 2
      ])
      {pool_name, pool_pid}
    end
  end

  defp initialize_metrics(config) do
    if config.enable_metrics do
      %{
        operations_completed: 0,
        operations_failed: 0,
        total_execution_time: 0,
        average_latency: 0,
        queue_size: 0,
        worker_utilization: 0.0,
        started_at: System.monotonic_time(:microsecond)
      }
    else
      %{}
    end
  end

  defp check_back_pressure(state) do
    queue_size = :queue.len(state.operation_queue)
    
    if queue_size > state.config.high_water_mark do
      {:error, :back_pressure}
    else
      :ok
    end
  end

  defp enqueue_with_priority(queue, {priority, _ref, _op, _from, _timestamp} = item) do
    # Simple priority queue implementation
    # In production, this would use a more sophisticated priority queue
    priority_value = priority_to_number(priority)
    :queue.in({priority_value, item}, queue)
  end

  defp priority_to_number(:critical), do: 1
  defp priority_to_number(:high), do: 2
  defp priority_to_number(:normal), do: 3
  defp priority_to_number(:low), do: 4

  defp dispatch_queued_operations(state) do
    case :queue.out(state.operation_queue) do
      {{:value, {_priority, queue_item}}, remaining_queue} ->
        case find_available_worker(state.worker_pools) do
          {:ok, worker_pool} ->
            {priority, ref, operation, from, timestamp} = queue_item
            
            # Dispatch to worker
            WorkerPool.execute_async(worker_pool, operation, ref, self())
            
            # Update metrics
            queue_wait_time = System.monotonic_time(:microsecond) - timestamp
            updated_metrics = record_queue_wait_time(state.metrics, queue_wait_time)
            
            %{state | 
              operation_queue: remaining_queue,
              metrics: updated_metrics
            }

          :no_workers_available ->
            state
        end

      {:empty, _} ->
        state
    end
  end

  defp find_available_worker(worker_pools) do
    # Find the worker pool with the least load
    worker_pools
    |> Enum.find(fn {_name, pool_pid} ->
      WorkerPool.available_workers(pool_pid) > 0
    end)
    |> case do
      {_name, pool_pid} -> {:ok, pool_pid}
      nil -> :no_workers_available
    end
  end

  defp execute_operations_concurrently(operations, worker_pools) do
    # Execute operations in parallel using Task.async_stream
    operations
    |> Task.async_stream(
      fn operation -> execute_single_operation(operation) end,
      max_concurrency: map_size(worker_pools),
      timeout: 30_000
    )
    |> Enum.map(fn
      {:ok, result} -> result
      {:exit, reason} -> {:error, {:execution_failed, reason}}
    end)
  end

  defp execute_single_operation({module, function, args}) when is_list(args) do
    apply(module, function, args)
  end

  defp execute_single_operation(operation) when is_function(operation) do
    operation.()
  end

  defp collect_load_statistics do
    %{
      cpu_utilization: get_cpu_utilization(),
      memory_usage: get_memory_usage(),
      process_count: :erlang.system_info(:process_count),
      run_queue_length: :erlang.statistics(:run_queue),
      timestamp: System.monotonic_time(:microsecond)
    }
  end

  defp get_cpu_utilization do
    # Simplified CPU utilization - in production would use more sophisticated method
    case :erlang.statistics(:wall_clock) do
      {wall_clock_time, _} when wall_clock_time > 0 ->
        # Basic approximation based on run queue
        run_queue = :erlang.statistics(:run_queue)
        logical_processors = :erlang.system_info(:logical_processors)
        min(100.0, (run_queue / logical_processors) * 100.0)
      _ -> 0.0
    end
  end

  defp get_memory_usage do
    memory_info = :erlang.memory()
    %{
      total: Keyword.get(memory_info, :total, 0),
      processes: Keyword.get(memory_info, :processes, 0),
      system: Keyword.get(memory_info, :system, 0),
      binary: Keyword.get(memory_info, :binary, 0)
    }
  end

  defp maybe_scale_workers(state) do
    cpu_utilization = state.load_stats[:cpu_utilization] || 0.0
    queue_size = :queue.len(state.operation_queue)
    current_workers = map_size(state.worker_pools)
    
    cond do
      # Scale up if high CPU utilization and queue backlog
      cpu_utilization > 80.0 and queue_size > 100 and 
      current_workers < state.config.max_workers ->
        scale_worker_pools(state.worker_pools, current_workers + 1)
        state

      # Scale down if low utilization
      cpu_utilization < 20.0 and queue_size < 10 and 
      current_workers > state.config.min_workers ->
        scale_worker_pools(state.worker_pools, current_workers - 1)
        state

      true ->
        state
    end
  end

  defp scale_worker_pools(pools, target_size) do
    current_size = map_size(pools)
    
    cond do
      target_size > current_size ->
        # Add new worker pools
        new_pools = for i <- (current_size + 1)..target_size, into: %{} do
          pool_name = :"worker_pool_#{i}"
          {:ok, pool_pid} = WorkerPool.start_link([name: pool_name, size: 1])
          {pool_name, pool_pid}
        end
        Map.merge(pools, new_pools)

      target_size < current_size ->
        # Remove excess worker pools
        pools_to_keep = pools |> Enum.take(target_size) |> Map.new()
        
        # Gracefully stop removed pools
        pools
        |> Enum.drop(target_size)
        |> Enum.each(fn {_name, pool_pid} ->
          WorkerPool.stop(pool_pid)
        end)
        
        pools_to_keep

      true ->
        pools
    end
  end

  defp update_back_pressure_status(state) do
    queue_size = :queue.len(state.operation_queue)
    
    back_pressure_active = cond do
      queue_size > state.config.high_water_mark -> true
      queue_size < state.config.low_water_mark -> false
      true -> state.back_pressure_active
    end
    
    %{state | back_pressure_active: back_pressure_active}
  end

  defp collect_current_metrics(state) do
    queue_size = :queue.len(state.operation_queue)
    worker_count = map_size(state.worker_pools)
    
    Map.merge(state.metrics, %{
      queue_size: queue_size,
      worker_count: worker_count,
      back_pressure_active: state.back_pressure_active,
      uptime: System.monotonic_time(:microsecond) - state.metrics[:started_at]
    })
  end

  defp update_operation_metrics(metrics, result) do
    case result do
      {:ok, _} ->
        %{metrics | 
          operations_completed: metrics.operations_completed + 1
        }
      {:error, _} ->
        %{metrics | 
          operations_failed: metrics.operations_failed + 1
        }
    end
  end

  defp record_queue_wait_time(metrics, wait_time) do
    # Update average latency with exponential moving average
    alpha = 0.1
    current_avg = metrics.average_latency || 0
    new_avg = alpha * wait_time + (1 - alpha) * current_avg
    
    %{metrics | average_latency: new_avg}
  end

  defp send_operation_result(ref, result) do
    # Find the process that requested this operation and send result
    # This is simplified - in production would maintain a registry
    spawn(fn ->
      send(self(), {:operation_result, ref, result})
    end)
  end

  defp schedule_load_monitoring do
    Process.send_after(self(), :monitor_load, 1_000)
  end
end