defmodule Raxol.Terminal.Buffer.MetricsTrackerTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Buffer.MetricsTracker

  setup do
    metrics = MetricsTracker.new()
    %{metrics: metrics}
  end

  test "new/0 initializes metrics correctly", %{metrics: metrics} do
    assert metrics.operations.reads == 0
    assert metrics.operations.writes == 0
    assert metrics.operations.scrolls == 0
    assert metrics.operations.resizes == 0
    assert metrics.performance.total_operations == 0
    assert metrics.performance.average_response_time == 0.0
  end

  test "update_metrics/3 increments operation and updates avg response time", %{
    metrics: metrics
  } do
    start_time = System.monotonic_time()
    :timer.sleep(1)
    updated = MetricsTracker.update_metrics(metrics, :reads, start_time)
    assert updated.operations.reads == 1
    assert updated.performance.total_operations == 1
    assert updated.performance.average_response_time > 0.0
  end

  test "calculate_memory_usage/1 estimates memory usage" do
    buffer = %{width: 10, height: 5}
    assert MetricsTracker.calculate_memory_usage(buffer) == 10 * 5 * 64
  end

  test "get_summary/1 returns correct summary", %{metrics: metrics} do
    summary = MetricsTracker.get_summary(metrics)
    assert summary.total_operations == 0
    assert summary.average_response_time_us == 0.0
    assert summary.operation_counts == metrics.operations
    assert summary.throughput_ops_per_sec == 0.0
  end

  test "reset/1 returns initial metrics" do
    metrics = MetricsTracker.new()
    start_time = System.monotonic_time()
    updated = MetricsTracker.update_metrics(metrics, :writes, start_time)
    reset = MetricsTracker.reset(updated)
    assert reset == MetricsTracker.new()
  end
end
