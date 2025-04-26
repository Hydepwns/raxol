defmodule Raxol.Benchmarks.Performance.MemoryUsage do
  @moduledoc """
  Memory usage performance benchmark functions for Raxol.
  """

  # Alias functions from Rendering module needed here
  alias Raxol.Benchmarks.Performance.Rendering, as: RenderingBenchmark

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
    {simple_memory, medium_memory, complex_memory} =
      measure_component_memory_usage()

    # Measure memory during continuous rendering
    {render_memory_start, render_memory_end} =
      measure_continuous_rendering_memory(1000)

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
      memory_efficiency_score:
        calculate_memory_efficiency_score(
          simple_memory,
          medium_memory,
          complex_memory
        )
    }

    IO.puts("✓ Memory usage benchmarks complete")
    results
  end

  # Helper functions moved from Raxol.Benchmarks.Performance

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
    simple_components = for _ <- 1..1000, do: RenderingBenchmark.generate_test_component(:simple)
    :erlang.garbage_collect()
    after_simple = :erlang.memory(:total)

    # Create medium components
    medium_components = for _ <- 1..100, do: RenderingBenchmark.generate_test_component(:medium)
    :erlang.garbage_collect()
    after_medium = :erlang.memory(:total)

    # Create complex components
    complex_components = for _ <- 1..10, do: RenderingBenchmark.generate_test_component(:complex)
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
      component = RenderingBenchmark.generate_test_component(:medium)
      RenderingBenchmark.render_component(component)
    end

    # Measure memory after rendering
    :erlang.garbage_collect()
    end_memory = :erlang.memory(:total) / 1024

    {start_memory, end_memory}
  end

  defp check_for_memory_leaks(iterations) do
    # Run memory-intensive operations repeatedly
    memory_measurements =
      for i <- 1..iterations do
        # Clear any previous garbage for accurate measurement
        :erlang.garbage_collect()

        # Create and render components
        components =
          for _ <- 1..10 do
            RenderingBenchmark.generate_test_component(:medium)
          end

        Enum.each(components, &RenderingBenchmark.render_component/1)

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
end
