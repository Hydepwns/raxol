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
      {new_state, _result} =
        flush_metrics_to_cloud(%{state | metrics_buffer: new_buffer})

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

      new_state = %{
        state
        | metrics_buffer: [],
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
      :datadog -> send_to_datadog(config, metrics)
      :prometheus -> send_to_prometheus(config, metrics)
      :cloudwatch -> send_to_cloudwatch(config, metrics)
      _ -> {:error, :invalid_service}
    end
  end

  def send_to_datadog(_config, _metrics) do
    # Send metrics to Datadog
    :ok
  end

  def send_to_prometheus(_config, _metrics) do
    # Send metrics to Prometheus
    :ok
  end

  def send_to_cloudwatch(_config, _metrics) do
    # Send metrics to CloudWatch
    :ok
  end

  defp validate_cloud_config(config) do
    # Merge with defaults to ensure all required fields are present
    config_with_defaults = Map.merge(@default_config, config)

    with :ok <- validate_service(config_with_defaults.service),
         :ok <- validate_endpoint(config_with_defaults.endpoint),
         :ok <- validate_api_key(config_with_defaults.api_key),
         :ok <- validate_batch_size(config_with_defaults.batch_size),
         :ok <- validate_flush_interval(config_with_defaults.flush_interval) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_service(service)
       when service in [:datadog, :prometheus, :cloudwatch],
       do: :ok

  defp validate_service(_), do: {:error, :invalid_service}

  defp validate_endpoint(endpoint) when is_binary(endpoint) and endpoint != "",
    do: :ok

  defp validate_endpoint(_), do: {:error, :invalid_endpoint}

  defp validate_api_key(api_key) when is_binary(api_key) and api_key != "",
    do: :ok

  defp validate_api_key(_), do: {:error, :invalid_api_key}

  defp validate_batch_size(size) when is_integer(size) and size > 0, do: :ok
  defp validate_batch_size(_), do: {:error, :invalid_batch_size}

  defp validate_flush_interval(interval)
       when is_integer(interval) and interval > 0,
       do: :ok

  defp validate_flush_interval(_), do: {:error, :invalid_flush_interval}

  defp schedule_flush do
    timer_id = System.unique_integer([:positive])

    Process.send_after(
      self(),
      {:flush_metrics, timer_id},
      @default_config.flush_interval
    )
  end
end
