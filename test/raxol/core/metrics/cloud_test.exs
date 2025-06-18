defmodule Raxol.Core.Metrics.CloudTest do
  @moduledoc """
  Tests for the cloud metrics system, including configuration,
  metric handling, and data formatting.
  """
  use ExUnit.Case
  alias Raxol.Core.Metrics.Cloud

  setup do
    {:ok, _pid} = Cloud.start_link()
    on_exit(fn -> Process.whereis(Cloud) |> Process.exit(:normal) end)
    :ok
  end

  describe "configure/1" do
    test "configures cloud service with valid config" do
      config = %{
        service: :datadog,
        endpoint: "https://api.datadoghq.com/api/v1/series",
        api_key: "test_key",
        batch_size: 50,
        flush_interval: 5000,
        compression: true
      }

      assert :ok == Cloud.configure(config)
      assert config == Cloud.get_config()
    end

    test "rejects invalid service" do
      config = %{
        service: :invalid,
        endpoint: "https://api.datadoghq.com/api/v1/series",
        api_key: "test_key"
      }

      assert {:error, :invalid_service} == Cloud.configure(config)
    end

    test "rejects invalid endpoint" do
      config = %{
        service: :datadog,
        endpoint: "",
        api_key: "test_key"
      }

      assert {:error, :invalid_endpoint} == Cloud.configure(config)
    end

    test "rejects invalid api key" do
      config = %{
        service: :datadog,
        endpoint: "https://api.datadoghq.com/api/v1/series",
        api_key: ""
      }

      assert {:error, :invalid_api_key} == Cloud.configure(config)
    end

    test "rejects invalid batch size" do
      config = %{
        service: :datadog,
        endpoint: "https://api.datadoghq.com/api/v1/series",
        api_key: "test_key",
        batch_size: 0
      }

      assert {:error, :invalid_batch_size} == Cloud.configure(config)
    end

    test "rejects invalid flush interval" do
      config = %{
        service: :datadog,
        endpoint: "https://api.datadoghq.com/api/v1/series",
        api_key: "test_key",
        flush_interval: 0
      }

      assert {:error, :invalid_flush_interval} == Cloud.configure(config)
    end
  end

  describe "metrics handling" do
    setup do
      config = %{
        service: :datadog,
        endpoint: "https://api.datadoghq.com/api/v1/series",
        api_key: "test_key",
        batch_size: 2,
        flush_interval: 1000
      }

      :ok = Cloud.configure(config)
      :ok
    end

    test "buffers metrics until batch size is reached" do
      send(Cloud, {:metrics, :performance, :frame_time, 16, [:test]})
      send(Cloud, {:metrics, :performance, :frame_time, 17, [:test]})

      # Wait for metrics to be processed
      Process.sleep(100)

      # Verify metrics were sent
      assert_receive {:metrics_sent, :ok}
    end

    test "formats metrics correctly for Datadog" do
      send(Cloud, {:metrics, :performance, :frame_time, 16, [:test]})
      send(Cloud, {:metrics, :performance, :frame_time, 17, [:test]})

      # Wait for metrics to be processed
      Process.sleep(100)

      # Verify metrics were formatted correctly
      assert_receive {:metrics_formatted,
                      %{
                        series: [
                          %{
                            metric: "frame_time",
                            points: [[_, 16.5]],
                            type: "gauge",
                            tags: [:test]
                          }
                        ]
                      }}
    end

    test "formats metrics correctly for Prometheus" do
      config = %{
        service: :prometheus,
        endpoint: "http://localhost:9090/metrics",
        api_key: "test_key",
        batch_size: 2,
        flush_interval: 1000
      }

      :ok = Cloud.configure(config)

      send(Cloud, {:metrics, :performance, :frame_time, 16, [:test]})
      send(Cloud, {:metrics, :performance, :frame_time, 17, [:test]})

      # Wait for metrics to be processed
      Process.sleep(100)

      # Verify metrics were formatted correctly
      assert_receive {:metrics_formatted, "frame_time{test} 16.5 _"}
    end

    test "formats metrics correctly for CloudWatch" do
      config = %{
        service: :cloudwatch,
        endpoint: "https://monitoring.amazonaws.com",
        api_key: "test_key",
        batch_size: 2,
        flush_interval: 1000
      }

      :ok = Cloud.configure(config)

      send(Cloud, {:metrics, :performance, :frame_time, 16, [:test]})
      send(Cloud, {:metrics, :performance, :frame_time, 17, [:test]})

      # Wait for metrics to be processed
      Process.sleep(100)

      # Verify metrics were formatted correctly
      assert_receive {:metrics_formatted,
                      %{
                        MetricData: [
                          %{
                            MetricName: "frame_time",
                            Value: 16.5,
                            Unit: "Count",
                            Timestamp: _,
                            Dimensions: [%{Name: "test", Value: "true"}]
                          }
                        ]
                      }}
    end
  end

  describe "flush_metrics/0" do
    test "flushes metrics immediately" do
      send(Cloud, {:metrics, :performance, :frame_time, 16, [:test]})
      assert :ok == Cloud.flush_metrics()
      assert_receive {:metrics_sent, :ok}
    end

    test "returns :ok when no metrics to flush" do
      assert :ok == Cloud.flush_metrics()
    end
  end
end
