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
    Mix.Task.run("app.start")

    summarize_chart_results = fn results ->
      results
      |> Enum.map_join("\n", fn r ->
        "  - #{r.size} points: #{Float.round(r.avg_time, 2)}ms avg (#{Float.round(r.min_time, 2)}ms min, #{Float.round(r.max_time, 2)}ms max)"
      end)
    end

    summarize_treemap_results = fn results ->
      results
      |> Enum.map_join("\n", fn r ->
        "  - #{r.size} dataset (#{r.node_count} nodes): #{Float.round(r.avg_time, 2)}ms avg (#{Float.round(r.min_time, 2)}ms min, #{Float.round(r.max_time, 2)}ms max)"
      end)
    end

    {datasets, iterations, title, test_size} = get_benchmark_config(args)

    output_dir =
      "test/performance/benchmark_results/visualization/#{Atom.to_string(test_size)}"

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

    benchmark_opts = [
      output_path: output_dir,
      datasets: datasets,
      iterations: iterations,
      cache_test: true,
      memory_test: true
    ]

    {benchmark_time, results} =
      :timer.tc(fn ->
        VisualizationBenchmark.run_benchmark(benchmark_opts)
      end)

    total_time_s = benchmark_time / 1_000_000

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
    size_mappings = [
      {"--small", :small},
      {"--medium", :medium},
      {"--large", :large},
      {"--production", :production}
    ]

    Enum.find_value(size_mappings, :small, fn {flag, size} ->
      if flag in args, do: size, else: nil
    end)
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
