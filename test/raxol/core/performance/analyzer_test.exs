defmodule Raxol.Core.Performance.AnalyzerTest do
  @moduledoc """
  Tests for the performance analyzer, including performance metrics analysis,
  issue identification, optimization suggestions, performance patterns,
  trends analysis, AI data preparation, and error handling.
  """
  use ExUnit.Case

  alias Raxol.Core.Performance.Analyzer

  describe "Performance Analyzer" do
    test "analyzes good performance metrics" do
      metrics = %{
        fps: 60,
        avg_frame_time: 16.5,
        jank_count: 0,
        memory_usage: 100_000_000,
        gc_stats: %{
          number_of_gcs: 10,
          words_reclaimed: 1000,
          heap_size: 100_000,
          heap_limit: 1_000_000
        }
      }

      analysis = Analyzer.analyze(metrics)

      assert analysis.performance_score >= 90
      assert analysis.issues == []
      assert analysis.suggestions == []
      assert analysis.patterns.fps_stability == "stable"
      assert analysis.patterns.memory_growth == "stable"
      assert analysis.patterns.gc_patterns == "stable"
      assert analysis.patterns.jank_patterns == "none"
    end

    test "identifies performance issues" do
      metrics = %{
        fps: 35,
        avg_frame_time: 28.5,
        jank_count: 5,
        memory_usage: 600_000_000,
        gc_stats: %{
          number_of_gcs: 150,
          words_reclaimed: 5000,
          heap_size: 500_000,
          heap_limit: 1_000_000
        }
      }

      analysis = Analyzer.analyze(metrics)

      assert analysis.performance_score < 70
      assert "Warning: Suboptimal FPS (< 45)" in analysis.issues
      assert "Warning: UI jank detected (5 frames)" in analysis.issues
      assert "Warning: Elevated memory usage (> 500MB)" in analysis.issues
      assert "Warning: Frequent garbage collection" in analysis.issues
    end

    test "generates optimization suggestions" do
      metrics = %{
        fps: 40,
        avg_frame_time: 25.0,
        jank_count: 3,
        memory_usage: 550_000_000,
        gc_stats: %{
          number_of_gcs: 120,
          words_reclaimed: 3000,
          heap_size: 400_000,
          heap_limit: 1_000_000
        }
      }

      analysis = Analyzer.analyze(metrics)

      assert "Review object lifecycle management" in analysis.suggestions
      assert "Optimize component rendering" in analysis.suggestions
      assert "Implement memory pooling" in analysis.suggestions
      assert "Review resource cleanup" in analysis.suggestions
    end

    test "identifies performance patterns" do
      metrics = %{
        fps: 45,
        avg_frame_time: 22.2,
        jank_count: 2,
        memory_usage: 300_000_000,
        gc_stats: %{
          number_of_gcs: 75,
          words_reclaimed: 2000,
          heap_size: 300_000,
          heap_limit: 1_000_000
        }
      }

      analysis = Analyzer.analyze(metrics)

      assert analysis.patterns.fps_stability == "moderate"
      assert analysis.patterns.memory_growth == "stable"
      assert analysis.patterns.gc_patterns == "moderate"
      assert analysis.patterns.jank_patterns == "minor"
    end

    test "analyzes performance trends" do
      metrics = %{
        fps: 55,
        avg_frame_time: 18.2,
        jank_count: 1,
        memory_usage: 200_000_000,
        gc_stats: %{
          number_of_gcs: 25,
          words_reclaimed: 1000,
          heap_size: 200_000,
          heap_limit: 1_000_000
        }
      }

      analysis = Analyzer.analyze(metrics)

      assert analysis.trends.fps_trend == "stable"
      assert analysis.trends.memory_trend == "stable"
      assert analysis.trends.jank_trend == "stable"
    end

    test "prepares data for AI analysis" do
      metrics = %{
        fps: 60,
        avg_frame_time: 16.5,
        jank_count: 0,
        memory_usage: 100_000_000,
        gc_stats: %{
          number_of_gcs: 10,
          words_reclaimed: 1000,
          heap_size: 100_000,
          heap_limit: 1_000_000
        }
      }

      analysis = Analyzer.analyze(metrics)
      ai_data = Analyzer.prepare_ai_data(analysis)

      assert Map.has_key?(ai_data, :metrics)
      assert Map.has_key?(ai_data, :analysis)
      assert Map.has_key?(ai_data, :context)
      assert Map.has_key?(ai_data, :format)
      assert Map.has_key?(ai_data, :version)

      assert Map.has_key?(ai_data.context, :timestamp)
      assert Map.has_key?(ai_data.context, :environment)
      assert Map.has_key?(ai_data.context, :system_info)
    end

    test "handles missing metrics gracefully" do
      metrics = %{
        fps: 60,
        avg_frame_time: 16.5,
        jank_count: 0,
        memory_usage: 100_000_000,
        gc_stats: %{}
      }

      analysis = Analyzer.analyze(metrics)

      assert analysis.performance_score >= 90
      assert analysis.issues == []
      assert analysis.suggestions == []
      assert analysis.patterns.fps_stability == "stable"
      assert analysis.patterns.memory_growth == "stable"
      assert analysis.patterns.gc_patterns == "stable"
      assert analysis.patterns.jank_patterns == "none"
    end
  end
end
