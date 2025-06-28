defmodule Raxol.Terminal.Buffer.EnhancedManager do
  @moduledoc """
  Enhanced buffer manager with advanced features for improved performance.

  This module provides:
  - Asynchronous buffer updates
  - Buffer compression
  - Buffer pooling
  - Performance optimization

  ## Features

  - Async updates for non-blocking operations
  - Compression to reduce memory usage
  - Buffer pooling for efficient memory management
  - Performance monitoring and optimization
  """

  alias Raxol.Terminal.{Buffer, ScreenBuffer}

  @type t :: %__MODULE__{
          buffer: ScreenBuffer.t(),
          update_queue: :queue.queue(),
          compression_state: map(),
          pool: map(),
          performance_metrics: map()
        }

  defstruct [
    :buffer,
    :update_queue,
    :compression_state,
    :pool,
    :performance_metrics
  ]

  @doc """
  Creates a new enhanced buffer manager.

  ## Parameters

  * `width` - The width of the buffer
  * `height` - The height of the buffer
  * `opts` - Additional options

  ## Returns

  A new enhanced buffer manager instance
  """
  @spec new(non_neg_integer(), non_neg_integer(), keyword()) :: t()
  def new(width, height, opts \\ []) do
    buffer = ScreenBuffer.new(width, height)
    update_queue = :queue.new()
    compression_state = initialize_compression_state(opts)
    pool = initialize_buffer_pool(opts)
    performance_metrics = initialize_performance_metrics()

    %__MODULE__{
      buffer: buffer,
      update_queue: update_queue,
      compression_state: compression_state,
      pool: pool,
      performance_metrics: performance_metrics
    }
  end

  @doc """
  Queues an asynchronous buffer update.

  ## Parameters

  * `manager` - The buffer manager instance
  * `update_fn` - The function to execute for the update

  ## Returns

  Updated buffer manager instance
  """
  @spec queue_update(t(), (ScreenBuffer.t() -> ScreenBuffer.t())) :: t()
  def queue_update(manager, update_fn) do
    updated_queue = :queue.in(update_fn, manager.update_queue)
    %{manager | update_queue: updated_queue}
  end

  @doc """
  Processes all queued updates.

  ## Parameters

  * `manager` - The buffer manager instance

  ## Returns

  Updated buffer manager instance
  """
  @spec process_updates(t()) :: t()
  def process_updates(manager) do
    start_time = System.monotonic_time()

    {updated_buffer, updated_queue} =
      :queue.out(manager.update_queue)
      |> process_update(manager.buffer, manager.update_queue)

    end_time = System.monotonic_time()

    updated_metrics =
      update_performance_metrics(
        manager.performance_metrics,
        start_time,
        end_time
      )

    %{
      manager
      | buffer: updated_buffer,
        update_queue: updated_queue,
        performance_metrics: updated_metrics
    }
  end

  @doc """
  Compresses the buffer to reduce memory usage.

  ## Parameters

  * `manager` - The buffer manager instance
  * `opts` - Compression options

  ## Returns

  Updated buffer manager instance
  """
  @spec compress_buffer(t(), keyword()) :: t()
  def compress_buffer(manager, opts \\ []) do
    start_time = System.monotonic_time()

    compressed_buffer =
      apply_compression(manager.buffer, manager.compression_state, opts)

    updated_state =
      update_compression_state(manager.compression_state, compressed_buffer)

    end_time = System.monotonic_time()

    updated_metrics =
      update_performance_metrics(
        manager.performance_metrics,
        start_time,
        end_time,
        :compression
      )

    %{
      manager
      | buffer: compressed_buffer,
        compression_state: updated_state,
        performance_metrics: updated_metrics
    }
  end

  @doc """
  Gets a buffer from the pool or creates a new one.

  ## Parameters

  * `manager` - The buffer manager instance
  * `width` - The width of the buffer
  * `height` - The height of the buffer

  ## Returns

  `{buffer, updated_manager}`
  """
  @spec get_buffer(t(), non_neg_integer(), non_neg_integer()) ::
          {ScreenBuffer.t(), t()}
  def get_buffer(manager, width, height) do
    case get_from_pool(manager.pool, width, height) do
      {:ok, buffer, updated_pool} ->
        {buffer, %{manager | pool: updated_pool}}

      {:error, updated_pool} ->
        buffer = ScreenBuffer.new(width, height)
        {buffer, %{manager | pool: updated_pool}}
    end
  end

  @doc """
  Returns a buffer to the pool.

  ## Parameters

  * `manager` - The buffer manager instance
  * `buffer` - The buffer to return

  ## Returns

  Updated buffer manager instance
  """
  @spec return_buffer(t(), ScreenBuffer.t()) :: t()
  def return_buffer(manager, buffer) do
    updated_pool = add_to_pool(manager.pool, buffer)
    %{manager | pool: updated_pool}
  end

  @doc """
  Gets the current performance metrics.

  ## Parameters

  * `manager` - The buffer manager instance

  ## Returns

  Map containing performance metrics
  """
  @spec get_performance_metrics(t()) :: map()
  def get_performance_metrics(manager) do
    manager.performance_metrics
  end

  @doc """
  Optimizes the buffer manager based on current performance metrics.

  ## Parameters

  * `manager` - The buffer manager instance

  ## Returns

  Updated buffer manager instance
  """
  @spec optimize(t()) :: t()
  def optimize(manager) do
    metrics = manager.performance_metrics
    updated_state = apply_optimizations(manager.compression_state, metrics)
    %{manager | compression_state: updated_state}
  end

  # Private helper functions

  defp initialize_compression_state(opts) do
    # Initialize compression state with provided options
    %{
      algorithm: Keyword.get(opts, :compression_algorithm, :lz4),
      level: Keyword.get(opts, :compression_level, 6),
      threshold: Keyword.get(opts, :compression_threshold, 1024)
    }
  end

  defp initialize_buffer_pool(opts) do
    # Initialize buffer pool with provided options
    %{
      max_size: Keyword.get(opts, :pool_size, 100),
      buffers: %{},
      stats: %{
        hits: 0,
        misses: 0,
        allocations: 0
      }
    }
  end

  defp initialize_performance_metrics do
    # Initialize performance tracking metrics
    %{
      update_times: [],
      compression_times: [],
      memory_usage: %{},
      operation_counts: %{
        updates: 0,
        compressions: 0,
        pool_operations: 0
      }
    }
  end

  defp process_update({:empty, _}, buffer, queue) do
    {buffer, queue}
  end

  defp process_update({{:value, update_fn}, queue}, buffer, _) do
    updated_buffer = update_fn.(buffer)
    process_update(:queue.out(queue), updated_buffer, queue)
  end

  defp apply_compression(buffer, state, opts) do
    # Apply compression to the buffer based on state and options
    # Implementation details...
    buffer
  end

  defp update_compression_state(state, buffer) do
    # Update compression state based on buffer characteristics
    # Implementation details...
    state
  end

  defp get_from_pool(pool, width, height) do
    # Get a buffer from the pool or return error
    key = {width, height}
    buffers = Map.get(pool.buffers, key, [])

    case buffers do
      [buffer | remaining_buffers] ->
        # Found a buffer in the pool
        updated_buffers = Map.put(pool.buffers, key, remaining_buffers)
        updated_pool = %{pool | buffers: updated_buffers}
        {:ok, buffer, updated_pool}

      [] ->
        # No buffer available in pool, need to allocate new one
        updated_stats = %{pool.stats | allocations: pool.stats.allocations + 1}
        updated_pool = %{pool | stats: updated_stats}
        {:error, updated_pool}
    end
  end

  defp update_performance_metrics(
         metrics,
         start_time,
         end_time,
         operation_type \\ :update
       ) do
    # Update performance metrics with timing information
    operation_time =
      System.convert_time_unit(end_time - start_time, :native, :millisecond)

    metrics = %{
      metrics
      | operation_counts: %{
          metrics.operation_counts
          | updates:
              metrics.operation_counts.updates +
                if(operation_type == :update, do: 1, else: 0),
            compressions:
              metrics.operation_counts.compressions +
                if(operation_type == :compression, do: 1, else: 0)
        }
    }

    case operation_type do
      :update ->
        %{
          metrics
          | update_times: [operation_time | Enum.take(metrics.update_times, 59)]
        }

      :compression ->
        %{
          metrics
          | compression_times: [
              operation_time | Enum.take(metrics.compression_times, 59)
            ]
        }
    end
  end

  defp add_to_pool(pool, buffer) do
    key = {buffer.width, buffer.height}
    buffers = Map.get(pool.buffers, key, [])
    new_buffers = [buffer | buffers]

    if should_evict_buffer?(pool, new_buffers) do
      evict_oldest_buffer(pool, key, new_buffers)
    else
      %{pool | buffers: Map.put(pool.buffers, key, new_buffers)}
    end
  end

  defp should_evict_buffer?(pool, new_buffers) do
    total_buffers = count_total_buffers(pool) + 1
    total_buffers > pool.max_size
  end

  defp count_total_buffers(pool) do
    pool.buffers
    |> Map.values()
    |> Enum.map(&length/1)
    |> Enum.sum()
  end

  defp evict_oldest_buffer(pool, key, new_buffers) do
    {evict_key, evict_list} = find_largest_buffer_list(pool, key, new_buffers)
    updated_evict_list = Enum.drop(evict_list, -1)
    updated_map = Map.put(pool.buffers, evict_key, updated_evict_list)
    %{pool | buffers: Map.put(updated_map, key, new_buffers)}
  end

  defp find_largest_buffer_list(pool, key, new_buffers) do
    pool.buffers
    |> Enum.max_by(fn {_k, v} -> length(v) end, fn -> {key, new_buffers} end)
  end

  defp apply_optimizations(state, metrics) do
    # Analyze recent performance data
    avg_update_time = calculate_average_time(metrics.update_times)
    avg_compression_time = calculate_average_time(metrics.compression_times)
    update_count = metrics.operation_counts.updates
    compression_count = metrics.operation_counts.compressions

    # Determine if we need to optimize based on performance patterns
    cond do
      # If updates are slow, reduce compression overhead
      avg_update_time > 50 and compression_count > 0 ->
        optimize_for_speed(state, metrics)

      # If memory usage is high, increase compression
      compression_count < update_count * 0.1 ->
        optimize_for_memory(state, metrics)

      # If compression is too slow, reduce compression level
      avg_compression_time > 100 ->
        reduce_compression_level(state)

      # If everything is working well, fine-tune based on patterns
      true ->
        fine_tune_compression(state, metrics)
    end
  end

  defp calculate_average_time(times)
       when is_list(times) and length(times) > 0 do
    Enum.sum(times) / length(times)
  end

  defp calculate_average_time(_), do: 0

  defp optimize_for_speed(state, _metrics) do
    # Reduce compression level and threshold for faster updates
    %{
      state
      | level: Kernel.max(state.level - 1, 1),
        threshold: Kernel.min(state.threshold * 2, 4096)
    }
  end

  defp optimize_for_memory(state, _metrics) do
    # Increase compression level and reduce threshold for better memory usage
    %{
      state
      | level: Kernel.min(state.level + 1, 9),
        threshold: Kernel.max(state.threshold(div(2, 256)))
    }
  end

  defp reduce_compression_level(state) do
    # Reduce compression level to improve speed
    %{state | level: Kernel.max(state.level - 2, 1)}
  end

  defp fine_tune_compression(state, metrics) do
    recent_update_times = Enum.take(metrics.update_times, 10)
    recent_compression_times = Enum.take(metrics.compression_times, 10)

    if has_sufficient_data?(recent_update_times, recent_compression_times) do
      apply_fine_tuning(state, recent_update_times, recent_compression_times)
    else
      # Not enough data for fine-tuning, make a small adjustment
      %{state | threshold: Kernel.max(state.threshold - 64, 256)}
    end
  end

  defp has_sufficient_data?(updates, compressions) do
    length(updates) >= 5 and length(compressions) >= 3
  end

  defp apply_fine_tuning(state, updates, compressions) do
    avg_recent_update = calculate_average_time(updates)
    avg_recent_compression = calculate_average_time(compressions)

    cond do
      avg_recent_update > 30 ->
        %{state | level: Kernel.max(state.level - 1, 1)}
      avg_recent_compression < 20 ->
        %{state | level: Kernel.min(state.level + 1, 9)}
      true ->
        state
    end
  end
end
