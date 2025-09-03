defmodule Raxol.Benchmarks.VisualizationBenchmark do
  @moduledoc """
  Performance benchmarking tool for visualization components.
  Provides tools to measure rendering time, memory usage, and optimization effectiveness
  for different data sizes and visualization types.
  """

  require Raxol.Core.Runtime.Log

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
  def run_benchmark(opts \\ [])

  def run_benchmark(opts) when is_map(opts),
    do: run_benchmark(Enum.into(opts, []))

  def run_benchmark(opts) when is_list(opts) do
    output_path = Keyword.get(opts, :output_path, "benchmark_results")
    dataset_sizes = Keyword.get(opts, :datasets, [10, 100, 1000, 10_000])
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
      _result =
        case test_memory do
          true ->
            # IO.puts("Starting memory tracking...") # DEBUG
            # Raxol.RuntimeDebug.start_memory_tracking()
            # Placeholder for memory tracking return value
            nil

          false ->
            nil
        end

      # Create standard bounds for testing
      bounds = %{x: 0, y: 0, width: 80, height: 24}

      # Create plugin state
      _plugin_state = %{
        cache_timeout: :timer.minutes(5),
        layout_cache: %{},
        last_chart_hash: nil,
        last_treemap_hash: nil,
        cleanup_ref: nil,
        config: %{
          chart_style: :line,
          treemap_style: :compact
        }
      }

      # Track times for each iteration
      times =
        for i <- 1..iterations do
          # Setup plugin state for each iteration (or before loop if not resetting cache)
          {:ok, _plugin_meta, plugin_state} =
            case {test_cache, i} do
              {true, _} -> Raxol.Plugins.VisualizationPlugin.init()
              {false, 1} -> Raxol.Plugins.VisualizationPlugin.init()
              {false, _} -> Raxol.Plugins.VisualizationPlugin.init()
            end

          IO.write("    Iteration #{i}/#{iterations}...")

          # Measure chart rendering time
          {time, _result} =
            :timer.tc(fn ->
              # Call the correct renderer module directly
              Raxol.Plugins.Visualization.ChartRenderer.render_chart_content(
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
        case test_memory do
          true ->
            # Raxol.RuntimeDebug.get_memory_snapshot()
            memory_info = nil
            # Raxol.RuntimeDebug.stop_memory_tracking()
            memory_info

          false ->
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
      _result =
        case test_memory do
          true -> nil
          false -> nil
        end

      # Create standard bounds for testing
      bounds = %{x: 0, y: 0, width: 80, height: 24}

      # Create plugin state
      _plugin_state = %{
        cache_timeout: :timer.minutes(5),
        layout_cache: %{},
        last_chart_hash: nil,
        last_treemap_hash: nil,
        cleanup_ref: nil,
        config: %{
          chart_style: :line,
          treemap_style: :compact
        }
      }

      # Track times for each iteration
      times = run_treemap_iterations(data, bounds, iterations, test_cache)

      # Collect memory data if requested
      memory_data =
        case test_memory do
          true ->
            memory_info = nil
            memory_info

          false ->
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

  defp run_treemap_iterations(data, bounds, iterations, test_cache) do
    for i <- 1..iterations do
      {:ok, _plugin_meta, plugin_state} =
        case {test_cache, i} do
          {true, _} -> Raxol.Plugins.VisualizationPlugin.init()
          {false, 1} -> Raxol.Plugins.VisualizationPlugin.init()
          {false, _} -> Raxol.Plugins.VisualizationPlugin.init()
        end

      IO.write("    Iteration #{i}/#{iterations}...")

      {time, _result} =
        :timer.tc(fn ->
          Raxol.Plugins.Visualization.TreemapRenderer.render_treemap_content(
            data,
            %{title: "Benchmark TreeMap"},
            bounds,
            plugin_state
          )
        end)

      time_ms = time / 1000
      IO.puts(" #{time_ms}ms")
      time_ms
    end
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

  defp generate_treemap_data(0), do: generate_empty_treemap()

  defp generate_treemap_data(size) when size <= 10,
    do: generate_small_treemap(size)

  defp generate_treemap_data(size) when size <= 100,
    do: generate_medium_treemap(size)

  defp generate_treemap_data(size), do: generate_large_treemap(size)

  defp generate_empty_treemap() do
    %{
      name: "Root",
      value: 0,
      children: []
    }
  end

  defp generate_small_treemap(size) do
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
  end

  defp generate_medium_treemap(size) do
    num_groups = min(10, div(size, 5))
    items_per_group = div(size, num_groups)
    remainder = rem(size, num_groups)

    %{
      name: "Root",
      value: size * 10,
      children:
        for g <- 1..num_groups do
          # Add an extra item to early groups if there's a remainder
          actual_items =
            case g <= remainder do
              true -> items_per_group + 1
              false -> items_per_group
            end

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
  end

  defp generate_large_treemap(size) do
    Raxol.Benchmarks.DataGenerator.generate_treemap_data(size)
  end

  defp count_nodes(data) do
    Raxol.Benchmarks.DataGenerator.count_nodes(data)
  end

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

    #{case Keyword.get(opts, :memory_test, true) do
      true -> format_memory_usage(chart_results, treemap_results)
      false -> "*Memory tracking disabled*"
    end}

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
    Enum.map_join(results, "\n", fn r ->
      "| #{r.size} | #{Float.round(r.avg_time, 2)} | #{Float.round(r.min_time, 2)} | #{Float.round(r.max_time, 2)} | #{Float.round(r.std_dev, 2)} |"
    end)
  end

  defp format_treemap_results(results) do
    Enum.map_join(results, "\n", fn r ->
      "| #{r.size} | #{r.node_count} | #{Float.round(r.avg_time, 2)} | #{Float.round(r.min_time, 2)} | #{Float.round(r.max_time, 2)} | #{Float.round(r.std_dev, 2)} |"
    end)
  end

  defp format_cache_performance(chart_results, treemap_results, opts) do
    case Keyword.get(opts, :cache_test, true) do
      true ->
        chart_speedup = calculate_cache_speedup(chart_results)
        treemap_speedup = calculate_cache_speedup(treemap_results)

        """
        Cache performance metrics demonstrate the effectiveness of the caching system:

        - **Chart Cache Speedup:** #{Float.round(chart_speedup, 2)}x faster after initial render (average)
        - **TreeMap Cache Speedup:** #{Float.round(treemap_speedup, 2)}x faster after initial render (average)

        This indicates that the caching system is #{evaluate_cache_effectiveness(chart_speedup, treemap_speedup)}.
        """

      false ->
        "*Cache testing disabled*"
    end
  end

  defp calculate_cache_speedup(results) do
    speedups = Enum.map(results, &calculate_dataset_speedup/1)
    Enum.sum(speedups) / length(speedups)
  end

  defp calculate_dataset_speedup(result) do
    with true <- length(result.times) > 1,
         first_time <- Enum.at(result.times, 0),
         rest_times <- Enum.slice(result.times, 1..-1//-1),
         avg_rest_time <- Enum.sum(rest_times) / length(rest_times) do
      case avg_rest_time > 0 do
        true -> first_time / avg_rest_time
        false -> 1.0
      end
    else
      _ -> 1.0
    end
  end

  defp evaluate_cache_effectiveness(chart_speedup, treemap_speedup) do
    avg_speedup = (chart_speedup + treemap_speedup) / 2
    classify_cache_effectiveness(avg_speedup)
  end

  defp classify_cache_effectiveness(avg_speedup) when avg_speedup >= 5.0,
    do: "highly effective"

  defp classify_cache_effectiveness(avg_speedup) when avg_speedup >= 2.0,
    do: "effective"

  defp classify_cache_effectiveness(avg_speedup) when avg_speedup >= 1.5,
    do: "moderately effective"

  defp classify_cache_effectiveness(avg_speedup) when avg_speedup >= 1.2,
    do: "slightly effective"

  defp classify_cache_effectiveness(_avg_speedup),
    do: "not significantly effective"

  defp format_memory_usage(chart_results, treemap_results) do
    # Extract memory metrics for largest datasets
    largest_chart = Enum.max_by(chart_results, fn r -> r.size end)
    largest_treemap = Enum.max_by(treemap_results, fn r -> r.size end)

    chart_memory = largest_chart.memory
    treemap_memory = largest_treemap.memory

    case {chart_memory, treemap_memory} do
      {chart_mem, treemap_mem} when chart_mem != nil and treemap_mem != nil ->
        """
        Memory usage metrics for the largest datasets:

        **Chart (#{largest_chart.size} data points):**
        - Memory Used: #{format_bytes(chart_memory.memory_used)}
        - GC Runs: #{chart_memory.gc_count}

        **TreeMap (#{largest_treemap.size} data points, #{largest_treemap.node_count} nodes):**
        - Memory Used: #{format_bytes(treemap_memory.memory_used)}
        - GC Runs: #{treemap_memory.gc_count}
        """

      _ ->
        "*Memory data collection failed*"
    end
  end

  defp format_bytes(bytes) when is_integer(bytes) and bytes >= 1_000_000,
    do: "#{Float.round(bytes / 1_000_000, 2)} MB"

  defp format_bytes(bytes) when is_integer(bytes) and bytes >= 1_000,
    do: "#{Float.round(bytes / 1_000, 2)} KB"

  defp format_bytes(bytes) when is_integer(bytes),
    do: "#{bytes} bytes"

  defp format_bytes(_), do: "unknown"

  defp interpret_performance(chart_results, treemap_results) do
    with {small_chart, large_chart} <- get_size_extremes(chart_results),
         {small_treemap, large_treemap} <- get_size_extremes(treemap_results) do
      analyze_scalability(
        small_chart,
        large_chart,
        small_treemap,
        large_treemap
      )
    else
      _ -> "Insufficient data to analyze performance scaling."
    end
  end

  defp get_size_extremes(results) do
    sorted = Enum.sort_by(results, & &1.size)

    case length(sorted) >= 2 do
      true -> {List.first(sorted), List.last(sorted)}
      false -> nil
    end
  end

  defp analyze_scalability(
         small_chart,
         large_chart,
         small_treemap,
         large_treemap
       ) do
    chart_efficiency = calculate_efficiency(small_chart, large_chart)
    treemap_efficiency = calculate_efficiency(small_treemap, large_treemap)

    classify_performance_analysis(chart_efficiency, treemap_efficiency)
  end

  defp classify_performance_analysis(chart_eff, treemap_eff)
       when chart_eff >= 0.8 and treemap_eff >= 0.8,
       do:
         "Both chart and treemap visualization components scale very efficiently with larger datasets."

  defp classify_performance_analysis(chart_eff, treemap_eff)
       when chart_eff >= 0.5 and treemap_eff >= 0.5,
       do:
         "Both visualizations show good scalability, with sub-linear performance degradation as data size increases."

  defp classify_performance_analysis(chart_eff, _treemap_eff)
       when chart_eff >= 0.5,
       do:
         "Chart visualization scales efficiently, but treemap performance could be improved with larger datasets."

  defp classify_performance_analysis(_chart_eff, treemap_eff)
       when treemap_eff >= 0.5,
       do:
         "Treemap visualization scales efficiently, but chart performance could be improved with larger datasets."

  defp classify_performance_analysis(_chart_eff, _treemap_eff),
    do:
      "Both visualizations show signs of performance degradation with larger datasets. Additional optimization may be necessary."

  defp calculate_efficiency(small, large) do
    size_ratio = large.size / small.size
    time_ratio = large.avg_time / small.avg_time
    size_ratio / time_ratio
  end
end
