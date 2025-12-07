Mix.install([{:jason, "~> 1.4"}])

defmodule PerformanceRegressionAnalyzer do
  @moduledoc """
  Performance regression analysis for CI/CD pipeline.
  Compares current benchmark results against baseline to detect regressions.
  """

  def analyze do
    current_parser = load_benchmark("regression/performance/current/parser.json")
    current_buffer = load_benchmark("regression/performance/current/buffer.json")
    current_cursor = load_benchmark("regression/performance/current/cursor.json")

    baseline_parser = load_benchmark("regression/performance/baselines/parser.json")
    baseline_buffer = load_benchmark("regression/performance/baselines/buffer.json")
    baseline_cursor = load_benchmark("regression/performance/baselines/cursor.json")

    results = %{
      parser: compare_benchmarks(baseline_parser, current_parser, "Parser"),
      buffer: compare_benchmarks(baseline_buffer, current_buffer, "Buffer"),
      cursor: compare_benchmarks(baseline_cursor, current_cursor, "Cursor")
    }

    generate_report(results)

    # Exit with error if significant regressions found
    if has_regressions?(results) do
      System.halt(1)
    end
  end

  defp load_benchmark(path) do
    case File.read(path) do
      {:ok, content} -> Jason.decode!(content)
      {:error, _} -> %{}
    end
  end

  defp compare_benchmarks(baseline, _current, module_name) when baseline == %{} do
    IO.puts("[WARN] No baseline data for #{module_name}, skipping comparison")
    %{status: :no_baseline, regressions: [], improvements: []}
  end

  defp compare_benchmarks(baseline, current, module_name) do
    IO.puts("[ANALYSIS] Analyzing #{module_name} performance...")

    regressions = []
    improvements = []

    # Compare key metrics
    parser_time_regression = compare_metric(
      get_in(baseline, ["statistics", "average"]),
      get_in(current, ["statistics", "average"]),
      "average_time"
    )

    parser_memory_regression = compare_metric(
      get_in(baseline, ["statistics", "memory"]) || 0,
      get_in(current, ["statistics", "memory"]) || 0,
      "memory_usage"
    )

    regressions = if parser_time_regression.regression?,
      do: [parser_time_regression | regressions], else: regressions
    improvements = if parser_time_regression.improvement?,
      do: [parser_time_regression | improvements], else: improvements

    regressions = if parser_memory_regression.regression?,
      do: [parser_memory_regression | regressions], else: regressions
    improvements = if parser_memory_regression.improvement?,
      do: [parser_memory_regression | improvements], else: improvements

    %{
      status: if(length(regressions) > 0, do: :regressions, else: :ok),
      regressions: regressions,
      improvements: improvements
    }
  end

  defp compare_metric(baseline, current, metric_name) do
    if baseline && current do
      change_ratio = (current - baseline) / baseline
      change_percent = change_ratio * 100

      cond do
        change_ratio > 0.05 ->  # >5% slower is regression
          %{
            regression?: true,
            improvement?: false,
            metric: metric_name,
            baseline: baseline,
            current: current,
            change_percent: change_percent
          }
        change_ratio < -0.05 ->  # >5% faster is improvement
          %{
            regression?: false,
            improvement?: true,
            metric: metric_name,
            baseline: baseline,
            current: current,
            change_percent: change_percent
          }
        true ->  # Within 5% tolerance
          %{
            regression?: false,
            improvement?: false,
            metric: metric_name,
            baseline: baseline,
            current: current,
            change_percent: change_percent
          }
      end
    else
      %{
        regression?: false,
        improvement?: false,
        metric: metric_name,
        baseline: baseline,
        current: current,
        change_percent: 0
      }
    end
  end

  defp generate_report(results) do
    IO.puts("\n[REPORT] Performance Regression Report")
    IO.puts("================================")

    total_regressions = count_total(results, :regressions)
    total_improvements = count_total(results, :improvements)

    IO.puts("Summary:")
    IO.puts("  [REGR] Regressions: #{total_regressions}")
    IO.puts("  [IMPR] Improvements: #{total_improvements}")

    for {module, result} <- results do
      IO.puts("\n#{String.capitalize(Atom.to_string(module))} Module:")

      case result.regressions do
        [] -> IO.puts("  [OK] No regressions detected")
        regressions ->
          IO.puts("  [REGR] #{length(regressions)} regression(s):")
          for reg <- regressions do
            IO.puts("    - #{reg.metric}: #{Float.round(reg.change_percent, 2)}% slower")
          end
      end

      case result.improvements do
        [] -> nil
        improvements ->
          IO.puts("  [IMPR] #{length(improvements)} improvement(s):")
          for imp <- improvements do
            IO.puts("    - #{imp.metric}: #{abs(Float.round(imp.change_percent, 2))}% faster")
          end
      end
    end

    # Save detailed report
    report_content = Jason.encode!(%{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      summary: %{
        total_regressions: total_regressions,
        total_improvements: total_improvements
      },
      modules: results
    }, pretty: true)

    File.mkdir_p!("regression/performance/reports")
    File.write!("regression/performance/reports/regression_report.json", report_content)
    IO.puts("\nDetailed report saved to regression/performance/reports/regression_report.json")
  end

  defp count_total(results, key) do
    results
    |> Enum.map(fn {_, result} -> length(result[key]) end)
    |> Enum.sum()
  end

  defp has_regressions?(results) do
    count_total(results, :regressions) > 0
  end
end

PerformanceRegressionAnalyzer.analyze()