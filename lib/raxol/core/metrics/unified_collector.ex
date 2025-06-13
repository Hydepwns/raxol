defmodule Raxol.Core.Metrics.UnifiedCollector do
  @moduledoc """
  Manages unified metrics collection across the application.
  """

  defstruct [
    :metrics,
    :start_time,
    :last_update,
    :collectors
  ]

  @type t :: %__MODULE__{
    metrics: map(),
    start_time: integer(),
    last_update: integer(),
    collectors: map()
  }

  @doc """
  Creates a new unified collector.
  """
  def new(opts \\ []) do
    %__MODULE__{
      metrics: %{},
      start_time: System.monotonic_time(),
      last_update: System.monotonic_time(),
      collectors: Keyword.get(opts, :collectors, %{})
    }
  end

  @doc """
  Records a metric value.
  """
  def record_metric(%__MODULE__{} = collector, name, value) do
    metrics = Map.update(collector.metrics, name, value, fn current ->
      case is_list(current) do
        true -> [value | current]
        false -> [value, current]
      end
    end)
    %{collector | metrics: metrics, last_update: System.monotonic_time()}
  end

  @doc """
  Gets a metric value.
  """
  def get_metric(%__MODULE__{} = collector, name) do
    Map.get(collector.metrics, name)
  end

  @doc """
  Gets all metrics.
  """
  def get_all_metrics(%__MODULE__{} = collector) do
    collector.metrics
  end

  @doc """
  Clears all metrics.
  """
  def clear_metrics(%__MODULE__{} = collector) do
    %{collector | metrics: %{}, last_update: System.monotonic_time()}
  end

  @doc """
  Adds a collector.
  """
  def add_collector(%__MODULE__{} = collector, name, collector_module) do
    collectors = Map.put(collector.collectors, name, collector_module)
    %{collector | collectors: collectors}
  end

  @doc """
  Removes a collector.
  """
  def remove_collector(%__MODULE__{} = collector, name) do
    collectors = Map.delete(collector.collectors, name)
    %{collector | collectors: collectors}
  end

  @doc """
  Gets a collector.
  """
  def get_collector(%__MODULE__{} = collector, name) do
    Map.get(collector.collectors, name)
  end

  @doc """
  Gets all collectors.
  """
  def get_collectors(%__MODULE__{} = collector) do
    collector.collectors
  end

  @doc """
  Collects metrics from all registered collectors.
  """
  def collect_metrics(%__MODULE__{} = collector) do
    Enum.reduce(collector.collectors, collector, fn {name, module}, acc ->
      case module.collect() do
        {:ok, metrics} ->
          record_metric(acc, name, metrics)
        _ ->
          acc
      end
    end)
  end

  @doc """
  Calculates the average of a metric.
  """
  def calculate_average(%__MODULE__{} = collector, name) do
    case get_metric(collector, name) do
      nil -> 0
      values when is_list(values) ->
        Enum.sum(values) / length(values)
      value -> value
    end
  end

  @doc """
  Calculates the sum of a metric.
  """
  def calculate_sum(%__MODULE__{} = collector, name) do
    case get_metric(collector, name) do
      nil -> 0
      values when is_list(values) ->
        Enum.sum(values)
      value -> value
    end
  end

  @doc """
  Calculates the minimum value of a metric.
  """
  def calculate_min(%__MODULE__{} = collector, name) do
    case get_metric(collector, name) do
      nil -> 0
      values when is_list(values) ->
        Enum.min(values)
      value -> value
    end
  end

  @doc """
  Calculates the maximum value of a metric.
  """
  def calculate_max(%__MODULE__{} = collector, name) do
    case get_metric(collector, name) do
      nil -> 0
      values when is_list(values) ->
        Enum.max(values)
      value -> value
    end
  end

  @doc """
  Gets the time since the last update.
  """
  def get_time_since_last_update(%__MODULE__{} = collector) do
    System.monotonic_time() - collector.last_update
  end

  @doc """
  Gets the total runtime of the collector.
  """
  def get_total_runtime(%__MODULE__{} = collector) do
    System.monotonic_time() - collector.start_time
  end

  @doc """
  Gets metrics for a specific metric name and tags.
  """
  @spec get_metrics(String.t(), map()) :: {:ok, list(map())} | {:error, term()}
  def get_metrics(metric_name, tags) do
    GenServer.call(__MODULE__, {:get_metrics, metric_name, tags})
  end
end
