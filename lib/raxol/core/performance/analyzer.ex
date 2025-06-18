defmodule Raxol.Core.Performance.Analyzer do
  @moduledoc '''
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
  '''

  @doc '''
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
        memory_usage: 1234567,
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
  '''
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

  @doc '''
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
  '''
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
      if(metrics.fps < 30, do: 20, else: 0),
      if(metrics.fps < 45, do: 10, else: 0),

      # Jank deductions
      if(metrics.jank_count > 0, do: metrics.jank_count * 5, else: 0),

      # Memory usage deductions
      # 1GB
      if(metrics.memory_usage > 1_000_000_000, do: 15, else: 0),
      # 500MB
      if(metrics.memory_usage > 500_000_000, do: 10, else: 0),

      # GC pressure deductions
      if(Map.get(metrics.gc_stats, :number_of_gcs, 0) > 100, do: 10, else: 0)
    ]

    # Calculate final score
    max(0, base_score - Enum.sum(deductions))
  end

  defp identify_issues(metrics) do
    issues = []

    # Check FPS
    issues =
      if metrics.fps < 45 and metrics.fps >= 30,
        do: ["Warning: Suboptimal FPS (< 45)" | issues],
        else: issues

    issues =
      if metrics.fps < 30,
        do: ["Critical: Low FPS (< 30)" | issues],
        else: issues

    # Check UI jank
    issues =
      if metrics.jank_count > 0 do
        ["Warning: UI jank detected (#{metrics.jank_count} frames)" | issues]
      else
        issues
      end

    # Check memory usage
    issues =
      if metrics.memory_usage > 1_000_000_000 do
        ["Critical: High memory usage (> 1GB)" | issues]
      else
        issues
      end

    issues =
      if metrics.memory_usage > 500_000_000 do
        ["Warning: Elevated memory usage (> 500MB)" | issues]
      else
        issues
      end

    # Check garbage collection
    issues =
      if Map.get(metrics.gc_stats, :number_of_gcs, 0) > 100 do
        ["Warning: Frequent garbage collection" | issues]
      else
        issues
      end

    issues
  end

  defp generate_suggestions(metrics) do
    suggestions = []

    # FPS suggestions
    suggestions =
      if metrics.fps < 30 do
        [
          "Consider using virtual scrolling for large lists",
          "Implement component memoization",
          "Review and optimize expensive computations"
          | suggestions
        ]
      else
        suggestions
      end

    # Memory suggestions
    suggestions =
      if metrics.memory_usage > 500_000_000 do
        [
          "Review memory usage patterns",
          "Implement memory-efficient data structures",
          "Consider implementing pagination"
          | suggestions
        ]
      else
        suggestions
      end

    # GC suggestions
    suggestions =
      if Map.get(metrics.gc_stats, :number_of_gcs, 0) > 100 do
        [
          "Review object lifecycle management",
          "Implement object pooling where appropriate",
          "Consider using WeakMap/WeakSet for caches"
          | suggestions
        ]
      else
        suggestions
      end

    suggestions
  end

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
    cond do
      metrics.fps >= 55 -> "stable"
      metrics.fps >= 45 -> "moderate"
      metrics.fps >= 30 -> "unstable"
      true -> "critical"
    end
  end

  defp analyze_memory_growth(metrics) do
    case metrics.memory_usage do
      usage when usage > 1_000_000_000 -> "exponential"
      usage when usage > 500_000_000 -> "linear"
      _ -> "stable"
    end
  end

  defp analyze_gc_patterns(metrics) do
    gc_count = Map.get(metrics.gc_stats, :number_of_gcs, 0)

    cond do
      gc_count > 100 -> "frequent"
      gc_count > 50 -> "moderate"
      true -> "stable"
    end
  end

  defp analyze_jank_patterns(metrics) do
    cond do
      metrics.jank_count > 10 -> "severe"
      metrics.jank_count > 5 -> "moderate"
      metrics.jank_count > 0 -> "minor"
      true -> "none"
    end
  end

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
