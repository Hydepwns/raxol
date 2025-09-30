defmodule MemoryRegressionAnalyzer do
  @moduledoc """
  Memory regression analysis for CI/CD pipeline.
  Compares current memory usage against baseline to detect regressions.
  """

  @memory_threshold_percent 10  # 10% memory increase is a regression
  @memory_threshold_absolute 50_000_000  # 50MB absolute increase is always a regression

  def analyze(scenario) do
    current_analysis = load_analysis("regression/memory/current/#{scenario}_analysis.json")
    current_benchmark = load_benchmark("regression/memory/current/#{scenario}_memory.json")

    baseline_analysis = load_analysis("regression/memory/baselines/#{scenario}_analysis.json")
    baseline_benchmark = load_benchmark("regression/memory/baselines/#{scenario}_memory.json")

    results = %{
      scenario: scenario,
      analysis_comparison: compare_analysis(baseline_analysis, current_analysis),
      benchmark_comparison: compare_benchmark(baseline_benchmark, current_benchmark),
      memory_gates: check_memory_gates(current_analysis, current_benchmark),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    generate_report(results)

    # Exit with error if regressions found
    if has_memory_regressions?(results) do
      IO.puts("Memory regressions detected! Failing CI.")
      System.halt(1)
    end
  end

  defp load_analysis(path) do
    case File.read(path) do
      {:ok, content} -> Jason.decode!(content)
      {:error, _} -> %{}
    end
  end

  defp load_benchmark(path) do
    case File.read(path) do
      {:ok, content} -> Jason.decode!(content)
      {:error, _} -> %{}
    end
  end

  defp compare_analysis(baseline, current) when baseline == %{} do
    %{status: :no_baseline, regressions: [], improvements: []}
  end

  defp compare_analysis(baseline, current) do
    regressions = []
    improvements = []

    # Compare peak memory usage
    peak_regression = compare_memory_metric(
      get_in(baseline, ["memory_patterns", "peak_usage"]),
      get_in(current, ["memory_patterns", "peak_usage"]),
      "peak_memory_usage"
    )

    # Compare sustained memory usage
    sustained_regression = compare_memory_metric(
      get_in(baseline, ["memory_patterns", "sustained_usage"]),
      get_in(current, ["memory_patterns", "sustained_usage"]),
      "sustained_memory_usage"
    )

    # Compare GC pressure
    gc_regression = compare_memory_metric(
      get_in(baseline, ["gc_analysis", "pressure_score"]),
      get_in(current, ["gc_analysis", "pressure_score"]),
      "gc_pressure"
    )

    regressions = collect_regressions([peak_regression, sustained_regression, gc_regression], regressions)
    improvements = collect_improvements([peak_regression, sustained_regression, gc_regression], improvements)

    %{
      status: if(length(regressions) > 0, do: :regressions, else: :ok),
      regressions: regressions,
      improvements: improvements
    }
  end

  defp compare_benchmark(baseline, current) when baseline == %{} do
    %{status: :no_baseline, regressions: [], improvements: []}
  end

  defp compare_benchmark(baseline, current) do
    regressions = []
    improvements = []

    # Compare memory usage from benchmarks
    memory_regression = compare_memory_metric(
      get_in(baseline, ["statistics", "memory"]),
      get_in(current, ["statistics", "memory"]),
      "benchmark_memory_usage"
    )

    regressions = collect_regressions([memory_regression], regressions)
    improvements = collect_improvements([memory_regression], improvements)

    %{
      status: if(length(regressions) > 0, do: :regressions, else: :ok),
      regressions: regressions,
      improvements: improvements
    }
  end

  defp compare_memory_metric(baseline, current, metric_name) do
    if baseline && current do
      change_absolute = current - baseline
      change_ratio = change_absolute / baseline
      change_percent = change_ratio * 100

      cond do
        change_absolute > @memory_threshold_absolute ->
          %{
            regression?: true,
            improvement?: false,
            severity: :critical,
            metric: metric_name,
            baseline: baseline,
            current: current,
            change_percent: change_percent,
            change_absolute: change_absolute
          }
        change_ratio > (@memory_threshold_percent / 100) ->
          %{
            regression?: true,
            improvement?: false,
            severity: :warning,
            metric: metric_name,
            baseline: baseline,
            current: current,
            change_percent: change_percent,
            change_absolute: change_absolute
          }
        change_ratio < -(@memory_threshold_percent / 100) ->
          %{
            regression?: false,
            improvement?: true,
            metric: metric_name,
            baseline: baseline,
            current: current,
            change_percent: change_percent,
            change_absolute: change_absolute
          }
        true ->
          %{
            regression?: false,
            improvement?: false,
            metric: metric_name,
            baseline: baseline,
            current: current,
            change_percent: change_percent,
            change_absolute: change_absolute
          }
      end
    else
      %{
        regression?: false,
        improvement?: false,
        metric: metric_name,
        baseline: baseline,
        current: current,
        change_percent: 0,
        change_absolute: 0
      }
    end
  end

  defp check_memory_gates(analysis, benchmark) do
    gates = []

    # Gate 1: Peak memory should not exceed 3MB per session
    peak_memory = get_in(analysis, ["memory_patterns", "peak_usage"]) || 0
    gates = if peak_memory > 3_000_000 do
      [%{gate: "peak_memory_limit", status: :failed, value: peak_memory, limit: 3_000_000} | gates]
    else
      [%{gate: "peak_memory_limit", status: :passed, value: peak_memory, limit: 3_000_000} | gates]
    end

    # Gate 2: Sustained memory should not exceed 2.5MB
    sustained_memory = get_in(analysis, ["memory_patterns", "sustained_usage"]) || 0
    gates = if sustained_memory > 2_500_000 do
      [%{gate: "sustained_memory_limit", status: :failed, value: sustained_memory, limit: 2_500_000} | gates]
    else
      [%{gate: "sustained_memory_limit", status: :passed, value: sustained_memory, limit: 2_500_000} | gates]
    end

    # Gate 3: GC pressure should be reasonable
    gc_pressure = get_in(analysis, ["gc_analysis", "pressure_score"]) || 0
    gates = if gc_pressure > 0.8 do
      [%{gate: "gc_pressure_limit", status: :failed, value: gc_pressure, limit: 0.8} | gates]
    else
      [%{gate: "gc_pressure_limit", status: :passed, value: gc_pressure, limit: 0.8} | gates]
    end

    gates
  end

  defp collect_regressions(comparisons, acc) do
    comparisons
    |> Enum.filter(fn comp -> comp && comp.regression? end)
    |> Enum.concat(acc)
  end

  defp collect_improvements(comparisons, acc) do
    comparisons
    |> Enum.filter(fn comp -> comp && comp.improvement? end)
    |> Enum.concat(acc)
  end

  defp generate_report(results) do
    IO.puts("\n[REPORT] Memory Regression Report - #{results.scenario}")
    IO.puts("=================================================")

    # Performance gates
    IO.puts("\nMemory Performance Gates:")
    for gate <- results.memory_gates do
      status_icon = if gate.status == :passed, do: "[PASS]", else: "[FAIL]"
      IO.puts("  #{status_icon} #{gate.gate}: #{format_bytes(gate.value)} (limit: #{format_bytes(gate.limit)})")
    end

    # Analysis comparison
    analysis_regressions = length(results.analysis_comparison.regressions)
    analysis_improvements = length(results.analysis_comparison.improvements)

    IO.puts("\n[ANALYSIS] Analysis Comparison:")
    IO.puts("  Regressions: #{analysis_regressions}")
    IO.puts("  Improvements: #{analysis_improvements}")

    for reg <- results.analysis_comparison.regressions do
      severity_icon = if reg.severity == :critical, do: "[CRITICAL]", else: "[WARN]"
      IO.puts("    #{severity_icon} #{reg.metric}: +#{format_bytes(reg.change_absolute)} (+#{Float.round(reg.change_percent, 2)}%)")
    end

    for imp <- results.analysis_comparison.improvements do
      IO.puts("    [IMPR] #{imp.metric}: -#{format_bytes(abs(imp.change_absolute))} (#{abs(Float.round(imp.change_percent, 2))}% improvement)")
    end

    # Benchmark comparison
    benchmark_regressions = length(results.benchmark_comparison.regressions)
    benchmark_improvements = length(results.benchmark_comparison.improvements)

    IO.puts("\nBenchmark Comparison:")
    IO.puts("  Regressions: #{benchmark_regressions}")
    IO.puts("  Improvements: #{benchmark_improvements}")

    for reg <- results.benchmark_comparison.regressions do
      severity_icon = if reg.severity == :critical, do: "[CRITICAL]", else: "[WARN]"
      IO.puts("    #{severity_icon} #{reg.metric}: +#{format_bytes(reg.change_absolute)} (+#{Float.round(reg.change_percent, 2)}%)")
    end

    for imp <- results.benchmark_comparison.improvements do
      IO.puts("    [IMPR] #{imp.metric}: -#{format_bytes(abs(imp.change_absolute))} (#{abs(Float.round(imp.change_percent, 2))}% improvement)")
    end

    # Save detailed report
    report_content = Jason.encode!(results, pretty: true)
    File.mkdir_p!("regression/memory/reports")
    File.write!("regression/memory/reports/#{results.scenario}_regression_report.json", report_content)
    IO.puts("\nDetailed report saved to regression/memory/reports/#{results.scenario}_regression_report.json")
  end

  defp format_bytes(bytes) when is_number(bytes) do
    cond do
      bytes >= 1_000_000_000 -> "#{Float.round(bytes / 1_000_000_000, 2)}GB"
      bytes >= 1_000_000 -> "#{Float.round(bytes / 1_000_000, 2)}MB"
      bytes >= 1_000 -> "#{Float.round(bytes / 1_000, 2)}KB"
      true -> "#{bytes}B"
    end
  end

  defp format_bytes(_), do: "N/A"

  defp has_memory_regressions?(results) do
    analysis_regressions = length(results.analysis_comparison.regressions)
    benchmark_regressions = length(results.benchmark_comparison.regressions)
    failed_gates = results.memory_gates |> Enum.count(fn gate -> gate.status == :failed end)

    analysis_regressions > 0 || benchmark_regressions > 0 || failed_gates > 0
  end
end

# Get scenario from command line args
scenario = System.argv() |> List.first() || "terminal_operations"
MemoryRegressionAnalyzer.analyze(scenario)