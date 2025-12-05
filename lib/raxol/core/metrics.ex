defmodule Raxol.Core.Metrics do
  @moduledoc """
  Core metrics module for Raxol framework.

  This module provides basic metrics collection and recording functionality
  with pure functional error handling patterns.
  """

  @doc """
  Initializes the metrics system.

  ## Parameters

  * `options` - Configuration options for metrics (optional)

  ## Returns

  * `:ok` - Metrics system initialized successfully
  * `{:error, reason}` - Failed to initialize metrics system
  """
  @spec init(keyword()) :: :ok | {:error, term()}
  def init(options \\ []) do
    with {:ok, _pid} <- safe_start_unified_collector(options),
         :ok <- safe_init_aggregator(options),
         :ok <- safe_init_alert_manager(options) do
      :ok
    else
      {:error, reason} -> {:error, {:metrics_init_failed, reason}}
    end
  end

  @spec safe_start_unified_collector(any()) :: any()
  defp safe_start_unified_collector(options) do
    # Use Task to safely start the collector with timeout
    task =
      Task.async(fn ->
        Raxol.Core.Metrics.MetricsCollector.start_link(options)
      end)

    case Task.yield(task, 5000) || Task.shutdown(task) do
      {:ok, {:ok, pid}} -> {:ok, pid}
      {:ok, {:error, reason}} -> {:error, {:collector_start_failed, reason}}
      nil -> {:error, :collector_start_timeout}
      {:exit, reason} -> {:error, {:collector_start_exit, reason}}
    end
  end

  @spec safe_init_aggregator(any()) :: any()
  defp safe_init_aggregator(options) do
    task =
      Task.async(fn ->
        Raxol.Core.Metrics.Aggregator.init(options)
      end)

    case Task.yield(task, 3000) || Task.shutdown(task) do
      {:ok, :ok} ->
        :ok

      {:ok, result} when result != :ok ->
        {:error, {:aggregator_init_failed, result}}

      nil ->
        {:error, :aggregator_init_timeout}

      {:exit, reason} ->
        {:error, {:aggregator_init_exit, reason}}
    end
  end

  @spec safe_init_alert_manager(any()) :: any()
  defp safe_init_alert_manager(options) do
    task =
      Task.async(fn ->
        Raxol.Core.Metrics.AlertManager.init(options)
      end)

    case Task.yield(task, 3000) || Task.shutdown(task) do
      {:ok, :ok} ->
        :ok

      {:ok, result} when result != :ok ->
        {:error, {:alert_manager_init_failed, result}}

      nil ->
        {:error, :alert_manager_init_timeout}

      {:exit, reason} ->
        {:error, {:alert_manager_init_exit, reason}}
    end
  end

  @doc """
  Records a metric with the given name, value, and optional tags.

  ## Parameters

  * `name` - Metric name
  * `value` - Metric value (number, string, or map)
  * `tags` - Optional tags as keyword list

  ## Returns

  * `:ok` - Metric recorded successfully
  * `{:error, reason}` - Failed to record metric

  ## Example

  ```elixir
  Raxol.Core.Metrics.record("render_time", 150, [component: "table"])
  Raxol.Core.Metrics.record("user_action", "button_click", [screen: "main"])
  ```
  """
  @spec record(String.t(), any(), keyword()) :: :ok
  def record(name, value, tags \\ []) do
    with :ok <- safe_record_to_collector(name, value, tags),
         :ok <- safe_record_to_aggregator(name, value, tags) do
      :ok
    else
      {:error, reason} -> {:error, {:metrics_record_failed, reason}}
    end
  end

  @spec safe_record_to_collector(String.t() | atom(), any(), any()) :: any()
  defp safe_record_to_collector(name, value, tags) do
    task =
      Task.async(fn ->
        Raxol.Core.Metrics.MetricsCollector.record_metric(name, :custom, value,
          tags: tags
        )
      end)

    case Task.yield(task, 1000) || Task.shutdown(task) do
      {:ok, :ok} -> :ok
      # Accept any successful response
      {:ok, _other} -> :ok
      # Don't fail on timeout - metrics are non-critical
      nil -> :ok
      # Continue even if collector fails
      {:exit, _reason} -> :ok
    end
  end

  @spec safe_record_to_aggregator(String.t() | atom(), any(), any()) :: any()
  defp safe_record_to_aggregator(name, value, tags) do
    task =
      Task.async(fn ->
        Raxol.Core.Metrics.Aggregator.record(name, value, tags)
      end)

    case Task.yield(task, 1000) || Task.shutdown(task) do
      {:ok, :ok} -> :ok
      # Accept any successful response
      {:ok, _other} -> :ok
      # Don't fail on timeout - metrics are non-critical
      nil -> :ok
      # Continue even if aggregator fails
      {:exit, _reason} -> :ok
    end
  end

  @doc """
  Gets all recorded metrics.

  ## Returns

  * `{:ok, metrics}` - Map of recorded metrics
  * `{:error, reason}` - Failed to get metrics
  """
  @spec get_metrics() :: {:ok, map()} | {:error, term()}
  def get_metrics do
    case safe_get_all_metrics() do
      {:ok, metrics} -> {:ok, metrics}
      {:error, reason} -> {:error, {:metrics_get_failed, reason}}
    end
  end

  defp safe_get_all_metrics do
    task =
      Task.async(fn ->
        Raxol.Core.Metrics.MetricsCollector.get_all_metrics()
      end)

    case Task.yield(task, 2000) || Task.shutdown(task) do
      {:ok, metrics} when is_map(metrics) -> {:ok, metrics}
      {:ok, other} -> {:ok, normalize_metrics(other)}
      nil -> {:error, :get_metrics_timeout}
      {:exit, reason} -> {:error, {:get_metrics_exit, reason}}
    end
  end

  @spec normalize_metrics(any()) :: any()
  defp normalize_metrics(data) when is_list(data) do
    # Convert list of metrics to map format
    Enum.reduce(data, %{}, fn
      {key, value}, acc -> Map.put(acc, key, value)
      _, acc -> acc
    end)
  end

  @spec normalize_metrics(any()) :: any()
  defp normalize_metrics(data) when is_map(data), do: data
  @spec normalize_metrics(any()) :: any()
  defp normalize_metrics(_), do: %{}

  @doc """
  Clears all recorded metrics.

  ## Returns

  * `:ok` - Metrics cleared successfully
  * `{:error, reason}` - Failed to clear metrics
  """
  @spec clear_metrics() ::
          :ok
          | {:error,
             {:metrics_clear_failed,
              :clear_collector_timeout
              | :clear_aggregator_timeout
              | {:clear_collector_exit, term()}
              | {:clear_aggregator_exit, term()}}}
  def clear_metrics do
    with :ok <- safe_clear_collector_metrics(),
         :ok <- safe_clear_aggregator() do
      :ok
    else
      {:error, reason} -> {:error, {:metrics_clear_failed, reason}}
    end
  end

  defp safe_clear_collector_metrics do
    task =
      Task.async(fn ->
        Raxol.Core.Metrics.MetricsCollector.clear_metrics()
      end)

    case Task.yield(task, 2000) || Task.shutdown(task) do
      {:ok, :ok} -> :ok
      # Accept any successful response
      {:ok, _} -> :ok
      nil -> {:error, :clear_collector_timeout}
      {:exit, reason} -> {:error, {:clear_collector_exit, reason}}
    end
  end

  defp safe_clear_aggregator do
    task =
      Task.async(fn ->
        Raxol.Core.Metrics.Aggregator.clear()
      end)

    case Task.yield(task, 2000) || Task.shutdown(task) do
      {:ok, :ok} -> :ok
      # Accept any successful response
      {:ok, _} -> :ok
      nil -> {:error, :clear_aggregator_timeout}
      {:exit, reason} -> {:error, {:clear_aggregator_exit, reason}}
    end
  end
end
