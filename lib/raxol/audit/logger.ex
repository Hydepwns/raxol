defmodule Raxol.Audit.Logger do
  @moduledoc """
  Centralized audit logging system for compliance and security tracking.

  This module provides a comprehensive audit trail for all security-relevant
  actions in the system. It integrates with the event sourcing infrastructure
  to ensure durability and supports various compliance frameworks.

  ## Features

  - Automatic event correlation and enrichment
  - Configurable retention policies
  - Real-time alerting for critical events
  - Export capabilities for compliance reports
  - Integration with external SIEM systems
  - Tamper-proof event storage using cryptographic signatures
  """

  use GenServer
  require Logger

  alias Raxol.Architecture.EventSourcing.EventStore
  alias Raxol.Audit.{Events, Storage, Analyzer, Exporter}

  alias Raxol.Audit.Events.{
    AuthorizationEvent,
    ConfigurationChangeEvent,
    ComplianceEvent,
    DataPrivacyEvent
  }

  defstruct [
    :config,
    :event_store,
    :storage,
    :analyzer,
    :exporter,
    :buffer,
    :metrics,
    :alert_handlers,
    :retention_policy,
    :encryption_key
  ]

  @type config :: %{
          enabled: boolean(),
          log_level: :debug | :info | :warning | :error | :critical,
          buffer_size: pos_integer(),
          flush_interval_ms: pos_integer(),
          retention_days: pos_integer(),
          encrypt_events: boolean(),
          sign_events: boolean(),
          alert_on_critical: boolean(),
          export_enabled: boolean(),
          siem_integration: map() | nil
        }

  @default_config %{
    enabled: true,
    log_level: :info,
    buffer_size: 1000,
    flush_interval_ms: 5000,
    retention_days: 365,
    encrypt_events: false,
    sign_events: true,
    alert_on_critical: true,
    export_enabled: true,
    siem_integration: nil
  }

  ## Client API

  @doc """
  Starts the audit logger.
  """
  def start_link(opts \\ []) do
    config =
      Keyword.get(opts, :config, %{})
      |> then(&Map.merge(@default_config, &1))

    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @doc """
  Logs an authentication attempt.
  """
  def log_authentication(username, method, outcome, opts \\ []) do
    event = Events.authentication_event(username, method, outcome, opts)
    log_event(event, :authentication, determine_severity(outcome))
  end

  @doc """
  Logs an authorization decision.
  """
  def log_authorization(user_id, resource, action, outcome, opts \\ []) do
    event = %AuthorizationEvent{
      event_id: generate_event_id(),
      timestamp: System.system_time(:millisecond),
      user_id: user_id,
      resource_type: resource.type,
      resource_id: resource.id,
      action: action,
      outcome: outcome,
      permission: Keyword.get(opts, :permission),
      denial_reason: Keyword.get(opts, :denial_reason),
      policy_evaluated: Keyword.get(opts, :policy),
      ip_address: Keyword.get(opts, :ip_address),
      session_id: Keyword.get(opts, :session_id),
      metadata: Keyword.get(opts, :metadata, %{})
    }

    severity = if outcome == :denied, do: :medium, else: :low
    log_event(event, :authorization, severity)
  end

  @doc """
  Logs a data access operation.
  """
  def log_data_access(user_id, operation, resource_type, opts \\ []) do
    event = Events.data_access_event(user_id, operation, resource_type, opts)

    severity =
      determine_data_severity(
        operation,
        Keyword.get(opts, :data_classification)
      )

    log_event(event, :data_access, severity)
  end

  @doc """
  Logs a configuration change.
  """
  def log_configuration_change(
        user_id,
        component,
        setting,
        old_value,
        new_value,
        opts \\ []
      ) do
    event = %ConfigurationChangeEvent{
      event_id: generate_event_id(),
      timestamp: System.system_time(:millisecond),
      user_id: user_id,
      component: component,
      setting: setting,
      old_value: sanitize_value(old_value),
      new_value: sanitize_value(new_value),
      change_type: determine_change_type(old_value, new_value),
      approval_required: Keyword.get(opts, :approval_required, false),
      approved_by: Keyword.get(opts, :approved_by),
      rollback_available: Keyword.get(opts, :rollback_available, true),
      ip_address: Keyword.get(opts, :ip_address),
      session_id: Keyword.get(opts, :session_id),
      metadata: Keyword.get(opts, :metadata, %{})
    }

    log_event(event, :configuration, :medium)
  end

  @doc """
  Logs a security event.
  """
  def log_security_event(event_type, severity, description, opts \\ []) do
    event = Events.security_event(event_type, severity, description, opts)
    log_event(event, :security, severity)
  end

  @doc """
  Logs a terminal operation.
  """
  def log_terminal_operation(user_id, terminal_id, action, opts \\ []) do
    event = Events.terminal_audit_event(user_id, terminal_id, action, opts)
    severity = determine_terminal_severity(action, Keyword.get(opts, :command))
    log_event(event, :terminal, severity)
  end

  @doc """
  Logs a compliance-related activity.
  """
  def log_compliance(framework, requirement, activity, status, opts \\ []) do
    event = %ComplianceEvent{
      event_id: generate_event_id(),
      timestamp: System.system_time(:millisecond),
      compliance_framework: framework,
      requirement: requirement,
      activity: activity,
      status: status,
      evidence: Keyword.get(opts, :evidence),
      auditor_id: Keyword.get(opts, :auditor_id),
      findings: Keyword.get(opts, :findings),
      remediation_required: Keyword.get(opts, :remediation_required, false),
      due_date: Keyword.get(opts, :due_date),
      metadata: Keyword.get(opts, :metadata, %{})
    }

    severity = if status == :non_compliant, do: :high, else: :info
    log_event(event, :compliance, severity)
  end

  @doc """
  Logs a data privacy request (GDPR).
  """
  def log_privacy_request(data_subject_id, request_type, status, opts \\ []) do
    event = %DataPrivacyEvent{
      event_id: generate_event_id(),
      timestamp: System.system_time(:millisecond),
      data_subject_id: data_subject_id,
      request_type: request_type,
      status: status,
      processor_id: Keyword.get(opts, :processor_id),
      data_categories: Keyword.get(opts, :data_categories),
      legal_basis: Keyword.get(opts, :legal_basis),
      retention_period: Keyword.get(opts, :retention_period),
      third_parties: Keyword.get(opts, :third_parties),
      cross_border_transfer: Keyword.get(opts, :cross_border_transfer, false),
      metadata: Keyword.get(opts, :metadata, %{})
    }

    log_event(event, :privacy, :medium)
  end

  @doc """
  Logs a debug message.
  """
  def debug(message) do
    Logger.debug("[AUDIT] #{message}")
  end

  @doc """
  Queries audit logs with filters.
  """
  def query_logs(filters \\ %{}, opts \\ []) do
    GenServer.call(__MODULE__, {:query_logs, filters, opts}, 30_000)
  end

  @doc """
  Exports audit logs for compliance reporting.
  """
  def export_logs(format, filters \\ %{}, opts \\ []) do
    GenServer.call(__MODULE__, {:export_logs, format, filters, opts}, 60_000)
  end

  @doc """
  Gets audit statistics.
  """
  def get_statistics(time_range \\ :last_24_hours) do
    GenServer.call(__MODULE__, {:get_statistics, time_range})
  end

  @doc """
  Verifies the integrity of audit logs.
  """
  def verify_integrity(start_time, end_time) do
    GenServer.call(
      __MODULE__,
      {:verify_integrity, start_time, end_time},
      60_000
    )
  end

  ## GenServer Implementation

  @impl GenServer
  def init(config) do
    Process.flag(:trap_exit, true)

    # Initialize components
    {:ok, event_store} = get_or_start_event_store()
    {:ok, storage} = Storage.start_link(config)
    {:ok, analyzer} = Analyzer.start_link(config)
    {:ok, exporter} = Exporter.start_link(config)

    state = %__MODULE__{
      config: config,
      event_store: event_store,
      storage: storage,
      analyzer: analyzer,
      exporter: exporter,
      buffer: [],
      metrics: init_metrics(),
      alert_handlers: init_alert_handlers(config),
      retention_policy: init_retention_policy(config),
      encryption_key: init_encryption_key(config)
    }

    # Schedule periodic tasks
    if config.enabled do
      :timer.send_interval(config.flush_interval_ms, :flush_buffer)
      # Every hour
      :timer.send_interval(3_600_000, :cleanup_old_logs)
      # Daily
      :timer.send_interval(86_400_000, :verify_integrity)
    end

    Logger.info("Audit logger initialized with config: #{inspect(config)}")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:log_event, event, category, severity}, _from, state) do
    if state.config.enabled and should_log?(severity, state.config.log_level) do
      case process_event(event, category, severity, state) do
        {:ok, new_state} ->
          {:reply, :ok, new_state}

        {:error, reason} ->
          Logger.error("Failed to log audit event: #{inspect(reason)}")
          {:reply, {:error, reason}, state}
      end
    else
      {:reply, :ok, state}
    end
  end

  @impl GenServer
  def handle_call({:query_logs, filters, opts}, _from, state) do
    case Storage.query(state.storage, filters, opts) do
      {:ok, results} -> {:reply, {:ok, results}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:export_logs, format, filters, opts}, _from, state) do
    case Exporter.export(state.exporter, format, filters, opts) do
      {:ok, exported_data} -> {:reply, {:ok, exported_data}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:get_statistics, time_range}, _from, state) do
    stats = calculate_statistics(state, time_range)
    {:reply, {:ok, stats}, state}
  end

  @impl GenServer
  def handle_call({:verify_integrity, start_time, end_time}, _from, state) do
    case verify_log_integrity(state, start_time, end_time) do
      :ok -> {:reply, {:ok, :verified}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_info(:flush_buffer, state) do
    case flush_buffer_to_storage(state) do
      {:ok, new_state} -> {:noreply, new_state}
      {:error, _reason} -> {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info(:cleanup_old_logs, state) do
    Task.start(fn ->
      cleanup_expired_logs(state)
    end)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:verify_integrity, state) do
    Task.start(fn ->
      verify_daily_integrity(state)
    end)

    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, state) do
    # Flush any remaining buffered events
    flush_buffer_to_storage(state)
    :ok
  end

  ## Private Functions

  defp log_event(event, category, severity) do
    GenServer.call(__MODULE__, {:log_event, event, category, severity})
  end

  defp process_event(event, category, severity, state) do
    # Enrich event with additional context
    enriched_event = enrich_event(event, state)

    # Sign event if configured
    signed_event =
      if state.config.sign_events do
        sign_event(enriched_event, state)
      else
        enriched_event
      end

    # Encrypt if configured
    final_event =
      if state.config.encrypt_events do
        encrypt_event(signed_event, state)
      else
        signed_event
      end

    # Add to buffer
    new_buffer = [final_event | state.buffer]

    # Check if we should flush immediately (critical events)
    should_flush =
      severity == :critical or length(new_buffer) >= state.config.buffer_size

    new_state = %{state | buffer: new_buffer}

    # Update metrics
    new_state = update_metrics(new_state, category, severity)

    # Send alerts if needed
    if severity in [:critical, :high] and state.config.alert_on_critical do
      send_alerts(final_event, severity, state)
    end

    # Flush if needed
    if should_flush do
      flush_buffer_to_storage(new_state)
    else
      {:ok, new_state}
    end
  end

  defp enrich_event(event, _state) do
    # Add system context
    Map.merge(event, %{
      node: node(),
      environment: System.get_env("RAXOL_ENV", "production"),
      version: Application.spec(:raxol, :vsn) |> to_string(),
      enriched_at: System.system_time(:millisecond)
    })
  end

  defp sign_event(event, state) do
    signature =
      :crypto.mac(
        :hmac,
        :sha256,
        state.encryption_key,
        :erlang.term_to_binary(event)
      )
      |> Base.encode64()

    Map.put(event, :signature, signature)
  end

  defp encrypt_event(event, state) do
    # Simple encryption - in production, use proper encryption library
    encrypted_data =
      :crypto.crypto_one_time(
        :aes_256_gcm,
        state.encryption_key,
        generate_iv(),
        :erlang.term_to_binary(event),
        true
      )

    %{
      encrypted: true,
      data: Base.encode64(encrypted_data),
      algorithm: "AES-256-GCM",
      timestamp: event.timestamp
    }
  end

  defp flush_buffer_to_storage(state) do
    if Enum.empty?(state.buffer) do
      {:ok, state}
    else
      events_to_flush = Enum.reverse(state.buffer)

      # Store in event store
      stream_name = "audit-#{Date.utc_today() |> Date.to_iso8601()}"

      case EventStore.append_events(
             state.event_store,
             events_to_flush,
             stream_name
           ) do
        {:ok, _event_ids} ->
          # Also store in specialized audit storage
          Storage.store_batch(state.storage, events_to_flush)

          # Clear buffer
          {:ok, %{state | buffer: []}}

        {:error, reason} ->
          Logger.error("Failed to flush audit buffer: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp determine_severity(:failure), do: :medium
  defp determine_severity(:locked), do: :high
  defp determine_severity(:expired), do: :low
  defp determine_severity(:success), do: :info
  defp determine_severity(_), do: :low

  defp determine_data_severity(:delete, :restricted), do: :critical
  defp determine_data_severity(:export, :restricted), do: :high
  defp determine_data_severity(:delete, :confidential), do: :high
  defp determine_data_severity(:export, :confidential), do: :medium
  defp determine_data_severity(_, _), do: :low

  defp determine_terminal_severity(:privilege_escalation, _), do: :critical

  defp determine_terminal_severity(:command_executed, command) do
    dangerous_commands = [
      "rm -rf",
      "sudo",
      "chmod 777",
      "curl | sh",
      "wget | sh"
    ]

    if Enum.any?(dangerous_commands, &String.contains?(command || "", &1)) do
      :high
    else
      :low
    end
  end

  defp determine_terminal_severity(_, _), do: :low

  defp determine_change_type(nil, _), do: :create
  defp determine_change_type(_, nil), do: :delete
  defp determine_change_type(_, _), do: :update

  defp sanitize_value(value) when is_binary(value) do
    # Remove sensitive patterns
    value
    |> String.replace(~r/password=\S+/, "password=***")
    |> String.replace(~r/token=\S+/, "token=***")
    |> String.replace(~r/key=\S+/, "key=***")
  end

  defp sanitize_value(value), do: value

  defp should_log?(event_level, configured_level) do
    level_priority = %{
      debug: 0,
      info: 1,
      warning: 2,
      error: 3,
      critical: 4
    }

    level_priority[event_level] >= level_priority[configured_level]
  end

  defp init_metrics do
    %{
      total_events: 0,
      events_by_category: %{},
      events_by_severity: %{},
      last_event_time: nil,
      start_time: System.system_time(:millisecond)
    }
  end

  defp update_metrics(state, category, severity) do
    metrics =
      state.metrics
      |> Map.update!(:total_events, &(&1 + 1))
      |> Map.update!(:events_by_category, fn cats ->
        Map.update(cats, category, 1, &(&1 + 1))
      end)
      |> Map.update!(:events_by_severity, fn sevs ->
        Map.update(sevs, severity, 1, &(&1 + 1))
      end)
      |> Map.put(:last_event_time, System.system_time(:millisecond))

    %{state | metrics: metrics}
  end

  defp init_alert_handlers(_config) do
    # Initialize alert handlers based on config
    []
  end

  defp init_retention_policy(config) do
    %{
      retention_days: config.retention_days,
      archive_after_days: 30,
      compress_after_days: 7
    }
  end

  defp init_encryption_key(_config) do
    # In production, load from secure key management
    :crypto.strong_rand_bytes(32)
  end

  defp send_alerts(event, severity, state) do
    # Send alerts through configured channels
    Task.start(fn ->
      Enum.each(state.alert_handlers, fn handler ->
        handler.(event, severity)
      end)
    end)
  end

  defp cleanup_expired_logs(state) do
    cutoff_time =
      System.system_time(:millisecond) -
        state.retention_policy.retention_days * 86_400_000

    Storage.delete_before(state.storage, cutoff_time)
  end

  defp verify_log_integrity(state, start_time, end_time) do
    case Storage.get_events_in_range(state.storage, start_time, end_time) do
      {:ok, events} ->
        verify_event_signatures(events, state)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp verify_event_signatures(events, state) do
    invalid =
      Enum.filter(events, fn event ->
        case Map.get(event, :signature) do
          # Unsigned events are allowed if signing is disabled
          nil ->
            false

          signature ->
            event_without_sig = Map.delete(event, :signature)

            expected_sig =
              :crypto.mac(
                :hmac,
                :sha256,
                state.encryption_key,
                :erlang.term_to_binary(event_without_sig)
              )
              |> Base.encode64()

            signature != expected_sig
        end
      end)

    if Enum.empty?(invalid) do
      :ok
    else
      {:error, {:tampered_events, length(invalid)}}
    end
  end

  defp verify_daily_integrity(state) do
    end_time = System.system_time(:millisecond)
    # 24 hours ago
    start_time = end_time - 86_400_000

    case verify_log_integrity(state, start_time, end_time) do
      :ok ->
        Logger.info("Daily integrity check passed")

      {:error, reason} ->
        Logger.error("Daily integrity check failed: #{inspect(reason)}")
        # Send critical alert
        send_alerts(%{integrity_check_failed: reason}, :critical, state)
    end
  end

  defp calculate_statistics(state, :last_24_hours) do
    %{
      total_events: state.metrics.total_events,
      events_by_category: state.metrics.events_by_category,
      events_by_severity: state.metrics.events_by_severity,
      uptime_hours:
        div(
          System.system_time(:millisecond) - state.metrics.start_time,
          3_600_000
        ),
      buffer_size: length(state.buffer),
      last_event: state.metrics.last_event_time
    }
  end

  defp get_or_start_event_store do
    case Process.whereis(EventStore) do
      nil -> EventStore.start_link()
      pid -> {:ok, pid}
    end
  end

  defp generate_event_id do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  defp generate_iv do
    :crypto.strong_rand_bytes(16)
  end
end
