defmodule Raxol.Core.Metrics.MetricsCollectorTest do
  @moduledoc """
  Tests for the unified metrics collector, including performance, resource,
  operation, custom, and system metrics collection.
  """
  use ExUnit.Case, async: false
  alias Raxol.Core.Metrics.MetricsCollector

  setup do
    # Stop any existing MetricsCollector
    case Process.whereis(MetricsCollector) do
      nil -> :ok
      pid -> GenServer.stop(pid)
    end

    {:ok, pid} = MetricsCollector.start_link(name: MetricsCollector)

    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end
    end)

    :ok
  end

  describe "performance metrics" do
    test "records and retrieves performance metrics" do
      # Record some performance metrics
      MetricsCollector.record_performance(:frame_time, 16)
      MetricsCollector.record_performance(:render_time, 8)

      # Get all metrics
      metrics = MetricsCollector.get_metrics()
      performance_metrics = metrics.performance

      # Verify metrics were recorded
      assert Map.has_key?(performance_metrics, :frame_time)
      assert Map.has_key?(performance_metrics, :render_time)

      # Verify values
      frame_time = hd(performance_metrics.frame_time)
      assert frame_time.value == 16
      assert is_struct(frame_time.timestamp, DateTime)

      render_time = hd(performance_metrics.render_time)
      assert render_time.value == 8
      assert is_struct(render_time.timestamp, DateTime)
    end

    test "maintains metric history limit" do
      # Record more metrics than the history limit
      Enum.each(1..1100, fn i ->
        MetricsCollector.record_performance(:test_metric, i)
      end)

      # Get metrics
      metrics = MetricsCollector.get_metrics()
      test_metrics = metrics.performance.test_metric

      # Verify history limit is maintained
      assert length(test_metrics) == 1000
      assert hd(test_metrics).value == 1100
    end
  end

  describe "resource metrics" do
    test "records and retrieves resource metrics" do
      # Record some resource metrics
      MetricsCollector.record_resource(:memory_usage, 1024)
      MetricsCollector.record_resource(:cpu_usage, 50)

      # Get resource metrics
      resource_metrics = MetricsCollector.get_metrics_by_type(:resource)

      # Verify metrics were recorded
      assert Map.has_key?(resource_metrics, :memory_usage)
      assert Map.has_key?(resource_metrics, :cpu_usage)

      # Verify values
      memory_usage = hd(resource_metrics.memory_usage)
      assert memory_usage.value == 1024
      assert is_struct(memory_usage.timestamp, DateTime)

      cpu_usage = hd(resource_metrics.cpu_usage)
      assert cpu_usage.value == 50
      assert is_struct(cpu_usage.timestamp, DateTime)
    end
  end

  describe "operation metrics" do
    test "records and retrieves operation metrics" do
      # Record some operation metrics
      MetricsCollector.record_operation(:buffer_write, 5)
      MetricsCollector.record_operation(:buffer_read, 3)

      # Get operation metrics
      operation_metrics = MetricsCollector.get_metrics_by_type(:operation)

      # Verify metrics were recorded
      assert Map.has_key?(operation_metrics, :buffer_write)
      assert Map.has_key?(operation_metrics, :buffer_read)

      # Verify values
      buffer_write = hd(operation_metrics.buffer_write)
      assert buffer_write.value == 5
      assert is_struct(buffer_write.timestamp, DateTime)

      buffer_read = hd(operation_metrics.buffer_read)
      assert buffer_read.value == 3
      assert is_struct(buffer_read.timestamp, DateTime)
    end
  end

  describe "custom metrics" do
    test "records and retrieves custom metrics" do
      # Record some custom metrics
      MetricsCollector.record_custom("user.login_time", 150)
      MetricsCollector.record_custom("api.request_time", 200)

      # Get custom metrics
      custom_metrics = MetricsCollector.get_metrics_by_type(:custom)

      # Verify metrics were recorded
      assert Map.has_key?(custom_metrics, "user.login_time")
      assert Map.has_key?(custom_metrics, "api.request_time")

      # Verify values
      login_time = hd(custom_metrics["user.login_time"])
      assert login_time.value == 150
      assert is_struct(login_time.timestamp, DateTime)

      request_time = hd(custom_metrics["api.request_time"])
      assert request_time.value == 200
      assert is_struct(request_time.timestamp, DateTime)
    end
  end

  describe "system metrics collection" do
    test "collects system metrics automatically" do
      # Wait for the periodic system metrics collection to run
      Process.sleep(200)

      metrics = MetricsCollector.get_metrics_by_type(:resource)
      resource_metrics = Map.keys(metrics)
      assert :process_count in resource_metrics
      assert :runtime_ratio in resource_metrics
      assert :gc_stats in resource_metrics
    end
  end

  describe "metric tags" do
    test "records metrics with tags" do
      # Record metrics with tags
      MetricsCollector.record_performance(:frame_time, 16, tags: [:ui, :render])
      MetricsCollector.record_resource(:memory_usage, 1024, tags: [:system])

      # Get metrics
      metrics = MetricsCollector.get_metrics()

      # Verify tags were recorded
      frame_time = hd(metrics.performance.frame_time)
      assert frame_time.tags == [:ui, :render]

      memory_usage = hd(metrics.resource.memory_usage)
      assert memory_usage.tags == [:system]
    end
  end
end
