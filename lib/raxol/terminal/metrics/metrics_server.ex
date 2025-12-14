defmodule Raxol.Terminal.Metrics.MetricsServer do
  @moduledoc """
  ETS-backed metrics collection and export module.

  Provides centralized metrics storage using ETS for high-performance
  concurrent writes and reads. Supports multiple metric types and
  Prometheus-compatible export.

  ## Design

  Uses ETS for write-heavy workloads (per Rich Hickey's feedback).
  No GenServer serialization for metric recording - direct ETS writes.

  ## Metric Types

  - **Counters**: Monotonically increasing values (e.g., operations count)
  - **Gauges**: Point-in-time values (e.g., memory usage)
  - **Histograms**: Distribution of values (e.g., latency percentiles)

  ## Usage

      # Initialize (call once at app startup)
      MetricsServer.init()

      # Record metrics
      MetricsServer.increment(:requests_total, %{path: "/api"})
      MetricsServer.gauge(:memory_bytes, 1024000, %{type: :heap})
      MetricsServer.histogram(:latency_ms, 42.5, %{endpoint: :render})

      # Query metrics
      MetricsServer.get(:requests_total, %{path: "/api"})
      MetricsServer.get_all()

      # Export for monitoring
      MetricsServer.export(:prometheus)
      MetricsServer.export(:json)
  """

  @metrics_table :raxol_metrics
  @histograms_table :raxol_histograms
  @errors_table :raxol_metric_errors

  @type metric_name :: atom()
  @type labels :: map()
  @type metric_value :: number()

  # ============================================================================
  # Initialization
  # ============================================================================

  @doc """
  Initializes the metrics storage tables.

  Call once during application startup.
  """
  @spec init() :: :ok
  def init do
    # Main metrics table (counters and gauges)
    if :ets.whereis(@metrics_table) == :undefined do
      :ets.new(@metrics_table, [
        :named_table,
        :public,
        :set,
        write_concurrency: true,
        read_concurrency: true
      ])
    end

    # Histograms table (stores individual samples)
    if :ets.whereis(@histograms_table) == :undefined do
      :ets.new(@histograms_table, [
        :named_table,
        :public,
        :bag,
        write_concurrency: true
      ])
    end

    # Errors table
    if :ets.whereis(@errors_table) == :undefined do
      :ets.new(@errors_table, [
        :named_table,
        :public,
        :ordered_set,
        write_concurrency: true
      ])
    end

    :ok
  end

  @doc """
  Checks if metrics storage is initialized.
  """
  @spec initialized?() :: boolean()
  def initialized? do
    :ets.whereis(@metrics_table) != :undefined
  end

  # ============================================================================
  # Counter Operations
  # ============================================================================

  @doc """
  Increments a counter metric.

  ## Examples

      MetricsServer.increment(:requests_total)
      MetricsServer.increment(:requests_total, %{path: "/api"})
      MetricsServer.increment(:requests_total, %{path: "/api"}, 5)
  """
  @spec increment(metric_name(), labels(), pos_integer()) :: :ok
  def increment(name, labels \\ %{}, amount \\ 1) do
    ensure_initialized!()
    key = metric_key(name, labels)

    :ets.update_counter(@metrics_table, key, {3, amount}, {key, :counter, 0})
    :ok
  end

  @doc """
  Gets the current value of a counter.
  """
  @spec get_counter(metric_name(), labels()) :: non_neg_integer()
  def get_counter(name, labels \\ %{}) do
    ensure_initialized!()
    key = metric_key(name, labels)

    case :ets.lookup(@metrics_table, key) do
      [{^key, :counter, value}] -> value
      [] -> 0
    end
  end

  # ============================================================================
  # Gauge Operations
  # ============================================================================

  @doc """
  Sets a gauge metric to a specific value.

  ## Examples

      MetricsServer.gauge(:memory_bytes, 1024000)
      MetricsServer.gauge(:cpu_percent, 45.5, %{core: 0})
  """
  @spec gauge(metric_name(), metric_value(), labels()) :: :ok
  def gauge(name, value, labels \\ %{}) do
    ensure_initialized!()
    key = metric_key(name, labels)
    timestamp = System.system_time(:millisecond)

    :ets.insert(@metrics_table, {key, :gauge, value, timestamp})
    :ok
  end

  @doc """
  Gets the current value of a gauge.
  """
  @spec get_gauge(metric_name(), labels()) :: metric_value() | nil
  def get_gauge(name, labels \\ %{}) do
    ensure_initialized!()
    key = metric_key(name, labels)

    case :ets.lookup(@metrics_table, key) do
      [{^key, :gauge, value, _ts}] -> value
      [] -> nil
    end
  end

  # ============================================================================
  # Histogram Operations
  # ============================================================================

  @doc """
  Records a value in a histogram.

  ## Examples

      MetricsServer.histogram(:latency_ms, 42.5)
      MetricsServer.histogram(:latency_ms, 15.2, %{endpoint: :render})
  """
  @spec histogram(metric_name(), metric_value(), labels()) :: :ok
  def histogram(name, value, labels \\ %{}) do
    ensure_initialized!()
    key = metric_key(name, labels)
    timestamp = System.system_time(:millisecond)

    :ets.insert(@histograms_table, {key, value, timestamp})
    :ok
  end

  @doc """
  Gets histogram statistics.

  Returns count, sum, min, max, and percentiles.
  """
  @spec get_histogram(metric_name(), labels()) :: map()
  def get_histogram(name, labels \\ %{}) do
    ensure_initialized!()
    key = metric_key(name, labels)

    values =
      :ets.lookup(@histograms_table, key)
      |> Enum.map(fn {_key, value, _ts} -> value end)
      |> Enum.sort()

    calculate_histogram_stats(values)
  end

  # ============================================================================
  # Generic Operations (Backward Compatibility)
  # ============================================================================

  @doc """
  Records a metric value (generic interface).
  """
  @spec record_metric(metric_name(), metric_value(), labels(), atom()) :: :ok
  def record_metric(name, value, labels \\ %{}, _store_name \\ nil) do
    gauge(name, value, labels)
  end

  @doc """
  Gets a metric value (generic interface).
  """
  @spec get_metric(metric_name(), labels(), atom()) ::
          {:ok, metric_value()} | {:error, :not_found}
  def get_metric(name, labels \\ %{}, _store_name \\ nil) do
    case get_gauge(name, labels) do
      nil -> {:error, :not_found}
      value -> {:ok, value}
    end
  end

  # ============================================================================
  # Error Recording
  # ============================================================================

  @doc """
  Records an error occurrence.
  """
  @spec record_error(String.t(), labels(), atom()) :: :ok
  def record_error(message, labels \\ %{}, _store_name \\ nil) do
    ensure_initialized!()
    timestamp = System.system_time(:millisecond)
    key = {timestamp, :crypto.strong_rand_bytes(4)}

    :ets.insert(@errors_table, {key, message, labels, timestamp})

    # Increment error counter
    increment(:errors_total, labels)
    :ok
  end

  @doc """
  Gets error statistics.
  """
  @spec get_error_stats(labels(), atom()) :: {:ok, map()}
  def get_error_stats(labels \\ %{}, _store_name \\ nil) do
    ensure_initialized!()

    # Get recent errors (last 100)
    errors =
      :ets.tab2list(@errors_table)
      |> Enum.filter(fn {_key, _msg, err_labels, _ts} ->
        labels_match?(err_labels, labels)
      end)
      |> Enum.sort_by(fn {_key, _msg, _labels, ts} -> ts end, :desc)
      |> Enum.take(100)
      |> Enum.map(fn {_key, msg, _labels, ts} ->
        %{message: msg, timestamp: ts}
      end)

    {:ok, %{count: length(errors), errors: errors}}
  end

  # ============================================================================
  # Cleanup
  # ============================================================================

  @doc """
  Cleans up old metrics.

  ## Options

    * `:older_than` - Remove entries older than this many milliseconds
    * `:type` - Only clean this type (:histogram, :error)
  """
  @spec cleanup_metrics(keyword(), atom()) :: :ok
  def cleanup_metrics(opts \\ [], _store_name \\ nil) do
    ensure_initialized!()

    older_than = Keyword.get(opts, :older_than, 3600_000)
    cutoff = System.system_time(:millisecond) - older_than

    type = Keyword.get(opts, :type)

    # Clean histograms
    if type in [nil, :histogram] do
      :ets.select_delete(@histograms_table, [
        {{:_, :_, :"$1"}, [{:<, :"$1", cutoff}], [true]}
      ])
    end

    # Clean errors
    if type in [nil, :error] do
      :ets.select_delete(@errors_table, [
        {{:_, :_, :_, :"$1"}, [{:<, :"$1", cutoff}], [true]}
      ])
    end

    :ok
  end

  # ============================================================================
  # Export
  # ============================================================================

  @doc """
  Exports metrics in the specified format.

  ## Formats

    * `:prometheus` - Prometheus text format
    * `:json` - JSON format

  ## Examples

      MetricsServer.export(:prometheus)
      MetricsServer.export(:json)
  """
  @spec export_metrics(keyword(), atom()) ::
          String.t() | {:error, :unsupported_format}
  def export_metrics(opts \\ [], _store_name \\ nil) do
    format = Keyword.get(opts, :format, :json)
    export(format)
  end

  @doc """
  Exports metrics in the specified format.
  """
  @spec export(atom()) :: String.t() | {:error, :unsupported_format}
  def export(format) do
    ensure_initialized!()

    case format do
      :prometheus -> export_prometheus()
      :json -> export_json()
      _ -> {:error, :unsupported_format}
    end
  end

  # ============================================================================
  # Query Operations
  # ============================================================================

  @doc """
  Gets all metrics as a map.
  """
  @spec get_all() :: map()
  def get_all do
    ensure_initialized!()

    metrics =
      :ets.tab2list(@metrics_table)
      |> Enum.map(fn
        {key, :counter, value} ->
          {key, %{type: :counter, value: value}}

        {key, :gauge, value, timestamp} ->
          {key, %{type: :gauge, value: value, timestamp: timestamp}}
      end)
      |> Map.new()

    histograms =
      :ets.tab2list(@histograms_table)
      |> Enum.group_by(fn {key, _val, _ts} -> key end)
      |> Enum.map(fn {key, entries} ->
        values = Enum.map(entries, fn {_, v, _} -> v end)
        {key, %{type: :histogram, stats: calculate_histogram_stats(values)}}
      end)
      |> Map.new()

    Map.merge(metrics, histograms)
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp ensure_initialized! do
    unless initialized?() do
      init()
    end
  end

  defp metric_key(name, labels) when map_size(labels) == 0, do: {name}

  defp metric_key(name, labels) do
    sorted_labels =
      labels
      |> Enum.sort_by(fn {k, _v} -> k end)
      |> Enum.map(fn {k, v} -> {k, v} end)

    {name, sorted_labels}
  end

  defp labels_match?(_err_labels, filter_labels)
       when map_size(filter_labels) == 0 do
    true
  end

  defp labels_match?(err_labels, filter_labels) do
    Enum.all?(filter_labels, fn {k, v} ->
      Map.get(err_labels, k) == v
    end)
  end

  defp calculate_histogram_stats([]),
    do: %{count: 0, sum: 0, min: 0, max: 0, p50: 0, p90: 0, p99: 0}

  defp calculate_histogram_stats(values) do
    count = length(values)
    sum = Enum.sum(values)

    %{
      count: count,
      sum: sum,
      min: List.first(values),
      max: List.last(values),
      avg: sum / count,
      p50: percentile(values, 50),
      p90: percentile(values, 90),
      p99: percentile(values, 99)
    }
  end

  defp percentile(sorted_values, p) do
    count = length(sorted_values)
    index = trunc(p / 100 * count)
    Enum.at(sorted_values, min(index, count - 1), 0)
  end

  defp export_prometheus do
    metrics = get_all()

    metrics
    |> Enum.map(fn {key, data} ->
      name = format_metric_name(key)
      format_prometheus_metric(name, key, data)
    end)
    |> Enum.join("\n")
  end

  defp format_prometheus_metric(name, key, %{type: :counter, value: value}) do
    labels = format_prometheus_labels(key)

    """
    # TYPE #{name} counter
    #{name}#{labels} #{value}
    """
  end

  defp format_prometheus_metric(name, key, %{type: :gauge, value: value}) do
    labels = format_prometheus_labels(key)

    """
    # TYPE #{name} gauge
    #{name}#{labels} #{value}
    """
  end

  defp format_prometheus_metric(name, key, %{type: :histogram, stats: stats}) do
    labels = format_prometheus_labels(key)

    """
    # TYPE #{name} histogram
    #{name}_count#{labels} #{stats.count}
    #{name}_sum#{labels} #{stats.sum}
    #{name}_bucket{le="0.5"} #{stats.p50}
    #{name}_bucket{le="0.9"} #{stats.p90}
    #{name}_bucket{le="0.99"} #{stats.p99}
    """
  end

  defp format_metric_name({name}), do: "raxol_#{name}"
  defp format_metric_name({name, _labels}), do: "raxol_#{name}"

  defp format_prometheus_labels({_name}), do: ""

  defp format_prometheus_labels({_name, labels}) do
    label_str =
      labels
      |> Enum.map(fn {k, v} -> "#{k}=\"#{v}\"" end)
      |> Enum.join(",")

    "{#{label_str}}"
  end

  defp export_json do
    metrics = get_all()

    data =
      Enum.map(metrics, fn {key, data} ->
        %{
          name: format_metric_name(key),
          labels: extract_labels(key),
          type: data.type,
          value: Map.get(data, :value) || Map.get(data, :stats)
        }
      end)

    Jason.encode!(%{metrics: data, timestamp: System.system_time(:millisecond)})
  end

  defp extract_labels({_name}), do: %{}
  defp extract_labels({_name, labels}), do: Map.new(labels)
end
