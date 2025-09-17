defmodule Raxol.Cloud.Monitoring do
  @moduledoc """
  Refactored Cloud Monitoring module with GenMonitoringServer-based state management.

  This module provides backward compatibility while eliminating Process dictionary usage.
  All state is now managed through the Cloud.Monitoring.MonitoringServer GenMonitoringServer.

  ## Migration Notes

  This module replaces direct Process dictionary usage with supervised GenMonitoringServer state.
  The API remains the same, but the implementation is now OTP-compliant and more robust.

  ## Features Maintained

  * Performance monitoring and metrics collection
  * Error and exception tracking
  * Resource usage tracking
  * Health checks and status monitoring
  * Alerting and notification system
  * Integration with popular monitoring services
  """

  alias Raxol.Cloud.Monitoring.MonitoringServer

  @deprecated "Use Raxol.Cloud.Monitoring instead of Raxol.Cloud.Monitoring"

  # Ensure server is started
  defp ensure_server_started do
    case Process.whereis(MonitoringServer) do
      nil ->
        {:ok, _pid} = MonitoringServer.start_link()
        :ok

      _pid ->
        :ok
    end
  end

  @doc """
  Initializes the monitoring system.

  ## Options

  * `:active` - Whether monitoring should be active on start (default: true)
  * `:metrics_interval` - Interval in ms between metrics collection (default: 10000)
  * `:health_check_interval` - Interval in ms between health checks (default: 60_000)
  * `:error_sample_rate` - Fraction of errors to track (0.0-1.0) (default: 1.0)
  * `:metrics_batch_size` - Number of metrics to batch before sending (default: 100)
  * `:backends` - List of monitoring service backends to use (default: [])
  * `:alert_thresholds` - Map of alert thresholds

  ## Examples

      iex> init(metrics_interval: 5000, backends: [:datadog, :prometheus])
      :ok
  """
  def init(opts \\ []) do
    ensure_server_started()
    MonitoringServer.init_monitoring(opts)
  end

  @doc """
  Updates the monitoring configuration.
  """
  def update_config(_state \\ nil, config) do
    ensure_server_started()
    MonitoringServer.update_config(config)
  end

  @doc """
  Starts the monitoring system if it's not already active.
  """
  def start do
    ensure_server_started()
    MonitoringServer.start_monitoring()
  end

  @doc """
  Stops the monitoring system.
  """
  def stop do
    ensure_server_started()
    MonitoringServer.stop_monitoring()
  end

  @doc """
  Records a metric with the given name and value.

  ## Options

  * `:tags` - List of tags to associate with the metric
  * `:timestamp` - Custom timestamp for the metric (default: current time)
  * `:source` - Source of the metric (default: :application)

  ## Examples

      iex> record_metric("response_time", 123, tags: ["api", "users"], source: :api)
      :ok
  """
  def record_metric(name, value, opts \\ []) do
    ensure_server_started()
    MonitoringServer.record_metric(name, value, opts)
    :ok
  end

  @doc """
  Records a batch of metrics.

  ## Examples

      iex> record_metrics([
      ...>   {"cpu_usage", 0.75, [source: :system]},
      ...>   {"memory_usage", 0.5, [source: :system]}
      ...> ])
      :ok
  """
  def record_metrics(metrics) do
    ensure_server_started()
    MonitoringServer.record_metrics(metrics)
    :ok
  end

  @doc """
  Records an error or exception.

  ## Options

  * `:context` - Additional context information about the error
  * `:severity` - Severity level (:debug, :info, :warning, :error, :critical)
  * `:tags` - List of tags to associate with the error
  * `:timestamp` - Custom timestamp for the error (default: current time)

  ## Examples

      iex> record_error(%RuntimeError{message: "Connection failed"},
      ...>   context: %{user_id: 123}, severity: :error)
      :ok
  """
  def record_error(error, opts \\ []) do
    ensure_server_started()
    MonitoringServer.record_error(error, opts)
    :ok
  end

  @doc """
  Runs a health check on the system.

  ## Options

  * `:components` - List of components to check (default: all)
  * `:timeout` - Timeout for health checks in milliseconds (default: 5000)

  ## Examples

      iex> run_health_check(components: [:database, :api])
      {:ok, %{status: :healthy, components: %{database: :healthy, api: :healthy}}}
  """
  def run_health_check(opts \\ []) do
    ensure_server_started()
    MonitoringServer.run_health_check(opts)
  end

  @doc """
  Triggers an alert with the given type and data.

  ## Options

  * `:severity` - Severity level of the alert (default: :warning)
  * `:notify` - Whether to send notifications (default: true)

  ## Examples

      iex> trigger_alert(:high_cpu_usage, %{value: 0.95}, severity: :critical)
      :ok
  """
  def trigger_alert(type, data, opts \\ []) do
    ensure_server_started()
    MonitoringServer.trigger_alert(type, data, opts)
    :ok
  end

  @doc """
  Gets the current monitoring status.
  """
  def status do
    ensure_server_started()
    MonitoringServer.get_status()
  end

  @doc """
  Gets recent metrics for the specified metric name.

  ## Options

  * `:limit` - Maximum number of metrics to return (default: 100)
  * `:since` - Only return metrics since this timestamp (default: 1 hour ago)
  * `:until` - Only return metrics until this timestamp (default: now)
  * `:tags` - Filter metrics by tags

  ## Examples

      iex> get_metrics("response_time", limit: 10, tags: ["api"])
      [%{name: "response_time", value: 123, timestamp: ~U[2023-01-01 12:00:00Z], tags: ["api"]}]
  """
  def get_metrics(name, opts \\ []) do
    ensure_server_started()
    MonitoringServer.get_metrics(name, opts)
  end

  @doc """
  Gets recent errors.

  ## Options

  * `:limit` - Maximum number of errors to return (default: 100)
  * `:since` - Only return errors since this timestamp (default: 1 day ago)
  * `:until` - Only return errors until this timestamp (default: now)
  * `:severity` - Filter errors by severity
  * `:tags` - Filter errors by tags

  ## Examples

      iex> get_errors(limit: 10, severity: :critical)
      [%{error: %RuntimeError{...}, severity: :critical, ...}]
  """
  def get_errors(opts \\ []) do
    ensure_server_started()
    MonitoringServer.get_errors(opts)
  end

  @doc """
  Gets recent alerts.

  ## Options

  * `:limit` - Maximum number of alerts to return (default: 100)
  * `:since` - Only return alerts since this timestamp (default: 1 day ago)
  * `:until` - Only return alerts until this timestamp (default: now)
  * `:type` - Filter alerts by type
  * `:severity` - Filter alerts by severity

  ## Examples

      iex> get_alerts(limit: 10, severity: :critical)
      [%{type: :high_cpu_usage, severity: :critical, ...}]
  """
  def get_alerts(opts \\ []) do
    ensure_server_started()
    MonitoringServer.get_alerts(opts)
  end
end
