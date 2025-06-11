defmodule Raxol.Core.Metrics.Aggregator do
  @moduledoc """
  Metric aggregation system for the Raxol metrics.

  This module handles:
  - Metric aggregation by time windows
  - Statistical calculations (mean, median, percentiles)
  - Metric grouping and categorization
  - Aggregation rules and policies
  - Real-time aggregation updates
  """

  use GenServer
  alias Raxol.Core.Metrics.{Config, UnifiedCollector}

  @type aggregation_type :: :sum | :mean | :median | :min | :max | :percentile
  @type time_window :: :minute | :hour | :day | :week | :month
  @type aggregation_rule :: %{
    type: aggregation_type(),
    window: time_window(),
    metric_name: String.t(),
    tags: map(),
    group_by: [String.t()]
  }

  @default_options %{
    window_size: :hour,
    aggregation_types: [:mean, :max, :min],
    group_by: [],
    retention_period: 7 * 24 * 60 * 60, # 7 days in seconds
    update_interval: 60 # 1 minute in seconds
  }

  @doc """
  Starts the metric aggregator.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Adds a new aggregation rule.
  """
  def add_rule(rule) do
    GenServer.call(__MODULE__, {:add_rule, rule})
  end

  @doc """
  Gets aggregated metrics for a specific rule.
  """
  def get_aggregated_metrics(rule_id) do
    GenServer.call(__MODULE__, {:get_aggregated_metrics, rule_id})
  end

  @doc """
  Updates aggregation for a specific rule.
  """
  def update_aggregation(rule_id) do
    GenServer.call(__MODULE__, {:update_aggregation, rule_id})
  end

  @doc """
  Gets all aggregation rules.
  """
  def get_rules do
    GenServer.call(__MODULE__, :get_rules)
  end

  @impl GenServer
  def init(opts) do
    state = %{
      rules: %{},
      next_rule_id: 1,
      aggregations: %{},
      options: Map.merge(@default_options, Map.new(opts))
    }
    schedule_update()
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:add_rule, rule}, _from, state) do
    rule_id = state.next_rule_id
    validated_rule = validate_rule(rule)

    new_state = %{state |
      rules: Map.put(state.rules, rule_id, validated_rule),
      aggregations: Map.put(state.aggregations, rule_id, []),
      next_rule_id: rule_id + 1
    }

    {:reply, {:ok, rule_id}, new_state}
  end

  @impl GenServer
  def handle_call({:get_aggregated_metrics, rule_id}, _from, state) do
    case Map.get(state.aggregations, rule_id) do
      nil -> {:reply, {:error, :rule_not_found}, state}
      metrics -> {:reply, {:ok, metrics}, state}
    end
  end

  @impl GenServer
  def handle_call({:update_aggregation, rule_id}, _from, state) do
    case Map.get(state.rules, rule_id) do
      nil ->
        {:reply, {:error, :rule_not_found}, state}

      rule ->
        metrics = UnifiedCollector.get_metrics(rule.metric_name, rule.tags)
        aggregated = aggregate_metrics(metrics, rule)

        new_state = %{state |
          aggregations: Map.put(state.aggregations, rule_id, aggregated)
        }

        {:reply, {:ok, aggregated}, new_state}
    end
  end

  @impl GenServer
  def handle_call(:get_rules, _from, state) do
    {:reply, {:ok, state.rules}, state}
  end

  @impl GenServer
  def handle_info(:update_aggregations, state) do
    new_state = update_all_aggregations(state)
    schedule_update()
    {:noreply, new_state}
  end

  defp validate_rule(rule) do
    %{
      type: Map.get(rule, :type, :mean),
      window: Map.get(rule, :window, :hour),
      metric_name: Map.get(rule, :metric_name),
      tags: Map.get(rule, :tags, %{}),
      group_by: Map.get(rule, :group_by, [])
    }
  end

  defp aggregate_metrics(metrics, rule) do
    metrics
    |> group_metrics(rule.group_by)
    |> Enum.map(fn {group, group_metrics} ->
      aggregated_value = calculate_aggregation(group_metrics, rule.type)
      %{
        timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond),
        value: aggregated_value,
        group: group,
        type: rule.type,
        window: rule.window
      }
    end)
  end

  defp group_metrics(metrics, []) do
    [{"all", metrics}]
  end
  defp group_metrics(metrics, group_by) do
    metrics
    |> Enum.group_by(fn metric ->
      group_by
      |> Enum.map(&Map.get(metric.tags, &1))
      |> Enum.join(":")
    end)
  end

  defp calculate_aggregation(metrics, type) do
    values = Enum.map(metrics, & &1.value)

    case type do
      :sum -> Enum.sum(values)
      :mean -> Enum.sum(values) / length(values)
      :median -> calculate_median(values)
      :min -> Enum.min(values)
      :max -> Enum.max(values)
      :percentile -> calculate_percentile(values, 95)
    end
  end

  defp calculate_median(values) do
    sorted = Enum.sort(values)
    len = length(sorted)
    mid = div(len, 2)

    if rem(len, 2) == 0 do
      (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2
    else
      Enum.at(sorted, mid)
    end
  end

  defp calculate_percentile(values, percentile) do
    sorted = Enum.sort(values)
    index = round(length(sorted) * percentile / 100)
    Enum.at(sorted, index)
  end

  defp update_all_aggregations(state) do
    Enum.reduce(state.rules, state, fn {rule_id, rule}, acc_state ->
      metrics = UnifiedCollector.get_metrics(rule.metric_name, rule.tags)
      aggregated = aggregate_metrics(metrics, rule)

      %{acc_state |
        aggregations: Map.put(acc_state.aggregations, rule_id, aggregated)
      }
    end)
  end

  defp schedule_update do
    Process.send_after(self(), :update_aggregations, @default_options.update_interval * 1000)
  end
end
