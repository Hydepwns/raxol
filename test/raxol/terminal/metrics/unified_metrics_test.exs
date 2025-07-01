defmodule Raxol.Terminal.Metrics.UnifiedMetricsTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  alias Raxol.Terminal.Metrics.UnifiedMetrics

  setup do
    {:ok, _pid} =
      UnifiedMetrics.start_link(
        name: :unified_metrics_test,
        retention_period: 1000,
        aggregation_interval: 100,
        alert_thresholds: %{
          "response_time" => 1000,
          "errors" => %{critical: true}
        },
        export_format: :prometheus
      )

    :ok
  end

  describe "basic operations" do
    test ~c"records and retrieves metrics" do
      assert :ok = UnifiedMetrics.record_metric("test_metric", 42, [], :unified_metrics_test)
      assert {:ok, 42} = UnifiedMetrics.get_metric("test_metric", [], :unified_metrics_test)
    end

    test ~c"handles different metric types" do
      # Counter
      assert :ok = UnifiedMetrics.record_metric("counter", 1, [type: :counter], :unified_metrics_test)
      assert :ok = UnifiedMetrics.record_metric("counter", 2, [type: :counter], :unified_metrics_test)
      assert {:ok, 3} = UnifiedMetrics.get_metric("counter", [], :unified_metrics_test)

      # Gauge
      assert :ok = UnifiedMetrics.record_metric("gauge", 10, [type: :gauge], :unified_metrics_test)
      assert :ok = UnifiedMetrics.record_metric("gauge", 20, [type: :gauge], :unified_metrics_test)
      assert {:ok, 20} = UnifiedMetrics.get_metric("gauge", [], :unified_metrics_test)

      # Histogram
      assert :ok =
               UnifiedMetrics.record_metric("histogram", 1, [type: :histogram], :unified_metrics_test)

      assert :ok =
               UnifiedMetrics.record_metric("histogram", 2, [type: :histogram], :unified_metrics_test)

      assert :ok =
               UnifiedMetrics.record_metric("histogram", 3, [type: :histogram], :unified_metrics_test)

      assert {:ok, stats} = UnifiedMetrics.get_metric("histogram", [], :unified_metrics_test)
      assert stats.count == 3
      assert stats.sum == 6
      assert stats.min == 1
      assert stats.max == 3
      assert stats.avg == 2.0

      # Summary
      assert :ok = UnifiedMetrics.record_metric("summary", 1, [type: :summary], :unified_metrics_test)
      assert :ok = UnifiedMetrics.record_metric("summary", 2, [type: :summary], :unified_metrics_test)
      assert :ok = UnifiedMetrics.record_metric("summary", 3, [type: :summary], :unified_metrics_test)
      assert {:ok, stats} = UnifiedMetrics.get_metric("summary", [], :unified_metrics_test)
      assert stats.count == 3
      assert stats.sum == 6
      assert stats.p50 == 2
      assert stats.p90 == 3
      assert stats.p99 == 3
    end
  end

  describe "labels and filtering" do
    test ~c"handles metric labels" do
      assert :ok =
               UnifiedMetrics.record_metric("labeled", 1,
                 [labels: %{service: "test"}], :unified_metrics_test
               )

      assert :ok =
               UnifiedMetrics.record_metric("labeled", 2,
                 [labels: %{service: "other"}], :unified_metrics_test
               )

      assert {:ok, 1} =
               UnifiedMetrics.get_metric("labeled", [labels: %{service: "test"}], :unified_metrics_test)

      assert {:ok, 2} =
               UnifiedMetrics.get_metric("labeled", [labels: %{service: "other"}], :unified_metrics_test)
    end

    test ~c"filters by time range" do
      now = System.system_time(:millisecond)
      assert :ok = UnifiedMetrics.record_metric("time_filtered", 1, [], :unified_metrics_test)
      Process.sleep(100)
      assert :ok = UnifiedMetrics.record_metric("time_filtered", 2, [], :unified_metrics_test)

      assert {:ok, 2} =
               UnifiedMetrics.get_metric("time_filtered",
                 [time_range: {now, now + 200}], :unified_metrics_test
               )
    end
  end

  describe "error tracking" do
    test ~c"records and retrieves errors" do
      assert :ok = UnifiedMetrics.record_error("test error", [], :unified_metrics_test)

      assert :ok =
               UnifiedMetrics.record_error("critical error",
                 [severity: :critical], :unified_metrics_test
               )

      assert {:ok, stats} = UnifiedMetrics.get_error_stats([], :unified_metrics_test)
      assert stats.total == 2
      assert stats.by_severity.error == 1
      assert stats.by_severity.critical == 1
      assert length(stats.recent) == 2
    end

    test ~c"filters errors by severity" do
      assert :ok = UnifiedMetrics.record_error("test error", [], :unified_metrics_test)

      assert :ok =
               UnifiedMetrics.record_error("critical error",
                 [severity: :critical], :unified_metrics_test
               )

      assert {:ok, stats} = UnifiedMetrics.get_error_stats([severity: :critical], :unified_metrics_test)
      assert stats.total == 1
      assert stats.by_severity.critical == 1
    end
  end

  describe "export formats" do
    test ~c"exports in Prometheus format" do
      assert :ok =
               UnifiedMetrics.record_metric("export_test", 42,
                 [labels: %{service: "test"}], :unified_metrics_test
               )

      assert {:ok, exported} =
               UnifiedMetrics.export_metrics([format: :prometheus], :unified_metrics_test)

      assert String.contains?(exported, "export_test{service=\"test\"} 42")
    end

    test ~c"exports in JSON format" do
      assert :ok =
               UnifiedMetrics.record_metric("export_test", 42,
                 [labels: %{service: "test"}], :unified_metrics_test
               )

      assert {:ok, exported} = UnifiedMetrics.export_metrics([format: :json], :unified_metrics_test)
      assert String.contains?(exported, "\"name\":\"export_test\"")
      assert String.contains?(exported, "\"value\":42")
    end
  end

  describe "cleanup" do
    test ~c"cleans up old metrics" do
      assert :ok = UnifiedMetrics.record_metric("cleanup_test", 1, [], :unified_metrics_test)
      # Wait for retention period
      Process.sleep(1100)
      assert :ok = UnifiedMetrics.cleanup_metrics([], :unified_metrics_test)

      assert {:error, :metric_not_found} =
               UnifiedMetrics.get_metric("cleanup_test", [], :unified_metrics_test)
    end

    test ~c"cleans up old errors" do
      assert :ok = UnifiedMetrics.record_error("old error", [], :unified_metrics_test)
      # Wait for retention period
      Process.sleep(1100)
      assert :ok = UnifiedMetrics.cleanup_metrics([], :unified_metrics_test)
      assert {:ok, stats} = UnifiedMetrics.get_error_stats([], :unified_metrics_test)
      assert stats.total == 0
    end
  end

  describe "alerts" do
    test ~c"triggers metric alerts" do
      log =
        capture_log(fn ->
          # Above threshold
          assert :ok = UnifiedMetrics.record_metric("response_time", 1500, [], :unified_metrics_test)
          # Give time for alert to be processed
          Process.sleep(50)
        end)

      assert log =~ "response_time"
      assert log =~ "threshold"
    end

    test ~c"triggers error alerts" do
      log =
        capture_log(fn ->
          assert :ok =
                   UnifiedMetrics.record_error("critical error",
                     [severity: :critical], :unified_metrics_test
                   )

          # Give time for alert to be processed
          Process.sleep(50)
        end)

      assert log =~ "critical error"
      assert log =~ "critical"
    end
  end

  describe "aggregation" do
    test ~c"aggregates metrics over time" do
      assert :ok = UnifiedMetrics.record_metric("aggregation_test", 1)
      assert :ok = UnifiedMetrics.record_metric("aggregation_test", 2)
      assert :ok = UnifiedMetrics.record_metric("aggregation_test", 3)

      # Wait for aggregation
      Process.sleep(150)
      assert {:ok, aggregated} = UnifiedMetrics.get_metric("aggregation_test")
      assert is_number(aggregated)
    end
  end
end
