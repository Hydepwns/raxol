defmodule Raxol.Terminal.Buffer.EnhancedManagerTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.{Buffer.EnhancedManager, ScreenBuffer}

  setup do
    manager = EnhancedManager.new(80, 24)
    {:ok, %{manager: manager}}
  end

  describe "new/3" do
    test "creates a new enhanced buffer manager", %{manager: manager} do
      assert manager.buffer != nil
      assert manager.update_queue != nil
      assert manager.compression_state != nil
      assert manager.pool != nil
      assert manager.performance_metrics != nil
    end

    test 'initializes with custom options' do
      opts = [
        compression_algorithm: :zstd,
        compression_level: 9,
        compression_threshold: 2048,
        pool_size: 200
      ]

      manager = EnhancedManager.new(80, 24, opts)
      assert manager.compression_state.algorithm == :zstd
      assert manager.compression_state.level == 9
      assert manager.compression_state.threshold == 2048
      assert manager.pool.max_size == 200
    end
  end

  describe "queue_update/2" do
    test "queues an update function", %{manager: manager} do
      update_fn = fn buffer -> %{buffer | width: 100} end
      updated_manager = EnhancedManager.queue_update(manager, update_fn)

      assert :queue.len(updated_manager.update_queue) == 1
    end

    test "queues multiple updates", %{manager: manager} do
      update_fn1 = fn buffer -> %{buffer | width: 100} end
      update_fn2 = fn buffer -> %{buffer | height: 50} end

      manager = EnhancedManager.queue_update(manager, update_fn1)
      manager = EnhancedManager.queue_update(manager, update_fn2)

      assert :queue.len(manager.update_queue) == 2
    end
  end

  describe "process_updates/1" do
    test "processes queued updates", %{manager: manager} do
      update_fn = fn buffer -> %{buffer | width: 100} end
      manager = EnhancedManager.queue_update(manager, update_fn)

      updated_manager = EnhancedManager.process_updates(manager)
      assert updated_manager.buffer.width == 100
      assert :queue.len(updated_manager.update_queue) == 0
    end

    test "updates performance metrics after processing", %{manager: manager} do
      update_fn = fn buffer -> buffer end
      manager = EnhancedManager.queue_update(manager, update_fn)

      updated_manager = EnhancedManager.process_updates(manager)
      metrics = EnhancedManager.get_performance_metrics(updated_manager)

      assert length(metrics.update_times) > 0
      assert metrics.operation_counts.updates > 0
    end
  end

  describe "compress_buffer/2" do
    test "compresses buffer with default options", %{manager: manager} do
      updated_manager = EnhancedManager.compress_buffer(manager)
      assert updated_manager.buffer != nil
    end

    test "compresses buffer with custom options", %{manager: manager} do
      opts = [compression_level: 9]
      updated_manager = EnhancedManager.compress_buffer(manager, opts)
      assert updated_manager.buffer != nil
    end

    test "updates performance metrics after compression", %{manager: manager} do
      updated_manager = EnhancedManager.compress_buffer(manager)
      metrics = EnhancedManager.get_performance_metrics(updated_manager)

      assert length(metrics.compression_times) > 0
      assert metrics.operation_counts.compressions > 0
    end
  end

  describe "buffer pooling" do
    test "gets buffer from pool or creates new one", %{manager: manager} do
      {buffer, updated_manager} = EnhancedManager.get_buffer(manager, 80, 24)
      assert buffer != nil
      assert buffer.width == 80
      assert buffer.height == 24
    end

    test "returns buffer to pool", %{manager: manager} do
      {buffer, manager} = EnhancedManager.get_buffer(manager, 80, 24)
      updated_manager = EnhancedManager.return_buffer(manager, buffer)

      assert updated_manager.pool != manager.pool
    end

    test "tracks pool statistics", %{manager: manager} do
      {buffer, manager} = EnhancedManager.get_buffer(manager, 80, 24)
      updated_manager = EnhancedManager.return_buffer(manager, buffer)

      stats = updated_manager.pool.stats
      assert stats.allocations > 0
    end
  end

  describe "performance metrics" do
    test "tracks update times", %{manager: manager} do
      update_fn = fn buffer -> buffer end
      manager = EnhancedManager.queue_update(manager, update_fn)
      updated_manager = EnhancedManager.process_updates(manager)

      metrics = EnhancedManager.get_performance_metrics(updated_manager)
      assert length(metrics.update_times) > 0
    end

    test "tracks compression times", %{manager: manager} do
      updated_manager = EnhancedManager.compress_buffer(manager)
      metrics = EnhancedManager.get_performance_metrics(updated_manager)

      assert length(metrics.compression_times) > 0
    end

    test "tracks memory usage", %{manager: manager} do
      metrics = EnhancedManager.get_performance_metrics(manager)
      assert is_map(metrics.memory_usage)
    end
  end

  describe "optimize/1" do
    test "optimizes based on performance metrics", %{manager: manager} do
      # First perform some operations to generate metrics
      update_fn = fn buffer -> buffer end
      manager = EnhancedManager.queue_update(manager, update_fn)
      manager = EnhancedManager.process_updates(manager)
      manager = EnhancedManager.compress_buffer(manager)

      # Then optimize
      optimized_manager = EnhancedManager.optimize(manager)
      assert optimized_manager.compression_state != manager.compression_state
    end
  end
end
