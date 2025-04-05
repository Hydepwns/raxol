defmodule Raxol.Benchmarks.Performance do
  @moduledoc """
  Performance benchmarking and validation tools for Raxol.
  
  This module provides utilities for measuring and validating performance metrics
  including rendering speed, memory usage, and event handling latency.
  """
  
  alias Raxol.System.Platform
  
  @doc """
  Runs all performance benchmarks and returns the results.
  
  ## Options
  
  * `:save_results` - Save results to file (default: `true`)
  * `:compare_with_baseline` - Compare with baseline metrics (default: `true`)
  * `:detailed` - Include detailed metrics (default: `false`)
  
  ## Returns
  
  Map containing benchmark results with the following structure:
  
  ```
  %{
    render_performance: %{...},
    event_latency: %{...},
    memory_usage: %{...},
    animation_fps: %{...},
    metrics_validation: %{...}
  }
  ```
  """
  def run_all(opts \\ []) do
    opts = Keyword.merge([
      save_results: true,
      compare_with_baseline: true,
      detailed: false
    ], opts)
    
    start_time = System.monotonic_time(:millisecond)
    IO.puts("\n=== Raxol Performance Benchmark Suite ===\n")
    
    # Run individual benchmarks
    render_results = benchmark_rendering()
    event_results = benchmark_event_handling()
    memory_results = benchmark_memory_usage()
    animation_results = benchmark_animation_performance()
    
    # Compile all results
    results = %{
      timestamp: DateTime.utc_now(),
      platform: Platform.get_platform_info(),
      runtime_info: get_runtime_info(),
      render_performance: render_results,
      event_latency: event_results,
      memory_usage: memory_results,
      animation_fps: animation_results,
      execution_time: System.monotonic_time(:millisecond) - start_time
    }
    
    # Validate against baseline metrics
    validated_results = 
      if opts[:compare_with_baseline] do
        baseline = get_baseline_metrics()
        validation = validate_metrics(results, baseline)
        Map.put(results, :metrics_validation, validation)
      else
        results
      end
    
    # Save results if requested
    if opts[:save_results] do
      save_benchmark_results(validated_results)
    end
    
    # Print summary
    print_summary(validated_results, opts[:detailed])
    
    validated_results
  end
  
  @doc """
  Benchmarks rendering performance for various component types and complexities.
  
  Tests rendering performance for:
  - Simple components (text, buttons)
  - Medium complexity (tables, lists)
  - Complex components (dashboards, multi-panel layouts)
  """
  def benchmark_rendering do
    IO.puts("Benchmarking rendering performance...")
    
    # Prepare test components
    simple_component = generate_test_component(:simple)
    medium_component = generate_test_component(:medium)
    complex_component = generate_test_component(:complex)
    
    # Measure rendering time for each complexity
    simple_render_time = measure_render_time(simple_component, 1000)
    medium_render_time = measure_render_time(medium_component, 100)
    complex_render_time = measure_render_time(complex_component, 10)
    
    # Measure full screen render time
    full_screen_time = measure_full_screen_render(100)
    
    # Calculate average render time per component
    results = %{
      simple_component_time_μs: simple_render_time,
      medium_component_time_μs: medium_render_time,
      complex_component_time_μs: complex_render_time,
      full_screen_render_time_ms: full_screen_time,
      components_per_frame: calculate_components_per_frame(simple_render_time),
      renders_per_second: calculate_renders_per_second(full_screen_time)
    }
    
    IO.puts("✓ Rendering benchmarks complete")
    results
  end
  
  @doc """
  Benchmarks event handling latency for different event types and volumes.
  
  Tests event handling for:
  - Keyboard events
  - Mouse events
  - Window events
  - Custom events
  - High-volume event bursts
  """
  def benchmark_event_handling do
    IO.puts("Benchmarking event handling latency...")
    
    # Set up event testing environment
    event_manager = setup_event_test_environment()
    
    # Measure event handling latency for different event types
    keyboard_latency = measure_event_latency(event_manager, :keyboard, 1000)
    mouse_latency = measure_event_latency(event_manager, :mouse, 1000)
    window_latency = measure_event_latency(event_manager, :window, 100)
    custom_latency = measure_event_latency(event_manager, :custom, 1000)
    
    # Measure burst handling (100 events dispatched rapidly)
    burst_latency = measure_burst_event_latency(event_manager, 100)
    
    # Calculate average and percentiles
    results = %{
      keyboard_event_latency_μs: keyboard_latency,
      mouse_event_latency_μs: mouse_latency,
      window_event_latency_μs: window_latency,
      custom_event_latency_μs: custom_latency,
      burst_events_latency_μs: burst_latency,
      events_per_second: calculate_events_per_second(keyboard_latency)
    }
    
    IO.puts("✓ Event handling benchmarks complete")
    results
  end
  
  @doc """
  Benchmarks memory usage patterns for components and rendering cycles.
  
  Measures:
  - Memory consumption per component
  - Memory growth during rendering
  - GC impact on performance
  - Memory leaks in long-running scenarios
  """
  def benchmark_memory_usage do
    IO.puts("Benchmarking memory usage...")
    
    # Measure base memory footprint
    base_memory = measure_memory_usage()
    
    # Measure memory for component creation
    {simple_memory, medium_memory, complex_memory} = measure_component_memory_usage()
    
    # Measure memory during continuous rendering
    {render_memory_start, render_memory_end} = measure_continuous_rendering_memory(1000)
    
    # Check for memory leaks
    leak_detected = check_for_memory_leaks(100)
    
    # Calculate memory efficiency metrics
    results = %{
      base_memory_usage_kb: base_memory,
      simple_component_memory_bytes: simple_memory,
      medium_component_memory_bytes: medium_memory,
      complex_component_memory_bytes: complex_memory,
      rendering_memory_growth_kb: render_memory_end - render_memory_start,
      memory_leak_detected: leak_detected,
      memory_efficiency_score: calculate_memory_efficiency_score(simple_memory, medium_memory, complex_memory)
    }
    
    IO.puts("✓ Memory usage benchmarks complete")
    results
  end
  
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
      animation_smoothness_score: calculate_animation_smoothness(frame_time_consistency, dropped_frames)
    }
    
    IO.puts("✓ Animation performance benchmarks complete")
    results
  end
  
  @doc """
  Saves benchmark results to a file.
  
  ## Parameters
  
  * `results` - Benchmark results map
  * `file_path` - Path to save results (default: auto-generated)
  """
  def save_benchmark_results(results, file_path \\ nil) do
    # Ensure the results directory exists
    File.mkdir_p!("_build/benchmark_results")
    
    # Generate a filename if not provided
    file_path = file_path || "_build/benchmark_results/raxol_performance_#{System.os_time(:second)}.json"
    
    # Convert results to JSON
    json_data = Jason.encode!(results, pretty: true)
    
    # Write to file
    File.write!(file_path, json_data)
    
    IO.puts("\nResults saved to: #{file_path}")
    {:ok, file_path}
  end
  
  @doc """
  Validates performance against baseline requirements.
  
  ## Parameters
  
  * `results` - Current benchmark results
  * `baseline` - Baseline metrics to compare against
  
  ## Returns
  
  Map containing validation results and pass/fail status for each metric
  """
  def validate_metrics(results, baseline) do
    # Define validators for each metric category
    validators = %{
      render_performance: &validate_render_metrics/2,
      event_latency: &validate_event_metrics/2,
      memory_usage: &validate_memory_metrics/2,
      animation_fps: &validate_animation_metrics/2
    }
    
    # Run each validator
    validations = Enum.map(validators, fn {category, validator_fn} ->
      result_metrics = Map.get(results, category, %{})
      baseline_metrics = Map.get(baseline, category, %{})
      
      {category, validator_fn.(result_metrics, baseline_metrics)}
    end)
    |> Enum.into(%{})
    
    # Calculate overall pass/fail status
    all_validations = validations
                      |> Enum.flat_map(fn {_, category_validations} -> 
                        Map.values(category_validations) 
                      end)
    
    passed_validations = Enum.count(all_validations, fn {status, _} -> status == :pass end)
    total_validations = length(all_validations)
    pass_percentage = if total_validations > 0, do: passed_validations / total_validations * 100, else: 0
    
    overall_status = cond do
      pass_percentage >= 95 -> :excellent
      pass_percentage >= 80 -> :good
      pass_percentage >= 60 -> :acceptable
      true -> :failed
    end
    
    # Add overall results to validations
    Map.put(validations, :overall, %{
      status: overall_status,
      pass_percentage: pass_percentage,
      passed_validations: passed_validations,
      total_validations: total_validations
    })
  end
  
  @doc """
  Retrieves baseline performance metrics for the current platform.
  
  If no platform-specific baseline exists, falls back to default baseline.
  """
  def get_baseline_metrics do
    platform = Platform.get_current_platform()
    
    # Try to load platform-specific baseline
    platform_file = Path.join("priv/baseline_metrics", "#{platform}_baseline.json")
    
    baseline = if File.exists?(platform_file) do
      platform_file
      |> File.read!()
      |> Jason.decode!(keys: :atoms)
    else
      # Fall back to default baseline
      Path.join("priv/baseline_metrics", "default_baseline.json")
      |> File.read!()
      |> Jason.decode!(keys: :atoms)
    end
    
    baseline
  end
  
  # Private helper functions
  
  defp get_runtime_info do
    %{
      elixir_version: System.version(),
      otp_version: :erlang.system_info(:otp_release) |> List.to_string(),
      system_architecture: :erlang.system_info(:system_architecture) |> List.to_string(),
      logical_processors: :erlang.system_info(:logical_processors_available),
      process_count: :erlang.system_info(:process_count),
      atom_count: :erlang.system_info(:atom_count)
    }
  end
  
  defp generate_test_component(:simple) do
    # Return a simple text or button component
    %{type: :simple, content: "Simple test component"}
  end
  
  defp generate_test_component(:medium) do
    # Return a medium complexity component like a form or table
    items = for i <- 1..10, do: %{id: i, name: "Item #{i}"}
    %{type: :medium, items: items, has_border: true}
  end
  
  defp generate_test_component(:complex) do
    # Return a complex component like a dashboard
    panels = for i <- 1..5 do
      sub_items = for j <- 1..10, do: %{id: j, value: j * i, label: "Value #{j}"}
      %{
        id: i,
        title: "Panel #{i}",
        items: sub_items,
        has_charts: true,
        has_tables: true
      }
    end
    
    %{type: :complex, panels: panels, layout: :grid}
  end
  
  defp measure_render_time(component, iterations) do
    {time, _} = :timer.tc(fn ->
      for _ <- 1..iterations do
        # Simulate rendering by converting component to string representation
        render_component(component)
      end
    end)
    
    # Return average microseconds per render
    time / iterations
  end
  
  defp render_component(component) do
    # Simulate the work of rendering a component to a string
    case component do
      %{type: :simple, content: content} ->
        content
        |> to_string()
        |> String.pad_trailing(20)
        |> String.pad_leading(24)
        
      %{type: :medium, items: items} ->
        header = "| ID  | Name       |\n|-----|------------|\n"
        rows = Enum.map_join(items, "\n", fn %{id: id, name: name} ->
          "| #{String.pad_trailing(to_string(id), 4)} | #{String.pad_trailing(name, 10)} |"
        end)
        header <> rows
        
      %{type: :complex, panels: panels} ->
        Enum.map_join(panels, "\n\n", fn panel ->
          title = "=== #{panel.title} ===\n"
          table = "Table with #{length(panel.items)} items"
          chart = "Chart visualization"
          title <> table <> "\n" <> chart
        end)
    end
  end
  
  defp measure_full_screen_render(iterations) do
    # Simulate rendering a full screen (80x24 terminal)
    width = 80
    height = 24
    
    {time, _} = :timer.tc(fn ->
      for _ <- 1..iterations do
        # Create a screen buffer and fill it with content
        buffer = for y <- 1..height do
          for x <- 1..width do
            "#{rem(x * y, 10)}"
          end
          |> Enum.join("")
        end
        |> Enum.join("\n")
        
        # Force evaluation 
        _ = byte_size(buffer)
      end
    end)
    
    # Return average milliseconds per full screen render
    time / iterations / 1000
  end
  
  defp calculate_components_per_frame(simple_component_time_μs) do
    # Calculate how many simple components can render in 16.67ms (60 FPS)
    frame_budget_μs = 16667
    trunc(frame_budget_μs / simple_component_time_μs)
  end
  
  defp calculate_renders_per_second(full_screen_time_ms) do
    # Calculate full screens per second
    trunc(1000 / full_screen_time_ms)
  end
  
  defp setup_event_test_environment do
    # Simulate setting up an event manager and environment
    # Return a mock event manager for testing
    %{handlers: %{}, subscriptions: []}
  end
  
  defp measure_event_latency(event_manager, event_type, iterations) do
    # Create test event based on type
    event = create_test_event(event_type)
    
    {time, _} = :timer.tc(fn ->
      for _ <- 1..iterations do
        # Simulate event dispatch and handling
        dispatch_event(event_manager, event)
      end
    end)
    
    # Return average microseconds per event
    time / iterations
  end
  
  defp create_test_event(:keyboard) do
    %{type: :keyboard, key: :enter, modifiers: []}
  end
  
  defp create_test_event(:mouse) do
    %{type: :mouse, x: 10, y: 10, button: :left, action: :click}
  end
  
  defp create_test_event(:window) do
    %{type: :window, action: :resize, width: 80, height: 24}
  end
  
  defp create_test_event(:custom) do
    %{type: :custom, name: :test_event, data: %{value: 42}}
  end
  
  defp dispatch_event(event_manager, event) do
    # Simulate the work of dispatching an event
    # Find matching handlers
    matching_handlers = event_manager.handlers
                     |> Map.get(event.type, [])
                     |> Enum.filter(fn handler -> 
                       handler.type == event.type 
                     end)
    
    # Process event through handlers
    Enum.each(matching_handlers, fn handler ->
      # Simulate handler execution
      _ = {handler, event}
    end)
    
    # Return updated manager with event history
    event_manager
  end
  
  defp measure_burst_event_latency(event_manager, event_count) do
    # Create a burst of mixed events
    events = for i <- 1..event_count do
      event_type = case rem(i, 4) do
        0 -> :keyboard
        1 -> :mouse
        2 -> :window
        3 -> :custom
      end
      create_test_event(event_type)
    end
    
    # Measure time to process all events
    {time, _} = :timer.tc(fn ->
      Enum.reduce(events, event_manager, fn event, manager ->
        dispatch_event(manager, event)
      end)
    end)
    
    # Return average microseconds per event in burst
    time / event_count
  end
  
  defp calculate_events_per_second(event_latency_μs) do
    # Calculate how many events can be processed per second
    trunc(1_000_000 / event_latency_μs)
  end
  
  defp measure_memory_usage do
    # Get memory usage in KB
    {:memory, memory} = :erlang.process_info(self(), :memory)
    memory / 1024
  end
  
  defp measure_component_memory_usage do
    # Measure memory before and after creating components
    
    # Clear any previous garbage
    :erlang.garbage_collect()
    initial_memory = :erlang.memory(:total)
    
    # Create simple components
    simple_components = for _ <- 1..1000, do: generate_test_component(:simple)
    :erlang.garbage_collect()
    after_simple = :erlang.memory(:total)
    
    # Create medium components
    medium_components = for _ <- 1..100, do: generate_test_component(:medium)
    :erlang.garbage_collect()
    after_medium = :erlang.memory(:total)
    
    # Create complex components
    complex_components = for _ <- 1..10, do: generate_test_component(:complex)
    :erlang.garbage_collect()
    after_complex = :erlang.memory(:total)
    
    # Calculate memory per component type (in bytes)
    simple_memory = (after_simple - initial_memory) / 1000
    medium_memory = (after_medium - after_simple) / 100
    complex_memory = (after_complex - after_medium) / 10
    
    # Keep references to prevent GC
    _ = {simple_components, medium_components, complex_components}
    
    {simple_memory, medium_memory, complex_memory}
  end
  
  defp measure_continuous_rendering_memory(iterations) do
    # Clear any previous garbage
    :erlang.garbage_collect()
    start_memory = :erlang.memory(:total) / 1024
    
    # Run continuous rendering
    for _ <- 1..iterations do
      component = generate_test_component(:medium)
      render_component(component)
    end
    
    # Measure memory after rendering
    :erlang.garbage_collect()
    end_memory = :erlang.memory(:total) / 1024
    
    {start_memory, end_memory}
  end
  
  defp check_for_memory_leaks(iterations) do
    # Run memory-intensive operations repeatedly
    memory_measurements = for i <- 1..iterations do
      # Clear any previous garbage for accurate measurement
      :erlang.garbage_collect()
      
      # Create and render components
      components = for _ <- 1..10 do
        generate_test_component(:medium)
      end
      
      Enum.each(components, &render_component/1)
      
      # Measure memory
      {:memory, memory} = :erlang.process_info(self(), :memory)
      {i, memory}
    end
    
    # Analyze memory growth pattern
    # Calculate linear regression to detect upward trend
    {xs, ys} = Enum.unzip(memory_measurements)
    
    # Simple linear regression
    n = length(memory_measurements)
    sum_x = Enum.sum(xs)
    sum_y = Enum.sum(ys)
    sum_xy = Enum.sum(for {x, y} <- memory_measurements, do: x * y)
    sum_x_squared = Enum.sum(for x <- xs, do: x * x)
    
    slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x_squared - sum_x * sum_x)
    
    # If slope is significantly positive, suggest potential leak
    slope > 100
  end
  
  defp calculate_memory_efficiency_score(simple, medium, complex) do
    # Normalize memory usage into a 0-100 score
    # Lower is better, use logarithmic scale to handle large variations
    simple_score = 100 - min(100, :math.log(simple) * 10)
    medium_score = 100 - min(100, :math.log(medium) * 8)
    complex_score = 100 - min(100, :math.log(complex) * 6)
    
    # Calculate weighted average
    (simple_score * 0.5 + medium_score * 0.3 + complex_score * 0.2)
    |> Float.round(1)
  end
  
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
      component = generate_test_component(:simple)
      render_component(component)
      
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
    frame_times = capture_frame_times(start_time, end_time, frame_duration, frame_times)
    
    # Calculate standard deviation of frame times
    mean = Enum.sum(frame_times) / length(frame_times)
    sum_squared_diffs = Enum.reduce(frame_times, 0, fn time, acc ->
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
      component = generate_test_component(:simple)
      render_component(component)
      
      # Calculate actual frame time
      actual_time = System.monotonic_time(:millisecond) - frame_start
      
      # Sleep remaining time
      remaining = max(0, frame_duration - actual_time)
      if remaining > 0, do: Process.sleep(trunc(remaining))
      
      # Record total frame time
      total_frame_time = System.monotonic_time(:millisecond) - frame_start
      
      # Recursive call to continue animation
      capture_frame_times(start_time, end_time, frame_duration, [total_frame_time | frame_times])
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
    {actual_frames, _} = count_timely_frames(start_time, end_time, frame_duration, 0, 0)
    
    # Calculate percentage of dropped frames
    drop_percentage = (expected_frames - actual_frames) / expected_frames * 100
    |> Float.round(1)
    |> max(0)
    
    drop_percentage
  end
  
  defp count_timely_frames(start_time, end_time, frame_duration, frame_count, dropped_count) do
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
        
        count_timely_frames(start_time, end_time, frame_duration, next_frame_count, next_dropped)
      else
        # Render the frame
        frame_start = System.monotonic_time(:millisecond)
        component = generate_test_component(:medium)
        render_component(component)
        _render_time = System.monotonic_time(:millisecond) - frame_start
        
        # Sleep if time remains
        remaining = max(0, target_time + frame_duration - System.monotonic_time(:millisecond))
        if remaining > 0, do: Process.sleep(trunc(remaining))
        
        # Continue to next frame
        count_timely_frames(start_time, end_time, frame_duration, frame_count + 1, dropped_count)
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
      component = generate_test_component(:medium)
      render_component(component)
      
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
  
  defp validate_render_metrics(results, baseline) do
    metrics = [
      {:simple_component_time_μs, &<=/2, "Simple component render time"},
      {:medium_component_time_μs, &<=/2, "Medium component render time"},
      {:complex_component_time_μs, &<=/2, "Complex component render time"},
      {:full_screen_render_time_ms, &<=/2, "Full screen render time"},
      {:components_per_frame, &>=/2, "Components per frame (60 FPS)"},
      {:renders_per_second, &>=/2, "Full screen renders per second"}
    ]
    
    validate_metric_list(results, baseline, metrics)
  end
  
  defp validate_event_metrics(results, baseline) do
    metrics = [
      {:keyboard_event_latency_μs, &<=/2, "Keyboard event latency"},
      {:mouse_event_latency_μs, &<=/2, "Mouse event latency"},
      {:window_event_latency_μs, &<=/2, "Window event latency"},
      {:custom_event_latency_μs, &<=/2, "Custom event latency"},
      {:burst_events_latency_μs, &<=/2, "Burst events latency"},
      {:events_per_second, &>=/2, "Events processed per second"}
    ]
    
    validate_metric_list(results, baseline, metrics)
  end
  
  defp validate_memory_metrics(results, baseline) do
    metrics = [
      {:simple_component_memory_bytes, &<=/2, "Simple component memory usage"},
      {:medium_component_memory_bytes, &<=/2, "Medium component memory usage"},
      {:complex_component_memory_bytes, &<=/2, "Complex component memory usage"},
      {:rendering_memory_growth_kb, &<=/2, "Memory growth during rendering"},
      {:memory_efficiency_score, &>=/2, "Memory efficiency score"}
    ]
    
    # Add memory leak validation
    leak_validation = 
      if results[:memory_leak_detected] do
        {:memory_leak_detected, :fail, "Memory leak detected", true}
      else
        {:memory_leak_detected, :pass, "No memory leak detected", false}
      end
    
    regular_validations = validate_metric_list(results, baseline, metrics)
    Map.put(regular_validations, :memory_leak_detected, leak_validation)
  end
  
  defp validate_animation_metrics(results, baseline) do
    metrics = [
      {:maximum_fps, &>=/2, "Maximum achievable FPS"},
      {:frame_time_consistency_ms, &<=/2, "Frame time consistency (lower is better)"},
      {:dropped_frames_percent, &<=/2, "Dropped frames percentage"},
      {:cpu_usage_percent, &<=/2, "CPU usage during animation"},
      {:animation_smoothness_score, &>=/2, "Animation smoothness score"}
    ]
    
    validate_metric_list(results, baseline, metrics)
  end
  
  defp validate_metric_list(results, baseline, metrics) do
    Enum.map(metrics, fn {metric, comparator, label} ->
      result_value = Map.get(results, metric)
      baseline_value = Map.get(baseline, metric)
      
      validation_result = cond do
        is_nil(result_value) ->
          {:skip, "Metric not measured"}
          
        is_nil(baseline_value) ->
          {:skip, "No baseline for comparison"}
          
        comparator.(result_value, baseline_value) ->
          {:pass, "#{label}: #{result_value} (baseline: #{baseline_value})"}
          
        true ->
          {:fail, "#{label}: #{result_value} (baseline: #{baseline_value})"}
      end
      
      {metric, validation_result}
    end)
    |> Enum.into(%{})
  end
  
  defp print_summary(results, detailed) do
    IO.puts("\n=== Performance Benchmark Summary ===\n")
    IO.puts("Platform: #{results.platform.name} #{results.platform.version}")
    IO.puts("Architecture: #{results.platform.architecture}")
    IO.puts("Terminal: #{results.platform.terminal}")
    IO.puts("Execution time: #{results.execution_time}ms\n")
    
    IO.puts("Rendering Performance:")
    IO.puts("- Simple component: #{Float.round(results.render_performance.simple_component_time_μs, 2)}μs")
    IO.puts("- Full screen render: #{Float.round(results.render_performance.full_screen_render_time_ms, 2)}ms")
    IO.puts("- Components per frame (60 FPS): #{results.render_performance.components_per_frame}")
    
    IO.puts("\nEvent Handling:")
    IO.puts("- Keyboard event latency: #{Float.round(results.event_latency.keyboard_event_latency_μs, 2)}μs")
    IO.puts("- Events per second: #{results.event_latency.events_per_second}")
    
    IO.puts("\nMemory Usage:")
    IO.puts("- Memory efficiency score: #{results.memory_usage.memory_efficiency_score}/100")
    IO.puts("- Memory leak detected: #{results.memory_usage.memory_leak_detected}")
    
    IO.puts("\nAnimation Performance:")
    IO.puts("- Maximum FPS: #{results.animation_fps.maximum_fps}")
    IO.puts("- Animation smoothness score: #{results.animation_fps.animation_smoothness_score}/100")
    IO.puts("- Dropped frames: #{results.animation_fps.dropped_frames_percent}%")
    
    if Map.has_key?(results, :metrics_validation) do
      validation = results.metrics_validation
      
      IO.puts("\n=== Validation Results ===\n")
      IO.puts("Overall status: #{validation.overall.status}")
      IO.puts("Pass rate: #{Float.round(validation.overall.pass_percentage, 1)}% (#{validation.overall.passed_validations}/#{validation.overall.total_validations})")
      
      if detailed do
        print_detailed_validation(validation)
      end
    end
    
    IO.puts("\nBenchmark complete.")
  end
  
  defp print_detailed_validation(validation) do
    categories = [:render_performance, :event_latency, :memory_usage, :animation_fps]
    
    Enum.each(categories, fn category ->
      category_results = Map.get(validation, category, %{})
      category_name = category |> to_string() |> String.replace("_", " ") |> String.capitalize()
      
      IO.puts("\n#{category_name}:")
      
      if map_size(category_results) > 0 do
        Enum.each(category_results, fn {_metric, {status, message}} ->
          status_icon = case status do
            :pass -> "✓"
            :fail -> "✗"
            :skip -> "?"
          end
          
          IO.puts("  #{status_icon} #{message}")
        end)
      else
        IO.puts("  No validation results available")
      end
    end)
  end
end 