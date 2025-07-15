defmodule Raxol.Terminal.Buffer.OperationQueue do
  @moduledoc """
  Manages the queue of pending buffer operations.

  This module is responsible for:
  - Adding operations to the queue
  - Managing queue size and batching
  - Providing queue statistics
  - Queue cleanup and management
  """

  alias Raxol.Terminal.Buffer.OperationProcessor

  @type operation :: OperationProcessor.operation()
  @type queue_state :: %{
          pending_operations: [operation()],
          processing_batch: boolean(),
          batch_size: non_neg_integer()
        }

  @doc """
  Creates a new operation queue.
  """
  @spec new(non_neg_integer()) :: queue_state()
  def new(batch_size \\ 20) do
    %{
      pending_operations: [],
      processing_batch: false,
      batch_size: batch_size
    }
  end

  @doc """
  Adds an operation to the queue.
  """
  @spec add_operation(queue_state(), operation()) :: queue_state()
  def add_operation(queue, operation) do
    %{queue | pending_operations: queue.pending_operations ++ [operation]}
  end

  @doc """
  Adds multiple operations to the queue.
  """
  @spec add_operations(queue_state(), [operation()]) :: queue_state()
  def add_operations(queue, operations) do
    %{queue | pending_operations: queue.pending_operations ++ operations}
  end

  @doc """
  Checks if the queue should be processed based on size.
  """
  @spec should_process?(queue_state()) :: boolean()
  def should_process?(queue) do
    !queue.processing_batch and
      length(queue.pending_operations) >= queue.batch_size
  end

  @doc """
  Gets the number of pending operations.
  """
  @spec pending_count(queue_state()) :: non_neg_integer()
  def pending_count(queue) do
    length(queue.pending_operations)
  end

  @doc """
  Checks if the queue is empty.
  """
  @spec empty?(queue_state()) :: boolean()
  def empty?(queue) do
    queue.pending_operations == []
  end

  @doc """
  Marks the queue as processing.
  """
  @spec mark_processing(queue_state()) :: queue_state()
  def mark_processing(queue) do
    %{queue | processing_batch: true}
  end

  @doc """
  Marks the queue as not processing.
  """
  @spec mark_not_processing(queue_state()) :: queue_state()
  def mark_not_processing(queue) do
    %{queue | processing_batch: false}
  end

  @doc """
  Clears all pending operations.
  """
  @spec clear(queue_state()) :: queue_state()
  def clear(queue) do
    %{queue | pending_operations: []}
  end

  @doc """
  Gets a batch of operations to process.
  """
  @spec get_batch(queue_state(), non_neg_integer()) ::
          {[operation()], queue_state()}
  def get_batch(queue, batch_size) do
    {operations_to_process, remaining_operations} =
      Enum.split(queue.pending_operations, batch_size)

    new_queue = %{queue | pending_operations: remaining_operations}
    {operations_to_process, new_queue}
  end

  @doc """
  Gets all pending operations and clears the queue.
  """
  @spec get_all(queue_state()) :: {[operation()], queue_state()}
  def get_all(queue) do
    {queue.pending_operations, clear(queue)}
  end

  @doc """
  Gets queue statistics.
  """
  @spec get_stats(queue_state()) :: map()
  def get_stats(queue) do
    %{
      pending_count: pending_count(queue),
      is_processing: queue.processing_batch,
      batch_size: queue.batch_size,
      is_empty: empty?(queue)
    }
  end
end
