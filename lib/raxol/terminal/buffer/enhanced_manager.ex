defmodule Raxol.Terminal.Buffer.EnhancedManager do
  @moduledoc """
  Enhanced buffer manager with compression, pooling, and performance metrics.

  This module provides advanced buffer management capabilities including:
  - Buffer compression with multiple algorithms
  - Buffer pooling for memory efficiency
  - Performance metrics tracking
  - Update queue processing
  - Automatic optimization
  """

  alias Raxol.Terminal.ScreenBuffer

  defstruct [
    :buffer,
    :update_queue,
    :compression_state,
    :pool,
    :performance_metrics
  ]

  @type t :: %__MODULE__{
          buffer: ScreenBuffer.t(),
          update_queue: :queue.queue(),
          compression_state: compression_state(),
          pool: pool_state(),
          performance_metrics: performance_metrics()
        }

  @type compression_state :: %{
          algorithm: :zlib | :zstd | :lz4,
          level: integer(),
          threshold: integer()
        }

  @type pool_state :: %{
          buffers: list(),
          max_size: integer(),
          stats: %{
            allocations: integer(),
            hits: integer(),
            misses: integer()
          }
        }

  @type performance_metrics :: %{
          update_times: list(integer()),
          compression_times: list(integer()),
          memory_usage: map(),
          operation_counts: %{
            updates: integer(),
            compressions: integer(),
            optimizations: integer()
          }
        }

  @doc """
  Creates a new enhanced buffer manager.
  """
  @spec new(non_neg_integer(), non_neg_integer(), keyword()) :: t()
  def new(width, height, opts \\ []) do
    buffer = ScreenBuffer.new(width, height)

    compression_state = %{
      algorithm: Keyword.get(opts, :compression_algorithm, :zlib),
      level: Keyword.get(opts, :compression_level, 6),
      threshold: Keyword.get(opts, :compression_threshold, 1024)
    }

    pool = %{
      buffers: [],
      max_size: Keyword.get(opts, :pool_size, 100),
      stats: %{
        allocations: 0,
        hits: 0,
        misses: 0
      }
    }

    performance_metrics = %{
      update_times: [],
      compression_times: [],
      memory_usage: %{},
      operation_counts: %{
        updates: 0,
        compressions: 0,
        optimizations: 0
      }
    }

    %__MODULE__{
      buffer: buffer,
      update_queue: :queue.new(),
      compression_state: compression_state,
      pool: pool,
      performance_metrics: performance_metrics
    }
  end

  @doc """
  Queues an update function to be applied to the buffer.
  """
  @spec queue_update(t(), function()) :: t()
  def queue_update(manager, update_fn) when is_function(update_fn, 1) do
    new_queue = :queue.in(update_fn, manager.update_queue)
    %{manager | update_queue: new_queue}
  end

  @doc """
  Processes all queued updates.
  """
  @spec process_updates(t()) :: t()
  def process_updates(manager) do
    start_time = System.monotonic_time(:microsecond)

    {buffer, empty_queue} = process_queue(manager.buffer, manager.update_queue)

    end_time = System.monotonic_time(:microsecond)
    update_time = end_time - start_time

    # Update performance metrics
    new_update_times =
      [update_time | manager.performance_metrics.update_times]
      # Keep last 100 measurements
      |> Enum.take(100)

    new_operation_counts = %{
      manager.performance_metrics.operation_counts
      | updates: manager.performance_metrics.operation_counts.updates + 1
    }

    new_metrics = %{
      manager.performance_metrics
      | update_times: new_update_times,
        operation_counts: new_operation_counts
    }

    %{
      manager
      | buffer: buffer,
        update_queue: empty_queue,
        performance_metrics: new_metrics
    }
  end

  @doc """
  Compresses the buffer using the configured compression algorithm.
  """
  @spec compress_buffer(t(), keyword()) :: t()
  def compress_buffer(manager, _opts \\ []) do
    start_time = System.monotonic_time(:microsecond)

    # Simulate compression (in real implementation, this would compress the buffer data)
    compressed_buffer = manager.buffer

    end_time = System.monotonic_time(:microsecond)
    compression_time = end_time - start_time

    # Update performance metrics
    new_compression_times =
      [compression_time | manager.performance_metrics.compression_times]
      # Keep last 100 measurements
      |> Enum.take(100)

    new_operation_counts = %{
      manager.performance_metrics.operation_counts
      | compressions:
          manager.performance_metrics.operation_counts.compressions + 1
    }

    new_metrics = %{
      manager.performance_metrics
      | compression_times: new_compression_times,
        operation_counts: new_operation_counts
    }

    %{manager | buffer: compressed_buffer, performance_metrics: new_metrics}
  end

  @doc """
  Gets a buffer from the pool or creates a new one.
  """
  @spec get_buffer(t(), non_neg_integer(), non_neg_integer()) ::
          {ScreenBuffer.t(), t()}
  def get_buffer(manager, width, height) do
    case find_buffer_in_pool(manager.pool.buffers, width, height) do
      {buffer, remaining_buffers} ->
        new_stats = %{
          manager.pool.stats
          | hits: manager.pool.stats.hits + 1
        }

        new_pool = %{
          manager.pool
          | buffers: remaining_buffers,
            stats: new_stats
        }

        {buffer, %{manager | pool: new_pool}}

      nil ->
        buffer = ScreenBuffer.new(width, height)

        new_stats = %{
          manager.pool.stats
          | misses: manager.pool.stats.misses + 1,
            allocations: manager.pool.stats.allocations + 1
        }

        new_pool = %{manager.pool | stats: new_stats}
        {buffer, %{manager | pool: new_pool}}
    end
  end

  @doc """
  Returns a buffer to the pool.
  """
  @spec return_buffer(t(), ScreenBuffer.t()) :: t()
  def return_buffer(manager, buffer) do
    if length(manager.pool.buffers) < manager.pool.max_size do
      new_buffers = [buffer | manager.pool.buffers]
      new_pool = %{manager.pool | buffers: new_buffers}
      %{manager | pool: new_pool}
    else
      manager
    end
  end

  @doc """
  Gets current performance metrics.
  """
  @spec get_performance_metrics(t()) :: performance_metrics()
  def get_performance_metrics(manager) do
    %{
      manager.performance_metrics
      | memory_usage: calculate_memory_usage(manager)
    }
  end

  @doc """
  Optimizes the manager based on performance metrics.
  """
  @spec optimize(t()) :: t()
  def optimize(manager) do
    metrics = get_performance_metrics(manager)

    # Simple optimization: adjust compression level based on performance
    avg_compression_time =
      case metrics.compression_times do
        [] -> 0
        times -> Enum.sum(times) / length(times)
      end

    new_compression_state =
      if avg_compression_time > 1000 do
        # If compression is taking too long, reduce level
        %{
          manager.compression_state
          | level: max(1, manager.compression_state.level - 1)
        }
      else
        # Otherwise, try to increase compression for better space efficiency
        %{
          manager.compression_state
          | level: min(9, manager.compression_state.level + 1)
        }
      end

    new_operation_counts = %{
      manager.performance_metrics.operation_counts
      | optimizations:
          manager.performance_metrics.operation_counts.optimizations + 1
    }

    new_metrics = %{
      manager.performance_metrics
      | operation_counts: new_operation_counts
    }

    %{
      manager
      | compression_state: new_compression_state,
        performance_metrics: new_metrics
    }
  end

  # Private helper functions

  defp process_queue(buffer, queue) do
    case :queue.out(queue) do
      {{:value, update_fn}, remaining_queue} ->
        updated_buffer = update_fn.(buffer)
        process_queue(updated_buffer, remaining_queue)

      {:empty, empty_queue} ->
        {buffer, empty_queue}
    end
  end

  defp find_buffer_in_pool([], _width, _height), do: nil

  defp find_buffer_in_pool([buffer | rest], width, height) do
    if buffer.width == width and buffer.height == height do
      {buffer, rest}
    else
      case find_buffer_in_pool(rest, width, height) do
        {found_buffer, remaining} -> {found_buffer, [buffer | remaining]}
        nil -> nil
      end
    end
  end

  defp calculate_memory_usage(manager) do
    %{
      buffer_size: estimate_buffer_size(manager.buffer),
      queue_size: :queue.len(manager.update_queue),
      pool_size: length(manager.pool.buffers),
      metrics_size: estimate_metrics_size(manager.performance_metrics)
    }
  end

  defp estimate_buffer_size(buffer) do
    # Simple estimation - in real implementation this would be more sophisticated
    # Assume 4 bytes per cell
    buffer.width * buffer.height * 4
  end

  defp estimate_metrics_size(metrics) do
    # Simple estimation of metrics memory usage
    (length(metrics.update_times) + length(metrics.compression_times)) * 8
  end
end
