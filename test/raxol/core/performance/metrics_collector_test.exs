defmodule Raxol.Core.Performance.MetricsCollectorTest do
  use ExUnit.Case
  
  alias Raxol.Core.Performance.MetricsCollector
  
  describe "Metrics Collector" do
    test "creates new collector" do
      collector = MetricsCollector.new()
      
      assert collector.frame_times == []
      assert collector.memory_usage == 0
      assert collector.gc_stats == %{}
      assert collector.last_gc_time == 0
    end
    
    test "records frame time" do
      collector = MetricsCollector.new()
      collector = MetricsCollector.record_frame(collector, 16)
      
      assert length(collector.frame_times) == 1
      assert hd(collector.frame_times) == 16
    end
    
    test "maintains frame time history limit" do
      collector = MetricsCollector.new()
      
      # Record more frames than history limit
      collector = Enum.reduce(1..70, collector, fn _, acc ->
        MetricsCollector.record_frame(acc, 16)
      end)
      
      assert length(collector.frame_times) == 60  # Default limit
    end
    
    test "calculates FPS correctly" do
      collector = MetricsCollector.new()
      
      # Record some frames
      collector = Enum.reduce(1..3, collector, fn _, acc ->
        MetricsCollector.record_frame(acc, 16)
      end)
      
      assert_in_delta MetricsCollector.get_fps(collector), 62.5, 0.1  # 1000ms / 16ms = 62.5 FPS
    end
    
    test "handles zero frame time in FPS calculation" do
      collector = MetricsCollector.new()
      collector = MetricsCollector.record_frame(collector, 0)
      
      assert MetricsCollector.get_fps(collector) == 0.0
    end
    
    test "calculates average frame time correctly" do
      collector = MetricsCollector.new()
      
      # Record some frames
      collector = Enum.reduce([16, 20, 24], collector, fn time, acc ->
        MetricsCollector.record_frame(acc, time)
      end)
      
      assert_in_delta MetricsCollector.get_avg_frame_time(collector), 20.0, 0.1
    end
    
    test "handles empty frame times" do
      collector = MetricsCollector.new()
      
      assert MetricsCollector.get_avg_frame_time(collector) == 0.0
      assert MetricsCollector.get_fps(collector) == 0.0
    end
    
    test "updates memory usage" do
      collector = MetricsCollector.new()
      
      # Initial update
      collector = MetricsCollector.update_memory_usage(collector)
      initial_memory = collector.memory_usage
      
      # Create some garbage to trigger GC
      _garbage = Enum.map(1..1000, &(&1))
      :erlang.garbage_collect()
      
      # Update again
      collector = MetricsCollector.update_memory_usage(collector)
      
      assert collector.memory_usage > 0
      assert collector.memory_usage != initial_memory
      assert collector.last_gc_time > 0
    end
    
    test "tracks memory usage trend" do
      collector = MetricsCollector.new()
      
      # Initial update
      collector = MetricsCollector.update_memory_usage(collector)
      initial_memory = collector.memory_usage
      
      # Create some garbage
      _garbage = Enum.map(1..1000, &(&1))
      
      # Update again
      collector = MetricsCollector.update_memory_usage(collector)
      
      # Calculate trend
      trend = MetricsCollector.get_memory_trend(collector)
      
      assert trend > 0  # Memory should be growing
      assert collector.memory_usage > initial_memory
    end
    
    test "collects garbage collection statistics" do
      collector = MetricsCollector.new()
      
      # Force some garbage collection
      _garbage = Enum.map(1..1000, &(&1))
      :erlang.garbage_collect()
      
      # Update metrics
      collector = MetricsCollector.update_memory_usage(collector)
      
      # Check GC stats
      gc_stats = MetricsCollector.get_gc_stats(collector)
      
      assert is_map(gc_stats)
      assert Map.has_key?(gc_stats, :number_of_gcs)
      assert Map.has_key?(gc_stats, :words_reclaimed)
      assert Map.has_key?(gc_stats, :heap_size)
      assert Map.has_key?(gc_stats, :heap_limit)
    end
  end
end 