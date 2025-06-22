defmodule Raxol.Core.Performance.AIAnalyzerTest do
  @moduledoc """
  Tests for the AI analyzer, including performance metrics analysis,
  report generation, and error handling.
  """
  use ExUnit.Case
  import Raxol.Guards

  alias Raxol.Core.Performance.AIAnalyzer

  describe "AI Analyzer" do
    test ~c"analyzes performance metrics" do
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

      analysis = AIAnalyzer.analyze(metrics)

      assert Map.has_key?(analysis, :insights)
      assert Map.has_key?(analysis, :recommendations)
      assert Map.has_key?(analysis, :risk_assessment)
      assert Map.has_key?(analysis, :optimization_impact)
      assert Map.has_key?(analysis, :ai_confidence)

      assert list?(analysis.insights)
      assert list?(analysis.recommendations)
      assert map?(analysis.risk_assessment)
      assert map?(analysis.optimization_impact)
      assert float?(analysis.ai_confidence)
    end

    test ~c"generates text report" do
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

      report = AIAnalyzer.generate_report(metrics, %{format: :text})

      assert Map.has_key?(report, :report)
      assert Map.has_key?(report, :analysis)
      assert Map.has_key?(report, :metadata)

      assert binary?(report.report)
      assert String.contains?(report.report, "Performance Analysis Report")
      assert String.contains?(report.report, "Key Insights")
      assert String.contains?(report.report, "Recommendations")
      assert String.contains?(report.report, "Risk Assessment")
      assert String.contains?(report.report, "Expected Impact")
    end

    test ~c"generates JSON report" do
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

      report = AIAnalyzer.generate_report(metrics, %{format: :json})

      assert Map.has_key?(report, :report)
      assert Map.has_key?(report, :analysis)
      assert Map.has_key?(report, :metadata)

      assert binary?(report.report)
      assert {:ok, _} = Jason.decode(report.report)
    end

    test ~c"generates HTML report" do
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

      report = AIAnalyzer.generate_report(metrics, %{format: :html})

      assert Map.has_key?(report, :report)
      assert Map.has_key?(report, :analysis)
      assert Map.has_key?(report, :metadata)

      assert binary?(report.report)
      assert String.contains?(report.report, "<!DOCTYPE html>")
      assert String.contains?(report.report, "<html>")
      assert String.contains?(report.report, "<head>")
      assert String.contains?(report.report, "<body>")
      assert String.contains?(report.report, "<style>")
    end

    test ~c"handles custom analysis options" do
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

      options = %{
        depth: :comprehensive,
        focus: [:fps, :memory],
        historical_data: [
          %{
            fps: 55,
            memory_usage: 90_000_000,
            timestamp: "2024-03-20T10:00:00Z"
          }
        ]
      }

      analysis = AIAnalyzer.analyze(metrics, options)

      assert Map.has_key?(analysis, :insights)
      assert Map.has_key?(analysis, :recommendations)
      assert Map.has_key?(analysis, :risk_assessment)
      assert Map.has_key?(analysis, :optimization_impact)
      assert Map.has_key?(analysis, :ai_confidence)
    end

    test ~c"handles missing metrics gracefully" do
      metrics = %{
        fps: 60,
        avg_frame_time: 16.5,
        jank_count: 0,
        memory_usage: 100_000_000,
        gc_stats: %{}
      }

      analysis = AIAnalyzer.analyze(metrics)

      assert Map.has_key?(analysis, :insights)
      assert Map.has_key?(analysis, :recommendations)
      assert Map.has_key?(analysis, :risk_assessment)
      assert Map.has_key?(analysis, :optimization_impact)
      assert Map.has_key?(analysis, :ai_confidence)
    end

    test ~c"includes metadata in report" do
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

      report = AIAnalyzer.generate_report(metrics)

      assert Map.has_key?(report.metadata, :generated_at)
      assert Map.has_key?(report.metadata, :version)

      assert struct?(report.metadata.generated_at, DateTime)
      assert binary?(report.metadata.version)
    end
  end
end
