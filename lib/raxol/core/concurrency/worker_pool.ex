defmodule Raxol.Core.Concurrency.WorkerPool do
  @moduledoc """
  High-performance worker pool for executing terminal operations concurrently.
  
  Features:
  - Dynamic worker scaling
  - Load balancing
  - Worker health monitoring
  - Resource isolation
  - Graceful shutdown
  """

  use GenServer
  require Logger

  defmodule Worker do
    @moduledoc "Individual worker process for executing operations."
    
    use GenServer
    
    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts)
    end
    
    def execute(worker_pid, operation, ref, manager_pid) do
      GenServer.cast(worker_pid, {:execute, operation, ref, manager_pid})
    end
    
    def get_stats(worker_pid) do
      GenServer.call(worker_pid, :get_stats)
    end
    
    # GenServer callbacks
    
    def init(_opts) do
      state = %{
        busy: false,
        operations_completed: 0,
        total_execution_time: 0,
        last_operation_at: nil,
        created_at: System.monotonic_time(:microsecond)
      }
      {:ok, state}
    end
    
    def handle_cast({:execute, operation, ref, manager_pid}, state) do
      start_time = System.monotonic_time(:microsecond)
      
      result = try do
        case operation do
          {module, function, args} -> apply(module, function, args)
          fun when is_function(fun) -> fun.()
          _ -> {:error, :invalid_operation}
        end
      rescue
        error -> {:error, {:execution_error, error}}
      catch
        :exit, reason -> {:error, {:exit, reason}}
        error -> {:error, {:catch, error}}
      end
      
      end_time = System.monotonic_time(:microsecond)
      execution_time = end_time - start_time
      
      # Send result back to manager
      send(manager_pid, {:operation_complete, self(), ref, result})
      
      # Update worker statistics
      new_state = %{state |
        busy: false,
        operations_completed: state.operations_completed + 1,
        total_execution_time: state.total_execution_time + execution_time,
        last_operation_at: end_time
      }
      
      {:noreply, new_state}
    end
    
    def handle_call(:get_stats, _from, state) do
      uptime = System.monotonic_time(:microsecond) - state.created_at
      avg_execution_time = if state.operations_completed > 0 do
        state.total_execution_time / state.operations_completed
      else
        0
      end
      
      stats = %{
        busy: state.busy,
        operations_completed: state.operations_completed,
        average_execution_time: avg_execution_time,
        uptime: uptime,
        last_operation_at: state.last_operation_at
      }
      
      {:reply, stats, state}
    end
  end

  defmodule State do
    @moduledoc false
    defstruct [
      :name,
      :workers,
      :available_workers,
      :busy_workers,
      :min_size,
      :max_size,
      :max_overflow,
      :overflow_workers,
      :strategy,
      :supervisor_pid
    ]
  end

  ## Public API

  @doc """
  Starts a worker pool.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Executes an operation asynchronously using the pool.
  """
  @spec execute_async(pid(), any(), reference(), pid()) :: :ok | {:error, term()}
  def execute_async(pool_pid, operation, ref, manager_pid) do
    GenServer.call(pool_pid, {:execute_async, operation, ref, manager_pid})
  end

  @doc """
  Gets the number of available workers.
  """
  @spec available_workers(pid()) :: non_neg_integer()
  def available_workers(pool_pid) do
    GenServer.call(pool_pid, :available_workers)
  end

  @doc """
  Gets pool statistics.
  """
  @spec get_stats(pid()) :: map()
  def get_stats(pool_pid) do
    GenServer.call(pool_pid, :get_stats)
  end

  @doc """
  Scales the pool to the specified size.
  """
  @spec scale(pid(), pos_integer()) :: :ok | {:error, term()}
  def scale(pool_pid, new_size) do
    GenServer.call(pool_pid, {:scale, new_size})
  end

  @doc """
  Stops the worker pool gracefully.
  """
  @spec stop(pid()) :: :ok
  def stop(pool_pid) do
    GenServer.call(pool_pid, :stop)
  end

  ## GenServer callbacks

  @impl GenServer
  def init(opts) do
    # Extract configuration
    name = Keyword.get(opts, :name, __MODULE__)
    size = Keyword.get(opts, :size, 4)
    max_overflow = Keyword.get(opts, :max_overflow, 0)
    strategy = Keyword.get(opts, :strategy, :lifo)
    
    # Start worker supervisor
    {:ok, supervisor_pid} = start_worker_supervisor(name)
    
    # Start initial workers
    workers = start_workers(supervisor_pid, size)
    
    state = %State{
      name: name,
      workers: workers,
      available_workers: workers,
      busy_workers: [],
      min_size: size,
      max_size: size + max_overflow,
      max_overflow: max_overflow,
      overflow_workers: [],
      strategy: strategy,
      supervisor_pid: supervisor_pid
    }
    
    Logger.debug("WorkerPool #{name} started with #{length(workers)} workers")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:execute_async, operation, ref, manager_pid}, _from, state) do
    case get_available_worker(state) do
      {:ok, worker_pid, new_state} ->
        Worker.execute(worker_pid, operation, ref, manager_pid)
        {:reply, :ok, new_state}
        
      {:error, :no_workers} ->
        # Try to create overflow worker if allowed
        case create_overflow_worker(state) do
          {:ok, worker_pid, new_state} ->
            Worker.execute(worker_pid, operation, ref, manager_pid)
            {:reply, :ok, new_state}
            
          {:error, :max_overflow_reached} ->
            {:reply, {:error, :pool_exhausted}, state}
        end
    end
  end

  @impl GenServer
  def handle_call(:available_workers, _from, state) do
    count = length(state.available_workers)
    {:reply, count, state}
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    # Collect statistics from all workers
    worker_stats = collect_worker_stats(state.workers ++ state.overflow_workers)
    
    pool_stats = %{
      total_workers: length(state.workers) + length(state.overflow_workers),
      available_workers: length(state.available_workers),
      busy_workers: length(state.busy_workers),
      overflow_workers: length(state.overflow_workers),
      min_size: state.min_size,
      max_size: state.max_size,
      strategy: state.strategy,
      worker_stats: worker_stats
    }
    
    {:reply, pool_stats, state}
  end

  @impl GenServer
  def handle_call({:scale, new_size}, _from, state) do
    cond do
      new_size > length(state.workers) ->
        # Scale up
        additional_workers = new_size - length(state.workers)
        new_workers = start_workers(state.supervisor_pid, additional_workers)
        updated_state = %{state |
          workers: state.workers ++ new_workers,
          available_workers: state.available_workers ++ new_workers,
          min_size: new_size,
          max_size: max(new_size, state.max_size)
        }
        {:reply, :ok, updated_state}
        
      new_size < length(state.workers) ->
        # Scale down
        workers_to_stop = length(state.workers) - new_size
        {workers_to_keep, workers_to_terminate} = Enum.split(state.workers, new_size)
        
        # Stop excess workers gracefully
        Enum.each(workers_to_terminate, fn worker_pid ->
          GenServer.stop(worker_pid, :normal)
        end)
        
        # Update available workers list
        available_workers = Enum.filter(state.available_workers, fn worker_pid ->
          worker_pid in workers_to_keep
        end)
        
        updated_state = %{state |
          workers: workers_to_keep,
          available_workers: available_workers,
          min_size: new_size
        }
        {:reply, :ok, updated_state}
        
      true ->
        # No change needed
        {:reply, :ok, state}
    end
  end

  @impl GenServer
  def handle_call(:stop, _from, state) do
    # Stop all workers
    Enum.each(state.workers ++ state.overflow_workers, fn worker_pid ->
      GenServer.stop(worker_pid, :normal)
    end)
    
    # Stop supervisor
    GenServer.stop(state.supervisor_pid, :normal)
    
    {:stop, :normal, :ok, state}
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, worker_pid, reason}, state) do
    # Handle worker crash
    Logger.warning("Worker #{inspect(worker_pid)} crashed with reason: #{inspect(reason)}")
    
    cond do
      worker_pid in state.workers ->
        # Replace crashed permanent worker
        {:ok, new_worker} = start_worker(state.supervisor_pid)
        
        updated_state = %{state |
          workers: replace_worker(state.workers, worker_pid, new_worker),
          available_workers: replace_worker(state.available_workers, worker_pid, new_worker),
          busy_workers: List.delete(state.busy_workers, worker_pid)
        }
        {:noreply, updated_state}
        
      worker_pid in state.overflow_workers ->
        # Remove crashed overflow worker
        updated_state = %{state |
          overflow_workers: List.delete(state.overflow_workers, worker_pid),
          busy_workers: List.delete(state.busy_workers, worker_pid)
        }
        {:noreply, updated_state}
        
      true ->
        # Unknown worker, ignore
        {:noreply, state}
    end
  end

  ## Private functions

  defp start_worker_supervisor(pool_name) do
    # Simple supervisor for workers
    DynamicSupervisor.start_link(
      name: :"#{pool_name}_supervisor",
      strategy: :one_for_one
    )
  end

  defp start_workers(supervisor_pid, count) do
    for _ <- 1..count do
      {:ok, worker_pid} = start_worker(supervisor_pid)
      worker_pid
    end
  end

  defp start_worker(supervisor_pid) do
    spec = {Worker, []}
    case DynamicSupervisor.start_child(supervisor_pid, spec) do
      {:ok, worker_pid} ->
        # Monitor the worker
        Process.monitor(worker_pid)
        {:ok, worker_pid}
      error -> error
    end
  end

  defp get_available_worker(state) do
    case state.strategy do
      :lifo ->
        get_available_worker_lifo(state)
      :fifo ->
        get_available_worker_fifo(state)
      :random ->
        get_available_worker_random(state)
    end
  end

  defp get_available_worker_lifo(state) do
    case state.available_workers do
      [worker_pid | rest] ->
        new_state = %{state |
          available_workers: rest,
          busy_workers: [worker_pid | state.busy_workers]
        }
        {:ok, worker_pid, new_state}
        
      [] ->
        {:error, :no_workers}
    end
  end

  defp get_available_worker_fifo(state) do
    case Enum.reverse(state.available_workers) do
      [worker_pid | rest] ->
        new_state = %{state |
          available_workers: Enum.reverse(rest),
          busy_workers: [worker_pid | state.busy_workers]
        }
        {:ok, worker_pid, new_state}
        
      [] ->
        {:error, :no_workers}
    end
  end

  defp get_available_worker_random(state) do
    case state.available_workers do
      [] ->
        {:error, :no_workers}
        
      workers ->
        worker_pid = Enum.random(workers)
        new_state = %{state |
          available_workers: List.delete(workers, worker_pid),
          busy_workers: [worker_pid | state.busy_workers]
        }
        {:ok, worker_pid, new_state}
    end
  end

  defp create_overflow_worker(state) do
    if length(state.overflow_workers) < state.max_overflow do
      case start_worker(state.supervisor_pid) do
        {:ok, worker_pid} ->
          new_state = %{state |
            overflow_workers: [worker_pid | state.overflow_workers],
            busy_workers: [worker_pid | state.busy_workers]
          }
          {:ok, worker_pid, new_state}
          
        error ->
          error
      end
    else
      {:error, :max_overflow_reached}
    end
  end

  defp collect_worker_stats(workers) do
    workers
    |> Enum.map(fn worker_pid ->
      case Worker.get_stats(worker_pid) do
        stats when is_map(stats) -> 
          Map.put(stats, :pid, worker_pid)
        _ -> 
          %{pid: worker_pid, error: :stats_unavailable}
      end
    end)
  end

  defp replace_worker(worker_list, old_worker, new_worker) do
    Enum.map(worker_list, fn
      ^old_worker -> new_worker
      worker -> worker
    end)
  end
end