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
      |> Enum.map_join("\n", fn r ->
        "  - #{r.size} points: #{Float.round(r.avg_time, 2)}ms avg (#{Float.round(r.min_time, 2)}ms min, #{Float.round(r.max_time, 2)}ms max)"
      end)
    end

    # Helper function to summarize treemap results
    summarize_treemap_results = fn results ->
      results
      |> Enum.map_join("\n", fn r ->
        "  - #{r.size} dataset (#{r.node_count} nodes): #{Float.round(r.avg_time, 2)}ms avg (#{Float.round(r.min_time, 2)}ms min, #{Float.round(r.max_time, 2)}ms max)"
      end)
    end

    # Get benchmark configuration
    {datasets, iterations, title, test_size} = get_benchmark_config(args)

    output_dir =
      "test/performance/benchmark_results/visualization/#{Atom.to_string(test_size)}"

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

  defp get_benchmark_config(args) do
    test_size = get_test_size(args)
    config = get_config_for_size(test_size)
    {config.datasets, config.iterations, config.title, test_size}
  end

  defp get_test_size(args) do
    cond do
      "--small" in args -> :small
      "--medium" in args -> :medium
      "--large" in args -> :large
      "--production" in args -> :production
      true -> :small
    end
  end

  defp get_config_for_size(test_size) do
    %{
      small: %{datasets: [10, 50, 100], iterations: 3, title: "Small Test"},
      medium: %{
        datasets: [10, 100, 500, 1000],
        iterations: 5,
        title: "Medium Test"
      },
      large: %{
        datasets: [10, 100, 1000, 5000, 10_000],
        iterations: 3,
        title: "Large Test"
      },
      production: %{
        datasets: [10, 100, 1000, 5000, 10_000, 50_000],
        iterations: 10,
        title: "Production Benchmark"
      }
    }[test_size]
  end
end
