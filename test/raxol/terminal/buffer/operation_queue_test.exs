defmodule Raxol.Terminal.Buffer.OperationQueueTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Buffer.OperationQueue

  def dummy_op(id), do: {:set_cell, id, id, %{char: "X"}}

  setup do
    queue = OperationQueue.new(3)
    %{queue: queue}
  end

  test "new/1 creates a queue with correct batch size" do
    queue = OperationQueue.new(5)
    assert queue.batch_size == 5
    assert queue.pending_operations == []
    refute queue.processing_batch
  end

  test "add_operation/2 adds a single operation", %{queue: queue} do
    queue = OperationQueue.add_operation(queue, dummy_op(1))
    assert length(queue.pending_operations) == 1
  end

  test "add_operations/2 adds multiple operations", %{queue: queue} do
    ops = [dummy_op(1), dummy_op(2)]
    queue = OperationQueue.add_operations(queue, ops)
    assert length(queue.pending_operations) == 2
  end

  test "should_process?/1 returns true when enough ops", %{queue: queue} do
    queue =
      OperationQueue.add_operations(queue, [
        dummy_op(1),
        dummy_op(2),
        dummy_op(3)
      ])

    assert OperationQueue.should_process?(queue)
  end

  test "should_process?/1 returns false if not enough ops or already processing",
       %{queue: queue} do
    queue = OperationQueue.add_operation(queue, dummy_op(1))
    refute OperationQueue.should_process?(queue)
    queue = OperationQueue.mark_processing(queue)
    refute OperationQueue.should_process?(queue)
  end

  test "pending_count/1 and empty?/1", %{queue: queue} do
    assert OperationQueue.pending_count(queue) == 0
    assert OperationQueue.empty?(queue)
    queue = OperationQueue.add_operation(queue, dummy_op(1))
    refute OperationQueue.empty?(queue)
    assert OperationQueue.pending_count(queue) == 1
  end

  test "mark_processing/1 and mark_not_processing/1", %{queue: queue} do
    queue = OperationQueue.mark_processing(queue)
    assert queue.processing_batch
    queue = OperationQueue.mark_not_processing(queue)
    refute queue.processing_batch
  end

  test "clear/1 removes all pending operations", %{queue: queue} do
    queue = OperationQueue.add_operations(queue, [dummy_op(1), dummy_op(2)])
    queue = OperationQueue.clear(queue)
    assert queue.pending_operations == []
  end

  test "get_batch/2 returns correct batch and updates queue", %{queue: queue} do
    queue =
      OperationQueue.add_operations(queue, [
        dummy_op(1),
        dummy_op(2),
        dummy_op(3),
        dummy_op(4)
      ])

    {batch, new_queue} = OperationQueue.get_batch(queue, 2)
    assert length(batch) == 2
    assert length(new_queue.pending_operations) == 2
  end

  test "get_all/1 returns all ops and clears queue", %{queue: queue} do
    queue = OperationQueue.add_operations(queue, [dummy_op(1), dummy_op(2)])
    {all, cleared} = OperationQueue.get_all(queue)
    assert length(all) == 2
    assert cleared.pending_operations == []
  end

  test "get_stats/1 returns correct stats", %{queue: queue} do
    queue = OperationQueue.add_operations(queue, [dummy_op(1)])
    stats = OperationQueue.get_stats(queue)
    assert stats.pending_count == 1
    assert stats.is_processing == false
    assert stats.batch_size == 3
    assert stats.is_empty == false
  end
end
