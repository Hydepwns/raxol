defmodule Raxol.Core.Performance.MonitorTest do
  @moduledoc """
  Tests for the performance monitor, including frame rate tracking,
  memory usage monitoring, garbage collection statistics,
  and jank detection.
  """
  use ExUnit.Case
  
  alias Raxol.Core.Performance.Monitor

  setup do
    {:ok, monitor} = Monitor.start_link()
    {:ok, _} = Raxol.Core.Preferences.start_link()
    {:ok, %{monitor: monitor}}
  end

  describe "Performance Monitor" do
    test "initializes with default settings" do
      {:ok, monitor} = Monitor.start_link(parent_pid: self())

      # Wait for the first memory check to occur
      assert_receive {:memory_check, _}, 6000

      metrics = Monitor.get_metrics(monitor)

      assert metrics.fps == 0.0
      assert metrics.avg_frame_time == 0.0
      assert metrics.jank_count == 0
      assert metrics.memory_usage > 0

      # :erlang.statistics(:garbage_collection) returns a tuple {Count, Reclaimed, StackReclaimed}
      assert is_tuple(metrics.gc_stats)
      assert tuple_size(metrics.gc_stats) == 3
      # Check GC count is non-negative integer
      assert elem(metrics.gc_stats, 0) >= 0

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
      # Faster interval for testing
      {:ok, monitor} =
        Monitor.start_link(memory_check_interval: 100, parent_pid: self())

      # Wait for initial memory check
      assert_receive {:memory_check, _}, 400

      initial_metrics = Monitor.get_metrics(monitor)
      initial_memory = initial_metrics.memory_usage
      # Assert that the value exists, even if it's 0 in test env
      assert is_integer(initial_memory)

      # Simulate memory allocation (e.g., create a large binary)
      # Allocate 1MB
      _large_binary = :binary.copy(" ", 1024 * 1024)
      :erlang.garbage_collect()

      # Wait for another memory check
      assert_receive {:memory_check, _}, 400

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
      {:ok, monitor} = Monitor.start_link(jank_threshold: 15)

      # Test with reduced motion disabled
      Raxol.Core.Preferences.set_preference(:reduced_motion, false)
      Monitor.record_frame(monitor, 25)
      Monitor.record_frame(monitor, 30)
      metrics = Monitor.get_metrics(monitor)
      assert metrics.jank_count == 2

      # Reset monitor
      Monitor.reset_metrics(monitor)

      # Test with reduced motion enabled
      Raxol.Core.Preferences.set_preference(:reduced_motion, true)
      Monitor.record_frame(monitor, 25)
      Monitor.record_frame(monitor, 30)
      metrics = Monitor.get_metrics(monitor)
      assert metrics.jank_count == 0

      GenServer.stop(monitor)
    end

    test "tracks garbage collection statistics" do
      # Faster interval
      {:ok, monitor} =
        Monitor.start_link(memory_check_interval: 100, parent_pid: self())

      # Wait for initial check
      assert_receive {:memory_check, _}, 400

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

      # Wait for GC stats to be updated
      assert_receive {:memory_check, _}, 400

      updated_metrics = Monitor.get_metrics(monitor)
      assert is_tuple(updated_metrics.gc_stats)
      assert tuple_size(updated_metrics.gc_stats) == 3
      {updated_gc_count, _, _} = updated_metrics.gc_stats
      assert updated_gc_count >= initial_gc_count

      GenServer.stop(monitor)
    end
  end
end
