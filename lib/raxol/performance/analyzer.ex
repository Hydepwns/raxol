defmodule Raxol.Performance.Analyzer do
  @moduledoc """
  Analyzes performance metrics and generates insights for AI analysis.

  This module:
  - Processes performance metrics
  - Identifies performance patterns
  - Generates optimization suggestions
  - Formats data for AI analysis

  ## Usage

  ```elixir
  # Get metrics from monitor
  metrics = Monitor.get_metrics(monitor)

  # Analyze metrics
  analysis = Analyzer.analyze(metrics)

  # Get AI-ready data
  ai_data = Analyzer.prepare_ai_data(analysis)
  ```
  """

  @doc """
  Analyzes performance metrics and generates insights.

  ## Parameters

  * `metrics` - Map of performance metrics from Monitor

  ## Returns

  Map containing analysis results:
  * `:performance_score` - Overall performance score (0-100)
  * `:issues` - List of identified performance issues
  * `:suggestions` - List of optimization suggestions
  * `:patterns` - Identified performance patterns
  * `:trends` - Performance trends over time

  ## Examples

      iex> metrics = %{
        fps: 60,
        avg_frame_time: 16.5,
        jank_count: 2,
        memory_usage: 1_234_567,
        gc_stats: %{...}
      }
      iex> Analyzer.analyze(metrics)
      %{
        performance_score: 85,
        issues: ["High memory usage", "Occasional jank"],
        suggestions: ["Optimize memory allocation", "Profile render loop"],
        patterns: %{...},
        trends: %{...}
      }
  """
  def analyze(metrics) do
    %{
      metrics: metrics,
      performance_score: calculate_performance_score(metrics),
      issues: identify_issues(metrics),
      suggestions: generate_suggestions(metrics),
      patterns: identify_patterns(metrics),
      trends: analyze_trends(metrics)
    }
  end

  @doc """
  Prepares performance data for AI analysis.

  ## Parameters

  * `analysis` - Analysis results from analyze/1

  ## Returns

  Map containing AI-ready data:
  * `:metrics` - Raw performance metrics
  * `:analysis` - Analysis results
  * `:context` - Additional context for AI
  * `:format` - Data format specification

  ## Examples

      iex> metrics = %{fps: 60, ...}
      iex> analysis = Analyzer.analyze(metrics)
      iex> ai_data = Analyzer.prepare_ai_data(analysis)
      iex> Map.has_key?(ai_data, :metrics)
      true
  """
  def prepare_ai_data(analysis) do
    %{
      metrics: analysis.metrics,
      analysis: analysis,
      context: %{
        timestamp: System.system_time(:second),
        environment: get_environment_info(),
        system_info: get_system_info()
      },
      format: "json",
      version: "1.0"
    }
  end

  # Private Helpers

  defp calculate_performance_score(metrics) do
    # Base score starts at 100
    base_score = 100

    # Deduct points for issues
    deductions = [
      # FPS deductions
      fps_deduction_severe(metrics.fps),
      fps_deduction_moderate(metrics.fps),

      # Jank deductions
      jank_deduction(metrics.jank_count),

      # Memory usage deductions
      memory_deduction_severe(metrics.memory_usage),
      memory_deduction_moderate(metrics.memory_usage),

      # GC pressure deductions
      gc_deduction(Map.get(metrics.gc_stats, :number_of_gcs, 0))
    ]

    # Calculate final score
    max(0, base_score - Enum.sum(deductions))
  end

  defp fps_deduction_severe(fps) when fps < 30, do: 20
  defp fps_deduction_severe(_fps), do: 0

  defp fps_deduction_moderate(fps) when fps < 45, do: 10
  defp fps_deduction_moderate(_fps), do: 0

  defp jank_deduction(0), do: 0
  defp jank_deduction(count), do: count * 5

  defp memory_deduction_severe(usage) when usage > 1_000_000_000, do: 15
  defp memory_deduction_severe(_usage), do: 0

  defp memory_deduction_moderate(usage) when usage > 500_000_000, do: 10
  defp memory_deduction_moderate(_usage), do: 0

  defp gc_deduction(count) when count > 100, do: 10
  defp gc_deduction(_count), do: 0

  defp identify_issues(metrics) do
    []
    |> add_fps_issues(metrics.fps)
    |> add_jank_issues(metrics.jank_count)
    |> add_memory_issues(metrics.memory_usage)
    |> add_gc_issues(Map.get(metrics.gc_stats, :number_of_gcs, 0))
  end

  defp add_fps_issues(issues, fps) when fps < 30 do
    ["Critical: Low FPS (< 30)" | issues]
  end

  defp add_fps_issues(issues, fps) when fps < 45 do
    ["Warning: Suboptimal FPS (< 45)" | issues]
  end

  defp add_fps_issues(issues, _fps), do: issues

  defp add_jank_issues(issues, 0), do: issues

  defp add_jank_issues(issues, jank_count) do
    ["Warning: UI jank detected (#{jank_count} frames)" | issues]
  end

  defp add_memory_issues(issues, usage) when usage > 1_000_000_000 do
    ["Critical: High memory usage (> 1GB)" | issues]
  end

  defp add_memory_issues(issues, usage) when usage > 500_000_000 do
    ["Warning: Elevated memory usage (> 500MB)" | issues]
  end

  defp add_memory_issues(issues, _usage), do: issues

  defp add_gc_issues(issues, count) when count > 100 do
    ["Warning: Frequent garbage collection" | issues]
  end

  defp add_gc_issues(issues, _count), do: issues

  defp generate_suggestions(metrics) do
    []
    |> add_fps_suggestions(metrics.fps)
    |> add_memory_suggestions(metrics.memory_usage)
    |> add_gc_suggestions(Map.get(metrics.gc_stats, :number_of_gcs, 0))
  end

  defp add_fps_suggestions(suggestions, fps) when fps < 30 do
    [
      "Consider using virtual scrolling for large lists",
      "Implement component memoization",
      "Review and optimize expensive computations"
      | suggestions
    ]
  end

  defp add_fps_suggestions(suggestions, _fps), do: suggestions

  defp add_memory_suggestions(suggestions, usage) when usage > 500_000_000 do
    [
      "Review memory usage patterns",
      "Implement memory-efficient data structures",
      "Consider implementing pagination"
      | suggestions
    ]
  end

  defp add_memory_suggestions(suggestions, _usage), do: suggestions

  defp add_gc_suggestions(suggestions, count) when count > 100 do
    [
      "Review object lifecycle management",
      "Implement object pooling where appropriate",
      "Consider using WeakMap/WeakSet for caches"
      | suggestions
    ]
  end

  defp add_gc_suggestions(suggestions, _count), do: suggestions

  defp identify_patterns(metrics) do
    %{
      fps_stability: analyze_fps_stability(metrics),
      memory_growth: analyze_memory_growth(metrics),
      gc_patterns: analyze_gc_patterns(metrics),
      jank_patterns: analyze_jank_patterns(metrics)
    }
  end

  defp analyze_trends(_metrics) do
    %{fps_trend: "stable", memory_trend: "stable", jank_trend: "stable"}
  end

  defp analyze_fps_stability(metrics) do
    classify_fps_stability(metrics.fps)
  end

  defp classify_fps_stability(fps) when fps >= 55, do: "stable"
  defp classify_fps_stability(fps) when fps >= 45, do: "moderate"
  defp classify_fps_stability(fps) when fps >= 30, do: "unstable"
  defp classify_fps_stability(_fps), do: "critical"

  defp analyze_memory_growth(metrics) do
    case metrics.memory_usage do
      usage when usage > 1_000_000_000 -> "exponential"
      usage when usage > 500_000_000 -> "linear"
      _ -> "stable"
    end
  end

  defp analyze_gc_patterns(metrics) do
    gc_count = Map.get(metrics.gc_stats, :number_of_gcs, 0)
    classify_gc_pattern(gc_count)
  end

  defp classify_gc_pattern(count) when count > 100, do: "frequent"
  defp classify_gc_pattern(count) when count > 50, do: "moderate"
  defp classify_gc_pattern(_count), do: "stable"

  defp analyze_jank_patterns(metrics) do
    classify_jank_pattern(metrics.jank_count)
  end

  defp classify_jank_pattern(count) when count > 10, do: "severe"
  defp classify_jank_pattern(count) when count > 5, do: "moderate"
  defp classify_jank_pattern(count) when count > 0, do: "minor"
  defp classify_jank_pattern(_count), do: "none"

  defp get_environment_info do
    %{
      node: :erlang.node(),
      system: :os.type(),
      version: System.version(),
      architecture: :erlang.system_info(:system_architecture)
    }
  end

  defp get_system_info do
    %{
      memory_total: :erlang.memory(:total),
      memory_system: :erlang.memory(:system),
      process_count: :erlang.system_info(:process_count),
      port_count: :erlang.system_info(:port_count)
    }
  end
end
