defmodule Raxol.Benchmarks.Performance.Animation do
  @moduledoc """
  Animation performance benchmark functions for Raxol.
  """

  # Alias functions from Rendering module needed here
  alias Raxol.Benchmarks.Performance.Rendering, as: RenderingBenchmark

  @doc """
  Benchmarks animation performance and frame rate stability.

  Tests:
  - Maximum achievable FPS
  - Frame time consistency
  - Animation smoothness
  - CPU usage during animation
  """
  def benchmark_animation_performance do
    IO.puts("Benchmarking animation performance...")

    # Measure maximum achievable FPS
    max_fps = measure_maximum_fps(5)

    # Measure frame time consistency (standard deviation of frame times)
    frame_time_consistency = measure_frame_time_consistency(60, 5)

    # Measure animation smoothness (dropped frames)
    dropped_frames = measure_dropped_frames(60, 5)

    # Measure CPU usage during animation
    cpu_usage = measure_cpu_during_animation(5)

    # Calculate animation performance metrics
    results = %{
      maximum_fps: max_fps,
      frame_time_consistency_ms: frame_time_consistency,
      dropped_frames_percent: dropped_frames,
      cpu_usage_percent: cpu_usage,
      animation_smoothness_score:
        calculate_animation_smoothness(frame_time_consistency, dropped_frames)
    }

    IO.puts("✓ Animation performance benchmarks complete")
    results
  end

  # Helper functions moved from Raxol.Benchmarks.Performance

  defp measure_maximum_fps(seconds) do
    # Simulate measuring maximum achievable FPS
    # Generate a simple animation and count frames
    frame_count = 0
    start_time = System.monotonic_time(:millisecond)

    # Run until time elapsed
    frame_count = measure_frames_until(start_time, seconds * 1000, frame_count)

    # Calculate FPS
    elapsed = (System.monotonic_time(:millisecond) - start_time) / 1000
    trunc(frame_count / elapsed)
  end

  defp measure_frames_until(start_time, duration, frame_count) do
    current_time = System.monotonic_time(:millisecond)

    if current_time - start_time < duration do
      # Simulate rendering a frame
      component = RenderingBenchmark.generate_test_component(:simple)
      RenderingBenchmark.render_component(component)

      # Recursive call to continue animation
      measure_frames_until(start_time, duration, frame_count + 1)
    else
      frame_count
    end
  end

  defp measure_frame_time_consistency(target_fps, seconds) do
    # Simulate animation at target FPS and measure frame time consistency
    frame_times = []
    frame_duration = trunc(1000 / target_fps)
    start_time = System.monotonic_time(:millisecond)
    end_time = start_time + seconds * 1000

    # Capture frame times
    frame_times =
      capture_frame_times(start_time, end_time, frame_duration, frame_times)

    # Calculate standard deviation of frame times
    mean = Enum.sum(frame_times) / length(frame_times)

    sum_squared_diffs =
      Enum.reduce(frame_times, 0, fn time, acc ->
        acc + :math.pow(time - mean, 2)
      end)

    :math.sqrt(sum_squared_diffs / length(frame_times))
    |> Float.round(2)
  end

  defp capture_frame_times(start_time, end_time, frame_duration, frame_times) do
    current_time = System.monotonic_time(:millisecond)

    if current_time < end_time do
      # Record time before frame
      frame_start = System.monotonic_time(:millisecond)

      # Simulate rendering a frame
      component = RenderingBenchmark.generate_test_component(:simple)
      RenderingBenchmark.render_component(component)

      # Calculate actual frame time
      actual_time = System.monotonic_time(:millisecond) - frame_start

      # Sleep remaining time
      remaining = max(0, frame_duration - actual_time)
      if remaining > 0, do: Process.sleep(trunc(remaining))

      # Record total frame time
      total_frame_time = System.monotonic_time(:millisecond) - frame_start

      # Recursive call to continue animation
      capture_frame_times(start_time, end_time, frame_duration, [
        total_frame_time | frame_times
      ])
    else
      frame_times
    end
  end

  defp measure_dropped_frames(target_fps, seconds) do
    # Simulate animation and count dropped frames
    frame_duration = trunc(1000 / target_fps)
    start_time = System.monotonic_time(:millisecond)
    end_time = start_time + seconds * 1000
    expected_frames = trunc(seconds * target_fps)

    # Run animation and count frames that meet deadline
    {actual_frames, _} =
      count_timely_frames(start_time, end_time, frame_duration, 0, 0)

    # Calculate percentage of dropped frames
    drop_percentage =
      ((expected_frames - actual_frames) / expected_frames * 100)
      |> Float.round(1)
      |> max(0)

    drop_percentage
  end

  defp count_timely_frames(
         start_time,
         end_time,
         frame_duration,
         frame_count,
         dropped_count
       ) do
    current_time = System.monotonic_time(:millisecond)

    if current_time < end_time do
      # Calculate target time for this frame
      target_time = start_time + frame_count * frame_duration

      # Check if we're late
      is_late = current_time > target_time + frame_duration

      # If we're late, count as dropped and move to next frame time
      if is_late do
        # Skip this frame
        frames_to_skip = trunc((current_time - target_time) / frame_duration)
        next_frame_count = frame_count + frames_to_skip
        next_dropped = dropped_count + frames_to_skip

        count_timely_frames(
          start_time,
          end_time,
          frame_duration,
          next_frame_count,
          next_dropped
        )
      else
        # Render the frame
        frame_start = System.monotonic_time(:millisecond)
        component = RenderingBenchmark.generate_test_component(:medium)
        RenderingBenchmark.render_component(component)
        _render_time = System.monotonic_time(:millisecond) - frame_start

        # Sleep if time remains
        remaining =
          max(
            0,
            target_time + frame_duration - System.monotonic_time(:millisecond)
          )

        if remaining > 0, do: Process.sleep(trunc(remaining))

        # Continue to next frame
        count_timely_frames(
          start_time,
          end_time,
          frame_duration,
          frame_count + 1,
          dropped_count
        )
      end
    else
      {frame_count, dropped_count}
    end
  end

  defp measure_cpu_during_animation(seconds) do
    # Simulate measuring CPU usage during animation
    # This is approximate since precise CPU measurement is OS-dependent

    # Get initial CPU time
    initial_reductions = get_reductions()
    start_time = System.monotonic_time(:millisecond)
    end_time = start_time + seconds * 1000

    # Run animation
    run_animation_until(end_time)

    # Get final CPU time
    final_reductions = get_reductions()
    elapsed_ms = System.monotonic_time(:millisecond) - start_time

    # Calculate approximate CPU percentage
    # This is based on reductions (Erlang VM work units) and is approximate
    reduction_rate = (final_reductions - initial_reductions) / elapsed_ms

    # Convert to approximate CPU percentage (calibrated value)
    # Higher reduction rate correlates with higher CPU usage
    min(100, reduction_rate / 50)
    |> Float.round(1)
  end

  defp get_reductions do
    {:reductions, reductions} = :erlang.process_info(self(), :reductions)
    reductions
  end

  defp run_animation_until(end_time) do
    if System.monotonic_time(:millisecond) < end_time do
      # Simulate rendering animation frame
      component = RenderingBenchmark.generate_test_component(:medium)
      RenderingBenchmark.render_component(component)

      # Small sleep to prevent CPU overload
      Process.sleep(16)

      # Continue animation
      run_animation_until(end_time)
    end
  end

  defp calculate_animation_smoothness(frame_time_consistency, dropped_frames) do
    # Calculate animation smoothness score (0-100)
    # Lower consistency and fewer dropped frames are better
    consistency_score = 100 - min(100, frame_time_consistency * 5)
    dropped_score = 100 - dropped_frames

    # Weighted average (consistency matters more than occasional drops)
    (consistency_score * 0.7 + dropped_score * 0.3)
    |> Float.round(1)
  end
end
