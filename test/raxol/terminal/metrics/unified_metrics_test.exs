defmodule Raxol.Terminal.Metrics.UnifiedMetricsTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Metrics.UnifiedMetrics

  setup do
    {:ok, _pid} = UnifiedMetrics.start_link(
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
    test "records and retrieves metrics" do
      assert :ok = UnifiedMetrics.record_metric("test_metric", 42)
      assert {:ok, 42} = UnifiedMetrics.get_metric("test_metric")
    end

    test "handles different metric types" do
      # Counter
      assert :ok = UnifiedMetrics.record_metric("counter", 1, type: :counter)
      assert :ok = UnifiedMetrics.record_metric("counter", 2, type: :counter)
      assert {:ok, 3} = UnifiedMetrics.get_metric("counter")

      # Gauge
      assert :ok = UnifiedMetrics.record_metric("gauge", 10, type: :gauge)
      assert :ok = UnifiedMetrics.record_metric("gauge", 20, type: :gauge)
      assert {:ok, 20} = UnifiedMetrics.get_metric("gauge")

      # Histogram
      assert :ok = UnifiedMetrics.record_metric("histogram", 1, type: :histogram)
      assert :ok = UnifiedMetrics.record_metric("histogram", 2, type: :histogram)
      assert :ok = UnifiedMetrics.record_metric("histogram", 3, type: :histogram)
      assert {:ok, stats} = UnifiedMetrics.get_metric("histogram")
      assert stats.count == 3
      assert stats.sum == 6
      assert stats.min == 1
      assert stats.max == 3
      assert stats.avg == 2.0

      # Summary
      assert :ok = UnifiedMetrics.record_metric("summary", 1, type: :summary)
      assert :ok = UnifiedMetrics.record_metric("summary", 2, type: :summary)
      assert :ok = UnifiedMetrics.record_metric("summary", 3, type: :summary)
      assert {:ok, stats} = UnifiedMetrics.get_metric("summary")
      assert stats.count == 3
      assert stats.sum == 6
      assert stats.p50 == 2
      assert stats.p90 == 3
      assert stats.p99 == 3
    end
  end

  describe "labels and filtering" do
    test "handles metric labels" do
      assert :ok = UnifiedMetrics.record_metric("labeled", 1, labels: %{service: "test"})
      assert :ok = UnifiedMetrics.record_metric("labeled", 2, labels: %{service: "other"})

      assert {:ok, 1} = UnifiedMetrics.get_metric("labeled", labels: %{service: "test"})
      assert {:ok, 2} = UnifiedMetrics.get_metric("labeled", labels: %{service: "other"})
    end

    test "filters by time range" do
      now = System.system_time(:millisecond)
      assert :ok = UnifiedMetrics.record_metric("time_filtered", 1)
      Process.sleep(100)
      assert :ok = UnifiedMetrics.record_metric("time_filtered", 2)

      assert {:ok, 2} = UnifiedMetrics.get_metric("time_filtered", time_range: {now, now + 200})
    end
  end

  describe "error tracking" do
    test "records and retrieves errors" do
      assert :ok = UnifiedMetrics.record_error("test error")
      assert :ok = UnifiedMetrics.record_error("critical error", severity: :critical)

      assert {:ok, stats} = UnifiedMetrics.get_error_stats()
      assert stats.total == 2
      assert stats.by_severity.error == 1
      assert stats.by_severity.critical == 1
      assert length(stats.recent) == 2
    end

    test "filters errors by severity" do
      assert :ok = UnifiedMetrics.record_error("test error")
      assert :ok = UnifiedMetrics.record_error("critical error", severity: :critical)

      assert {:ok, stats} = UnifiedMetrics.get_error_stats(severity: :critical)
      assert stats.total == 1
      assert stats.by_severity.critical == 1
    end
  end

  describe "export formats" do
    test "exports in Prometheus format" do
      assert :ok = UnifiedMetrics.record_metric("export_test", 42, labels: %{service: "test"})
      assert {:ok, exported} = UnifiedMetrics.export_metrics(format: :prometheus)
      assert String.contains?(exported, "export_test{service=\"test\"} 42")
    end

    test "exports in JSON format" do
      assert :ok = UnifiedMetrics.record_metric("export_test", 42, labels: %{service: "test"})
      assert {:ok, exported} = UnifiedMetrics.export_metrics(format: :json)
      assert String.contains?(exported, "\"name\":\"export_test\"")
      assert String.contains?(exported, "\"value\":42")
    end
  end

  describe "cleanup" do
    test "cleans up old metrics" do
      assert :ok = UnifiedMetrics.record_metric("cleanup_test", 1)
      Process.sleep(1100)  # Wait for retention period
      assert :ok = UnifiedMetrics.cleanup_metrics()
      assert {:error, :metric_not_found} = UnifiedMetrics.get_metric("cleanup_test")
    end

    test "cleans up old errors" do
      assert :ok = UnifiedMetrics.record_error("old error")
      Process.sleep(1100)  # Wait for retention period
      assert :ok = UnifiedMetrics.cleanup_metrics()
      assert {:ok, stats} = UnifiedMetrics.get_error_stats()
      assert stats.total == 0
    end
  end

  describe "alerts" do
    test "triggers metric alerts" do
      assert :ok = UnifiedMetrics.record_metric("response_time", 1500)  # Above threshold
      # Should log a warning
    end

    test "triggers error alerts" do
      assert :ok = UnifiedMetrics.record_error("critical error", severity: :critical)
      # Should log an error
    end
  end

  describe "aggregation" do
    test "aggregates metrics over time" do
      assert :ok = UnifiedMetrics.record_metric("aggregation_test", 1)
      assert :ok = UnifiedMetrics.record_metric("aggregation_test", 2)
      assert :ok = UnifiedMetrics.record_metric("aggregation_test", 3)

      Process.sleep(150)  # Wait for aggregation
      assert {:ok, aggregated} = UnifiedMetrics.get_metric("aggregation_test")
      assert is_number(aggregated)
    end
  end
end
