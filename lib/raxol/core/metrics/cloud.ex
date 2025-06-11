defmodule Raxol.Core.Metrics.Cloud do
  @moduledoc """
  Cloud integration for the Raxol metrics system.

  This module handles:
  - Sending metrics to cloud services
  - Metric aggregation for cloud transmission
  - Cloud service configuration
  - Metric batching and compression
  """

  use GenServer
  alias Raxol.Core.Metrics.{Config, UnifiedCollector}

  @type cloud_service :: :datadog | :prometheus | :cloudwatch
  @type cloud_config :: %{
    service: cloud_service(),
    endpoint: String.t(),
    api_key: String.t(),
    batch_size: pos_integer(),
    flush_interval: pos_integer(),
    compression: boolean()
  }

  @default_config %{
    service: :datadog,
    endpoint: "https://api.datadoghq.com/api/v1/series",
    batch_size: 100,
    flush_interval: 10_000,
    compression: true
  }

  @doc """
  Starts the cloud metrics service.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Configures the cloud metrics service.
  """
  def configure(config) when is_map(config) do
    GenServer.call(__MODULE__, {:configure, config})
  end

  @doc """
  Gets the current cloud configuration.
  """
  def get_config do
    GenServer.call(__MODULE__, :get_config)
  end

  @doc """
  Manually triggers a metrics flush to the cloud service.
  """
  def flush_metrics do
    GenServer.call(__MODULE__, :flush_metrics)
  end

  @impl GenServer
  def init(opts) do
    config = Map.merge(@default_config, Map.new(opts))
    state = %{
      config: config,
      metrics_buffer: [],
      last_flush: System.system_time(:millisecond)
    }
    schedule_flush()
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:configure, new_config}, _from, state) do
    case validate_cloud_config(new_config) do
      :ok ->
        new_state = %{state | config: Map.merge(state.config, new_config)}
        {:reply, :ok, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call(:get_config, _from, state) do
    {:reply, state.config, state}
  end

  @impl GenServer
  def handle_call(:flush_metrics, _from, state) do
    {new_state, result} = flush_metrics_to_cloud(state)
    {:reply, result, new_state}
  end

  @impl GenServer
  def handle_info(:flush_metrics, state) do
    {new_state, _result} = flush_metrics_to_cloud(state)
    schedule_flush()
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info({:metrics, type, name, value, tags}, state) do
    metric = %{
      type: type,
      name: name,
      value: value,
      tags: tags,
      timestamp: System.system_time(:second)
    }
    new_buffer = [metric | state.metrics_buffer]

    if length(new_buffer) >= state.config.batch_size do
      {new_state, _result} = flush_metrics_to_cloud(%{state | metrics_buffer: new_buffer})
      {:noreply, new_state}
    else
      {:noreply, %{state | metrics_buffer: new_buffer}}
    end
  end

  defp flush_metrics_to_cloud(state) do
    if state.metrics_buffer == [] do
      {state, :ok}
    else
      metrics = prepare_metrics_for_cloud(state.metrics_buffer)
      result = send_metrics_to_cloud(metrics, state.config)
      new_state = %{state |
        metrics_buffer: [],
        last_flush: System.system_time(:millisecond)
      }
      {new_state, result}
    end
  end

  defp prepare_metrics_for_cloud(metrics) do
    metrics
    |> Enum.group_by(&{&1.type, &1.name})
    |> Enum.map(fn {{type, name}, values} ->
      %{
        type: type,
        name: name,
        values: Enum.map(values, & &1.value),
        tags: List.first(values).tags,
        timestamp: List.first(values).timestamp
      }
    end)
  end

  defp send_metrics_to_cloud(metrics, config) do
    case config.service do
      :datadog -> send_to_datadog(metrics, config)
      :prometheus -> send_to_prometheus(metrics, config)
      :cloudwatch -> send_to_cloudwatch(metrics, config)
    end
  end

  defp send_to_datadog(metrics, config) do
    body = Jason.encode!(%{
      series: Enum.map(metrics, &format_datadog_metric(&1))
    })

    headers = [
      {"Content-Type", "application/json"},
      {"DD-API-KEY", config.api_key}
    ]

    case HTTPoison.post(config.endpoint, body, headers) do
      {:ok, %{status_code: 202}} -> :ok
      {:ok, response} -> {:error, {:datadog_error, response}}
      {:error, reason} -> {:error, {:request_error, reason}}
    end
  end

  defp send_to_prometheus(metrics, config) do
    body = Enum.map_join(metrics, "\n", &format_prometheus_metric(&1))

    headers = [
      {"Content-Type", "text/plain"},
      {"X-API-Key", config.api_key}
    ]

    case HTTPoison.post(config.endpoint, body, headers) do
      {:ok, %{status_code: 200}} -> :ok
      {:ok, response} -> {:error, {:prometheus_error, response}}
      {:error, reason} -> {:error, {:request_error, reason}}
    end
  end

  defp send_to_cloudwatch(metrics, config) do
    body = Jason.encode!(%{
      MetricData: Enum.map(metrics, &format_cloudwatch_metric(&1))
    })

    headers = [
      {"Content-Type", "application/json"},
      {"X-AWS-Key", config.api_key}
    ]

    case HTTPoison.post(config.endpoint, body, headers) do
      {:ok, %{status_code: 200}} -> :ok
      {:ok, response} -> {:error, {:cloudwatch_error, response}}
      {:error, reason} -> {:error, {:request_error, reason}}
    end
  end

  defp format_datadog_metric(metric) do
    %{
      metric: metric.name,
      points: [[metric.timestamp, Enum.sum(metric.values) / length(metric.values)]],
      type: "gauge",
      tags: metric.tags
    }
  end

  defp format_prometheus_metric(metric) do
    tags = Enum.map_join(metric.tags, ",", &"#{&1}")
    value = Enum.sum(metric.values) / length(metric.values)
    "#{metric.name}{#{tags}} #{value} #{metric.timestamp}"
  end

  defp format_cloudwatch_metric(metric) do
    %{
      MetricName: metric.name,
      Value: Enum.sum(metric.values) / length(metric.values),
      Unit: "Count",
      Timestamp: DateTime.from_unix!(metric.timestamp),
      Dimensions: Enum.map(metric.tags, &%{Name: &1, Value: "true"})
    }
  end

  defp validate_cloud_config(config) do
    with :ok <- validate_service(config.service),
         :ok <- validate_endpoint(config.endpoint),
         :ok <- validate_api_key(config.api_key),
         :ok <- validate_batch_size(config.batch_size),
         :ok <- validate_flush_interval(config.flush_interval) do
      :ok
    end
  end

  defp validate_service(service) when service in [:datadog, :prometheus, :cloudwatch], do: :ok
  defp validate_service(_), do: {:error, :invalid_service}

  defp validate_endpoint(endpoint) when is_binary(endpoint) and endpoint != "", do: :ok
  defp validate_endpoint(_), do: {:error, :invalid_endpoint}

  defp validate_api_key(api_key) when is_binary(api_key) and api_key != "", do: :ok
  defp validate_api_key(_), do: {:error, :invalid_api_key}

  defp validate_batch_size(size) when is_integer(size) and size > 0, do: :ok
  defp validate_batch_size(_), do: {:error, :invalid_batch_size}

  defp validate_flush_interval(interval) when is_integer(interval) and interval > 0, do: :ok
  defp validate_flush_interval(_), do: {:error, :invalid_flush_interval}

  defp schedule_flush do
    Process.send_after(self(), :flush_metrics, @default_config.flush_interval)
  end
end
