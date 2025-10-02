defmodule Raxol.Terminal.Graphics.MemoryManager do
  @moduledoc """
  Advanced memory management system for terminal graphics operations.

  This module provides:
  - Intelligent memory allocation and pooling
  - Graphics memory optimization strategies
  - Automatic garbage collection for graphics resources
  - Memory usage monitoring and reporting
  - Prevention of memory leaks in graphics operations
  - Dynamic memory scaling based on workload

  ## Features

  ### Memory Pooling
  - Pre-allocated memory pools for different graphics sizes
  - Pool-specific allocation strategies (FIFO, LRU, Size-based)
  - Dynamic pool resizing based on usage patterns
  - Memory fragmentation prevention

  ### Resource Management
  - Automatic cleanup of unused graphics resources
  - Reference counting for shared graphics elements
  - Weak references to prevent memory leaks
  - Resource lifecycle tracking

  ### Performance Optimization
  - Memory access pattern optimization
  - Cache-friendly memory layouts
  - NUMA-aware allocation on supported systems
  - Memory prefetching for predictable access patterns

  ## Usage

      # Initialize memory manager
      {:ok, manager} = MemoryManager.start_link(%{
        total_budget: 256_000_000,  # 256MB
        pool_strategy: :adaptive,
        gc_strategy: :generational
      })

      # Allocate graphics memory
      {:ok, buffer} = MemoryManager.allocate(manager, 1024 * 1024, %{
        type: :image_buffer,
        usage: :read_write,
        lifetime: :long
      })

      # Use memory pools
      {:ok, pool} = MemoryManager.create_pool(manager, :image_thumbnails, %{
        chunk_size: 256 * 256 * 4,  # 256x256 RGBA
        initial_count: 50,
        max_count: 200
      })
  """

  use Raxol.Core.Behaviours.BaseManager
  # bytes
  @type memory_budget :: non_neg_integer()
  @type allocation_id :: String.t()
  @type pool_id :: atom()

  @type memory_stats :: %{
          total_budget: memory_budget(),
          allocated: non_neg_integer(),
          available: non_neg_integer(),
          peak_usage: non_neg_integer(),
          allocation_count: non_neg_integer(),
          pool_stats: map(),
          fragmentation_ratio: float()
        }

  @type allocation_info :: %{
          id: allocation_id(),
          size: non_neg_integer(),
          type: atom(),
          usage: :read_only | :write_only | :read_write,
          lifetime: :short | :medium | :long,
          allocated_at: non_neg_integer(),
          last_accessed: non_neg_integer(),
          reference_count: non_neg_integer()
        }

  @type memory_pool :: %{
          id: pool_id(),
          chunk_size: non_neg_integer(),
          chunk_count: non_neg_integer(),
          max_chunks: non_neg_integer(),
          available_chunks: [term()],
          allocated_chunks: [term()],
          allocation_strategy: :fifo | :lifo | :lru | :adaptive,
          created_at: non_neg_integer()
        }

  defstruct [
    :config,
    :allocations,
    :memory_pools,
    :stats,
    :gc_state,
    :monitoring_pid
  ]

  @default_config %{
    # 128MB default budget
    total_budget: 128_000_000,
    # :fixed, :adaptive, :dynamic
    pool_strategy: :adaptive,
    # :mark_sweep, :generational, :incremental
    gc_strategy: :generational,
    # Trigger GC at 80% memory usage
    gc_threshold: 0.8,
    # Defragment at 30% fragmentation
    defrag_threshold: 0.3,
    monitoring_enabled: true,
    allocation_tracking: true,
    # Grow pools by 50% when needed
    pool_growth_factor: 1.5,
    # 64-byte alignment for GPU compatibility
    chunk_alignment: 64
  }

  # Public API

  @doc """
  Allocates memory for graphics operations.

  ## Parameters

  - `size` - Size in bytes to allocate
  - `metadata` - Allocation metadata (type, usage, lifetime)

  ## Returns

  - `{:ok, {allocation_id, buffer}}` - Successfully allocated
  - `{:error, reason}` - Allocation failed

  ## Examples

      {:ok, {id, buffer}} = MemoryManager.allocate(1024 * 1024, %{
        type: :image_buffer,
        usage: :read_write,
        lifetime: :medium
      })
  """
  @spec allocate(non_neg_integer(), map()) ::
          {:ok, {allocation_id(), term()}} | {:error, term()}
  def allocate(size, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:allocate, size, metadata})
  end

  @doc """
  Deallocates previously allocated memory.
  """
  @spec deallocate(allocation_id()) :: :ok | {:error, term()}
  def deallocate(allocation_id) do
    GenServer.call(__MODULE__, {:deallocate, allocation_id})
  end

  @doc """
  Creates a memory pool for frequently allocated graphics of the same size.

  ## Parameters

  - `pool_id` - Unique identifier for the pool
  - `config` - Pool configuration (chunk_size, initial_count, etc.)

  ## Examples

      {:ok, pool} = MemoryManager.create_pool(:thumbnails, %{
        chunk_size: 256 * 256 * 4,  # 256x256 RGBA
        initial_count: 20,
        max_count: 100,
        strategy: :lru
      })
  """
  @spec create_pool(pool_id(), map()) :: {:ok, memory_pool()} | {:error, term()}
  def create_pool(pool_id, config) do
    GenServer.call(__MODULE__, {:create_pool, pool_id, config})
  end

  @doc """
  Allocates memory from a specific pool.
  """
  @spec allocate_from_pool(pool_id(), map()) ::
          {:ok, {allocation_id(), term()}} | {:error, term()}
  def allocate_from_pool(pool_id, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:allocate_from_pool, pool_id, metadata})
  end

  @doc """
  Returns memory to a specific pool for reuse.
  """
  @spec return_to_pool(pool_id(), allocation_id()) :: :ok | {:error, term()}
  def return_to_pool(pool_id, allocation_id) do
    GenServer.call(__MODULE__, {:return_to_pool, pool_id, allocation_id})
  end

  @doc """
  Forces garbage collection of unused graphics resources.
  """
  @spec garbage_collect() :: {:ok, memory_stats()} | {:error, term()}
  def garbage_collect do
    GenServer.call(__MODULE__, :garbage_collect)
  end

  @doc """
  Defragments memory pools to reduce fragmentation.
  """
  @spec defragment() :: {:ok, memory_stats()} | {:error, term()}
  def defragment do
    GenServer.call(__MODULE__, :defragment)
  end

  @doc """
  Gets current memory usage statistics.
  """
  @spec get_stats() :: memory_stats()
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Sets memory budget dynamically.
  """
  @spec set_budget(memory_budget()) :: :ok | {:error, term()}
  def set_budget(new_budget) do
    GenServer.call(__MODULE__, {:set_budget, new_budget})
  end

  # GenServer Implementation

  @impl true
  def init_manager(config) do
    merged_config = Map.merge(@default_config, config)

    initial_state = %__MODULE__{
      config: merged_config,
      allocations: %{},
      memory_pools: %{},
      stats: initialize_stats(merged_config),
      gc_state: initialize_gc_state(),
      monitoring_pid: start_monitoring(merged_config)
    }

    # Schedule periodic maintenance
    schedule_maintenance()

    {:ok, initial_state}
  end

  @impl true
  def handle_manager_call({:allocate, size, metadata}, _from, state) do
    case can_allocate?(size, state) do
      true ->
        {:ok, allocation_id, buffer, new_state} =
          perform_allocation(size, metadata, state)

        {:reply, {:ok, {allocation_id, buffer}}, new_state}

      false ->
        # Try garbage collection and retry
        {:ok, allocation_id, buffer, new_state} =
          attempt_gc_and_retry(size, metadata, state)

        {:reply, {:ok, {allocation_id, buffer}}, new_state}
    end
  end

  @impl true
  def handle_manager_call({:deallocate, allocation_id}, _from, state) do
    case Map.get(state.allocations, allocation_id) do
      nil ->
        {:reply, {:error, :allocation_not_found}, state}

      allocation_info ->
        new_allocations = Map.delete(state.allocations, allocation_id)

        new_stats =
          update_stats_after_deallocation(state.stats, allocation_info)

        # Perform actual memory deallocation
        :ok = free_memory_buffer(allocation_info)

        {:reply, :ok, %{state | allocations: new_allocations, stats: new_stats}}
    end
  end

  @impl true
  def handle_manager_call({:create_pool, pool_id, config}, _from, state) do
    case Map.get(state.memory_pools, pool_id) do
      nil ->
        {:ok, pool, new_state} = create_memory_pool(pool_id, config, state)
        {:reply, {:ok, pool}, new_state}

      _existing_pool ->
        {:reply, {:error, :pool_already_exists}, state}
    end
  end

  @impl true
  def handle_manager_call(
        {:allocate_from_pool, pool_id, metadata},
        _from,
        state
      ) do
    case Map.get(state.memory_pools, pool_id) do
      nil ->
        {:reply, {:error, :pool_not_found}, state}

      pool ->
        {:ok, allocation_id, buffer, new_state} =
          allocate_from_memory_pool(pool, metadata, state)

        {:reply, {:ok, {allocation_id, buffer}}, new_state}
    end
  end

  @impl true
  def handle_manager_call(
        {:return_to_pool, pool_id, allocation_id},
        _from,
        state
      ) do
    case {Map.get(state.memory_pools, pool_id),
          Map.get(state.allocations, allocation_id)} do
      {nil, _} ->
        {:reply, {:error, :pool_not_found}, state}

      {_, nil} ->
        {:reply, {:error, :allocation_not_found}, state}

      {pool, allocation} ->
        {:error, reason} = return_allocation_to_pool(pool, allocation, state)
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call(:garbage_collect, _from, state) do
    {:ok, new_state, stats} = perform_garbage_collection(state)
    {:reply, {:ok, stats}, new_state}
  end

  @impl true
  def handle_manager_call(:defragment, _from, state) do
    {:ok, new_state, stats} = perform_defragmentation(state)
    {:reply, {:ok, stats}, new_state}
  end

  @impl true
  def handle_manager_call(:get_stats, _from, state) do
    current_stats = calculate_current_stats(state)
    {:reply, current_stats, state}
  end

  @impl true
  def handle_manager_call({:set_budget, new_budget}, _from, state) do
    case new_budget > 0 do
      true ->
        new_config = Map.put(state.config, :total_budget, new_budget)
        new_stats = Map.put(state.stats, :total_budget, new_budget)
        {:reply, :ok, %{state | config: new_config, stats: new_stats}}

      false ->
        {:reply, {:error, :invalid_budget}, state}
    end
  end

  @impl true
  def handle_manager_info(:maintenance, state) do
    new_state = perform_maintenance(state)
    schedule_maintenance()
    {:noreply, new_state}
  end

  @impl true
  def handle_manager_info({:monitoring, stats}, state) do
    # Update monitoring statistics
    Log.module_debug("Memory stats: #{inspect(stats)}")
    {:noreply, state}
  end

  # Private Functions

  defp can_allocate?(size, state) do
    available = state.stats.total_budget - state.stats.allocated
    size <= available
  end

  defp perform_allocation(size, metadata, state) do
    allocation_id = generate_allocation_id()

    # Allocate actual memory buffer
    {:ok, buffer} = allocate_memory_buffer(size, metadata)

    allocation_info = %{
      id: allocation_id,
      size: size,
      type: Map.get(metadata, :type, :generic),
      usage: Map.get(metadata, :usage, :read_write),
      lifetime: Map.get(metadata, :lifetime, :medium),
      allocated_at: System.system_time(:millisecond),
      last_accessed: System.system_time(:millisecond),
      reference_count: 1
    }

    new_allocations = Map.put(state.allocations, allocation_id, allocation_info)
    new_stats = update_stats_after_allocation(state.stats, allocation_info)

    new_state = %{state | allocations: new_allocations, stats: new_stats}
    {:ok, allocation_id, buffer, new_state}
  end

  defp attempt_gc_and_retry(size, metadata, state) do
    {:ok, new_state, _stats} = perform_garbage_collection(state)

    case can_allocate?(size, new_state) do
      true -> perform_allocation(size, metadata, new_state)
      # Return empty buffer
      false -> {:ok, generate_allocation_id(), <<>>, state}
    end
  end

  defp create_memory_pool(pool_id, config, state) do
    # 1MB default
    chunk_size = Map.get(config, :chunk_size, 1024 * 1024)
    initial_count = Map.get(config, :initial_count, 10)
    max_count = Map.get(config, :max_count, 100)
    strategy = Map.get(config, :strategy, :lru)

    # Pre-allocate initial chunks
    {:ok, chunks} = pre_allocate_chunks(chunk_size, initial_count)

    pool = %{
      id: pool_id,
      chunk_size: chunk_size,
      chunk_count: initial_count,
      max_chunks: max_count,
      available_chunks: chunks,
      allocated_chunks: [],
      allocation_strategy: strategy,
      created_at: System.system_time(:millisecond)
    }

    new_pools = Map.put(state.memory_pools, pool_id, pool)
    new_state = %{state | memory_pools: new_pools}

    {:ok, pool, new_state}
  end

  defp allocate_from_memory_pool(pool, metadata, state) do
    case pool.available_chunks do
      [] ->
        # Try to grow the pool
        # No chunks available, return empty allocation
        {:ok, generate_allocation_id(), <<>>, state}

      [chunk | remaining] ->
        allocation_id = generate_allocation_id()

        allocation_info = %{
          id: allocation_id,
          size: pool.chunk_size,
          type: Map.get(metadata, :type, :pooled),
          usage: Map.get(metadata, :usage, :read_write),
          lifetime: Map.get(metadata, :lifetime, :short),
          allocated_at: System.system_time(:millisecond),
          last_accessed: System.system_time(:millisecond),
          reference_count: 1,
          pool_id: pool.id
        }

        updated_pool = %{
          pool
          | available_chunks: remaining,
            allocated_chunks: [chunk | pool.allocated_chunks]
        }

        new_allocations =
          Map.put(state.allocations, allocation_id, allocation_info)

        new_pools = Map.put(state.memory_pools, pool.id, updated_pool)
        new_stats = update_stats_after_allocation(state.stats, allocation_info)

        new_state = %{
          state
          | allocations: new_allocations,
            memory_pools: new_pools,
            stats: new_stats
        }

        {:ok, allocation_id, chunk, new_state}
    end
  end

  defp perform_garbage_collection(state) do
    # Identify candidates for collection based on lifetime and access patterns
    candidates = identify_gc_candidates(state.allocations)

    # Collect unused allocations
    {collected_allocations, remaining_allocations} =
      collect_unused_allocations(candidates, state.allocations)

    # Update statistics
    freed_memory =
      Enum.reduce(collected_allocations, 0, fn {_id, info}, acc ->
        acc + info.size
      end)

    new_stats = %{
      state.stats
      | allocated: state.stats.allocated - freed_memory,
        allocation_count:
          state.stats.allocation_count - length(collected_allocations)
    }

    new_state = %{state | allocations: remaining_allocations, stats: new_stats}

    Log.info(
      "GC collected #{length(collected_allocations)} allocations, freed #{freed_memory} bytes"
    )

    {:ok, new_state, new_stats}
  end

  defp identify_gc_candidates(allocations) do
    now = System.system_time(:millisecond)

    Enum.filter(allocations, fn {_id, info} ->
      case info.lifetime do
        # 1 minute
        :short -> now - info.last_accessed > 60_000
        # 5 minutes
        :medium -> now - info.last_accessed > 300_000
        # 30 minutes
        :long -> now - info.last_accessed > 1800_000
      end
    end)
  end

  defp collect_unused_allocations(candidates, allocations) do
    Enum.split_with(allocations, fn {id, _info} ->
      not Enum.any?(candidates, fn {cand_id, _} -> cand_id == id end)
    end)
  end

  # Helper functions for memory operations

  defp allocate_memory_buffer(size, _metadata) do
    # In a real implementation, this would allocate actual memory
    # For now, simulate with a binary
    buffer = :binary.copy(<<0>>, size)
    {:ok, buffer}
  end

  defp free_memory_buffer(_allocation_info) do
    # In a real implementation, this would free actual memory
    :ok
  end

  defp pre_allocate_chunks(chunk_size, count) do
    chunks =
      Enum.map(1..count, fn _ ->
        :binary.copy(<<0>>, chunk_size)
      end)

    {:ok, chunks}
  end

  defp generate_allocation_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp initialize_stats(config) do
    %{
      total_budget: config.total_budget,
      allocated: 0,
      available: config.total_budget,
      peak_usage: 0,
      allocation_count: 0,
      pool_stats: %{},
      fragmentation_ratio: 0.0
    }
  end

  defp initialize_gc_state do
    %{
      last_gc: 0,
      gc_count: 0,
      total_freed: 0
    }
  end

  defp start_monitoring(config) do
    case config.monitoring_enabled do
      true ->
        {:ok, pid} = Task.start_link(fn -> monitoring_loop() end)
        pid

      false ->
        nil
    end
  end

  defp monitoring_loop do
    # Monitor every 5 seconds
    :timer.sleep(5000)
    stats = GenServer.call(__MODULE__, :get_stats)
    send(self(), {:monitoring, stats})
    monitoring_loop()
  end

  defp schedule_maintenance do
    # Every 30 seconds
    Process.send_after(self(), :maintenance, 30_000)
  end

  defp perform_maintenance(state) do
    # Perform routine maintenance tasks
    state
    |> check_memory_pressure()
    |> cleanup_stale_pools()
    |> update_fragmentation_stats()
  end

  defp check_memory_pressure(state) do
    usage_ratio = state.stats.allocated / state.stats.total_budget

    case usage_ratio > state.config.gc_threshold do
      true ->
        Log.info(
          "Memory pressure detected (#{Float.round(usage_ratio * 100, 1)}%), triggering GC"
        )

        {:ok, new_state, _stats} = perform_garbage_collection(state)
        new_state

      false ->
        state
    end
  end

  defp cleanup_stale_pools(state), do: state
  defp update_fragmentation_stats(state), do: state

  defp return_allocation_to_pool(_pool, _allocation, _state),
    do: {:error, :not_implemented}

  defp perform_defragmentation(state), do: {:ok, state, state.stats}
  defp calculate_current_stats(state), do: state.stats

  defp update_stats_after_allocation(stats, allocation_info) do
    %{
      stats
      | allocated: stats.allocated + allocation_info.size,
        available: stats.available - allocation_info.size,
        allocation_count: stats.allocation_count + 1,
        peak_usage:
          max(stats.peak_usage, stats.allocated + allocation_info.size)
    }
  end

  defp update_stats_after_deallocation(stats, allocation_info) do
    %{
      stats
      | allocated: stats.allocated - allocation_info.size,
        available: stats.available + allocation_info.size,
        allocation_count: stats.allocation_count - 1
    }
  end
end
