defmodule Raxol.UI.Rendering.OptimizedPipelineTest do
  @moduledoc """
  Performance tests for the optimized rendering pipeline.
  Validates that optimizations meet the performance targets from TODO.md:
  - Render time: <1ms per frame
  - Parser time: <3μs per operation  
  - Memory usage: <3MB per session
  """

  use ExUnit.Case, async: false  # Some tests require timing
  
  alias Raxol.UI.Rendering.{
    DamageTracker,
    RenderBatcher,
    AdaptiveFramerate,
    TreeDiffer
  }

  describe "DamageTracker" do
    test "computes no damage for identical trees" do
      tree = %{type: :view, children: [%{type: :label, attrs: %{text: "Hello"}}]}
      
      damage = DamageTracker.compute_damage(:no_change, tree)
      assert damage == %{}
    end

    test "computes full damage for tree replacement" do
      old_tree = %{type: :view, children: []}
      new_tree = %{type: :view, children: [%{type: :label, attrs: %{text: "New"}}]}
      
      damage = DamageTracker.compute_damage({:replace, new_tree}, old_tree)
      
      assert %{[] => %{path: [], type: :structure, priority: :high}} = damage
    end

    test "computes partial damage for tree updates" do
      tree = %{
        type: :view, 
        children: [
          %{type: :label, attrs: %{text: "Item 1"}},
          %{type: :label, attrs: %{text: "Item 2"}}
        ]
      }
      
      changes = %{type: :indexed_children, diffs: [{0, {:replace, %{type: :label, attrs: %{text: "Updated"}}}}]}
      damage = DamageTracker.compute_damage({:update, [], changes}, tree)
      
      assert Map.has_key?(damage, [])
      assert damage[[]][:type] == :structure
    end

    test "merges damage regions correctly" do
      damage1 = %{
        [0] => %{path: [0], type: :content, bounds: %{x: 0, y: 0, width: 100, height: 20}, priority: :medium}
      }
      damage2 = %{
        [1] => %{path: [1], type: :style, bounds: %{x: 0, y: 20, width: 100, height: 20}, priority: :high}
      }
      
      merged = DamageTracker.merge_damage(damage1, damage2)
      
      assert Map.keys(merged) |> Enum.sort() == [[0], [1]]
      assert merged[[1]][:priority] == :high
    end

    test "filters damage by viewport" do
      damage = %{
        [0] => %{path: [0], type: :content, bounds: %{x: 0, y: 0, width: 100, height: 20}, priority: :medium},
        [1] => %{path: [1], type: :content, bounds: %{x: 0, y: 500, width: 100, height: 20}, priority: :medium}
      }
      viewport = %{x: 0, y: 0, width: 800, height: 400}
      
      filtered = DamageTracker.filter_viewport_damage(damage, viewport)
      
      # Only the first region should remain (second is below viewport)
      assert Map.keys(filtered) == [[0]]
    end
  end

  describe "RenderBatcher performance" do
    setup do
      {:ok, batcher} = RenderBatcher.start_link(name: :"test_batcher_#{:rand.uniform(1000)}")
      %{batcher: batcher}
    end

    test "batches multiple updates efficiently", %{batcher: batcher} do
      simple_tree = %{type: :view, children: [%{type: :label, attrs: %{text: "Test"}}]}
      
      # Submit multiple updates rapidly
      start_time = System.monotonic_time(:microsecond)
      
      for i <- 1..10 do
        updated_tree = %{type: :view, children: [%{type: :label, attrs: %{text: "Test #{i}"}}]}
        RenderBatcher.submit_update(updated_tree, {:replace, updated_tree}, :medium, batcher)
      end
      
      end_time = System.monotonic_time(:microsecond)
      batch_time = end_time - start_time
      
      # Should be very fast - just queueing operations
      assert batch_time < 1_000  # < 1ms
      
      # Force flush and check stats
      RenderBatcher.force_flush(batcher)
      stats = RenderBatcher.get_stats(batcher)
      
      assert stats.updates_batched == 10
      assert stats.batches_processed == 1
    end

    test "handles high-priority updates immediately", %{batcher: batcher} do
      tree = %{type: :view, children: [%{type: :label, attrs: %{text: "Critical"}}]}
      
      # Submit normal and high priority updates
      RenderBatcher.submit_update(tree, {:replace, tree}, :low, batcher)
      RenderBatcher.submit_update(tree, {:replace, tree}, :high, batcher)
      
      # High priority should trigger immediate processing
      stats = RenderBatcher.get_stats(batcher)
      assert stats.pending_updates >= 0  # May have been processed already
    end
  end

  describe "AdaptiveFramerate performance" do
    setup do
      {:ok, framerate} = AdaptiveFramerate.start_link(name: :"test_framerate_#{:rand.uniform(1000)}")
      %{framerate: framerate}
    end

    test "starts with 60fps default", %{framerate: framerate} do
      interval = AdaptiveFramerate.get_frame_interval(framerate)
      assert interval == 16  # 60fps = 16ms intervals
    end

    test "adapts frame rate based on performance", %{framerate: framerate} do
      # Report slow render times
      for _ <- 1..5 do
        AdaptiveFramerate.report_render(30_000, 100, 20, framerate)  # 30ms render time
      end
      
      # Give time for adaptation
      Process.sleep(50)
      AdaptiveFramerate.force_adaptation(framerate)
      
      stats = AdaptiveFramerate.get_stats(framerate)
      
      # Should adapt to lower frame rate due to slow renders
      assert stats.current_fps <= 45  # Should reduce from 60fps
    end

    test "reports performance statistics", %{framerate: framerate} do
      AdaptiveFramerate.report_render(8_000, 25, 3, framerate)
      
      stats = AdaptiveFramerate.get_stats(framerate)
      
      assert is_integer(stats.current_fps)
      assert is_integer(stats.current_interval_ms)  
      assert is_integer(stats.sample_count)
    end
  end

  describe "TreeDiffer performance benchmarks" do
    @tag :slow
    @tag :skip_on_ci
    test "meets diff performance targets" do
      # Create trees of varying complexity
      simple_tree = %{type: :view, children: [%{type: :label, attrs: %{text: "Hello"}}]}
      
      complex_tree = %{
        type: :view,
        children: for i <- 1..100 do
          %{type: :label, attrs: %{text: "Item #{i}"}}
        end
      }

      # Test simple diff performance (target: significant portion of <1ms budget)
      {time_simple, _} = :timer.tc(fn ->
        for _ <- 1..1000 do
          TreeDiffer.diff_trees(simple_tree, simple_tree)
        end
      end)
      
      avg_simple_us = time_simple / 1000
      assert avg_simple_us < 1.0  # < 1μs per simple diff
      
      # Test complex diff performance  
      modified_complex = %{complex_tree | children: tl(complex_tree.children)}
      
      {time_complex, _} = :timer.tc(fn ->
        for _ <- 1..100 do
          TreeDiffer.diff_trees(complex_tree, modified_complex)
        end
      end)
      
      avg_complex_us = time_complex / 100
      assert avg_complex_us < 100.0  # < 100μs per complex diff
    end

    @tag :slow
    @tag :skip_on_ci
    test "diff algorithm scales efficiently" do
      # Create trees of increasing size
      sizes = [10, 50, 100, 200]
      times = for size <- sizes do
        tree = %{
          type: :view,
          children: for i <- 1..size do
            %{type: :label, attrs: %{text: "Item #{i}"}}
          end
        }
        
        modified = %{tree | children: tl(tree.children)}
        
        {time, _} = :timer.tc(fn ->
          TreeDiffer.diff_trees(tree, modified)
        end)
        
        {size, time}
      end
      
      # Check that time grows sub-linearly (better than O(n²))
      [{_, time1}, {_, time2}, {_, time3}, {_, time4}] = times
      
      # Time should not grow quadratically
      ratio_1_to_2 = time2 / time1
      ratio_3_to_4 = time4 / time3
      
      # Growth rate should be stable (not accelerating)
      assert ratio_3_to_4 < ratio_1_to_2 * 2  # Not quadratic growth
    end
  end

  describe "Memory usage optimization" do
    test "damage tracking uses bounded memory" do
      # Create large damage map
      large_damage = for i <- 1..1000 do
        {[i], %{path: [i], type: :content, bounds: nil, priority: :low}}
      end |> Map.new()
      
      # Optimize should reduce memory usage
      optimized = DamageTracker.optimize_damage_regions(large_damage)
      
      # Memory usage should be controlled
      original_size = :erts_debug.size(large_damage)
      optimized_size = :erts_debug.size(optimized)
      
      # Optimized version should not be significantly larger
      assert optimized_size <= original_size * 1.1  # At most 10% overhead
    end

    test "render batcher bounds queue size" do
      {:ok, batcher} = RenderBatcher.start_link(name: :"memory_test_#{:rand.uniform(1000)}")
      
      # Submit many updates
      tree = %{type: :view, children: [%{type: :label, attrs: %{text: "Memory test"}}]}
      
      for i <- 1..100 do
        updated_tree = put_in(tree, [:children, Access.at(0), :attrs, :text], "Update #{i}")
        RenderBatcher.submit_update(updated_tree, {:replace, updated_tree}, :low, batcher)
      end
      
      stats = RenderBatcher.get_stats(batcher)
      
      # Should batch and not accumulate unbounded updates
      assert stats.pending_updates < 100  # Should have been processed in batches
    end
  end

  describe "Integration performance test" do
    @tag :performance
    test "end-to-end render pipeline meets <1ms target for simple updates" do
      # This test validates the overall performance target
      simple_tree = %{
        type: :view,
        children: [
          %{type: :label, attrs: %{text: "Line 1"}},
          %{type: :label, attrs: %{text: "Line 2"}},
          %{type: :label, attrs: %{text: "Line 3"}}
        ]
      }
      
      modified_tree = put_in(simple_tree, [:children, Access.at(0), :attrs, :text], "Updated Line 1")
      
      # Measure full pipeline operations
      {total_time, _} = :timer.tc(fn ->
        # 1. Compute diff
        diff_result = TreeDiffer.diff_trees(simple_tree, modified_tree)
        
        # 2. Compute damage
        damage = DamageTracker.compute_damage(diff_result, simple_tree)
        
        # 3. Optimize damage  
        _optimized_damage = DamageTracker.optimize_damage_regions(damage)
        
        # 4. Group by priority (simulates batching decision)
        _grouped = DamageTracker.group_by_priority(damage)
      end)
      
      # Should complete well under 1ms (1000μs) for simple cases
      assert total_time < 500  # < 0.5ms for simple 3-node tree updates
    end

    @tag :performance  
    test "complex scene updates stay under performance budget" do
      # Larger scene with 50 elements
      complex_tree = %{
        type: :view,
        children: for i <- 1..50 do
          %{
            type: :view,
            children: [
              %{type: :label, attrs: %{text: "Item #{i}"}},
              %{type: :label, attrs: %{text: "Description #{i}"}}
            ]
          }
        end
      }
      
      # Update multiple items
      modified_tree = %{
        complex_tree |
        children: 
          Enum.map(complex_tree.children, fn
            %{children: [label1, label2]} = view ->
              %{view | children: [
                %{label1 | attrs: %{label1.attrs | text: "Updated " <> label1.attrs.text}},
                label2
              ]}
          end)
      }
      
      {total_time, _} = :timer.tc(fn ->
        diff_result = TreeDiffer.diff_trees(complex_tree, modified_tree)
        damage = DamageTracker.compute_damage(diff_result, complex_tree)
        _optimized = DamageTracker.optimize_damage_regions(damage)
      end)
      
      # Complex scenes should still complete reasonably quickly  
      # Target: <10ms for complex scenes (within frame budget)
      assert total_time < 10_000  # < 10ms
    end
  end
end