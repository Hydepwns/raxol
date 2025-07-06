defmodule Raxol.Test.MetricsHelper do
  @moduledoc """
  Test helper module for the metrics system.
  Provides utilities for setting up test environments, recording metrics,
  verifying metric values, and cleaning up after tests.
  """

  @doc """
  Sets up a test environment for metrics testing.

  ## Options
    * `:collector_opts` - Options for the metrics collector
    * `:aggregator_opts` - Options for the metrics aggregator
    * `:visualizer_opts` - Options for the metrics visualizer
    * `:alert_manager_opts` - Options for the alert manager

  ## Returns
    * `{:ok, state}` - The test state containing all started components
  """
  def setup_metrics_test(opts \\ []) do
    # Start metrics collector
    collector =
      case Raxol.Core.Metrics.UnifiedCollector.start_link(
        Keyword.get(opts, :collector_opts,
          retention_period: :timer.minutes(5),
          max_samples: 100,
          flush_interval: :timer.seconds(1),
          cloud_enabled: false
        )
      ) do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
        {:error, reason} -> raise "Failed to start UnifiedCollector: #{inspect(reason)}"
      end

    # Start metrics aggregator
    aggregator =
      case Raxol.Core.Metrics.Aggregator.start_link(
        Keyword.get(opts, :aggregator_opts,
          update_interval: :timer.seconds(1),
          max_rules: 10
        )
      ) do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
        {:error, reason} -> raise "Failed to start Aggregator: #{inspect(reason)}"
      end

    # Start metrics visualizer
    visualizer =
      case Raxol.Core.Metrics.Visualizer.start_link(
        Keyword.get(opts, :visualizer_opts,
          max_charts: 10,
          default_time_range: :timer.minutes(5)
        )
      ) do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
        {:error, reason} -> raise "Failed to start Visualizer: #{inspect(reason)}"
      end

    # Start alert manager
    alert_manager =
      case Raxol.Core.Metrics.AlertManager.start_link(
        Keyword.get(opts, :alert_manager_opts,
          check_interval: :timer.seconds(1),
          max_rules: 10,
          default_cooldown: :timer.seconds(5)
        )
      ) do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
        {:error, reason} -> raise "Failed to start AlertManager: #{inspect(reason)}"
      end

    %{
      collector: collector,
      aggregator: aggregator,
      visualizer: visualizer,
      alert_manager: alert_manager
    }
  end

  @doc """
  Cleans up the metrics test environment.

  ## Parameters
    * `state` - The test state returned by `setup_metrics_test/1`
  """
  def cleanup_metrics_test(state) do
    if Process.alive?(state.collector) do
      Raxol.Core.Metrics.UnifiedCollector.stop(state.collector)
    end

    if Process.alive?(state.aggregator) do
      Raxol.Core.Metrics.Aggregator.stop(state.aggregator)
    end

    if Process.alive?(state.visualizer) do
      Raxol.Core.Metrics.Visualizer.stop(state.visualizer)
    end

    if Process.alive?(state.alert_manager) do
      Raxol.Core.Metrics.AlertManager.stop(state.alert_manager)
    end
  end

  @doc """
  Records a test metric.

  ## Parameters
    * `name` - The metric name
    * `type` - The metric type (:performance, :resource, :operation, :custom)
    * `value` - The metric value
    * `opts` - Additional options (tags, timestamp)

  ## Examples
      iex> record_test_metric("buffer_operations", :performance, 42, tags: %{operation: "write"})
      :ok
  """
  def record_test_metric(name, type, value, opts \\ []) do
    Raxol.Core.Metrics.UnifiedCollector.record_metric(name, type, value, opts)
  end

  @doc """
  Verifies that a metric has been recorded with the expected value.

  ## Parameters
    * `name` - The metric name
    * `type` - The metric type
    * `expected_value` - The expected metric value
    * `opts` - Additional options (tags, time_window)

  ## Returns
    * `:ok` - If the metric matches the expected value
    * `{:error, reason}` - If the metric doesn't match or isn't found

  ## Examples
      iex> verify_metric("buffer_operations", :performance, 42, tags: %{operation: "write"})
      :ok
  """
  def verify_metric(name, type, expected_value, opts \\ []) do
    case Raxol.Core.Metrics.UnifiedCollector.get_metric(name, type, opts) do
      {:ok, %{value: ^expected_value}} ->
        :ok

      {:ok, %{value: actual_value}} ->
        {:error, {:unexpected_value, actual_value}}

      {:ok, []} ->
        {:error, :metric_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Waits for a metric to be recorded with the expected value.

  ## Parameters
    * `name` - The metric name
    * `type` - The metric type
    * `expected_value` - The expected metric value
    * `opts` - Additional options
      * `:timeout` - Maximum time to wait (default: 1000ms)
      * `:check_interval` - Interval between checks (default: 100ms)
      * `:tags` - Expected tags
      * `:time_window` - Time window to check

  ## Returns
    * `:ok` - If the metric matches the expected value
    * `{:error, :timeout}` - If the metric doesn't match within the timeout

  ## Examples
      iex> wait_for_metric("buffer_operations", :performance, 42, timeout: 2000)
      :ok
  """
  def wait_for_metric(name, type, expected_value, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 1000)
    check_interval = Keyword.get(opts, :check_interval, 100)
    start_time = System.monotonic_time(:millisecond)
    end_time = start_time + timeout

    wait_for_metric_loop(
      name,
      type,
      expected_value,
      opts,
      check_interval,
      end_time
    )
  end

  defp wait_for_metric_loop(
         name,
         type,
         expected_value,
         opts,
         check_interval,
         end_time
       ) do
    case verify_metric(name, type, expected_value, opts) do
      :ok ->
        :ok

      {:error, _} ->
        if System.monotonic_time(:millisecond) >= end_time do
          {:error, :timeout}
        else
          Process.sleep(check_interval)

          wait_for_metric_loop(
            name,
            type,
            expected_value,
            opts,
            check_interval,
            end_time
          )
        end
    end
  end

  @doc """
  Creates a test aggregation rule.

  ## Parameters
    * `name` - The rule name
    * `metric_name` - The metric to aggregate
    * `type` - The aggregation type
    * `opts` - Additional options (time_window, group_by)

  ## Examples
      iex> create_test_rule("hourly_ops", "buffer_operations", :mean, time_window: :timer.hours(1))
      :ok
  """
  def create_test_rule(name, metric_name, type, opts \\ []) do
    Raxol.Core.Metrics.Aggregator.add_rule(%{
      name: name,
      metric_name: metric_name,
      type: type,
      time_window: Keyword.get(opts, :time_window, :timer.minutes(5)),
      group_by: Keyword.get(opts, :group_by, [])
    })
  end

  @doc """
  Creates a test alert rule.

  ## Parameters
    * `name` - The rule name
    * `metric_name` - The metric to monitor
    * `condition` - The alert condition
    * `opts` - Additional options (severity, cooldown, notification)

  ## Examples
      iex> create_test_alert("high_usage", "memory_usage", {:above, 90}, severity: :warning)
      :ok
  """
  def create_test_alert(name, metric_name, condition, opts \\ []) do
    Raxol.Core.Metrics.AlertManager.add_rule(%{
      name: name,
      metric_name: metric_name,
      condition: condition,
      severity: Keyword.get(opts, :severity, :warning),
      cooldown: Keyword.get(opts, :cooldown, :timer.minutes(5)),
      notification: Keyword.get(opts, :notification, %{type: :test})
    })
  end

  @doc """
  Creates a test chart.

  ## Parameters
    * `metric_name` - The metric to visualize
    * `chart_type` - The type of chart
    * `opts` - Additional options (title, time_range, group_by)

  ## Examples
      iex> create_test_chart("buffer_operations", :line, title: "Buffer Operations")
      {:ok, chart_id}
  """
  def create_test_chart(metric_name, chart_type, opts \\ []) do
    Raxol.Core.Metrics.Visualizer.create_chart(
      metric_name,
      chart_type,
      %{
        title: Keyword.get(opts, :title, "Test Chart"),
        time_range: Keyword.get(opts, :time_range, :timer.minutes(5)),
        group_by: Keyword.get(opts, :group_by, [])
      }
    )
  end

  @doc """
  Creates a mock metrics collector for testing.
  """
  def create_mock_collector do
    %{
      metrics: %{},
      start_time: System.monotonic_time(),
      last_update: System.monotonic_time()
    }
  end

  @doc """
  Records a metric value in the collector.
  """
  def record_metric(collector, name, value) do
    metrics =
      Map.update(collector.metrics, name, value, fn current ->
        case is_list(current) do
          true -> [value | current]
          false -> [value, current]
        end
      end)

    %{collector | metrics: metrics, last_update: System.monotonic_time()}
  end

  @doc """
  Gets a metric value from the collector.
  """
  def get_metric(collector, name) do
    Map.get(collector.metrics, name)
  end

  @doc """
  Gets a metric value by name and type.
  """
  def get_metric_value(name, type) do
    case Raxol.Core.Metrics.UnifiedCollector.get_metric(name, type) do
      [] -> nil
      [metric | _] -> metric.value
      _ -> nil
    end
  end

  @doc """
  Collects metrics of a specific type.
  """
  def collect_metrics(type, opts \\ []) do
    Raxol.Core.Metrics.UnifiedCollector.get_metrics_by_type(type)
  end

  @doc """
  Gets all metrics from the collector.
  """
  def get_all_metrics(collector) do
    collector.metrics
  end

  @doc """
  Clears all metrics from the collector.
  """
  def clear_metrics(collector) do
    Raxol.Core.Metrics.UnifiedCollector.clear_metrics(collector)
  end

  @doc """
  Calculates the average of a metric.
  """
  def calculate_average(collector, name) do
    case get_metric(collector, name) do
      nil ->
        0

      values when is_list(values) ->
        Enum.sum(values) / length(values)

      value ->
        value
    end
  end

  @doc """
  Calculates the sum of a metric.
  """
  def calculate_sum(collector, name) do
    case get_metric(collector, name) do
      nil ->
        0

      values when is_list(values) ->
        Enum.sum(values)

      value ->
        value
    end
  end

  @doc """
  Calculates the minimum value of a metric.
  """
  def calculate_min(collector, name) do
    case get_metric(collector, name) do
      nil ->
        0

      values when is_list(values) ->
        Enum.min(values)

      value ->
        value
    end
  end

  @doc """
  Calculates the maximum value of a metric.
  """
  def calculate_max(collector, name) do
    case get_metric(collector, name) do
      nil ->
        0

      values when is_list(values) ->
        Enum.max(values)

      value ->
        value
    end
  end

  @doc """
  Gets the time since the last update.
  """
  def get_time_since_last_update(collector) do
    System.monotonic_time() - collector.last_update
  end

  @doc """
  Gets the total runtime of the collector.
  """
  def get_total_runtime(collector) do
    System.monotonic_time() - collector.start_time
  end

  @doc """
  Verifies multiple metrics at once.

  ## Parameters
    * `collector` - The metrics collector
    * `expected_metrics` - List of expected metrics with their values

  ## Returns
    * `:ok` - If all metrics match the expected values
    * `{:error, reason}` - If any metric doesn't match

  ## Examples
      iex> verify_metrics(collector, [
      ...>   {"buffer_operations", :performance, 42},
      ...>   {"cursor_movements", :performance, 10}
      ...> ])
      :ok
  """
  def verify_metrics(_collector, expected_metrics) when is_list(expected_metrics) do
    Enum.reduce_while(expected_metrics, :ok, fn {name, type, expected_value}, _acc ->
      case verify_metric(name, type, expected_value) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, {name, reason}}}
      end
    end)
  end

  def verify_metrics(_collector, expected_metrics) when is_map(expected_metrics) do
    Enum.reduce_while(expected_metrics, :ok, fn {name, expected_value}, _acc ->
      case verify_metric(name, :custom, expected_value) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, {name, reason}}}
      end
    end)
  end
end
