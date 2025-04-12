defmodule Raxol.Core.Performance.AIAnalyzerTest do
  use ExUnit.Case

  alias Raxol.Core.Performance.AIAnalyzer

  describe "AI Analyzer" do
    test "analyzes performance metrics" do
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

      assert is_list(analysis.insights)
      assert is_list(analysis.recommendations)
      assert is_map(analysis.risk_assessment)
      assert is_map(analysis.optimization_impact)
      assert is_float(analysis.ai_confidence)
    end

    test "generates text report" do
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

      assert is_binary(report.report)
      assert String.contains?(report.report, "Performance Analysis Report")
      assert String.contains?(report.report, "Key Insights")
      assert String.contains?(report.report, "Recommendations")
      assert String.contains?(report.report, "Risk Assessment")
      assert String.contains?(report.report, "Expected Impact")
    end

    test "generates JSON report" do
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

      assert is_binary(report.report)
      assert {:ok, _} = Jason.decode(report.report)
    end

    test "generates HTML report" do
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

      assert is_binary(report.report)
      assert String.contains?(report.report, "<!DOCTYPE html>")
      assert String.contains?(report.report, "<html>")
      assert String.contains?(report.report, "<head>")
      assert String.contains?(report.report, "<body>")
      assert String.contains?(report.report, "<style>")
    end

    test "handles custom analysis options" do
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

    test "handles missing metrics gracefully" do
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

    test "includes metadata in report" do
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

      assert is_struct(report.metadata.generated_at, DateTime)
      assert is_binary(report.metadata.version)
    end
  end
end
