defmodule Raxol.Core.Performance.MonitorTest do
  use ExUnit.Case
  
  alias Raxol.Core.Performance.Monitor
  
  setup do
    {:ok, monitor} = Monitor.start_link()
    {:ok, %{monitor: monitor}}
  end
  
  describe "Performance Monitor" do
    test "initializes with default settings", %{monitor: monitor} do
      assert :ok == Monitor.record_frame(monitor, 16)
      assert false == Monitor.detect_jank?(monitor)
      
      metrics = Monitor.get_metrics(monitor)
      assert metrics.fps > 0
      assert metrics.avg_frame_time == 16.0
      assert metrics.jank_count == 0
      assert metrics.memory_usage > 0
      assert is_map(metrics.gc_stats)
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
      assert_in_delta metrics.fps, 62.5, 0.1  # 1000ms / 16ms = 62.5 FPS
    end
    
    test "tracks memory usage", %{monitor: monitor} do
      # Initial memory check
      metrics = Monitor.get_metrics(monitor)
      initial_memory = metrics.memory_usage
      
      # Create some garbage to trigger GC
      _garbage = Enum.map(1..1000, &(&1))
      :erlang.garbage_collect()
      
      # Wait for next memory check
      Process.sleep(100)
      
      # Get updated metrics
      metrics = Monitor.get_metrics(monitor)
      assert metrics.memory_usage > 0
      assert metrics.memory_usage != initial_memory
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
    
    test "adapts to reduced motion setting", %{monitor: monitor} do
      # Start with reduced motion
      {:ok, reduced_monitor} = Monitor.start_link(reduced_motion: true)
      
      # Record frames
      assert :ok == Monitor.record_frame(reduced_monitor, 20)
      assert :ok == Monitor.record_frame(reduced_monitor, 20)
      
      metrics = Monitor.get_metrics(reduced_monitor)
      assert metrics.jank_count == 0  # Jank detection is disabled in reduced motion
    end
    
    test "tracks garbage collection statistics", %{monitor: monitor} do
      # Force some garbage collection
      _garbage = Enum.map(1..1000, &(&1))
      :erlang.garbage_collect()
      
      # Wait for next memory check
      Process.sleep(100)
      
      metrics = Monitor.get_metrics(monitor)
      assert is_map(metrics.gc_stats)
      assert Map.has_key?(metrics.gc_stats, :number_of_gcs)
      assert Map.has_key?(metrics.gc_stats, :words_reclaimed)
    end
  end
end 