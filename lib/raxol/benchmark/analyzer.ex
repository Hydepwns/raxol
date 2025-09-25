defmodule Raxol.Benchmark.Analyzer do
  @moduledoc """
  Legacy analyzer module for backward compatibility.
  Delegates to the new modular benchmark analysis system.
  """

  alias Raxol.Benchmark.StatisticalAnalyzer
  alias Raxol.Benchmark.RegressionDetector

  @doc """
  Analyze benchmark results.
  Delegates to StatisticalAnalyzer for detailed analysis.
  """
  def analyze(results) do
    # Transform the results to match expected format
    case results do
      [%{results: %{scenarios: scenarios}} | _] ->
        # Extract timing data from scenarios in the nested results structure
        timing_data = extract_timing_data(scenarios)
        analyze_timing_data(timing_data)

      [%{scenarios: scenarios} | _] ->
        # Direct scenarios structure
        timing_data = extract_timing_data(scenarios)
        analyze_timing_data(timing_data)

      _ when is_list(results) and length(results) > 0 ->
        # Check if it's a list of numbers
        if Enum.all?(results, &is_number/1) do
          analysis = StatisticalAnalyzer.analyze(results)

          %{
            summary: generate_summary(analysis),
            statistics: analysis,
            recommendations: generate_recommendations(analysis)
          }
        else
          # Unknown format, return default
          %{
            summary: %{
              total_operations: 0,
              average_time: 0,
              fastest_time: 0,
              slowest_time: 0,
              std_deviation: 0
            },
            statistics: %{count: 0, mean: 0, std_dev: 0},
            recommendations: []
          }
        end

      _ ->
        # Fallback for unknown data format
        %{
          summary: %{
            total_operations: 0,
            average_time: 0,
            fastest_time: 0,
            slowest_time: 0,
            std_deviation: 0
          },
          statistics: %{count: 0, mean: 0, std_dev: 0},
          recommendations: []
        }
    end
  end

  @doc """
  Check for performance regressions.
  """
  def check_regressions(results, baseline \\ nil) do
    case baseline do
      nil ->
        []

      baseline_results ->
        detector_result = RegressionDetector.detect(results, baseline_results)
        detector_result.regressions
    end
  end

  @doc """
  Format time values for human-readable output.
  """
  def format_time(ns) when is_number(ns) do
    cond do
      ns < 1_000 ->
        "#{Float.round(ns, 2)}ns"

      ns < 1_000_000 ->
        "#{Float.round(ns / 1_000, 2)}μs"

      ns < 1_000_000_000 ->
        "#{Float.round(ns / 1_000_000, 2)}ms"

      true ->
        "#{Float.round(ns / 1_000_000_000, 2)}s"
    end
  end

  def format_time(_), do: "N/A"

  # Private helper functions

  defp analyze_timing_data(timing_data) do
    if Enum.empty?(timing_data) do
      # Fallback to default analysis if no timing data found
      %{
        summary: %{
          total_operations: 0,
          average_time: 0,
          fastest_time: 0,
          slowest_time: 0,
          std_deviation: 0
        },
        statistics: %{count: 0, mean: 0, std_dev: 0},
        recommendations: []
      }
    else
      analysis = StatisticalAnalyzer.analyze(timing_data)

      %{
        summary: generate_summary(analysis),
        statistics: analysis,
        recommendations: generate_recommendations(analysis)
      }
    end
  end

  defp extract_timing_data(scenarios) when is_list(scenarios) do
    scenarios
    |> Enum.flat_map(fn scenario ->
      case scenario do
        %{run_time_data: %{statistics: %{average: avg}}} when is_number(avg) ->
          [avg]

        %{run_time_data: %{statistics: stats}} ->
          # Extract available timing values
          [
            Map.get(stats, :average, 0),
            Map.get(stats, :minimum, 0),
            Map.get(stats, :maximum, 0)
          ]
          |> Enum.filter(&is_number/1)

        _ ->
          []
      end
    end)
    |> Enum.filter(&(&1 > 0))
  end

  defp extract_timing_data(_), do: []

  defp generate_summary(analysis) when is_map(analysis) do
    %{
      total_operations: Map.get(analysis, :count, 0),
      average_time: Map.get(analysis, :mean, 0),
      fastest_time: Map.get(analysis, :min, 0),
      slowest_time: Map.get(analysis, :max, 0),
      std_deviation: Map.get(analysis, :std_dev, 0)
    }
  end

  defp generate_recommendations(analysis) when is_map(analysis) do
    recommendations = []

    cv = Map.get(analysis, :coefficient_of_variation, 0)
    std_dev = Map.get(analysis, :std_dev, 0)
    mean = Map.get(analysis, :mean, 1)

    recommendations =
      if cv > 0.2 do
        [
          "High variability detected. Consider running more iterations for stable results."
          | recommendations
        ]
      else
        recommendations
      end

    recommendations =
      if std_dev > mean * 0.5 do
        [
          "Large standard deviation indicates inconsistent performance."
          | recommendations
        ]
      else
        recommendations
      end

    Enum.reverse(recommendations)
  end

  @doc """
  Analyze profile results.
  """
  def analyze_profile(name, _results) do
    # Simple profile analysis for now
    IO.puts("Profile analysis for #{name}:")
    # Results are available for further processing if needed
    :ok
  end

  @doc """
  Report regressions found in benchmark results.
  """
  def report_regressions(regressions) when is_list(regressions) do
    if Enum.empty?(regressions) do
      IO.puts("No performance regressions detected.")
    else
      IO.puts("Performance regressions detected:")

      Enum.each(regressions, fn regression ->
        IO.puts("  - #{inspect(regression)}")
      end)
    end

    :ok
  end
end
