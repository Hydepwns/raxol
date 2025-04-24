defmodule Raxol.Benchmarks.VisualizationBenchmark do
  @moduledoc """
  Performance benchmarking tool for visualization components.
  Provides tools to measure rendering time, memory usage, and optimization effectiveness
  for different data sizes and visualization types.
  """

  require Logger

  @doc """
  Run a comprehensive benchmark suite for visualization components.

  This test will:
  1. Generate test datasets of varying sizes
  2. Benchmark chart rendering performance
  3. Benchmark treemap rendering performance
  4. Test cache hit performance
  5. Measure memory usage
  6. Generate a summary report

  ## Options

  * `:output_path` - Path to write the benchmark results (default: "benchmark_results")
  * `:datasets` - List of dataset sizes to test (default: [10, 100, 1000, 10000])
  * `:iterations` - Number of times to run each test (default: 5)
  * `:cache_test` - Whether to test cache performance (default: true)
  * `:memory_test` - Whether to track memory usage (default: true)
  """
  def run_benchmark(opts \\ []) do
    output_path = Keyword.get(opts, :output_path, "benchmark_results")
    dataset_sizes = Keyword.get(opts, :datasets, [10, 100, 1000, 10000])
    iterations = Keyword.get(opts, :iterations, 5)
    test_cache = Keyword.get(opts, :cache_test, true)
    test_memory = opts[:test_memory] || false

    # Create output directory if it doesn't exist
    File.mkdir_p!(output_path)

    # Generate test datasets
    IO.puts("Generating test datasets...")
    chart_datasets = generate_chart_datasets(dataset_sizes)
    treemap_datasets = generate_treemap_datasets(dataset_sizes)

    # Run chart benchmarks
    IO.puts("\nRunning chart benchmarks...")

    chart_results =
      benchmark_charts(chart_datasets, iterations, test_cache, test_memory)

    # Run treemap benchmarks
    IO.puts("\nRunning treemap benchmarks...")

    treemap_results =
      benchmark_treemaps(treemap_datasets, iterations, test_cache, test_memory)

    # Write results
    results_file =
      Path.join(output_path, "visualization_benchmark_#{timestamp()}.md")

    write_results(results_file, chart_results, treemap_results, opts)

    IO.puts("\nBenchmark completed. Results written to #{results_file}")

    # Return summary
    %{
      chart_results: chart_results,
      treemap_results: treemap_results,
      output_file: results_file
    }
  end

  @doc """
  Benchmark chart rendering performance.
  """
  def benchmark_charts(datasets, iterations, test_cache, test_memory) do
    Enum.map(datasets, fn {size, data} ->
      IO.puts("  Benchmarking chart with #{size} data points...")

      # Prepare test environment
      if test_memory do
        # IO.puts("Starting memory tracking...") # DEBUG
        # Raxol.RuntimeDebug.start_memory_tracking()
        # Placeholder for memory tracking return value
        _result = nil
      end

      # Create standard bounds for testing
      bounds = %{x: 0, y: 0, width: 80, height: 24}

      # Track times for each iteration
      times =
        for i <- 1..iterations do
          IO.write("    Iteration #{i}/#{iterations}...")

          # Reset cache between iterations if not testing cache
          if !(test_cache or i == 1) do
            # This resets the plugin state, clearing the cache
            _init_result = Raxol.Plugins.VisualizationPlugin.init()
          end

          # Measure chart rendering time
          {time, _result} =
            :timer.tc(fn ->
              plugin_state = %Raxol.Plugins.VisualizationPlugin.State{
                cache_timeout: :timer.minutes(5),
                layout_cache: %{},
                last_chart_hash: nil,
                last_treemap_hash: nil,
                cleanup_ref: nil
              }

              Raxol.Plugins.VisualizationPlugin.render_chart_content(
                data,
                %{title: "Benchmark Chart"},
                bounds,
                plugin_state
              )
            end)

          # Convert to milliseconds
          time_ms = time / 1000
          IO.puts(" #{time_ms}ms")
          time_ms
        end

      # Collect memory data if requested
      memory_data =
        if test_memory do
          # Raxol.RuntimeDebug.get_memory_snapshot()
          memory_info = nil
          # Raxol.RuntimeDebug.stop_memory_tracking()
          # IO.inspect(memory_info, label: "Memory Info #{label}") # DEBUG
          memory_info
        else
          nil
        end

      # Calculate statistics
      avg_time = Enum.sum(times) / length(times)
      min_time = Enum.min(times)
      max_time = Enum.max(times)
      std_dev = calculate_stddev(times, avg_time)

      # Build result map
      %{
        type: :chart,
        size: size,
        iterations: iterations,
        times: times,
        avg_time: avg_time,
        min_time: min_time,
        max_time: max_time,
        std_dev: std_dev,
        cache_enabled: test_cache,
        memory: memory_data
      }
    end)
  end

  @doc """
  Benchmark treemap rendering performance.
  """
  def benchmark_treemaps(datasets, iterations, test_cache, test_memory) do
    Enum.map(datasets, fn {size, data} ->
      IO.puts("  Benchmarking treemap with #{size} nodes...")

      # Prepare test environment
      if test_memory do
        # Raxol.RuntimeDebug.start_memory_tracking()
        # Placeholder for memory tracking return value
        _result = nil
      end

      # Create standard bounds for testing
      bounds = %{x: 0, y: 0, width: 80, height: 24}

      # Track times for each iteration
      times =
        for i <- 1..iterations do
          IO.write("    Iteration #{i}/#{iterations}...")

          # Reset cache between iterations if not testing cache
          if !(test_cache or i == 1) do
            # This resets the plugin state, clearing the cache
            _init_result = Raxol.Plugins.VisualizationPlugin.init()
          end

          # Measure treemap rendering time
          {time, _result} =
            :timer.tc(fn ->
              plugin_state = %Raxol.Plugins.VisualizationPlugin.State{
                cache_timeout: :timer.minutes(5),
                layout_cache: %{},
                last_chart_hash: nil,
                last_treemap_hash: nil,
                cleanup_ref: nil
              }

              Raxol.Plugins.VisualizationPlugin.render_treemap_content(
                data,
                %{title: "Benchmark TreeMap"},
                bounds,
                plugin_state
              )
            end)

          # Convert to milliseconds
          time_ms = time / 1000
          IO.puts(" #{time_ms}ms")
          time_ms
        end

      # Collect memory data if requested
      memory_data =
        if test_memory do
          # Raxol.RuntimeDebug.get_memory_snapshot()
          memory_info = nil
          # Raxol.RuntimeDebug.stop_memory_tracking()
          # IO.inspect(memory_info, label: "Memory Info #{label}") # DEBUG
          memory_info
        else
          nil
        end

      # Count total nodes including children
      node_count = count_nodes(data)

      # Calculate statistics
      avg_time = Enum.sum(times) / length(times)
      min_time = Enum.min(times)
      max_time = Enum.max(times)
      std_dev = calculate_stddev(times, avg_time)

      # Build result map
      %{
        type: :treemap,
        size: size,
        node_count: node_count,
        iterations: iterations,
        times: times,
        avg_time: avg_time,
        min_time: min_time,
        max_time: max_time,
        std_dev: std_dev,
        cache_enabled: test_cache,
        memory: memory_data
      }
    end)
  end

  # --- Helper Functions ---

  defp generate_chart_datasets(sizes) do
    Enum.map(sizes, fn size ->
      data =
        for i <- 1..size do
          {"Item #{i}", :rand.uniform(100)}
        end

      {size, data}
    end)
  end

  defp generate_treemap_datasets(sizes) do
    Enum.map(sizes, fn size ->
      # Create a hierarchical structure
      data = generate_treemap_data(size)
      {size, data}
    end)
  end

  defp generate_treemap_data(size) do
    cond do
      # Empty dataset
      size == 0 ->
        %{
          name: "Root",
          value: 0,
          children: []
        }

      # Small dataset - flat structure
      size <= 10 ->
        %{
          name: "Root",
          value: size * 10,
          children:
            for i <- 1..size do
              %{
                name: "Item #{i}",
                value: :rand.uniform(100)
              }
            end
        }

      # Medium dataset - two levels
      size <= 100 ->
        num_groups = min(10, div(size, 5))
        items_per_group = div(size, num_groups)
        remainder = rem(size, num_groups)

        %{
          name: "Root",
          value: size * 10,
          children:
            for g <- 1..num_groups do
              # Add an extra item to early groups if there's a remainder
              actual_items = items_per_group + if g <= remainder, do: 1, else: 0

              %{
                name: "Group #{g}",
                value: actual_items * 10,
                children:
                  for i <- 1..actual_items do
                    %{
                      name: "Item #{g}.#{i}",
                      value: :rand.uniform(100)
                    }
                  end
              }
            end
        }

      # Large dataset - three levels
      true ->
        # Create a three-level hierarchy
        num_sections = min(10, div(size, 100))
        num_groups_per_section = min(10, div(size, 50))
        items_per_group = div(size, num_sections * num_groups_per_section)

        %{
          name: "Root",
          value: size * 10,
          children:
            for s <- 1..num_sections do
              %{
                name: "Section #{s}",
                value: div(size, num_sections) * 10,
                children:
                  for g <- 1..num_groups_per_section do
                    %{
                      name: "Group #{s}.#{g}",
                      value: items_per_group * 10,
                      children:
                        for i <- 1..items_per_group do
                          %{
                            name: "Item #{s}.#{g}.#{i}",
                            value: :rand.uniform(100)
                          }
                        end
                    }
                  end
              }
            end
        }
    end
  end

  defp count_nodes(nil), do: 0
  defp count_nodes(%{children: nil}), do: 1
  defp count_nodes(%{children: []}), do: 1

  defp count_nodes(%{children: children}) when is_list(children) do
    1 + Enum.sum(Enum.map(children, &count_nodes/1))
  end

  defp count_nodes(_), do: 1

  defp calculate_stddev(values, mean) do
    variance =
      values
      |> Enum.map(fn x -> :math.pow(x - mean, 2) end)
      |> Enum.sum()
      |> Kernel./(length(values))

    :math.sqrt(variance)
  end

  defp timestamp do
    {{year, month, day}, {hour, minute, _}} = :calendar.local_time()

    "#{year}#{zero_pad(month)}#{zero_pad(day)}_#{zero_pad(hour)}#{zero_pad(minute)}"
  end

  defp zero_pad(number) when number < 10, do: "0#{number}"
  defp zero_pad(number), do: "#{number}"

  defp write_results(file, chart_results, treemap_results, opts) do
    # Prepare markdown content
    content = """
    # Visualization Performance Benchmark Results

    **Date:** #{format_timestamp()}

    **Test Configuration:**
    - Iterations per test: #{Keyword.get(opts, :iterations, 5)}
    - Cache Testing: #{Keyword.get(opts, :cache_test, true)}
    - Memory Tracking: #{Keyword.get(opts, :memory_test, true)}

    ## Chart Performance

    | Dataset Size | Avg Time (ms) | Min Time (ms) | Max Time (ms) | Std Dev |
    |--------------|---------------|---------------|---------------|---------|
    #{format_chart_results(chart_results)}

    ## TreeMap Performance

    | Dataset Size | Node Count | Avg Time (ms) | Min Time (ms) | Max Time (ms) | Std Dev |
    |--------------|------------|---------------|---------------|---------------|---------|
    #{format_treemap_results(treemap_results)}

    ## Cache Performance

    #{format_cache_performance(chart_results, treemap_results, opts)}

    ## Memory Usage

    #{if Keyword.get(opts, :memory_test, true), do: format_memory_usage(chart_results, treemap_results), else: "*Memory tracking disabled*"}

    ## Conclusions

    - #{interpret_performance(chart_results, treemap_results)}
    """

    # Write to file
    File.write!(file, content)
  end

  defp format_timestamp do
    {{year, month, day}, {hour, minute, second}} = :calendar.local_time()

    "#{year}-#{zero_pad(month)}-#{zero_pad(day)} #{zero_pad(hour)}:#{zero_pad(minute)}:#{zero_pad(second)}"
  end

  defp format_chart_results(results) do
    results
    |> Enum.map(fn r ->
      "| #{r.size} | #{Float.round(r.avg_time, 2)} | #{Float.round(r.min_time, 2)} | #{Float.round(r.max_time, 2)} | #{Float.round(r.std_dev, 2)} |"
    end)
    |> Enum.join("\n")
  end

  defp format_treemap_results(results) do
    results
    |> Enum.map(fn r ->
      "| #{r.size} | #{r.node_count} | #{Float.round(r.avg_time, 2)} | #{Float.round(r.min_time, 2)} | #{Float.round(r.max_time, 2)} | #{Float.round(r.std_dev, 2)} |"
    end)
    |> Enum.join("\n")
  end

  defp format_cache_performance(chart_results, treemap_results, opts) do
    if Keyword.get(opts, :cache_test, true) do
      chart_speedup = calculate_cache_speedup(chart_results)
      treemap_speedup = calculate_cache_speedup(treemap_results)

      """
      Cache performance metrics demonstrate the effectiveness of the caching system:

      - **Chart Cache Speedup:** #{Float.round(chart_speedup, 2)}x faster after initial render (average)
      - **TreeMap Cache Speedup:** #{Float.round(treemap_speedup, 2)}x faster after initial render (average)

      This indicates that the caching system is #{evaluate_cache_effectiveness(chart_speedup, treemap_speedup)}.
      """
    else
      "*Cache testing disabled*"
    end
  end

  defp calculate_cache_speedup(results) do
    # For each dataset, compare first vs. subsequent iterations
    speedups =
      results
      |> Enum.map(fn result ->
        if length(result.times) > 1 do
          first_time = Enum.at(result.times, 0)
          rest_times = Enum.slice(result.times, 1..-1//-1)
          avg_rest_time = Enum.sum(rest_times) / length(rest_times)

          if avg_rest_time > 0, do: first_time / avg_rest_time, else: 1.0
        else
          1.0
        end
      end)

    # Calculate average speedup across all dataset sizes
    Enum.sum(speedups) / length(speedups)
  end

  defp evaluate_cache_effectiveness(chart_speedup, treemap_speedup) do
    avg_speedup = (chart_speedup + treemap_speedup) / 2

    cond do
      avg_speedup >= 5.0 -> "highly effective"
      avg_speedup >= 2.0 -> "effective"
      avg_speedup >= 1.5 -> "moderately effective"
      avg_speedup >= 1.2 -> "slightly effective"
      true -> "not significantly effective"
    end
  end

  defp format_memory_usage(chart_results, treemap_results) do
    # Extract memory metrics for largest datasets
    largest_chart = Enum.max_by(chart_results, fn r -> r.size end)
    largest_treemap = Enum.max_by(treemap_results, fn r -> r.size end)

    chart_memory = largest_chart.memory
    treemap_memory = largest_treemap.memory

    if chart_memory && treemap_memory do
      """
      Memory usage metrics for the largest datasets:

      **Chart (#{largest_chart.size} data points):**
      - Memory Used: #{format_bytes(chart_memory.memory_used)}
      - GC Runs: #{chart_memory.gc_count}

      **TreeMap (#{largest_treemap.size} data points, #{largest_treemap.node_count} nodes):**
      - Memory Used: #{format_bytes(treemap_memory.memory_used)}
      - GC Runs: #{treemap_memory.gc_count}
      """
    else
      "*Memory data collection failed*"
    end
  end

  defp format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_000_000 -> "#{Float.round(bytes / 1_000_000, 2)} MB"
      bytes >= 1_000 -> "#{Float.round(bytes / 1_000, 2)} KB"
      true -> "#{bytes} bytes"
    end
  end

  defp format_bytes(_), do: "unknown"

  defp interpret_performance(chart_results, treemap_results) do
    # Get largest datasets to analyze scalability
    chart_by_size = Enum.sort_by(chart_results, fn r -> r.size end)
    treemap_by_size = Enum.sort_by(treemap_results, fn r -> r.size end)

    # Basic analysis - compare small vs large datasets
    if length(chart_by_size) >= 2 && length(treemap_by_size) >= 2 do
      small_chart = List.first(chart_by_size)
      large_chart = List.last(chart_by_size)
      chart_size_ratio = large_chart.size / small_chart.size
      chart_time_ratio = large_chart.avg_time / small_chart.avg_time

      small_treemap = List.first(treemap_by_size)
      large_treemap = List.last(treemap_by_size)
      treemap_size_ratio = large_treemap.size / small_treemap.size
      treemap_time_ratio = large_treemap.avg_time / small_treemap.avg_time

      # Analyze scalability
      chart_efficiency = chart_size_ratio / chart_time_ratio
      treemap_efficiency = treemap_size_ratio / treemap_time_ratio

      # Interpret results
      cond do
        chart_efficiency >= 0.8 && treemap_efficiency >= 0.8 ->
          "Both chart and treemap visualization components scale very efficiently with larger datasets."

        chart_efficiency >= 0.5 && treemap_efficiency >= 0.5 ->
          "Both visualizations show good scalability, with sub-linear performance degradation as data size increases."

        chart_efficiency >= 0.5 ->
          "Chart visualization scales efficiently, but treemap performance could be improved with larger datasets."

        treemap_efficiency >= 0.5 ->
          "Treemap visualization scales efficiently, but chart performance could be improved with larger datasets."

        true ->
          "Both visualizations show signs of performance degradation with larger datasets. Additional optimization may be necessary."
      end
    else
      "Insufficient data to analyze performance scaling."
    end
  end
end
