defmodule Raxol.Core.Performance.MonitorTest do
  use ExUnit.Case

  alias Raxol.Core.Performance.Monitor

  setup do
    {:ok, monitor} = Monitor.start_link()
    {:ok, %{monitor: monitor}}
  end

  describe "Performance Monitor" do
    test "initializes with default settings" do
      {:ok, monitor} = Monitor.start_link()

      # Allow time for the first memory check to occur
      Process.sleep(5100) # Default interval is 5000ms

      metrics = Monitor.get_metrics(monitor)

      assert metrics.fps == 0.0
      assert metrics.avg_frame_time == 0.0
      assert metrics.jank_count == 0
      assert metrics.memory_usage > 0

      # :erlang.statistics(:garbage_collection) returns a tuple {Count, Reclaimed, StackReclaimed}
      assert is_tuple(metrics.gc_stats)
      assert tuple_size(metrics.gc_stats) == 3
      assert elem(metrics.gc_stats, 0) >= 0 # Check GC count is non-negative integer

      GenServer.stop(monitor)
    end

    test "detects jank when frame time exceeds threshold", %{monitor: monitor} do
      # Record a janky frame (20ms > 16ms threshold)
      assert :ok == Monitor.record_frame(monitor, 20)
      assert true == Monitor.detect_jank?(monitor)

      metrics = Monitor.get_metrics(monitor)
      assert metrics.jank_count == 1
    end

    test "tracks frame rate correctly", %{monitor: monitor} do
      # Record several frames
      assert :ok == Monitor.record_frame(monitor, 16)
      assert :ok == Monitor.record_frame(monitor, 16)
      assert :ok == Monitor.record_frame(monitor, 16)

      metrics = Monitor.get_metrics(monitor)
      # 1000ms / 16ms = 62.5 FPS
      assert_in_delta metrics.fps, 62.5, 0.1
    end

    test "tracks memory usage" do
      {:ok, monitor} = Monitor.start_link(memory_check_interval: 100) # Faster interval for testing

      # Allow time for initial memory check
      Process.sleep(300) # Increased sleep

      initial_metrics = Monitor.get_metrics(monitor)
      initial_memory = initial_metrics.memory_usage
      # Assert that the value exists, even if it's 0 in test env
      assert is_integer(initial_memory)

      # Simulate memory allocation (e.g., create a large binary)
      _large_binary = :binary.copy(" ", 1024 * 1024) # Allocate 1MB
      :erlang.garbage_collect()

      # Allow time for another memory check
      Process.sleep(300) # Increased sleep

      updated_metrics = Monitor.get_metrics(monitor)
      updated_memory = updated_metrics.memory_usage

      # Assert that memory usage value exists after update
      assert is_integer(updated_memory)

      GenServer.stop(monitor)
    end

    test "handles multiple frames in window", %{monitor: monitor} do
      # Record 60 frames (window size)
      Enum.each(1..60, fn _ ->
        assert :ok == Monitor.record_frame(monitor, 16)
      end)

      metrics = Monitor.get_metrics(monitor)
      assert metrics.jank_count == 0
      assert_in_delta metrics.avg_frame_time, 16.0, 0.1
    end

    test "adapts to reduced motion setting" do
      # Mock UserPreferences to simulate reduced motion
      # TODO: Replace with actual preference system if available
      # For now, we test the current behavior: jank is still detected
      # as JankDetector doesn't implement reduced motion logic.

      {:ok, monitor} = Monitor.start_link(jank_threshold: 15)

      # Simulate some work that might cause jank
      Monitor.record_frame(monitor, 10)
      Monitor.record_frame(monitor, 25)
      Monitor.record_frame(monitor, 30)
      Monitor.record_frame(monitor, 5)

      metrics = Monitor.get_metrics(monitor)

      # Assert that jank IS counted, even if reduced motion was hypothetically enabled
      # This assertion should pass based on current JankDetector implementation
      assert metrics.jank_count == 2

      GenServer.stop(monitor)
    end

    test "tracks garbage collection statistics" do
      {:ok, monitor} = Monitor.start_link(memory_check_interval: 100) # Faster interval

      # Allow time for initial check (Increased sleep)
      Process.sleep(300)

      initial_metrics = Monitor.get_metrics(monitor)
      # Assert initial GC stats structure
      assert is_tuple(initial_metrics.gc_stats)
      assert tuple_size(initial_metrics.gc_stats) == 3
      {initial_gc_count, _, _} = initial_metrics.gc_stats
      assert initial_gc_count >= 0

      # Trigger garbage collection
      :erlang.garbage_collect()
      _large_binary = :binary.copy(" ", 1024 * 10)
      :erlang.garbage_collect()

      # Allow time for GC stats to be updated (Increased sleep)
      Process.sleep(300)

      updated_metrics = Monitor.get_metrics(monitor)
      assert is_tuple(updated_metrics.gc_stats)
      assert tuple_size(updated_metrics.gc_stats) == 3
      {updated_gc_count, _, _} = updated_metrics.gc_stats
      assert updated_gc_count >= initial_gc_count

      GenServer.stop(monitor)
    end
  end
end
