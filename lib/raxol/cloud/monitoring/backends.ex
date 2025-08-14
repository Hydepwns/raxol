defmodule Raxol.Cloud.Monitoring.Backends do
  @moduledoc """
  Backend adapters for various monitoring services.

  This module provides integrations with popular monitoring and observability
  platforms, allowing Raxol applications to send metrics, logs, and traces
  to external services.
  """

  @type backend_type :: :prometheus | :datadog | :new_relic | :grafana | :custom
  @type metric_data :: %{
          name: String.t(),
          value: number(),
          tags: map(),
          timestamp: integer()
        }
  @type log_data :: %{
          level: atom(),
          message: String.t(),
          metadata: map(),
          timestamp: integer()
        }

  @doc """
  Initializes a monitoring backend.
  """
  @spec init_backend(backend_type(), map()) :: {:ok, pid()} | {:error, term()}
  def init_backend(backend_type, config) do
    case backend_type do
      :prometheus -> init_prometheus(config)
      :datadog -> init_datadog(config)
      :new_relic -> init_new_relic(config)
      :grafana -> init_grafana(config)
      :custom -> init_custom_backend(config)
      _ -> {:error, :unsupported_backend}
    end
  end

  @doc """
  Sends metrics to the specified backend.
  """
  @spec send_metrics(backend_type(), [metric_data()]) :: :ok | {:error, term()}
  def send_metrics(backend_type, metrics) do
    case backend_type do
      :prometheus -> send_prometheus_metrics(metrics)
      :datadog -> send_datadog_metrics(metrics)
      :new_relic -> send_new_relic_metrics(metrics)
      :grafana -> send_grafana_metrics(metrics)
      :custom -> send_custom_metrics(metrics)
      _ -> {:error, :unsupported_backend}
    end
  end

  @doc """
  Sends logs to the specified backend.
  """
  @spec send_logs(backend_type(), [log_data()]) :: :ok | {:error, term()}
  def send_logs(backend_type, logs) do
    case backend_type do
      :prometheus -> {:ok, :logs_not_supported}
      :datadog -> send_datadog_logs(logs)
      :new_relic -> send_new_relic_logs(logs)
      :grafana -> send_grafana_logs(logs)
      :custom -> send_custom_logs(logs)
      _ -> {:error, :unsupported_backend}
    end
  end

  # Prometheus backend implementation
  defp init_prometheus(config) do
    port = Map.get(config, :port, 9090)
    path = Map.get(config, :metrics_path, "/metrics")

    # Start Prometheus metrics endpoint
    case start_prometheus_endpoint(port, path) do
      {:ok, pid} -> {:ok, pid}
      error -> error
    end
  end

  defp send_prometheus_metrics(metrics) do
    # Prometheus metrics are typically pulled, not pushed
    # Register metrics with the Prometheus registry
    Enum.each(metrics, &register_prometheus_metric/1)
    :ok
  end

  defp start_prometheus_endpoint(port, path) do
    try do
      # This would typically use a library like prometheus_ex
      # For now, we'll use a simple HTTP endpoint
      cowboy_opts = [port: port]

      dispatch = [
        {:_,
         [
           {path, __MODULE__.PrometheusHandler, []}
         ]}
      ]

      case :cowboy.start_clear(:prometheus_metrics, cowboy_opts, %{
             env: %{dispatch: dispatch}
           }) do
        {:ok, pid} -> {:ok, pid}
        {:error, :eaddrinuse} -> {:error, :port_in_use}
        error -> error
      end
    rescue
      error -> {:error, error}
    end
  end

  defp register_prometheus_metric(%{name: name, value: value, tags: tags}) do
    # Register or update the metric in Prometheus registry
    metric_name = String.replace(name, ".", "_")

    # This would use prometheus_ex functions
    # :prometheus_gauge.set(metric_name, tags, value)
    # For now, store in process dictionary as placeholder
    Raxol.Cloud.Monitoring.Server.put_prometheus_metric(metric_name, {value, tags})
  end

  # DataDog backend implementation
  defp init_datadog(config) do
    api_key = Map.get(config, :api_key)
    app_key = Map.get(config, :app_key)
    host = Map.get(config, :host, "app.datadoghq.com")

    with {:ok, _} <- validate_api_key(api_key) do
      {:ok, %{api_key: api_key, app_key: app_key, host: host}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_api_key(nil), do: {:error, :api_key_required}
  defp validate_api_key(api_key) when is_binary(api_key), do: {:ok, api_key}
  defp validate_api_key(_), do: {:error, :invalid_api_key}

  defp send_datadog_metrics(metrics) do
    config = Application.get_env(:raxol, :datadog_config, %{})
    api_key = Map.get(config, :api_key)

    with {:ok, _} <- validate_api_key(api_key),
         datadog_metrics = Enum.map(metrics, &format_datadog_metric/1),
         payload = %{series: datadog_metrics},
         headers = [
           {"Content-Type", "application/json"},
           {"DD-API-KEY", api_key}
         ],
         {:ok, response} <-
           HTTPoison.post(
             "https://api.datadoghq.com/api/v1/series",
             Jason.encode!(payload),
             headers
           ) do
      case response.status_code do
        202 -> :ok
        status -> {:error, {:http_error, status}}
      end
    else
      {:error, :api_key_required} -> {:error, :api_key_not_configured}
      {:error, reason} -> {:error, reason}
    end
  rescue
    error -> {:error, error}
  end

  defp send_datadog_logs(logs) do
    config = Application.get_env(:raxol, :datadog_config, %{})
    api_key = Map.get(config, :api_key)

    with {:ok, _} <- validate_api_key(api_key),
         datadog_logs = Enum.map(logs, &format_datadog_log/1),
         headers = [
           {"Content-Type", "application/json"},
           {"DD-API-KEY", api_key}
         ],
         {:ok, response} <-
           HTTPoison.post(
             "https://http-intake.logs.datadoghq.com/v1/input/#{api_key}",
             Jason.encode!(datadog_logs),
             headers
           ) do
      case response.status_code do
        200 -> :ok
        status -> {:error, {:http_error, status}}
      end
    else
      {:error, :api_key_required} -> {:error, :api_key_not_configured}
      {:error, reason} -> {:error, reason}
    end
  rescue
    error -> {:error, error}
  end

  # New Relic backend implementation
  defp init_new_relic(config) do
    license_key = Map.get(config, :license_key)

    with {:ok, _} <- validate_license_key(license_key) do
      {:ok, %{license_key: license_key}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_license_key(nil), do: {:error, :license_key_required}
  defp validate_license_key(key) when is_binary(key), do: {:ok, key}
  defp validate_license_key(_), do: {:error, :invalid_license_key}

  defp send_new_relic_metrics(metrics) do
    config = Application.get_env(:raxol, :new_relic_config, %{})
    license_key = Map.get(config, :license_key)

    with {:ok, _} <- validate_license_key(license_key),
         new_relic_metrics = Enum.map(metrics, &format_new_relic_metric/1),
         payload = %{metrics: new_relic_metrics},
         headers = [
           {"Content-Type", "application/json"},
           {"X-License-Key", license_key}
         ],
         {:ok, response} <-
           HTTPoison.post(
             "https://metric-api.newrelic.com/metric/v1",
             Jason.encode!(payload),
             headers
           ) do
      case response.status_code do
        202 -> :ok
        status -> {:error, {:http_error, status}}
      end
    else
      {:error, :license_key_required} -> {:error, :license_key_not_configured}
      {:error, reason} -> {:error, reason}
    end
  rescue
    error -> {:error, error}
  end

  defp send_new_relic_logs(logs) do
    config = Application.get_env(:raxol, :new_relic_config, %{})
    license_key = Map.get(config, :license_key)

    with {:ok, _} <- validate_license_key(license_key),
         new_relic_logs = Enum.map(logs, &format_new_relic_log/1),
         headers = [
           {"Content-Type", "application/json"},
           {"X-License-Key", license_key}
         ],
         {:ok, response} <-
           HTTPoison.post(
             "https://log-api.newrelic.com/log/v1",
             Jason.encode!(new_relic_logs),
             headers
           ) do
      case response.status_code do
        202 -> :ok
        status -> {:error, {:http_error, status}}
      end
    else
      {:error, :license_key_required} -> {:error, :license_key_not_configured}
      {:error, reason} -> {:error, reason}
    end
  rescue
    error -> {:error, error}
  end

  # Grafana backend implementation
  defp init_grafana(config) do
    url = Map.get(config, :url)
    api_key = Map.get(config, :api_key)

    with {:ok, _} <- validate_grafana_config(url, api_key) do
      {:ok, %{url: url, api_key: api_key}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_grafana_config(nil, _), do: {:error, :url_required}
  defp validate_grafana_config(_, nil), do: {:error, :api_key_required}
  defp validate_grafana_config(url, api_key) 
       when is_binary(url) and is_binary(api_key), do: {:ok, {url, api_key}}
  defp validate_grafana_config(_, _), do: {:error, :url_and_api_key_required}

  defp send_grafana_metrics(metrics) do
    config = Application.get_env(:raxol, :grafana_config, %{})
    url = Map.get(config, :url)
    api_key = Map.get(config, :api_key)

    with {:ok, _} <- validate_grafana_config(url, api_key),
         grafana_metrics = Enum.map(metrics, &format_grafana_metric/1),
         headers = [
           {"Content-Type", "application/json"},
           {"Authorization", "Bearer #{api_key}"}
         ],
         {:ok, response} <-
           HTTPoison.post(
             "#{url}/api/v1/push",
             Jason.encode!(grafana_metrics),
             headers
           ) do
      case response.status_code do
        200 -> :ok
        status -> {:error, {:http_error, status}}
      end
    else
      {:error, :url_required} -> {:error, :grafana_not_configured}
      {:error, :api_key_required} -> {:error, :grafana_not_configured}
      {:error, :url_and_api_key_required} -> {:error, :grafana_not_configured}
      {:error, reason} -> {:error, reason}
    end
  rescue
    error -> {:error, error}
  end

  defp send_grafana_logs(_logs) do
    # Grafana typically handles logs through Loki
    {:ok, :logs_handled_by_loki}
  end

  # Custom backend implementation
  defp init_custom_backend(config) do
    handler = Map.get(config, :handler)

    with {:ok, _} <- validate_handler(handler) do
      {:ok, %{handler: handler}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_handler(nil), do: {:error, :handler_required}
  defp validate_handler(handler) when is_function(handler, 2), do: {:ok, handler}
  defp validate_handler(_), do: {:error, :invalid_handler}

  defp send_custom_metrics(metrics) do
    config = Application.get_env(:raxol, :custom_monitoring_config, %{})
    handler = Map.get(config, :metrics_handler)

    with {:ok, _} <- validate_metrics_handler(handler) do
      try do
        handler.(metrics)
        :ok
      rescue
        error -> {:error, error}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_metrics_handler(nil), do: {:error, :handler_not_configured}
  defp validate_metrics_handler(handler) when is_function(handler, 1), do: {:ok, handler}
  defp validate_metrics_handler(_), do: {:error, :invalid_handler}

  defp send_custom_logs(logs) do
    config = Application.get_env(:raxol, :custom_monitoring_config, %{})
    handler = Map.get(config, :logs_handler)

    with {:ok, _} <- validate_logs_handler(handler) do
      try do
        handler.(logs)
        :ok
      rescue
        error -> {:error, error}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_logs_handler(nil), do: {:error, :handler_not_configured}
  defp validate_logs_handler(handler) when is_function(handler, 1), do: {:ok, handler}
  defp validate_logs_handler(_), do: {:error, :invalid_handler}

  # Format functions for different backends

  defp format_datadog_metric(%{
         name: name,
         value: value,
         tags: tags,
         timestamp: timestamp
       }) do
    %{
      metric: name,
      points: [[timestamp, value]],
      tags: format_tags_for_datadog(tags),
      type: "gauge"
    }
  end

  defp format_datadog_log(%{
         level: level,
         message: message,
         metadata: metadata,
         timestamp: timestamp
       }) do
    %{
      ddsource: "raxol",
      ddtags: format_tags_for_datadog(metadata),
      hostname: Map.get(metadata, :hostname, "unknown"),
      message: message,
      level: Atom.to_string(level),
      timestamp: timestamp
    }
  end

  defp format_new_relic_metric(%{
         name: name,
         value: value,
         tags: tags,
         timestamp: timestamp
       }) do
    %{
      name: name,
      type: "gauge",
      value: value,
      timestamp: timestamp,
      attributes: tags
    }
  end

  defp format_new_relic_log(%{
         level: level,
         message: message,
         metadata: metadata,
         timestamp: timestamp
       }) do
    Map.merge(metadata, %{
      message: message,
      level: Atom.to_string(level),
      timestamp: timestamp,
      service: "raxol"
    })
  end

  defp format_grafana_metric(%{
         name: name,
         value: value,
         tags: tags,
         timestamp: timestamp
       }) do
    %{
      name: name,
      value: value,
      time: timestamp,
      labels: tags
    }
  end

  defp format_tags_for_datadog(tags) when is_map(tags) do
    Enum.map(tags, fn {key, value} -> "#{key}:#{value}" end)
  end

  defp format_tags_for_datadog(_), do: []
end
