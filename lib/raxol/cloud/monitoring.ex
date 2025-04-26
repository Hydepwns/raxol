defmodule Raxol.Cloud.Monitoring do
  @moduledoc """
  Cloud monitoring system for Raxol applications.

  This module provides comprehensive monitoring capabilities for Raxol
  applications, including performance metrics, error tracking, usage statistics,
  and health checks.

  Features:
  * Performance monitoring and metrics collection
  * Error and exception tracking
  * Resource usage tracking
  * Health checks and status monitoring
  * Alerting and notification system
  * Integration with popular monitoring services
  """

  alias Raxol.Cloud.Monitoring.{Metrics, Errors, Health, Alerts}
  alias Raxol.Cloud.EdgeComputing

  # Monitoring state
  defmodule State do
    @moduledoc false
    defstruct [
      :active,
      :config,
      :current_session,
      :metrics,
      :errors,
      :health_status,
      :alert_history
    ]

    def new do
      %__MODULE__{
        active: false,
        config: %{
          # 10 seconds
          metrics_interval: 10000,
          # 1 minute
          health_check_interval: 60000,
          # 100%
          error_sample_rate: 1.0,
          metrics_batch_size: 100,
          # monitoring service backends
          backends: [],
          alert_thresholds: %{
            # 5% error rate
            error_rate: 0.05,
            # 1 second
            response_time: 1000,
            # 90% usage
            memory_usage: 0.9
          }
        },
        current_session: nil,
        metrics: %{},
        errors: [],
        health_status: :unknown,
        alert_history: []
      }
    end
  end

  # Process dictionary key for monitoring state
  @monitoring_key :raxol_monitoring_state

  @doc """
  Initializes the monitoring system.

  ## Options

  * `:active` - Whether monitoring should be active on start (default: true)
  * `:metrics_interval` - Interval in ms between metrics collection (default: 10000)
  * `:health_check_interval` - Interval in ms between health checks (default: 60000)
  * `:error_sample_rate` - Fraction of errors to track (0.0-1.0) (default: 1.0)
  * `:metrics_batch_size` - Number of metrics to batch before sending (default: 100)
  * `:backends` - List of monitoring service backends to use (default: [])
  * `:alert_thresholds` - Map of alert thresholds (default: see State.new)

  ## Examples

      iex> init(metrics_interval: 5000, backends: [:datadog, :prometheus])
      :ok
  """
  def init(opts \\ []) do
    state = State.new()

    # Override defaults with provided options
    config =
      Keyword.take(opts, [
        :metrics_interval,
        :health_check_interval,
        :error_sample_rate,
        :metrics_batch_size,
        :backends,
        :alert_thresholds
      ])

    # Update state with provided config
    state = update_config(state, config)

    # Set active state
    active = Keyword.get(opts, :active, true)
    state = %{state | active: active}

    # Initialize current session
    session_id = generate_session_id()
    state = %{state | current_session: session_id}

    # Store state
    Process.put(@monitoring_key, state)

    # Initialize components
    Metrics.init(state.config)
    Errors.init(state.config)
    Health.init(state.config)
    Alerts.init(state.config)

    # Start monitoring if active
    if active do
      _monitoring_pid = start_monitoring(state.config)
    end

    :ok
  end

  @doc """
  Updates the monitoring configuration.
  """
  def update_config(state \\ nil, config) do
    with_state(state, fn s ->
      # Merge new config with existing config
      updated_config = Map.merge(s.config, Map.new(config))
      %{s | config: updated_config}
    end)
  end

  @doc """
  Starts the monitoring system if it's not already active.
  """
  def start() do
    with_state(fn state ->
      if not state.active do
        # Start monitoring loops
        _monitoring_pid = start_monitoring(state.config)
        %{state | active: true}
      else
        state
      end
    end)

    :ok
  end

  @doc """
  Stops the monitoring system.
  """
  def stop() do
    with_state(fn state ->
      %{state | active: false}
    end)

    :ok
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
    state = get_state()

    if state.active do
      # Record metric
      Metrics.record(name, value, opts)

      # Check for alerts
      check_alert_threshold(name, value, opts)
    end

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
    state = get_state()

    if state.active do
      Enum.each(metrics, fn {name, value, opts} ->
        record_metric(name, value, opts)
      end)
    end

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
    state = get_state()

    if state.active do
      # Sample errors based on configuration
      if :rand.uniform() <= state.config.error_sample_rate do
        Errors.record(
          error,
          Keyword.put_new(opts, :session_id, state.current_session)
        )
      end
    end

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
    state = get_state()

    if state.active do
      # Run health check
      result = Health.check(opts)

      # Update state with health status
      with_state(fn s ->
        %{s | health_status: result.status}
      end)

      # Check if we need to trigger alerts
      if result.status == :unhealthy do
        trigger_alert(:unhealthy_system, %{
          message: "System health check failed",
          components: result.components
        })
      end

      {:ok, result}
    else
      {:error, :monitoring_inactive}
    end
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
    state = get_state()

    if state.active do
      # Create alert
      alert = %{
        id: generate_alert_id(),
        type: type,
        data: data,
        severity: Keyword.get(opts, :severity, :warning),
        timestamp: DateTime.utc_now(),
        session_id: state.current_session
      }

      # Add to alert history
      with_state(fn s ->
        updated_history = [alert | s.alert_history] |> Enum.take(100)
        %{s | alert_history: updated_history}
      end)

      # Process the alert
      Alerts.process(alert, opts)
    end

    :ok
  end

  @doc """
  Gets the current monitoring status.
  """
  def status() do
    state = get_state()

    %{
      active: state.active,
      session_id: state.current_session,
      health_status: state.health_status,
      metrics_count: Metrics.count(),
      errors_count: Errors.count(),
      alerts_count: length(state.alert_history),
      last_health_check: Health.last_check_time()
    }
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
    Metrics.get(name, opts)
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
    Errors.get(opts)
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
    state = get_state()

    limit = Keyword.get(opts, :limit, 100)

    since =
      Keyword.get(
        opts,
        :since,
        DateTime.add(DateTime.utc_now(), -24 * 60 * 60, :second)
      )

    until = Keyword.get(opts, :until, DateTime.utc_now())
    type = Keyword.get(opts, :type)
    severity = Keyword.get(opts, :severity)

    state.alert_history
    |> Enum.filter(fn alert ->
      DateTime.compare(alert.timestamp, since) in [:gt, :eq] &&
        DateTime.compare(alert.timestamp, until) in [:lt, :eq] &&
        (type == nil || alert.type == type) &&
        (severity == nil || alert.severity == severity)
    end)
    |> Enum.take(limit)
  end

  # Private functions

  defp with_state(arg1, arg2 \\ nil) do
    {state, fun} =
      if is_function(arg1) do
        {get_state(), arg1}
      else
        {arg1 || get_state(), arg2}
      end

    result = fun.(state)

    if is_map(result) and Map.has_key?(result, :active) do
      # If a state map is returned, update the state
      Process.put(@monitoring_key, result)
      result
    else
      # Otherwise just return the result
      result
    end
  end

  defp get_state() do
    Process.get(@monitoring_key) || State.new()
  end

  defp start_monitoring(config) do
    # Start metrics collection
    schedule_metrics_collection(config.metrics_interval)

    # Start health checks
    schedule_health_check(config.health_check_interval)
  end

  defp schedule_metrics_collection(interval) do
    spawn(fn ->
      Process.sleep(interval)

      state = get_state()

      if state.active do
        # Collect system metrics
        collect_system_metrics()

        # Schedule next collection
        schedule_metrics_collection(interval)
      end
    end)
  end

  defp schedule_health_check(interval) do
    spawn(fn ->
      Process.sleep(interval)

      state = get_state()

      if state.active do
        # Run health check
        _ = run_health_check()

        # Schedule next check
        _ = schedule_health_check(interval)
      end
    end)
  end

  defp collect_system_metrics() do
    # Collect various system metrics

    # Memory usage
    memory = :erlang.memory()
    total_memory = memory[:total]
    process_memory = memory[:processes]

    record_metric("memory.total", total_memory, source: :system)
    record_metric("memory.processes", process_memory, source: :system)

    record_metric("memory.usage_ratio", process_memory / total_memory,
      source: :system
    )

    # Process metrics
    process_count = length(:erlang.processes())
    record_metric("process.count", process_count, source: :system)

    # Runtime metrics
    runtime_info = :erlang.statistics(:runtime)
    uptime = :erlang.statistics(:wall_clock)

    runtime_ratio = elem(runtime_info, 0) / elem(uptime, 0)
    record_metric("runtime.ratio", runtime_ratio, source: :system)

    # Edge computing metrics (if available)
    if function_exported?(EdgeComputing, :get_metrics, 0) do
      edge_metrics = EdgeComputing.get_metrics()

      edge_metrics
      |> Enum.each(fn {name, value} ->
        record_metric("edge.#{name}", value, source: :edge)
      end)
    end

    # GC metrics
    record_metric(
      "gc.count",
      :erlang.statistics(:garbage_collection) |> elem(0),
      source: :system
    )

    # Reductions (work done)
    record_metric("reductions", :erlang.statistics(:reductions) |> elem(0),
      source: :system
    )
  end

  defp check_alert_threshold(name, value, _opts) do
    state = get_state()
    thresholds = state.config.alert_thresholds

    # Check specific metric thresholds
    case name do
      "memory.usage_ratio" when value > thresholds.memory_usage ->
        trigger_alert(
          :high_memory_usage,
          %{
            value: value,
            threshold: thresholds.memory_usage
          },
          severity: determine_severity(value, thresholds.memory_usage)
        )

      "response_time" when value > thresholds.response_time ->
        trigger_alert(
          :high_response_time,
          %{
            value: value,
            threshold: thresholds.response_time
          },
          severity: determine_severity(value, thresholds.response_time)
        )

      "error_rate" when value > thresholds.error_rate ->
        trigger_alert(
          :high_error_rate,
          %{
            value: value,
            threshold: thresholds.error_rate
          },
          severity: determine_severity(value, thresholds.error_rate)
        )

      _ ->
        # No threshold hit
        :ok
    end
  end

  defp determine_severity(value, threshold) do
    cond do
      value > threshold * 2.0 -> :critical
      value > threshold * 1.5 -> :error
      value > threshold * 1.2 -> :warning
      true -> :info
    end
  end

  defp generate_session_id() do
    "session_#{:erlang.system_time(:microsecond)}_#{:rand.uniform(1_000_000)}"
  end

  defp generate_alert_id() do
    "alert_#{:erlang.system_time(:microsecond)}_#{:rand.uniform(1_000_000)}"
  end
end
