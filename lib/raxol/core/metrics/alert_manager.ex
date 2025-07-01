defmodule Raxol.Core.Metrics.AlertManager do
  @moduledoc """
  Alert management system for the Raxol metrics.

  This module handles:
  - Alert rule definition and management
  - Metric threshold monitoring
  - Alert state tracking
  - Alert notifications
  - Alert history
  """

  use GenServer
  alias Raxol.Core.Metrics.{UnifiedCollector, Aggregator}

  @type alert_condition :: :above | :below | :equals | :not_equals
  @type alert_severity :: :info | :warning | :error | :critical
  @type alert_rule :: %{
          name: String.t(),
          description: String.t(),
          metric_name: String.t(),
          condition: alert_condition(),
          threshold: number(),
          severity: alert_severity(),
          tags: map(),
          group_by: [String.t()],
          # seconds
          cooldown: pos_integer(),
          notification_channels: [String.t()]
        }

  @default_options %{
    # 1 minute in seconds
    check_interval: 60,
    history_size: 1000,
    # 5 minutes in seconds
    default_cooldown: 300,
    default_severity: :warning
  }

  # Helper function to get the process name
  defp process_name(pid_or_name \\ __MODULE__)
  defp process_name(pid) when is_pid(pid), do: pid
  defp process_name(name) when is_atom(name), do: name
  defp process_name(_), do: __MODULE__

  @doc """
  Starts the alert manager.
  """
  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Adds a new alert rule.
  """
  def add_rule(rule, process \\ __MODULE__) do
    GenServer.call(process_name(process), {:add_rule, rule})
  end

  @doc """
  Gets all alert rules.
  """
  def get_rules(process \\ __MODULE__) do
    GenServer.call(process_name(process), :get_rules)
  end

  @doc """
  Gets the current alert state for a rule.
  """
  def get_alert_state(rule_id, process \\ __MODULE__) do
    GenServer.call(process_name(process), {:get_alert_state, rule_id})
  end

  @doc """
  Gets the alert history.
  """
  def get_alert_history(rule_id, process \\ __MODULE__) do
    GenServer.call(process_name(process), {:get_alert_history, rule_id})
  end

  @doc """
  Acknowledges an alert.
  """
  def acknowledge_alert(rule_id, process \\ __MODULE__) do
    GenServer.call(process_name(process), {:acknowledge_alert, rule_id})
  end

  @impl GenServer
  def init(opts) do
    state = %{
      rules: %{},
      next_rule_id: 1,
      alert_states: %{},
      alert_history: %{},
      options: Map.merge(@default_options, Map.new(opts))
    }

    schedule_check()
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:add_rule, rule}, _from, state) do
    rule_id = state.next_rule_id
    validated_rule = validate_rule(rule)

    new_state = %{
      state
      | rules: Map.put(state.rules, rule_id, validated_rule),
        alert_states:
          Map.put(state.alert_states, rule_id, %{
            active: false,
            last_triggered: nil,
            acknowledged: false,
            current_value: nil
          }),
        alert_history: Map.put(state.alert_history, rule_id, []),
        next_rule_id: rule_id + 1
    }

    {:reply, {:ok, rule_id}, new_state}
  end

  @impl GenServer
  def handle_call(:get_rules, _from, state) do
    {:reply, {:ok, state.rules}, state}
  end

  @impl GenServer
  def handle_call({:get_alert_state, rule_id}, _from, state) do
    case Map.get(state.alert_states, rule_id) do
      nil -> {:reply, {:error, :rule_not_found}, state}
      alert_state -> {:reply, {:ok, alert_state}, state}
    end
  end

  @impl GenServer
  def handle_call({:get_alert_history, rule_id}, _from, state) do
    case Map.get(state.alert_history, rule_id) do
      nil -> {:reply, {:error, :rule_not_found}, state}
      history -> {:reply, {:ok, history}, state}
    end
  end

  @impl GenServer
  def handle_call({:acknowledge_alert, rule_id}, _from, state) do
    case Map.get(state.alert_states, rule_id) do
      nil ->
        {:reply, {:error, :rule_not_found}, state}

      alert_state ->
        new_alert_state = %{alert_state | acknowledged: true}

        new_state = %{
          state
          | alert_states: Map.put(state.alert_states, rule_id, new_alert_state)
        }

        {:reply, {:ok, new_alert_state}, new_state}
    end
  end

  @impl GenServer
  def handle_info({:check_alerts, _timer_id}, state) do
    new_state = check_all_alerts(state)
    schedule_check()
    {:noreply, new_state}
  end

  defp validate_rule(rule) do
    %{
      name: Map.get(rule, :name, "Unnamed Alert"),
      description: Map.get(rule, :description, ""),
      metric_name: Map.get(rule, :metric_name),
      condition: Map.get(rule, :condition, :above),
      threshold: Map.get(rule, :threshold),
      severity: Map.get(rule, :severity, @default_options.default_severity),
      tags: Map.get(rule, :tags, %{}),
      group_by: Map.get(rule, :group_by, []),
      cooldown: Map.get(rule, :cooldown, @default_options.default_cooldown),
      notification_channels: Map.get(rule, :notification_channels, [])
    }
  end

  defp check_all_alerts(state) do
    Enum.reduce(state.rules, state, fn {rule_id, rule}, acc_state ->
      check_alert(rule_id, rule, acc_state)
    end)
  end

  defp check_alert(rule_id, rule, state) do
    metrics = UnifiedCollector.get_metrics(rule.metric_name, rule.tags)
    current_value = get_current_value(metrics, rule)
    alert_state = state.alert_states[rule_id]

    {new_alert_state, should_trigger} =
      evaluate_alert(
        current_value,
        rule,
        alert_state
      )

    if should_trigger do
      trigger_alert(rule_id, rule, current_value, state)
    else
      %{
        state
        | alert_states: Map.put(state.alert_states, rule_id, new_alert_state)
      }
    end
  end

  defp get_current_value(metrics, rule) do
    case rule.group_by do
      [] ->
        metrics
        |> List.first()
        |> Map.get(:value)

      group_by ->
        metrics
        |> Enum.group_by(fn metric ->
          group_by
          |> Enum.map_join(":", &Map.get(metric.tags, &1))
        end)
        |> Enum.map(fn {group, group_metrics} ->
          values = Enum.map(group_metrics, & &1.value)
          {group, Aggregator.calculate_aggregation(values, :mean)}
        end)
    end
  end

  defp evaluate_alert(current_value, rule, alert_state) do
    now = DateTime.utc_now()
    in_cooldown = is_in_cooldown?(alert_state.last_triggered, rule.cooldown, now)
    should_trigger = evaluate_condition(rule.condition, current_value, rule.threshold)

    new_alert_state = %{
      alert_state
      | current_value: current_value,
        active: should_trigger and not in_cooldown
    }

    {new_alert_state, should_trigger and not in_cooldown}
  end

  defp is_in_cooldown?(last_triggered, cooldown, now) do
    case last_triggered do
      nil -> false
      triggered -> DateTime.diff(now, triggered) < cooldown
    end
  end

  defp evaluate_condition(condition, value, threshold) do
    case {condition, value, threshold} do
      {:above, val, thresh} when val > thresh -> true
      {:below, val, thresh} when val < thresh -> true
      {:equals, val, thresh} when val == thresh -> true
      {:not_equals, val, thresh} when val != thresh -> true
      _ -> false
    end
  end

  defp trigger_alert(rule_id, rule, current_value, state) do
    now = DateTime.utc_now()

    alert = %{
      rule_id: rule_id,
      rule_name: rule.name,
      severity: rule.severity,
      current_value: current_value,
      threshold: rule.threshold,
      condition: rule.condition,
      triggered_at: now,
      acknowledged: false
    }

    # Update alert state
    new_alert_state = %{
      active: true,
      last_triggered: now,
      acknowledged: false,
      current_value: current_value
    }

    # Add to history
    history = [alert | state.alert_history[rule_id]]
    history = Enum.take(history, state.options.history_size)

    # Send notifications
    send_notifications(alert, rule.notification_channels)

    %{
      state
      | alert_states: Map.put(state.alert_states, rule_id, new_alert_state),
        alert_history: Map.put(state.alert_history, rule_id, history)
    }
  end

  defp send_notifications(alert, channels) do
    Enum.each(channels, fn channel ->
      case channel do
        "email" -> send_email_notification(alert)
        "slack" -> send_slack_notification(alert)
        "webhook" -> send_webhook_notification(alert)
        _ -> :ok
      end
    end)
  end

  defp send_email_notification(alert) do
    Raxol.Core.Runtime.Log.info(
      "Alert: #{alert.rule_name} - #{alert.severity} threshold exceeded",
      %{
        rule_id: alert.rule_id,
        current_value: alert.current_value,
        threshold: alert.threshold,
        condition: alert.condition,
        channel: "email"
      }
    )
  end

  defp send_slack_notification(alert) do
    Raxol.Core.Runtime.Log.info(
      "Alert: #{alert.rule_name} - #{alert.severity} threshold exceeded",
      %{
        rule_id: alert.rule_id,
        current_value: alert.current_value,
        threshold: alert.threshold,
        condition: alert.condition,
        channel: "slack"
      }
    )
  end

  defp send_webhook_notification(alert) do
    Raxol.Core.Runtime.Log.info(
      "Alert: #{alert.rule_name} - #{alert.severity} threshold exceeded",
      %{
        rule_id: alert.rule_id,
        current_value: alert.current_value,
        threshold: alert.threshold,
        condition: alert.condition,
        channel: "webhook"
      }
    )
  end

  defp schedule_check do
    timer_id = System.unique_integer([:positive])

    Process.send_after(
      self(),
      {:check_alerts, timer_id},
      @default_options.check_interval * 1000
    )
  end
end
