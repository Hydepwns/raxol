defmodule Raxol.Terminal.Metrics.UnifiedMetrics do
  @moduledoc """
  Unified metrics system for the Raxol terminal emulator.
  This module provides centralized metrics collection for:
  - Performance metrics (response times, throughput)
  - Resource usage (memory, CPU)
  - Error tracking
  - Usage statistics
  """

  use GenServer
  require Logger

  # Types
  @type metric_id :: term()
  @type metric_value :: number() | map() | list()
  @type metric_type :: :counter | :gauge | :histogram | :summary
  @type metric_state :: %{
          id: metric_id(),
          type: metric_type(),
          value: metric_value(),
          timestamp: integer(),
          labels: map(),
          metadata: map()
        }
  @type metric_config :: %{
          retention_period: non_neg_integer(),
          aggregation_interval: non_neg_integer(),
          alert_thresholds: map(),
          export_format: :prometheus | :json | :custom
        }

  # Client API

  # Helper function to get the process name
  defp process_name(pid) when is_pid(pid), do: pid
  defp process_name(name) when is_atom(name), do: name
  defp process_name(_), do: __MODULE__

  @doc """
  Starts the unified metrics manager.

  ## Options
    * `:retention_period` - How long to keep metrics (in milliseconds)
    * `:aggregation_interval` - How often to aggregate metrics (in milliseconds)
    * `:alert_thresholds` - Thresholds for alerting
    * `:export_format` - Format for exporting metrics
  """
  def start_link(opts \\ []) do
    opts = if is_map(opts), do: Enum.into(opts, []), else: opts
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Records a metric value.

  ## Parameters
    * `name` - The metric name
    * `value` - The metric value
    * `opts` - Recording options
      * `:type` - Metric type (:counter, :gauge, :histogram, :summary)
      * `:labels` - Metric labels
      * `:metadata` - Additional metadata
  """
  def record_metric(name, value, opts \\ [], process \\ __MODULE__) do
    GenServer.call(process_name(process), {:record_metric, name, value, opts})
  end

  @doc """
  Gets the current value of a metric.

  ## Parameters
    * `name` - The metric name
    * `opts` - Get options
      * `:labels` - Filter by labels
      * `:time_range` - Time range to query
  """
  def get_metric(name, opts \\ [], process \\ __MODULE__) do
    GenServer.call(process_name(process), {:get_metric, name, opts})
  end

  @doc """
  Records an error event.

  ## Parameters
    * `error` - The error to record
    * `opts` - Recording options
      * `:severity` - Error severity
      * `:context` - Error context
      * `:metadata` - Additional metadata
  """
  def record_error(error, opts \\ [], process \\ __MODULE__) do
    GenServer.call(process_name(process), {:record_error, error, opts})
  end

  @doc """
  Gets error statistics.

  ## Parameters
    * `opts` - Get options
      * `:time_range` - Time range to query
      * `:severity` - Filter by severity
  """
  def get_error_stats(opts \\ [], process \\ __MODULE__) do
    GenServer.call(process_name(process), {:get_error_stats, opts})
  end

  @doc """
  Exports metrics in the configured format.

  ## Parameters
    * `opts` - Export options
      * `:format` - Override the default export format
      * `:time_range` - Time range to export
  """
  def export_metrics(opts \\ [], process \\ __MODULE__) do
    GenServer.call(process_name(process), {:export_metrics, opts})
  end

  @doc """
  Cleans up old metrics.

  ## Parameters
    * `opts` - Cleanup options
      * `:before` - Timestamp before which to clean up
  """
  def cleanup_metrics(opts \\ [], process \\ __MODULE__) do
    GenServer.call(process_name(process), {:cleanup_metrics, opts})
  end

  # Server Callbacks

  def init(opts) do
    # 24 hours
    retention_period = Keyword.get(opts, :retention_period, 24 * 60 * 60 * 1000)
    # 1 minute
    aggregation_interval = Keyword.get(opts, :aggregation_interval, 60 * 1000)
    alert_thresholds = Keyword.get(opts, :alert_thresholds, %{})
    export_format = Keyword.get(opts, :export_format, :prometheus)

    state = %{
      metrics: %{},
      errors: [],
      config: %{
        retention_period: retention_period,
        aggregation_interval: aggregation_interval,
        alert_thresholds: alert_thresholds,
        export_format: export_format
      },
      last_aggregation: System.system_time(:millisecond)
    }

    schedule_aggregation(aggregation_interval)
    {:ok, state}
  end

  def handle_call({:record_metric, name, value, opts}, _from, state) do
    type = Keyword.get(opts, :type, :gauge)
    labels = Keyword.get(opts, :labels, %{})
    metadata = Keyword.get(opts, :metadata, %{})

    metric = %{
      id: generate_metric_id(),
      type: type,
      value: value,
      timestamp: System.system_time(:millisecond),
      labels: labels,
      metadata: metadata
    }

    updated_metrics = Map.update(state.metrics, name, [metric], &[metric | &1])
    updated_state = %{state | metrics: updated_metrics}

    check_alerts(name, metric, state.config.alert_thresholds)

    {:reply, :ok, updated_state}
  end

  def handle_call({:get_metric, name, opts}, _from, state) do
    case Map.get(state.metrics, name) do
      nil ->
        {:reply, {:error, :metric_not_found}, state}

      metrics ->
        filtered_metrics = filter_metrics(metrics, opts)
        aggregated_value = aggregate_metrics(filtered_metrics)
        {:reply, {:ok, aggregated_value}, state}
    end
  end

  def handle_call({:record_error, error, opts}, _from, state) do
    severity = Keyword.get(opts, :severity, :error)
    context = Keyword.get(opts, :context, %{})
    metadata = Keyword.get(opts, :metadata, %{})

    error_record = %{
      error: error,
      severity: severity,
      context: context,
      metadata: metadata,
      timestamp: System.system_time(:millisecond)
    }

    updated_errors = [error_record | state.errors]
    updated_state = %{state | errors: updated_errors}

    check_error_alerts(error_record, state.config.alert_thresholds)

    {:reply, :ok, updated_state}
  end

  def handle_call({:get_error_stats, opts}, _from, state) do
    filtered_errors = filter_errors(state.errors, opts)
    stats = calculate_error_stats(filtered_errors)
    {:reply, {:ok, stats}, state}
  end

  def handle_call({:export_metrics, opts}, _from, state) do
    format = Keyword.get(opts, :format, state.config.export_format)
    time_range = Keyword.get(opts, :time_range)

    filtered_metrics = filter_by_time_range(state.metrics, time_range)
    exported = export_metrics_in_format(filtered_metrics, format)

    {:reply, {:ok, exported}, state}
  end

  def handle_call({:cleanup_metrics, opts}, _from, state) do
    before =
      Keyword.get(
        opts,
        :before,
        System.system_time(:millisecond) - state.config.retention_period
      )

    updated_metrics = cleanup_old_metrics(state.metrics, before)
    updated_errors = cleanup_old_errors(state.errors, before)
    updated_state = %{state | metrics: updated_metrics, errors: updated_errors}
    {:reply, :ok, updated_state}
  end

  def handle_info({:aggregate_metrics, _timer_id}, state) do
    updated_metrics = aggregate_all_metrics(state.metrics)

    updated_state = %{
      state
      | metrics: updated_metrics,
        last_aggregation: System.system_time(:millisecond)
    }

    schedule_aggregation(state.config.aggregation_interval)
    {:noreply, updated_state}
  end

  # Private Functions

  defp generate_metric_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16()
  end

  defp schedule_aggregation(interval) do
    timer_id = System.unique_integer([:positive])
    Process.send_after(self(), {:aggregate_metrics, timer_id}, interval)
  end

  defp filter_metrics(metrics, opts) do
    metrics
    |> filter_by_labels(Keyword.get(opts, :labels))
    |> filter_by_time_range(Keyword.get(opts, :time_range))
  end

  defp filter_by_labels(metrics, nil), do: metrics

  defp filter_by_labels(metrics, labels) do
    Enum.filter(metrics, fn metric ->
      Enum.all?(labels, fn {key, value} ->
        Map.get(metric.labels, key) == value
      end)
    end)
  end

  defp filter_by_time_range(metrics, nil), do: metrics

  defp filter_by_time_range(metrics, {start, finish}) do
    Enum.filter(metrics, fn metric ->
      metric.timestamp >= start and metric.timestamp <= finish
    end)
  end

  defp aggregate_metrics(metrics) do
    case metrics do
      [] ->
        nil

      [metric] ->
        metric.value

      metrics ->
        case hd(metrics).type do
          :counter -> Enum.sum(Enum.map(metrics, & &1.value))
          :gauge -> List.first(metrics).value
          :histogram -> calculate_histogram_stats(metrics)
          :summary -> calculate_summary_stats(metrics)
        end
    end
  end

  defp calculate_histogram_stats(metrics) do
    values = Enum.map(metrics, & &1.value)

    %{
      count: length(values),
      sum: Enum.sum(values),
      min: Enum.min(values),
      max: Enum.max(values),
      avg: Enum.sum(values) / length(values)
    }
  end

  defp calculate_summary_stats(metrics) do
    values = Enum.map(metrics, & &1.value)
    sorted = Enum.sort(values)
    count = length(values)

    %{
      count: count,
      sum: Enum.sum(values),
      p50: percentile(sorted, 0.5),
      p90: percentile(sorted, 0.9),
      p99: percentile(sorted, 0.99)
    }
  end

  defp percentile(sorted, p) do
    count = length(sorted)

    if count == 0 do
      nil
    else
      # For percentiles, we want the value at the p-th percentile position
      # For a list of n elements, the p-th percentile is at position ceil(p * n)
      index = ceil(p * count) - 1
      # Clamp to valid range
      index = max(0, min(index, count - 1))
      Enum.at(sorted, index)
    end
  end

  defp filter_errors(errors, opts) do
    errors
    |> filter_by_severity(Keyword.get(opts, :severity))
    |> filter_by_time_range(Keyword.get(opts, :time_range))
  end

  defp filter_by_severity(errors, nil), do: errors

  defp filter_by_severity(errors, severity) do
    Enum.filter(errors, &(&1.severity == severity))
  end

  defp calculate_error_stats(errors) do
    %{
      total: length(errors),
      by_severity: group_by_severity(errors),
      recent: Enum.take(errors, 10)
    }
  end

  defp group_by_severity(errors) do
    errors
    |> Enum.group_by(& &1.severity)
    |> Map.new(fn {severity, errors} -> {severity, length(errors)} end)
  end

  defp export_metrics_in_format(metrics, format) do
    case format do
      :prometheus -> export_prometheus(metrics)
      :json -> export_json(metrics)
      :custom -> export_custom(metrics)
    end
  end

  defp export_prometheus(metrics) do
    metrics
    |> Enum.map_join("\n", fn {name, values} ->
      value = aggregate_metrics(values)
      labels = format_labels(hd(values).labels)
      "#{name}#{labels} #{value}"
    end)
  end

  defp export_json(metrics) do
    metrics
    |> Enum.map(fn {name, values} ->
      %{
        name: name,
        value: aggregate_metrics(values),
        labels: hd(values).labels,
        timestamp: hd(values).timestamp
      }
    end)
    |> Jason.encode!()
  end

  defp export_custom(metrics) do
    metrics
    |> Enum.map(fn {name, values} ->
      value = aggregate_metrics(values)
      labels = hd(values).labels
      timestamp = hd(values).timestamp

      %{
        metric_name: name,
        current_value: value,
        labels: labels,
        last_updated: timestamp,
        sample_count: length(values)
      }
    end)
    |> inspect(pretty: true)
  end

  defp format_labels(labels) do
    case labels do
      %{} = labels when map_size(labels) > 0 ->
        labels
        |> Enum.map_join(",", fn {key, value} -> "#{key}=\"#{value}\"" end)
        |> then(&"{#{&1}}")

      _ ->
        ""
    end
  end

  defp cleanup_old_metrics(metrics, before) do
    metrics
    |> Enum.map(fn {name, values} ->
      filtered = Enum.filter(values, &(&1.timestamp >= before))
      {name, filtered}
    end)
    |> Enum.filter(fn {_, values} -> length(values) > 0 end)
    |> Map.new()
  end

  defp cleanup_old_errors(errors, before) do
    Enum.filter(errors, &(&1.timestamp >= before))
  end

  defp check_alerts(name, metric, thresholds) do
    case Map.get(thresholds, name) do
      nil ->
        :ok

      threshold ->
        if exceeds_threshold?(metric.value, threshold) do
          Logger.warning(
            "Metric #{name} exceeded threshold: #{inspect(metric)}"
          )
        end
    end
  end

  defp check_error_alerts(error, _thresholds) do
    if error.severity == :critical do
      Logger.error("Critical error occurred: #{inspect(error)}")
    end

    :ok
  end

  defp exceeds_threshold?(value, threshold)
       when is_number(value) and is_number(threshold) do
    value > threshold
  end

  defp exceeds_threshold?(_, _), do: false

  defp aggregate_all_metrics(metrics) do
    metrics
    |> Enum.map(fn {name, values} ->
      aggregated = aggregate_metrics(values)

      {name,
       [
         %{
           id: generate_metric_id(),
           type: hd(values).type,
           value: aggregated,
           timestamp: hd(values).timestamp,
           labels: hd(values).labels,
           metadata: hd(values).metadata
         }
       ]}
    end)
    |> Map.new()
  end
end
