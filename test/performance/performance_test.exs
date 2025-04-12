defmodule Raxol.PerformanceTest do
  use ExUnit.Case, async: false

  alias Raxol.Benchmarks.Performance

  @moduletag :performance
  # 2 minute timeout for performance tests
  @moduletag timeout: 120_000

  test "rendering performance meets requirements" do
    render_results = Performance.benchmark_rendering()

    # Basic validation of rendering performance
    assert render_results.simple_component_time_μs < 100,
           "Simple component rendering time should be < 100μs"

    assert render_results.full_screen_render_time_ms < 20,
           "Full screen rendering time should be < 20ms"

    assert render_results.components_per_frame > 100,
           "Should render at least 100 simple components in one frame budget"

    assert render_results.renders_per_second >= 30,
           "Should achieve at least 30 full screen renders per second"
  end

  test "event handling performance meets requirements" do
    event_results = Performance.benchmark_event_handling()

    # Validate event handling performance
    assert event_results.keyboard_event_latency_μs < 50,
           "Keyboard event latency should be < 50μs"

    assert event_results.mouse_event_latency_μs < 50,
           "Mouse event latency should be < 50μs"

    assert event_results.burst_events_latency_μs < 100,
           "Burst event handling should be < 100μs per event"

    assert event_results.events_per_second > 10_000,
           "Should process at least 10,000 events per second"
  end

  test "memory usage is efficient" do
    memory_results = Performance.benchmark_memory_usage()

    # Validate memory usage metrics
    assert memory_results.simple_component_memory_bytes < 1000,
           "Simple components should use < 1KB memory each"

    assert memory_results.memory_efficiency_score > 70,
           "Memory efficiency score should be > 70/100"

    assert memory_results.memory_leak_detected == false,
           "No memory leaks should be detected"
  end

  test "animation performance is smooth" do
    animation_results = Performance.benchmark_animation_performance()

    # Validate animation performance metrics
    assert animation_results.maximum_fps >= 60,
           "Should achieve at least 60 FPS maximum"

    assert animation_results.dropped_frames_percent < 5,
           "Dropped frames should be < 5%"

    assert animation_results.animation_smoothness_score > 80,
           "Animation smoothness score should be > 80/100"
  end

  # This test runs all benchmarks and validates against baseline metrics
  # It's tagged as :full_benchmark so it can be run separately
  @tag :full_benchmark
  test "full benchmark suite against baseline" do
    results = Performance.run_all(detailed: true)

    if Map.has_key?(results, :metrics_validation) do
      validation = results.metrics_validation

      # Assert overall status is at least :acceptable
      assert validation.overall.status in [:excellent, :good, :acceptable],
             "Overall performance should be at least acceptable"

      # Assert passing percentage is adequate
      assert validation.overall.pass_percentage >= 60,
             "At least 60% of metrics should pass baseline validation"
    else
      flunk(
        "Benchmark results did not include validation against baseline metrics"
      )
    end
  end
end
