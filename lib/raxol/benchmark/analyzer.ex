defmodule Raxol.Benchmark.Analyzer do
  @moduledoc """
  Analyzes benchmark results for performance insights and regression detection.

  Provides statistical analysis, trend detection, and performance recommendations
  based on benchmark data.
  """

  require Logger

  # 10% slower is considered a regression
  @regression_threshold 1.1
  # 10% faster is considered an improvement
  @improvement_threshold 0.9

  @type analysis_result :: %{
          summary: map(),
          regressions: list(),
          improvements: list(),
          recommendations: list(),
          statistics: map()
        }

  @doc """
  Performs comprehensive analysis on benchmark results.
  """
  @spec analyze(list(map())) :: analysis_result()
  def analyze(results) do
    %{
      summary: generate_summary(results),
      regressions: detect_regressions(results),
      improvements: detect_improvements(results),
      recommendations: generate_recommendations(results),
      statistics: calculate_statistics(results)
    }
  end

  @doc """
  Checks for performance regressions against baseline.
  """
  def check_regressions(results) do
    Enum.flat_map(results, fn suite_result ->
      baseline = load_baseline(suite_result.suite_name)

      if baseline do
        compare_with_baseline(suite_result, baseline)
      else
        Logger.info("No baseline found for #{suite_result.suite_name}")
        []
      end
    end)
  end

  @doc """
  Reports detected regressions with details.
  """
  def report_regressions(regressions) do
    Enum.each(regressions, fn regression ->
      Logger.warning("""
      Performance Regression Detected:
      Suite: #{regression.suite}
      Benchmark: #{regression.benchmark}
      Current: #{format_time(regression.current)}
      Baseline: #{format_time(regression.baseline)}
      Degradation: #{regression.percentage}%
      """)
    end)
  end

  @doc """
  Analyzes profile data for bottlenecks.
  """
  def analyze_profile(name, results) do
    Logger.info("Analyzing profile for #{name}...")

    # Extract timing data
    scenario = results.scenarios |> List.first()

    if scenario do
      %{
        name: name,
        total_time: scenario.run_time_data.statistics.average,
        memory_usage: scenario.memory_usage_data.statistics.average,
        hot_spots: identify_hot_spots(scenario),
        optimization_opportunities: find_optimizations(scenario)
      }
    else
      %{name: name, error: "No scenario data available"}
    end
  end

  @doc """
  Generates performance trends over time.
  """
  def generate_trends(suite_name, days \\ 30) do
    historical_data = load_historical_data(suite_name, days)

    %{
      suite: suite_name,
      period: "#{days} days",
      trends: calculate_trends(historical_data),
      visualization: generate_trend_chart(historical_data)
    }
  end

  @doc """
  Compares performance across different versions.
  """
  def compare_versions(suite_name, version1, version2) do
    data1 = load_version_data(suite_name, version1)
    data2 = load_version_data(suite_name, version2)

    %{
      suite: suite_name,
      versions: {version1, version2},
      comparison: generate_comparison(data1, data2),
      winner: determine_winner(data1, data2)
    }
  end

  # Private functions

  defp compare_with_baseline(suite_result, baseline) do
    Enum.flat_map(suite_result.results.scenarios, fn scenario ->
      baseline_scenario =
        Enum.find(baseline.results.scenarios, fn b ->
          b.name == scenario.name
        end)

      if baseline_scenario do
        current_avg = scenario.run_time_data.statistics.average
        baseline_avg = baseline_scenario.run_time_data.statistics.average

        if current_avg > baseline_avg * 1.1 do
          [
            %{
              suite: suite_result.suite_name,
              benchmark: scenario.name,
              current: current_avg,
              baseline: baseline_avg,
              percentage:
                Float.round(
                  (current_avg - baseline_avg) / baseline_avg * 100,
                  2
                )
            }
          ]
        else
          []
        end
      else
        []
      end
    end)
  end

  defp generate_summary(results) do
    total_benchmarks =
      Enum.reduce(results, 0, fn suite, acc ->
        acc + length(suite.results.scenarios)
      end)

    total_duration =
      Enum.reduce(results, 0, fn suite, acc ->
        acc + suite.duration
      end)

    %{
      total_suites: length(results),
      total_benchmarks: total_benchmarks,
      total_duration_ms: total_duration,
      timestamp: DateTime.utc_now(),
      fastest_operations: find_fastest_operations(results),
      slowest_operations: find_slowest_operations(results)
    }
  end

  defp detect_regressions(results) do
    Enum.flat_map(results, fn suite ->
      baseline = load_baseline(suite.suite_name)

      if baseline do
        suite.results.scenarios
        |> Enum.filter(fn scenario ->
          baseline_time = get_baseline_time(baseline, scenario.name)
          current_time = scenario.run_time_data.statistics.average

          baseline_time && current_time > baseline_time * @regression_threshold
        end)
        |> Enum.map(fn scenario ->
          baseline_time = get_baseline_time(baseline, scenario.name)
          current_time = scenario.run_time_data.statistics.average

          %{
            suite: suite.suite_name,
            benchmark: scenario.name,
            current: current_time,
            baseline: baseline_time,
            percentage: Float.round((current_time / baseline_time - 1) * 100, 2)
          }
        end)
      else
        []
      end
    end)
  end

  defp detect_improvements(results) do
    Enum.flat_map(results, fn suite ->
      baseline = load_baseline(suite.suite_name)

      if baseline do
        suite.results.scenarios
        |> Enum.filter(fn scenario ->
          baseline_time = get_baseline_time(baseline, scenario.name)
          current_time = scenario.run_time_data.statistics.average

          baseline_time && current_time < baseline_time * @improvement_threshold
        end)
        |> Enum.map(fn scenario ->
          baseline_time = get_baseline_time(baseline, scenario.name)
          current_time = scenario.run_time_data.statistics.average

          %{
            suite: suite.suite_name,
            benchmark: scenario.name,
            current: current_time,
            baseline: baseline_time,
            percentage: Float.round((1 - current_time / baseline_time) * 100, 2)
          }
        end)
      else
        []
      end
    end)
  end

  defp generate_recommendations(results) do
    recommendations = []

    # Check for high memory usage
    memory_intensive = find_memory_intensive_operations(results)

    recommendations =
      if length(memory_intensive) > 0 do
        [
          "Consider optimizing memory usage in: #{Enum.join(memory_intensive, ", ")}"
          | recommendations
        ]
      else
        recommendations
      end

    # Check for high variance
    high_variance = find_high_variance_operations(results)

    recommendations =
      if length(high_variance) > 0 do
        [
          "High variance detected in: #{Enum.join(high_variance, ", ")}. Consider investigating stability."
          | recommendations
        ]
      else
        recommendations
      end

    # Check for slow operations
    # 100ms
    slow_ops = find_operations_above_threshold(results, 100_000)

    recommendations =
      if length(slow_ops) > 0 do
        [
          "Operations exceeding 100ms: #{Enum.join(slow_ops, ", ")}. Consider optimization."
          | recommendations
        ]
      else
        recommendations
      end

    recommendations
  end

  defp calculate_statistics(results) do
    all_times =
      Enum.flat_map(results, fn suite ->
        Enum.map(suite.results.scenarios, fn scenario ->
          scenario.run_time_data.statistics.average
        end)
      end)

    %{
      min: Enum.min(all_times, fn -> 0 end),
      max: Enum.max(all_times, fn -> 0 end),
      mean: calculate_mean(all_times),
      median: calculate_median(all_times),
      std_dev: calculate_std_dev(all_times),
      percentiles: calculate_percentiles(all_times)
    }
  end

  defp identify_hot_spots(_scenario) do
    # This would integrate with actual profiling data
    # For now, return placeholder
    []
  end

  defp find_optimizations(scenario) do
    optimizations = []

    # Check memory allocation
    optimizations = if scenario.memory_usage_data.statistics.average > 1_000_000 do
      ["High memory allocation detected" | optimizations]
    else
      optimizations
    end

    # Check execution time
    optimizations = if scenario.run_time_data.statistics.average > 50_000 do
      [
        "Consider breaking into smaller operations" | optimizations
      ]
    else
      optimizations
    end

    optimizations
  end

  defp find_fastest_operations(results, limit \\ 5) do
    results
    |> Enum.flat_map(fn suite ->
      Enum.map(suite.results.scenarios, fn scenario ->
        %{
          suite: suite.suite_name,
          operation: scenario.name,
          time: scenario.run_time_data.statistics.average
        }
      end)
    end)
    |> Enum.sort_by(& &1.time)
    |> Enum.take(limit)
  end

  defp find_slowest_operations(results, limit \\ 5) do
    results
    |> Enum.flat_map(fn suite ->
      Enum.map(suite.results.scenarios, fn scenario ->
        %{
          suite: suite.suite_name,
          operation: scenario.name,
          time: scenario.run_time_data.statistics.average
        }
      end)
    end)
    |> Enum.sort_by(& &1.time, :desc)
    |> Enum.take(limit)
  end

  defp find_memory_intensive_operations(results) do
    results
    |> Enum.flat_map(fn suite ->
      suite.results.scenarios
      |> Enum.filter(fn scenario ->
        # 10MB
        scenario.memory_usage_data.statistics.average > 10_000_000
      end)
      |> Enum.map(& &1.name)
    end)
  end

  defp find_high_variance_operations(results) do
    results
    |> Enum.flat_map(fn suite ->
      suite.results.scenarios
      |> Enum.filter(fn scenario ->
        stats = scenario.run_time_data.statistics
        # 20% variance
        stats.std_dev > stats.average * 0.2
      end)
      |> Enum.map(& &1.name)
    end)
  end

  defp find_operations_above_threshold(results, threshold) do
    results
    |> Enum.flat_map(fn suite ->
      suite.results.scenarios
      |> Enum.filter(fn scenario ->
        scenario.run_time_data.statistics.average > threshold
      end)
      |> Enum.map(& &1.name)
    end)
  end

  defp load_baseline(suite_name) do
    path = "bench/baselines/#{suite_name}.benchee"

    if File.exists?(path) do
      case :erlang.binary_to_term(File.read!(path)) do
        {:ok, data} -> data
        _ -> nil
      end
    else
      nil
    end
  end

  defp get_baseline_time(baseline, benchmark_name) do
    scenario = Enum.find(baseline.scenarios, &(&1.name == benchmark_name))
    scenario && scenario.run_time_data.statistics.average
  end

  defp load_historical_data(_suite_name, _days) do
    # Would load from storage
    []
  end

  defp calculate_trends(_historical_data) do
    # Calculate trend lines
    %{
      direction: :stable,
      change_rate: 0.0
    }
  end

  defp generate_trend_chart(_historical_data) do
    # Would generate actual chart data
    "Chart placeholder"
  end

  defp load_version_data(_suite_name, _version) do
    # Would load version-specific data
    %{}
  end

  defp generate_comparison(_data1, _data2) do
    %{}
  end

  defp determine_winner(_data1, _data2) do
    :tie
  end

  def format_time(nanoseconds) when is_number(nanoseconds) do
    cond do
      nanoseconds < 1_000 ->
        "#{nanoseconds}ns"

      nanoseconds < 1_000_000 ->
        "#{Float.round(nanoseconds / 1_000, 2)}μs"

      nanoseconds < 1_000_000_000 ->
        "#{Float.round(nanoseconds / 1_000_000, 2)}ms"

      true ->
        "#{Float.round(nanoseconds / 1_000_000_000, 2)}s"
    end
  end

  defp calculate_mean([]), do: 0

  defp calculate_mean(values) do
    Enum.sum(values) / length(values)
  end

  defp calculate_median([]), do: 0

  defp calculate_median(values) do
    sorted = Enum.sort(values)
    middle = div(length(sorted), 2)

    if rem(length(sorted), 2) == 0 do
      (Enum.at(sorted, middle - 1) + Enum.at(sorted, middle)) / 2
    else
      Enum.at(sorted, middle)
    end
  end

  defp calculate_std_dev([]), do: 0

  defp calculate_std_dev(values) do
    mean = calculate_mean(values)

    variance =
      Enum.reduce(values, 0, fn x, acc ->
        acc + :math.pow(x - mean, 2)
      end) / length(values)

    :math.sqrt(variance)
  end

  defp calculate_percentiles(values) do
    sorted = Enum.sort(values)

    %{
      p50: percentile(sorted, 0.5),
      p90: percentile(sorted, 0.9),
      p95: percentile(sorted, 0.95),
      p99: percentile(sorted, 0.99)
    }
  end

  defp percentile([], _), do: 0

  defp percentile(sorted_values, p) do
    index = round(p * (length(sorted_values) - 1))
    Enum.at(sorted_values, index, 0)
  end
end
