defmodule Mix.Tasks.Benchmark.Visualization do
  @moduledoc """
  Runs visualization performance benchmarks.

  ## Usage

      $ mix benchmark.visualization [--small|--medium|--large|--production]

  ## Options

      * `--small` - Run a small benchmark with fewer data points (default)
      * `--medium` - Run a medium-sized benchmark
      * `--large` - Run a large benchmark with more data points
      * `--production` - Run a comprehensive benchmark for production analysis
  """

  use Mix.Task
  alias Raxol.Benchmarks.VisualizationBenchmark

  @impl Mix.Task
  def run(args) do
    # Start the application to ensure all modules are loaded
    Mix.Task.run("app.start")

    # Helper function to summarize chart results
    summarize_chart_results = fn results ->
      results
      |> Enum.map(fn r ->
        "  - #{r.size} points: #{Float.round(r.avg_time, 2)}ms avg (#{Float.round(r.min_time, 2)}ms min, #{Float.round(r.max_time, 2)}ms max)"
      end)
      |> Enum.join("\n")
    end

    # Helper function to summarize treemap results
    summarize_treemap_results = fn results ->
      results
      |> Enum.map(fn r ->
        "  - #{r.size} dataset (#{r.node_count} nodes): #{Float.round(r.avg_time, 2)}ms avg (#{Float.round(r.min_time, 2)}ms min, #{Float.round(r.max_time, 2)}ms max)"
      end)
      |> Enum.join("\n")
    end

    # Determine test size based on args
    test_size =
      cond do
        "--small" in args -> :small
        "--medium" in args -> :medium
        "--large" in args -> :large
        "--production" in args -> :production
        # Default to small
        true -> :small
      end

    # Configure dataset sizes and iterations based on test size
    {datasets, iterations, title} =
      case test_size do
        :small ->
          {[10, 50, 100], 3, "Small Test"}

        :medium ->
          {[10, 100, 500, 1000], 5, "Medium Test"}

        :large ->
          {[10, 100, 1000, 5000, 10000], 3, "Large Test"}

        :production ->
          {[10, 100, 1000, 5000, 10000, 50000], 10, "Production Benchmark"}
      end

    # Set output directory
    output_dir = "benchmark_results/visualization/#{Atom.to_string(test_size)}"

    # Print header
    IO.puts("""
    =================================================
    Raxol Visualization Performance Benchmark
    #{title}
    =================================================

    Starting benchmark with:
      Dataset sizes: #{inspect(datasets)}
      Iterations: #{iterations}
      Output: #{output_dir}
    """)

    # Run benchmark
    benchmark_opts = [
      output_path: output_dir,
      datasets: datasets,
      iterations: iterations,
      cache_test: true,
      memory_test: true
    ]

    # Time the entire benchmark
    {benchmark_time, results} =
      :timer.tc(fn ->
        VisualizationBenchmark.run_benchmark(benchmark_opts)
      end)

    # Convert to seconds
    total_time_s = benchmark_time / 1_000_000

    # Print summary
    IO.puts("""
    =================================================
    Benchmark Completed in #{Float.round(total_time_s, 2)} seconds
    =================================================

    Results written to: #{results.output_file}

    Chart Results Summary:
    #{summarize_chart_results.(results.chart_results)}

    TreeMap Results Summary:
    #{summarize_treemap_results.(results.treemap_results)}

    To view full results, open:
    #{Path.expand(results.output_file)}
    """)
  end
end
