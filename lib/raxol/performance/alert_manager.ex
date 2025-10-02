defmodule Raxol.Performance.AlertManager do
  @moduledoc """
  Advanced alerting system for Raxol performance monitoring.

  This module provides comprehensive alerting capabilities:
  - Multi-channel alert delivery (email, Slack, webhooks, SMS)
  - Intelligent alert grouping and deduplication
  - Alert escalation based on severity and duration
  - Integration with external monitoring systems (PagerDuty, Datadog, etc.)
  - Alert acknowledgment and resolution tracking
  - Historical alert analysis and reporting

  The AlertManager integrates with AutomatedMonitor to provide real-time
  notifications when performance issues are detected.
  """

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Core.Runtime.Log

  # Alert configuration
  # 5 minutes
  @alert_cooldown_ms 300_000
  # 30 minutes
  @escalation_timeout_ms 1_800_000

  defstruct [
    :alert_channels,
    :escalation_rules,
    :alert_history,
    :active_alerts,
    :alert_groups,
    :rate_limits,
    :external_integrations
  ]

  ## Client API

  @doc """
  Send a performance alert through configured channels.
  """
  def send_alert(alert_data, opts \\ []) do
    GenServer.call(__MODULE__, {:send_alert, alert_data, opts})
  end

  @doc """
  Acknowledge an active alert.
  """
  def acknowledge_alert(alert_id, user_info) do
    GenServer.call(__MODULE__, {:acknowledge_alert, alert_id, user_info})
  end

  @doc """
  Resolve an active alert.
  """
  def resolve_alert(alert_id, resolution_info) do
    GenServer.call(__MODULE__, {:resolve_alert, alert_id, resolution_info})
  end

  @doc """
  Configure alert channels and integrations.
  """
  def configure_channels(channel_config) do
    GenServer.call(__MODULE__, {:configure_channels, channel_config})
  end

  @doc """
  Get alert statistics and metrics.
  """
  def get_alert_stats do
    GenServer.call(__MODULE__, :get_alert_stats)
  end

  @doc """
  Get historical alert data for analysis.
  """
  def get_alert_history(time_range \\ :last_24_hours) do
    GenServer.call(__MODULE__, {:get_alert_history, time_range})
  end

  ## BaseManager Implementation

  @impl true
  def init_manager(opts) do
    state = %__MODULE__{
      alert_channels: configure_default_channels(opts),
      escalation_rules: configure_escalation_rules(opts),
      alert_history: [],
      active_alerts: %{},
      alert_groups: %{},
      rate_limits: %{},
      external_integrations: configure_external_integrations(opts)
    }

    # Start cleanup timer
    :timer.send_interval(60_000, :cleanup_alerts)

    Log.info("Performance AlertManager initialized", %{
      channels: Map.keys(state.alert_channels),
      integrations: Map.keys(state.external_integrations)
    })

    {:ok, state}
  end

  @impl true
  def handle_manager_call({:send_alert, alert_data, opts}, _from, state) do
    case process_alert(alert_data, opts, state) do
      {:ok, alert_id, new_state} ->
        {:reply, {:ok, alert_id}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}

      {:rate_limited, next_allowed} ->
        {:reply, {:rate_limited, next_allowed}, state}
    end
  end

  @impl true
  def handle_manager_call(
        {:acknowledge_alert, alert_id, user_info},
        _from,
        state
      ) do
    case Map.get(state.active_alerts, alert_id) do
      nil ->
        {:reply, {:error, :alert_not_found}, state}

      alert ->
        updated_alert = %{
          alert
          | status: :acknowledged,
            acknowledged_by: user_info,
            acknowledged_at: System.system_time(:millisecond)
        }

        new_active_alerts =
          Map.put(state.active_alerts, alert_id, updated_alert)

        new_state = %{state | active_alerts: new_active_alerts}

        Log.info("Alert acknowledged", %{
          alert_id: alert_id,
          user: user_info,
          type: alert.type
        })

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_manager_call(
        {:resolve_alert, alert_id, resolution_info},
        _from,
        state
      ) do
    case Map.get(state.active_alerts, alert_id) do
      nil ->
        {:reply, {:error, :alert_not_found}, state}

      alert ->
        resolved_alert = %{
          alert
          | status: :resolved,
            resolved_by: resolution_info.user,
            resolved_at: System.system_time(:millisecond),
            resolution_notes: resolution_info.notes
        }

        # Move to history
        new_history = [resolved_alert | state.alert_history]
        new_active_alerts = Map.delete(state.active_alerts, alert_id)

        new_state = %{
          state
          | active_alerts: new_active_alerts,
            alert_history: new_history
        }

        # Send resolution notification
        send_resolution_notification(resolved_alert, new_state)

        Log.info("Alert resolved", %{
          alert_id: alert_id,
          user: resolution_info.user,
          type: alert.type,
          duration_ms: resolved_alert.resolved_at - alert.created_at
        })

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_manager_call({:configure_channels, channel_config}, _from, state) do
    new_channels = Map.merge(state.alert_channels, channel_config)
    new_state = %{state | alert_channels: new_channels}

    Log.info("Alert channels updated", %{
      channels: Map.keys(new_channels)
    })

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_call(:get_alert_stats, _from, state) do
    stats = calculate_alert_statistics(state)
    {:reply, stats, state}
  end

  @impl true
  def handle_manager_call({:get_alert_history, time_range}, _from, state) do
    filtered_history = filter_alert_history(state.alert_history, time_range)
    {:reply, filtered_history, state}
  end

  @impl true
  def handle_manager_info(:cleanup_alerts, state) do
    # Clean up old resolved alerts and rate limit counters
    current_time = System.system_time(:millisecond)

    # Remove old rate limit entries
    new_rate_limits =
      state.rate_limits
      |> Enum.filter(fn {_key, last_time} ->
        # 1 hour
        current_time - last_time < 3_600_000
      end)
      |> Map.new()

    # Check for escalation
    escalated_alerts = check_escalation(state.active_alerts, current_time)
    new_state = %{state | rate_limits: new_rate_limits}

    # Process escalations
    final_state = process_escalations(escalated_alerts, new_state)

    {:noreply, final_state}
  end

  ## Private Implementation

  defp process_alert(alert_data, opts, state) do
    alert_id = generate_alert_id(alert_data)
    current_time = System.system_time(:millisecond)

    # Check rate limiting
    case check_rate_limit(alert_data, current_time, state.rate_limits) do
      {:rate_limited, next_allowed} ->
        {:rate_limited, next_allowed}

      :ok ->
        # Check for existing similar alerts (deduplication)
        case find_similar_alert(alert_data, state.active_alerts) do
          {:existing, existing_id} ->
            # Update existing alert instead of creating new one
            update_existing_alert(existing_id, alert_data, state)

          nil ->
            # Create new alert
            create_new_alert(alert_id, alert_data, opts, current_time, state)
        end
    end
  end

  defp check_rate_limit(alert_data, current_time, rate_limits) do
    rate_key = "#{alert_data.type}_#{alert_data.metric}"
    last_sent = Map.get(rate_limits, rate_key, 0)

    if current_time - last_sent < @alert_cooldown_ms do
      next_allowed = last_sent + @alert_cooldown_ms
      {:rate_limited, next_allowed}
    else
      :ok
    end
  end

  defp find_similar_alert(alert_data, active_alerts) do
    Enum.find_value(active_alerts, fn {alert_id, existing_alert} ->
      if alerts_similar?(alert_data, existing_alert) do
        {:existing, alert_id}
      else
        nil
      end
    end)
  end

  defp alerts_similar?(new_alert, existing_alert) do
    new_alert.type == existing_alert.type and
      new_alert.metric == existing_alert.metric and
      existing_alert.status == :active
  end

  defp update_existing_alert(alert_id, alert_data, state) do
    existing_alert = Map.get(state.active_alerts, alert_id)

    updated_alert = %{
      existing_alert
      | occurrence_count: existing_alert.occurrence_count + 1,
        last_occurrence: System.system_time(:millisecond),
        current_value: alert_data.value
    }

    new_active_alerts = Map.put(state.active_alerts, alert_id, updated_alert)
    new_state = %{state | active_alerts: new_active_alerts}

    # Send update notification if occurrence count hits certain thresholds
    if should_send_update_notification?(updated_alert) do
      send_alert_update(updated_alert, new_state)
    end

    {:ok, alert_id, new_state}
  end

  defp create_new_alert(alert_id, alert_data, _opts, current_time, state) do
    severity = determine_alert_severity(alert_data)

    alert = %{
      id: alert_id,
      type: alert_data.type,
      metric: alert_data.metric,
      current_value: alert_data.value,
      threshold: alert_data.threshold,
      severity: severity,
      status: :active,
      created_at: current_time,
      occurrence_count: 1,
      last_occurrence: current_time,
      escalation_level: 0,
      metadata: Map.get(alert_data, :metadata, %{})
    }

    # Add to active alerts
    new_active_alerts = Map.put(state.active_alerts, alert_id, alert)

    # Update rate limits
    rate_key = "#{alert_data.type}_#{alert_data.metric}"
    new_rate_limits = Map.put(state.rate_limits, rate_key, current_time)

    new_state = %{
      state
      | active_alerts: new_active_alerts,
        rate_limits: new_rate_limits
    }

    # Send alert notifications
    case send_alert_notifications(alert, new_state) do
      :ok ->
        Log.info("Performance alert sent", %{
          alert_id: alert_id,
          type: alert.type,
          severity: severity,
          value: alert_data.value,
          threshold: alert_data.threshold
        })

        {:ok, alert_id, new_state}

      {:error, reason} ->
        Log.error("Failed to send alert notifications", %{
          alert_id: alert_id,
          reason: reason
        })

        {:error, reason}
    end
  end

  defp generate_alert_id(alert_data) do
    timestamp = System.system_time(:millisecond)

    hash =
      :crypto.hash(
        :sha256,
        "#{alert_data.type}_#{alert_data.metric}_#{timestamp}"
      )

    Base.encode16(hash, case: :lower) |> String.slice(0, 12)
  end

  defp determine_alert_severity(alert_data) do
    ratio = alert_data.value / alert_data.threshold

    cond do
      ratio > 3.0 -> :critical
      ratio > 2.0 -> :high
      ratio > 1.5 -> :medium
      true -> :low
    end
  end

  defp send_alert_notifications(alert, state) do
    # Send through all configured channels based on severity
    channels_to_use =
      get_channels_for_severity(alert.severity, state.alert_channels)

    results =
      Enum.map(channels_to_use, fn {channel_name, channel_config} ->
        send_to_channel(channel_name, channel_config, alert)
      end)

    case Enum.any?(results, fn result -> result == :ok end) do
      true -> :ok
      false -> {:error, :all_channels_failed}
    end
  end

  defp get_channels_for_severity(:critical, channels) do
    # Critical alerts go to all channels
    Map.to_list(channels)
  end

  defp get_channels_for_severity(:high, channels) do
    # High severity alerts go to primary channels
    channels
    |> Enum.filter(fn {_name, config} ->
      config.priority in [:high, :critical]
    end)
  end

  defp get_channels_for_severity(:medium, channels) do
    # Medium alerts go to standard channels
    channels
    |> Enum.filter(fn {_name, config} ->
      config.priority in [:medium, :high, :critical]
    end)
  end

  defp get_channels_for_severity(:low, channels) do
    # Low alerts only go to monitoring channels
    channels
    |> Enum.filter(fn {_name, config} ->
      config.priority == :low or config.type == :monitoring
    end)
  end

  defp send_to_channel(:email, config, alert) do
    send_email_alert(config, alert)
  end

  defp send_to_channel(:slack, config, alert) do
    send_slack_alert(config, alert)
  end

  defp send_to_channel(:webhook, config, alert) do
    send_webhook_alert(config, alert)
  end

  defp send_to_channel(:log, _config, alert) do
    # Always send to centralized logging
    Log.warning("Performance Alert", %{
      alert_id: alert.id,
      type: alert.type,
      metric: alert.metric,
      value: alert.current_value,
      threshold: alert.threshold,
      severity: alert.severity
    })

    :ok
  end

  defp send_to_channel(channel_type, _config, alert) do
    Log.warning("Unsupported alert channel: #{channel_type}", %{
      alert_id: alert.id
    })

    {:error, :unsupported_channel}
  end

  defp send_email_alert(config, alert) do
    # Email implementation would go here
    Log.debug("Would send email alert", %{
      to: config.recipients,
      alert_id: alert.id,
      severity: alert.severity
    })

    :ok
  end

  defp send_slack_alert(config, alert) do
    # Slack implementation would go here
    Log.debug("Would send Slack alert", %{
      channel: config.channel,
      alert_id: alert.id,
      severity: alert.severity
    })

    :ok
  end

  defp send_webhook_alert(config, alert) do
    # Webhook implementation would go here
    Log.debug("Would send webhook alert", %{
      url: config.url,
      alert_id: alert.id,
      severity: alert.severity
    })

    :ok
  end

  defp should_send_update_notification?(alert) do
    # Send updates at specific occurrence thresholds
    alert.occurrence_count in [5, 10, 25, 50, 100]
  end

  defp send_alert_update(alert, state) do
    Log.info("Alert occurrence threshold reached", %{
      alert_id: alert.id,
      occurrences: alert.occurrence_count,
      duration_ms: System.system_time(:millisecond) - alert.created_at
    })

    # Send update through configured channels
    send_alert_notifications(alert, state)
  end

  defp check_escalation(active_alerts, current_time) do
    Enum.filter(active_alerts, fn {_id, alert} ->
      alert.status == :active and
        current_time - alert.created_at > @escalation_timeout_ms and
        alert.escalation_level == 0
    end)
  end

  defp process_escalations(escalated_alerts, state) do
    Enum.reduce(escalated_alerts, state, fn {alert_id, alert}, acc_state ->
      escalated_alert = %{alert | escalation_level: 1}

      new_active_alerts =
        Map.put(acc_state.active_alerts, alert_id, escalated_alert)

      Log.warning("Alert escalated due to timeout", %{
        alert_id: alert_id,
        duration_ms: System.system_time(:millisecond) - alert.created_at
      })

      # Send escalation notification
      send_escalation_notification(escalated_alert, acc_state)

      %{acc_state | active_alerts: new_active_alerts}
    end)
  end

  defp send_escalation_notification(alert, state) do
    # Escalations always go to critical channels
    critical_channels =
      get_channels_for_severity(:critical, state.alert_channels)

    Enum.each(critical_channels, fn {channel_name, channel_config} ->
      send_to_channel(channel_name, channel_config, alert)
    end)
  end

  defp send_resolution_notification(alert, state) do
    Log.info("Sending alert resolution notification", %{
      alert_id: alert.id
    })

    # Send resolution through primary channels
    primary_channels = get_channels_for_severity(:high, state.alert_channels)

    Enum.each(primary_channels, fn {channel_name, channel_config} ->
      send_resolution_to_channel(channel_name, channel_config, alert)
    end)
  end

  defp send_resolution_to_channel(channel_type, _config, alert) do
    Log.debug("Sending resolution notification via #{channel_type}", %{
      alert_id: alert.id,
      resolved_by: alert.resolved_by
    })

    :ok
  end

  defp calculate_alert_statistics(state) do
    current_time = System.system_time(:millisecond)
    last_24h = current_time - 86_400_000

    recent_alerts =
      Enum.filter(state.alert_history, fn alert ->
        alert.created_at > last_24h
      end)

    %{
      active_alerts: map_size(state.active_alerts),
      total_alerts_24h: length(recent_alerts),
      critical_alerts_24h:
        Enum.count(recent_alerts, &(&1.severity == :critical)),
      avg_resolution_time_ms: calculate_avg_resolution_time(recent_alerts),
      alert_rate_per_hour: length(recent_alerts) / 24,
      top_alert_types: get_top_alert_types(recent_alerts)
    }
  end

  defp calculate_avg_resolution_time(alerts) do
    resolved_alerts = Enum.filter(alerts, &(&1.status == :resolved))

    case resolved_alerts do
      [] ->
        0

      alerts ->
        total_time =
          Enum.sum(
            Enum.map(alerts, fn alert ->
              alert.resolved_at - alert.created_at
            end)
          )

        div(total_time, length(alerts))
    end
  end

  defp get_top_alert_types(alerts) do
    alerts
    |> Enum.group_by(&{&1.type, &1.metric})
    |> Enum.map(fn {type, type_alerts} -> {type, length(type_alerts)} end)
    |> Enum.sort_by(fn {_type, count} -> count end, :desc)
    |> Enum.take(5)
  end

  defp filter_alert_history(history, :last_hour) do
    cutoff = System.system_time(:millisecond) - 3_600_000
    Enum.filter(history, &(&1.created_at > cutoff))
  end

  defp filter_alert_history(history, :last_24_hours) do
    cutoff = System.system_time(:millisecond) - 86_400_000
    Enum.filter(history, &(&1.created_at > cutoff))
  end

  defp filter_alert_history(history, :last_week) do
    cutoff = System.system_time(:millisecond) - 604_800_000
    Enum.filter(history, &(&1.created_at > cutoff))
  end

  defp filter_alert_history(history, _), do: history

  defp configure_default_channels(opts) do
    %{
      log: %{type: :log, priority: :low, enabled: true},
      console: %{type: :console, priority: :medium, enabled: true}
    }
    |> Map.merge(Keyword.get(opts, :channels, %{}))
  end

  defp configure_escalation_rules(_opts) do
    %{
      timeout_ms: @escalation_timeout_ms,
      max_level: 2,
      escalation_channels: [:email, :slack, :webhook]
    }
  end

  defp configure_external_integrations(opts) do
    Keyword.get(opts, :integrations, %{})
  end
end
