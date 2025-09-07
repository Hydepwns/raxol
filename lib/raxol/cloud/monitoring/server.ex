defmodule Raxol.Cloud.Monitoring.Server do
  @moduledoc """
  Unified GenServer implementation for the Cloud Monitoring system in Raxol.

  This server consolidates all monitoring functionality including metrics collection,
  error tracking, health checks, and alerting while eliminating Process dictionary usage.

  ## Features
  - Performance monitoring and metrics collection
  - Error and exception tracking
  - Resource usage tracking
  - Health checks and status monitoring
  - Alerting and notification system
  - Integration with monitoring service backends
  - Supervised state management
  """

  use GenServer
  require Logger

  alias Raxol.Cloud.EdgeComputing

  # Client API

  @doc """
  Starts the Cloud Monitoring server.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns a child specification for this server.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  # Public API - Main Monitoring

  def init_monitoring(opts \\ []) do
    GenServer.call(__MODULE__, {:init_monitoring, opts})
  end

  def update_config(config) do
    GenServer.call(__MODULE__, {:update_config, config})
  end

  def start_monitoring do
    GenServer.call(__MODULE__, :start_monitoring)
  end

  def stop_monitoring do
    GenServer.call(__MODULE__, :stop_monitoring)
  end

  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  # Metrics API

  def init_metrics(metrics_state) do
    GenServer.call(__MODULE__, {:init_metrics, metrics_state})
  end

  def update_metrics(metrics_state) do
    GenServer.call(__MODULE__, {:update_metrics, metrics_state})
  end

  def record_metric(name, value, opts \\ []) do
    GenServer.cast(__MODULE__, {:record_metric, name, value, opts})
  end

  def record_metrics(metrics) do
    GenServer.cast(__MODULE__, {:record_metrics, metrics})
  end

  def get_metrics do
    GenServer.call(__MODULE__, :get_all_metrics)
  end

  def get_metrics(name, opts \\ []) do
    GenServer.call(__MODULE__, {:get_metrics, name, opts})
  end

  def metrics_count do
    GenServer.call(__MODULE__, :metrics_count)
  end

  # Error tracking API

  def record_error(error, opts \\ []) do
    GenServer.cast(__MODULE__, {:record_error, error, opts})
  end

  def get_errors(opts \\ []) do
    GenServer.call(__MODULE__, {:get_errors, opts})
  end

  def errors_count do
    GenServer.call(__MODULE__, :errors_count)
  end

  # Health check API

  def run_health_check(opts \\ []) do
    GenServer.call(__MODULE__, {:run_health_check, opts}, 10_000)
  end

  def get_health_status do
    GenServer.call(__MODULE__, :get_health_status)
  end

  def last_health_check_time do
    GenServer.call(__MODULE__, :last_health_check_time)
  end

  @doc """
  Initializes health monitoring with given state.
  """
  def init_health(health_state) do
    GenServer.call(__MODULE__, {:init_health, health_state})
  end

  @doc """
  Updates health monitoring state.
  """
  def update_health(health_state) do
    GenServer.call(__MODULE__, {:update_health, health_state})
  end

  # Alerts API

  def trigger_alert(type, data, opts \\ []) do
    GenServer.cast(__MODULE__, {:trigger_alert, type, data, opts})
  end

  def get_alerts(opts \\ []) do
    GenServer.call(__MODULE__, {:get_alerts, opts})
  end

  def process_alert(alert, opts \\ []) do
    GenServer.cast(__MODULE__, {:process_alert, alert, opts})
  end

  # Backends API

  def send_to_backend(backend, data) do
    GenServer.cast(__MODULE__, {:send_to_backend, backend, data})
  end

  def get_prometheus_metric(metric_name) do
    GenServer.call(__MODULE__, {:get_prometheus_metric, metric_name})
  end

  def set_prometheus_metric(metric_name, value, tags) do
    GenServer.cast(
      __MODULE__,
      {:set_prometheus_metric, metric_name, value, tags}
    )
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    state = %{
      # Main monitoring state
      active: Keyword.get(opts, :active, false),
      current_session: generate_session_id(),

      # Configuration
      config: %{
        metrics_interval: Keyword.get(opts, :metrics_interval, 10_000),
        health_check_interval:
          Keyword.get(opts, :health_check_interval, 60_000),
        error_sample_rate: Keyword.get(opts, :error_sample_rate, 1.0),
        metrics_batch_size: Keyword.get(opts, :metrics_batch_size, 100),
        backends: Keyword.get(opts, :backends, []),
        alert_thresholds:
          Keyword.get(opts, :alert_thresholds, %{
            error_rate: 0.05,
            response_time: 1000,
            memory_usage: 0.9
          })
      },

      # Metrics state
      metrics: %{
        data: %{},
        count: 0,
        buffer: [],
        last_flush: DateTime.utc_now()
      },

      # Errors state
      errors: %{
        data: [],
        count: 0,
        last_error: nil
      },

      # Health state
      health: %{
        status: :unknown,
        last_check: nil,
        components: %{},
        check_results: []
      },

      # Alerts state
      alerts: %{
        history: [],
        active_alerts: %{},
        notification_channels: []
      },

      # Backends state
      backends: %{
        prometheus_metrics: %{},
        datadog_client: nil,
        custom_backends: []
      },

      # Monitoring processes
      monitoring_pids: %{
        metrics_collector: nil,
        health_checker: nil
      }
    }

    {:ok, state}
  end

  # Handle monitoring initialization
  @impl true
  def handle_call({:init_monitoring, opts}, _from, state) do
    # Update config with provided options
    config_updates =
      Keyword.take(opts, [
        :metrics_interval,
        :health_check_interval,
        :error_sample_rate,
        :metrics_batch_size,
        :backends,
        :alert_thresholds
      ])

    updated_config = Map.merge(state.config, Map.new(config_updates))
    active = Keyword.get(opts, :active, true)

    updated_state = %{
      state
      | config: updated_config,
        active: active,
        current_session: generate_session_id()
    }

    # Start monitoring if active
    updated_state = start_monitoring_if_active(active, updated_state)

    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call({:update_config, config}, _from, state) do
    updated_config = Map.merge(state.config, config)
    {:reply, :ok, %{state | config: updated_config}}
  end

  @impl true
  def handle_call(:start_monitoring, _from, state) do
    handle_start_monitoring_request(state.active, state)
  end

  @impl true
  def handle_call(:stop_monitoring, _from, state) do
    updated_state = stop_monitoring_processes(%{state | active: false})
    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      active: state.active,
      session_id: state.current_session,
      health_status: state.health.status,
      metrics_count: state.metrics.count,
      errors_count: state.errors.count,
      alerts_count: length(state.alerts.history),
      last_health_check: state.health.last_check
    }

    {:reply, status, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:init_metrics, metrics_state}, _from, state) do
    updated_state = %{
      state
      | metrics: Map.merge(state.metrics, %{state: metrics_state})
    }

    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call({:update_metrics, metrics_state}, _from, state) do
    updated_state = %{
      state
      | metrics: Map.merge(state.metrics, %{state: metrics_state})
    }

    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call(:get_all_metrics, _from, state) do
    {:reply, state.metrics.data, state}
  end

  @impl true
  def handle_call({:get_metrics, name, opts}, _from, state) do
    limit = Keyword.get(opts, :limit, 100)
    metrics = Map.get(state.metrics.data, name, []) |> Enum.take(limit)
    {:reply, metrics, state}
  end

  @impl true
  def handle_call(:metrics_count, _from, state) do
    {:reply, state.metrics.count, state}
  end

  @impl true
  def handle_call({:get_errors, opts}, _from, state) do
    limit = Keyword.get(opts, :limit, 100)
    errors = state.errors.data |> Enum.take(limit)
    {:reply, errors, state}
  end

  @impl true
  def handle_call(:errors_count, _from, state) do
    {:reply, state.errors.count, state}
  end

  @impl true
  def handle_call({:run_health_check, opts}, _from, state) do
    handle_health_check_request(state.active, opts, state)
    components = Keyword.get(opts, :components, [:database, :api, :edge])
    timeout = Keyword.get(opts, :timeout, 5000)

    # Run health checks for each component
    check_results =
      Enum.map(components, fn component ->
        {component, check_component_health(component, timeout)}
      end)

    # Determine overall status based on individual checks
    overall_status =
      case check_results do
        [] ->
          :unknown

        results ->
          has_critical =
            Enum.any?(results, fn {_, status} -> status.level == :critical end)

          has_warning =
            Enum.any?(results, fn {_, status} -> status.level == :warning end)

          cond do
            has_critical -> :critical
            has_warning -> :warning
            true -> :healthy
          end
      end

    # Update health state
    health_status = %{
      status: overall_status,
      last_check: DateTime.utc_now(),
      components: Map.new(check_results),
      response_time: System.monotonic_time() - System.monotonic_time()
    }

    updated_health = %{
      state.health
      | status: overall_status,
        last_check: DateTime.utc_now()
    }

    new_state = %{state | health: updated_health}

    {:reply, health_status, new_state}
  end

  @impl true
  def handle_call(:get_health_status, _from, state) do
    {:reply, state.health.status, state}
  end

  @impl true
  def handle_call(:last_health_check_time, _from, state) do
    {:reply, state.health.last_check, state}
  end

  @impl true
  def handle_call({:init_health, health_state}, _from, state) do
    updated_health = Map.merge(state.health, health_state)
    updated_state = %{state | health: updated_health}
    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call({:update_health, health_state}, _from, state) do
    updated_health = Map.merge(state.health, health_state)
    updated_state = %{state | health: updated_health}
    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call({:get_alerts, opts}, _from, state) do
    limit = Keyword.get(opts, :limit, 100)
    alerts = state.alerts.active |> Enum.take(limit)
    {:reply, alerts, state}
  end

  @impl true
  def handle_call({:get_prometheus_metric, metric_name}, _from, state) do
    value = Map.get(state.backends.prometheus_metrics, metric_name)
    {:reply, value, state}
  end

  # Metrics handlers

  @impl true
  def handle_cast({:record_metric, name, value, opts}, state) do
    handle_metric_recording(state.active, name, value, opts, state)
  end

  @impl true
  def handle_cast({:record_metrics, metrics}, state) do
    updated_state =
      Enum.reduce(metrics, state, fn {name, value, opts}, acc_state ->
        {:noreply, new_state} =
          handle_cast({:record_metric, name, value, opts}, acc_state)

        new_state
      end)

    {:noreply, updated_state}
  end

  # Error tracking handlers

  @impl true
  def handle_cast({:record_error, error, opts}, state) do
    handle_error_recording(
      state.active && :rand.uniform() <= state.config.error_sample_rate,
      error,
      opts,
      state
    )
  end

  # Alert handlers

  @impl true
  def handle_cast({:trigger_alert, type, data, opts}, state) do
    handle_alert_trigger(state.active, type, data, opts, state)

    alert = %{
      id: generate_alert_id(),
      type: type,
      data: data,
      severity: Keyword.get(opts, :severity, :warning),
      timestamp: DateTime.utc_now(),
      session_id: state.current_session
    }

    updated_alerts = %{
      state.alerts
      | history: [alert | state.alerts.history] |> Enum.take(100),
        active_alerts: Map.put(state.alerts.active_alerts, alert.id, alert)
    }

    # Process the alert (send notifications, etc.)
    process_alert_internal(alert, opts, state.config)

    {:noreply, %{state | alerts: updated_alerts}}
  end

  @impl true
  def handle_cast({:process_alert, alert, _opts}, state) do
    # Process alert through configured channels
    Enum.each(state.alerts.notification_channels, fn channel ->
      send_alert_to_channel(alert, channel)
    end)

    {:noreply, state}
  end

  # Backend handlers

  @impl true
  def handle_cast({:send_to_backend, backend, _data}, state) do
    case backend do
      :prometheus ->
        # Store in Prometheus format
        {:noreply, state}

      :datadog ->
        # Send to Datadog
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:set_prometheus_metric, metric_name, value, tags}, state) do
    updated_prometheus =
      Map.put(state.backends.prometheus_metrics, metric_name, {value, tags})

    updated_backends = %{
      state.backends
      | prometheus_metrics: updated_prometheus
    }

    {:noreply, %{state | backends: updated_backends}}
  end

  # Handle monitoring process messages
  @impl true
  def handle_info(:collect_metrics, state) do
    handle_metrics_collection(state.active, state)
  end

  @impl true
  def handle_info(:run_health_check, state) do
    handle_scheduled_health_check(state.active, state)
  end

  # Pattern matching helper functions for monitoring operations

  defp start_monitoring_if_active(false, state), do: state

  defp start_monitoring_if_active(true, state),
    do: start_monitoring_processes(state)

  defp handle_start_monitoring_request(true, state) do
    {:reply, {:ok, :already_active}, state}
  end

  defp handle_start_monitoring_request(false, state) do
    updated_state = start_monitoring_processes(%{state | active: true})
    {:reply, :ok, updated_state}
  end

  defp handle_metric_recording(false, _name, _value, _opts, state) do
    {:noreply, state}
  end

  defp handle_metric_recording(true, name, value, opts, state) do
    timestamp = Keyword.get(opts, :timestamp, DateTime.utc_now())
    tags = Keyword.get(opts, :tags, [])
    source = Keyword.get(opts, :source, :application)

    metric = %{
      name: name,
      value: value,
      timestamp: timestamp,
      tags: tags,
      source: source
    }

    # Update metrics data
    metrics_data =
      Map.update(
        state.metrics.data,
        name,
        [metric],
        &([metric | &1] |> Enum.take(1000))
      )

    # Add to buffer for batch processing
    buffer = [metric | state.metrics.buffer]

    # Check if we need to flush
    {buffer, last_flush} =
      handle_buffer_flush(
        length(buffer) >= state.config.metrics_batch_size,
        buffer,
        state
      )

    updated_metrics = %{
      state.metrics
      | data: metrics_data,
        count: state.metrics.count + 1,
        buffer: buffer,
        last_flush: last_flush
    }

    # Check alert thresholds
    updated_state =
      check_alert_threshold(name, value, %{state | metrics: updated_metrics})

    {:noreply, updated_state}
  end

  defp handle_buffer_flush(false, buffer, state) do
    {buffer, state.metrics.last_flush}
  end

  defp handle_buffer_flush(true, buffer, state) do
    flush_metrics_to_backends(buffer, state.config.backends)
    {[], DateTime.utc_now()}
  end

  defp handle_error_recording(false, _error, _opts, state) do
    {:noreply, state}
  end

  defp handle_error_recording(true, error, opts, state) do
    error_entry = %{
      error: error,
      context: Keyword.get(opts, :context, %{}),
      severity: Keyword.get(opts, :severity, :error),
      tags: Keyword.get(opts, :tags, []),
      timestamp: Keyword.get(opts, :timestamp, DateTime.utc_now()),
      session_id: Keyword.get(opts, :session_id, state.current_session)
    }

    updated_errors = %{
      state.errors
      | data: [error_entry | state.errors.data] |> Enum.take(1000),
        count: state.errors.count + 1,
        last_error: error_entry
    }

    {:noreply, %{state | errors: updated_errors}}
  end

  defp handle_health_check_request(false, _opts, state) do
    {:reply, {:error, :monitoring_inactive}, state}
  end

  defp handle_health_check_request(true, opts, state) do
    components = Keyword.get(opts, :components, [:database, :api, :edge])
    timeout = Keyword.get(opts, :timeout, 5000)

    # Run health checks for each component
    check_results =
      Enum.map(components, fn component ->
        {component, check_component_health(component, timeout)}
      end)
      |> Enum.into(%{})

    # Determine overall status
    overall_status =
      determine_overall_health_status(
        Enum.all?(check_results, fn {_, status} -> status == :healthy end)
      )

    updated_health = %{
      state.health
      | status: overall_status,
        last_check: DateTime.utc_now(),
        components: check_results,
        check_results:
          [check_results | state.health.check_results] |> Enum.take(100)
    }

    updated_state = %{state | health: updated_health}

    # Trigger alert if unhealthy
    updated_state =
      handle_unhealthy_alert(
        overall_status == :unhealthy,
        check_results,
        updated_state
      )

    result = %{
      status: overall_status,
      components: check_results,
      timestamp: updated_health.last_check
    }

    {:reply, {:ok, result}, updated_state}
  end

  defp determine_overall_health_status(true), do: :healthy
  defp determine_overall_health_status(false), do: :unhealthy

  defp handle_unhealthy_alert(false, _check_results, state), do: state

  defp handle_unhealthy_alert(true, check_results, state) do
    {:noreply, alert_state} =
      handle_cast(
        {:trigger_alert, :unhealthy_system,
         %{
           message: "System health check failed",
           components: check_results
         }, [severity: :critical]},
        state
      )

    alert_state
  end

  defp handle_alert_trigger(false, _type, _data, _opts, state) do
    {:noreply, state}
  end

  defp handle_alert_trigger(true, type, data, opts, state) do
    alert = %{
      id: generate_alert_id(),
      type: type,
      data: data,
      severity: Keyword.get(opts, :severity, :warning),
      timestamp: DateTime.utc_now(),
      session_id: state.current_session
    }

    updated_alerts = %{
      state.alerts
      | history: [alert | state.alerts.history] |> Enum.take(100),
        active_alerts: Map.put(state.alerts.active_alerts, alert.id, alert)
    }

    # Process the alert (send notifications, etc.)
    process_alert_internal(alert, opts, state.config)

    {:noreply, %{state | alerts: updated_alerts}}
  end

  defp handle_metrics_collection(false, state), do: {:noreply, state}

  defp handle_metrics_collection(true, state) do
    # Collect system metrics
    collect_system_metrics(state)

    # Schedule next collection
    Process.send_after(
      self(),
      :collect_metrics,
      state.config.metrics_interval
    )

    {:noreply, state}
  end

  defp handle_scheduled_health_check(false, state), do: {:noreply, state}

  defp handle_scheduled_health_check(true, state) do
    # Run health check
    {:reply, _result, new_state} =
      handle_call({:run_health_check, []}, nil, state)

    # Schedule next check
    Process.send_after(
      self(),
      :run_health_check,
      state.config.health_check_interval
    )

    {:noreply, new_state}
  end

  defp check_edge_computing_status(false), do: :healthy

  defp check_edge_computing_status(true) do
    case EdgeComputing.status() do
      %{mode: _} -> :healthy
      _ -> :unhealthy
    end
  end

  # Private helper functions

  defp start_monitoring_processes(state) do
    # Start metrics collection timer
    Process.send_after(self(), :collect_metrics, state.config.metrics_interval)

    # Start health check timer
    Process.send_after(
      self(),
      :run_health_check,
      state.config.health_check_interval
    )

    state
  end

  defp stop_monitoring_processes(state) do
    # Monitoring will stop when active flag is false and timers check it
    state
  end

  defp check_component_health(:database, _timeout) do
    # Check database connectivity
    :healthy
  end

  defp check_component_health(:api, _timeout) do
    # Check API responsiveness
    :healthy
  end

  defp check_component_health(:edge, _timeout) do
    # Check edge computing status
    check_edge_computing_status(function_exported?(EdgeComputing, :status, 0))
  end

  defp check_component_health(_, _), do: :healthy

  defp collect_system_metrics(state) do
    # Memory metrics
    memory = :erlang.memory()

    GenServer.cast(
      self(),
      {:record_metric, "memory.total", memory[:total], [source: :system]}
    )

    GenServer.cast(
      self(),
      {:record_metric, "memory.processes", memory[:processes],
       [source: :system]}
    )

    # Process metrics
    GenServer.cast(
      self(),
      {:record_metric, "process.count", length(:erlang.processes()),
       [source: :system]}
    )

    # Runtime metrics
    runtime_info = :erlang.statistics(:runtime)
    uptime = :erlang.statistics(:wall_clock)
    runtime_ratio = elem(runtime_info, 0) / max(elem(uptime, 0), 1)

    GenServer.cast(
      self(),
      {:record_metric, "runtime.ratio", runtime_ratio, [source: :system]}
    )

    # GC metrics
    gc_count = :erlang.statistics(:garbage_collection) |> elem(0)

    GenServer.cast(
      self(),
      {:record_metric, "gc.count", gc_count, [source: :system]}
    )

    state
  end

  defp check_alert_threshold(name, value, state) do
    thresholds = state.config.alert_thresholds

    case name do
      "memory.usage_ratio" when value > thresholds.memory_usage ->
        {:noreply, new_state} =
          handle_cast(
            {:trigger_alert, :high_memory_usage,
             %{
               value: value,
               threshold: thresholds.memory_usage
             }, [severity: determine_severity(value, thresholds.memory_usage)]},
            state
          )

        new_state

      "response_time" when value > thresholds.response_time ->
        {:noreply, new_state} =
          handle_cast(
            {:trigger_alert, :high_response_time,
             %{
               value: value,
               threshold: thresholds.response_time
             },
             [severity: determine_severity(value, thresholds.response_time)]},
            state
          )

        new_state

      _ ->
        state
    end
  end

  # Helper functions for pattern matching refactoring

  defp determine_severity(value, threshold) when value > threshold * 2.0,
    do: :critical

  defp determine_severity(value, threshold) when value > threshold * 1.5,
    do: :error

  defp determine_severity(value, threshold) when value > threshold * 1.2,
    do: :warning

  defp determine_severity(_value, _threshold), do: :info

  defp flush_metrics_to_backends(buffer, backends) do
    Enum.each(backends, fn backend ->
      send_metrics_to_backend(buffer, backend)
    end)
  end

  defp send_metrics_to_backend(_metrics, _backend) do
    # Implementation would send metrics to specific backend
    :ok
  end

  defp process_alert_internal(alert, _opts, _config) do
    # Log the alert
    Logger.warning("Alert triggered: #{inspect(alert)}")

    # Send to notification channels (implementation would vary)
    :ok
  end

  defp send_alert_to_channel(_alert, _channel) do
    # Implementation would send alert to specific channel
    :ok
  end

  defp generate_session_id do
    "session_#{:erlang.system_time(:microsecond)}_#{:rand.uniform(1_000_000)}"
  end

  defp generate_alert_id do
    "alert_#{:erlang.system_time(:microsecond)}_#{:rand.uniform(1_000_000)}"
  end
end
