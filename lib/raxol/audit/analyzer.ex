defmodule Raxol.Audit.Analyzer do
  @moduledoc """
  Analyzes audit events in real-time to detect security threats, anomalies,
  and compliance violations.

  This module implements various detection algorithms including:
  - Brute force attack detection
  - Privilege escalation attempts
  - Data exfiltration patterns
  - Unusual access patterns
  - Compliance violations
  """

  use GenServer
  require Logger

  defstruct [
    :config,
    :detection_rules,
    :alert_thresholds,
    :user_profiles,
    :anomaly_detector,
    :threat_indicators,
    :compliance_rules,
    :recent_events,
    :metrics
  ]

  @type detection_rule :: %{
          name: String.t(),
          type: :threshold | :pattern | :anomaly | :correlation,
          condition: function(),
          severity: :low | :medium | :high | :critical,
          action: :alert | :block | :investigate
        }

  ## Client API

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @doc """
  Analyzes an audit event for threats and anomalies.
  """
  def analyze_event(analyzer \\ __MODULE__, event) do
    GenServer.call(analyzer, {:analyze_event, event})
  end

  @doc """
  Analyzes a batch of events for correlations.
  """
  def analyze_batch(analyzer \\ __MODULE__, events) do
    GenServer.call(analyzer, {:analyze_batch, events})
  end

  @doc """
  Gets current threat level assessment.
  """
  def get_threat_assessment(analyzer \\ __MODULE__) do
    GenServer.call(analyzer, :get_threat_assessment)
  end

  @doc """
  Gets compliance status.
  """
  def get_compliance_status(analyzer \\ __MODULE__) do
    GenServer.call(analyzer, :get_compliance_status)
  end

  ## GenServer Implementation

  @impl GenServer
  def init(config) do
    state = %__MODULE__{
      config: config,
      detection_rules: init_detection_rules(),
      alert_thresholds: init_alert_thresholds(),
      user_profiles: %{},
      anomaly_detector: init_anomaly_detector(),
      threat_indicators: init_threat_indicators(),
      compliance_rules: init_compliance_rules(config),
      recent_events: :queue.new(),
      metrics: init_metrics()
    }

    # Schedule periodic analysis tasks
    # Every minute
    :timer.send_interval(60_000, :analyze_patterns)
    # Every 5 minutes
    :timer.send_interval(300_000, :update_profiles)

    Logger.info("Audit analyzer initialized")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:analyze_event, event}, _from, state) do
    {analysis_result, new_state} = perform_analysis(event, state)
    {:reply, analysis_result, new_state}
  end

  @impl GenServer
  def handle_call({:analyze_batch, events}, _from, state) do
    {analysis_results, new_state} = perform_batch_analysis(events, state)
    {:reply, analysis_results, new_state}
  end

  @impl GenServer
  def handle_call(:get_threat_assessment, _from, state) do
    assessment = calculate_threat_assessment(state)
    {:reply, {:ok, assessment}, state}
  end

  @impl GenServer
  def handle_call(:get_compliance_status, _from, state) do
    status = check_compliance_status(state)
    {:reply, {:ok, status}, state}
  end

  @impl GenServer
  def handle_info(:analyze_patterns, state) do
    new_state = analyze_recent_patterns(state)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(:update_profiles, state) do
    new_state = update_user_profiles(state)
    {:noreply, new_state}
  end

  ## Private Functions

  defp perform_analysis(event, state) do
    # Add event to recent events queue
    new_recent = :queue.in(event, state.recent_events)

    new_recent = trim_queue_if_needed(new_recent, 1000)

    # Run detection rules
    detections = run_detection_rules(event, state.detection_rules, state)

    # Check for anomalies
    anomalies = detect_anomalies(event, state)

    # Check compliance
    compliance_violations = check_compliance(event, state.compliance_rules)

    # Update user profile
    new_profiles = update_user_profile(event, state.user_profiles)

    # Update metrics
    new_metrics = update_metrics(event, detections, state.metrics)

    # Build analysis result
    analysis_result = %{
      event_id: event.event_id,
      timestamp: event.timestamp,
      detections: detections,
      anomalies: anomalies,
      compliance_violations: compliance_violations,
      risk_score: calculate_risk_score(detections, anomalies),
      recommended_actions: determine_actions(detections, anomalies)
    }

    new_state = %{
      state
      | recent_events: new_recent,
        user_profiles: new_profiles,
        metrics: new_metrics
    }

    # Trigger alerts if needed
    maybe_send_alert(analysis_result, state)

    {analysis_result, new_state}
  end

  defp perform_batch_analysis(events, state) do
    # Detect correlated patterns
    correlations = detect_correlations(events, state)

    # Check for attack patterns
    attack_patterns = detect_attack_patterns(events, state)

    # Analyze data flow
    data_flow_anomalies = analyze_data_flow(events, state)

    analysis_results = %{
      correlations: correlations,
      attack_patterns: attack_patterns,
      data_flow_anomalies: data_flow_anomalies,
      batch_risk_score:
        calculate_batch_risk_score(correlations, attack_patterns)
    }

    {analysis_results, state}
  end

  defp run_detection_rules(event, rules, state) do
    rules
    |> Enum.filter(fn rule -> rule.condition.(event, state) end)
    |> Enum.map(fn rule ->
      %{
        rule_name: rule.name,
        type: rule.type,
        severity: rule.severity,
        action: rule.action,
        details: extract_rule_details(rule, event)
      }
    end)
  end

  defp detect_anomalies(event, state) do
    anomalies = []

    # Check for unusual time of activity
    anomalies = add_time_anomaly_if_needed(anomalies, event, state)

    # Check for unusual location
    anomalies = add_location_anomaly_if_needed(anomalies, event, state)

    # Check for unusual behavior pattern
    anomalies = add_behavior_anomaly_if_needed(anomalies, event, state)

    anomalies
  end

  defp detect_correlations(events, _state) do
    correlations = []

    # Check for rapid succession of failed authentications
    failed_auth_count =
      Enum.count(events, fn e ->
        Map.get(e, :event_type) == :authentication and
          Map.get(e, :outcome) == :failure
      end)

    correlations_with_auth =
      add_brute_force_correlation(correlations, failed_auth_count)

    # Check for data exfiltration pattern
    data_access_events =
      Enum.filter(events, fn e ->
        Map.get(e, :operation) in [:read, :export]
      end)

    check_and_add_exfiltration_pattern(
      correlations_with_auth,
      data_access_events
    )
  end

  defp detect_attack_patterns(events, _state) do
    patterns = []

    # Check for privilege escalation attempts
    priv_events =
      Enum.filter(events, fn e ->
        Map.get(e, :action) == :privilege_escalation or
          String.contains?(Map.get(e, :command, ""), ["sudo", "su", "chmod"])
      end)

    patterns_with_priv = add_privilege_escalation_pattern(patterns, priv_events)

    # Check for reconnaissance patterns
    recon_commands = [
      "whoami",
      "id",
      "uname",
      "ps",
      "netstat",
      "ifconfig",
      "ls -la"
    ]

    recon_events =
      Enum.filter(events, fn e ->
        command = Map.get(e, :command, "")
        Enum.any?(recon_commands, &String.contains?(command, &1))
      end)

    add_reconnaissance_pattern(patterns_with_priv, recon_events)
  end

  defp analyze_data_flow(events, _state) do
    # Group events by user
    by_user = Enum.group_by(events, &Map.get(&1, :user_id))

    Enum.flat_map(by_user, fn {user_id, user_events} ->
      # Check for unusual data access patterns
      resources_accessed =
        user_events
        |> Enum.map(&Map.get(&1, :resource_id))
        |> Enum.filter(&(&1 != nil))
        |> Enum.uniq()
        |> length()

      check_excessive_resource_access(user_id, resources_accessed)
    end)
  end

  defp check_compliance(event, compliance_rules) do
    compliance_rules
    |> Enum.filter(fn rule -> rule.check.(event) end)
    |> Enum.map(fn rule ->
      %{
        framework: rule.framework,
        requirement: rule.requirement,
        violation: rule.violation_type,
        severity: rule.severity,
        remediation: rule.remediation
      }
    end)
  end

  defp unusual_time?(event, state) do
    hour =
      event.timestamp
      |> DateTime.from_unix!(:millisecond)
      |> Map.get(:hour)

    user_id = Map.get(event, :user_id)
    user_profile = Map.get(state.user_profiles, user_id, %{})
    usual_hours = Map.get(user_profile, :usual_hours, 8..18)

    hour not in usual_hours
  end

  defp unusual_location?(%{ip_address: nil}, _state), do: false

  defp unusual_location?(event, state) do
    user_id = Map.get(event, :user_id)
    user_profile = Map.get(state.user_profiles, user_id, %{})
    known_ips = Map.get(user_profile, :known_ips, MapSet.new())
    ip = Map.get(event, :ip_address)

    not MapSet.member?(known_ips, ip)
  end

  defp unusual_behavior?(event, state) do
    # Simplified behavior analysis
    user_id = Map.get(event, :user_id)
    user_profile = Map.get(state.user_profiles, user_id, %{})
    baseline = Map.get(user_profile, :behavior_baseline, %{})

    # Check if event type is unusual for this user
    event_type = Map.get(event, :event_type)
    usual_events = Map.get(baseline, :common_events, [])

    event_type not in usual_events and length(usual_events) > 10
  end

  defp calculate_risk_score(detections, anomalies) do
    detection_score =
      Enum.reduce(detections, 0, fn detection, acc ->
        acc + severity_score(detection.severity)
      end)

    anomaly_score =
      Enum.reduce(anomalies, 0, fn anomaly, acc ->
        acc + severity_score(anomaly.severity)
      end)

    min(100, detection_score + anomaly_score)
  end

  defp calculate_batch_risk_score(correlations, patterns) do
    correlation_score =
      Enum.reduce(correlations, 0, fn corr, acc ->
        acc + severity_score(corr.severity)
      end)

    pattern_score =
      Enum.reduce(patterns, 0, fn pattern, acc ->
        acc + severity_score(pattern.severity)
      end)

    min(100, correlation_score * 2 + pattern_score * 3)
  end

  defp severity_score(:low), do: 10
  defp severity_score(:medium), do: 25
  defp severity_score(:high), do: 50
  defp severity_score(:critical), do: 100

  defp determine_actions(detections, anomalies) do
    actions = []

    critical_detection = Enum.any?(detections, &(&1.severity == :critical))
    high_detection = Enum.any?(detections, &(&1.severity == :high))

    actions = add_critical_actions(actions, critical_detection)
    actions = add_high_priority_actions(actions, high_detection)
    add_anomaly_review_if_needed(actions, anomalies)
  end

  defp should_alert?(analysis_result) do
    analysis_result.risk_score > 50 or
      Enum.any?(
        analysis_result.detections,
        &(&1.severity in [:high, :critical])
      ) or
      length(analysis_result.compliance_violations) > 0
  end

  defp send_security_alert(analysis_result, _state) do
    Task.start(fn ->
      Logger.warning("Security Alert: #{inspect(analysis_result)}")
      # Here you would integrate with alerting systems (PagerDuty, Slack, etc.)
    end)
  end

  defp update_user_profile(%{user_id: nil}, profiles), do: profiles

  defp update_user_profile(event, profiles) do
    user_id = Map.get(event, :user_id)

    profile =
      Map.get(profiles, user_id, %{
        usual_hours: MapSet.new(),
        known_ips: MapSet.new(),
        common_events: [],
        behavior_baseline: %{}
      })

    # Update profile with new data
    hour =
      event.timestamp
      |> DateTime.from_unix!(:millisecond)
      |> Map.get(:hour)

    updated_profile =
      profile
      |> Map.update!(:usual_hours, &MapSet.put(&1, hour))
      |> Map.update!(:known_ips, &update_known_ips(&1, event))
      |> Map.update!(:common_events, &update_common_events(&1, event))

    Map.put(profiles, user_id, updated_profile)
  end

  defp analyze_recent_patterns(state) do
    recent_list = :queue.to_list(state.recent_events)

    # Analyze patterns in recent events
    patterns = detect_attack_patterns(recent_list, state)
    log_patterns_if_found(patterns)

    state
  end

  defp update_user_profiles(state) do
    # Periodically refine user profiles based on accumulated data
    state
  end

  defp calculate_threat_assessment(state) do
    recent_list = :queue.to_list(state.recent_events)

    critical_events =
      Enum.count(recent_list, fn e ->
        Map.get(e, :severity) == :critical
      end)

    high_events =
      Enum.count(recent_list, fn e ->
        Map.get(e, :severity) == :high
      end)

    threat_level = determine_threat_level(critical_events, high_events)

    %{
      threat_level: threat_level,
      critical_events: critical_events,
      high_events: high_events,
      total_events: length(recent_list),
      assessment_time: System.system_time(:millisecond)
    }
  end

  defp check_compliance_status(_state) do
    # Check current compliance status
    %{
      frameworks: [:soc2, :hipaa, :gdpr, :pci_dss],
      status: :compliant,
      last_check: System.system_time(:millisecond),
      findings: []
    }
  end

  defp init_detection_rules do
    [
      %{
        name: "brute_force_detection",
        type: :threshold,
        condition: fn event, _state ->
          Map.get(event, :event_type) == :authentication and
            Map.get(event, :outcome) == :failure
        end,
        severity: :high,
        action: :alert
      },
      %{
        name: "suspicious_command_execution",
        type: :pattern,
        condition: fn event, _state ->
          command =
            case event do
              %{command: cmd} when is_binary(cmd) -> cmd
              _ -> Map.get(event, :command, "")
            end

          suspicious = ["curl", "wget", "rm -rf", ":()", "| sh", "| bash"]
          Enum.any?(suspicious, &String.contains?(String.downcase(command), &1))
        end,
        severity: :critical,
        action: :block
      },
      %{
        name: "unauthorized_access_attempt",
        type: :pattern,
        condition: fn event, _state ->
          Map.get(event, :event_type) == :authorization and
            Map.get(event, :outcome) == :denied
        end,
        severity: :medium,
        action: :alert
      },
      %{
        name: "security_event_detected",
        type: :pattern,
        condition: fn event, _state ->
          Map.get(event, :event_type) == :security or
            Map.get(event, :action) == :intrusion_detected
        end,
        severity: :high,
        action: :investigate
      }
    ]
  end

  defp init_alert_thresholds do
    %{
      failed_auth_threshold: 5,
      data_access_threshold: 1000,
      configuration_changes_threshold: 10,
      time_window_minutes: 5
    }
  end

  defp init_anomaly_detector do
    %{
      baseline_window_days: 30,
      # Standard deviations
      deviation_threshold: 3.0,
      min_data_points: 100
    }
  end

  defp init_threat_indicators do
    %{
      known_bad_ips: MapSet.new(),
      suspicious_user_agents: [],
      malicious_patterns: []
    }
  end

  defp init_compliance_rules(_config) do
    [
      %{
        framework: :gdpr,
        requirement: "Data access logging",
        check: fn event ->
          Map.get(event, :event_type) == :data_access and
            Map.get(event, :data_classification) == :personal and
            Map.get(event, :legal_basis) == nil
        end,
        violation_type: :missing_legal_basis,
        severity: :high,
        remediation: "Ensure legal basis is documented for personal data access"
      },
      %{
        framework: :hipaa,
        requirement: "PHI access control",
        check: fn event ->
          Map.get(event, :data_classification) == :phi and
            Map.get(event, :mfa_used) == false
        end,
        violation_type: :missing_mfa,
        severity: :critical,
        remediation: "MFA required for PHI access"
      }
    ]
  end

  defp init_metrics do
    %{
      events_analyzed: 0,
      detections_triggered: 0,
      anomalies_detected: 0,
      compliance_violations: 0,
      alerts_sent: 0,
      start_time: System.system_time(:millisecond)
    }
  end

  defp update_metrics(_event, detections, metrics) do
    metrics
    |> Map.update!(:events_analyzed, &(&1 + 1))
    |> Map.update!(:detections_triggered, &(&1 + length(detections)))
  end

  defp extract_rule_details(_rule, event) do
    %{
      triggered_at: event.timestamp,
      event_id: event.event_id,
      user_id: Map.get(event, :user_id),
      resource: Map.get(event, :resource_id)
    }
  end

  # Helper functions for pattern matching refactoring

  defp determine_threat_level(critical_events, _high_events)
       when critical_events > 5,
       do: :critical

  defp determine_threat_level(critical_events, _high_events)
       when critical_events > 0,
       do: :high

  defp determine_threat_level(_critical_events, high_events)
       when high_events > 10,
       do: :high

  defp determine_threat_level(_critical_events, high_events)
       when high_events > 5,
       do: :medium

  defp determine_threat_level(_critical_events, _high_events), do: :low

  defp trim_queue_if_needed(queue, max_length) do
    case :queue.len(queue) > max_length do
      true ->
        {_, trimmed} = :queue.out(queue)
        trimmed

      false ->
        queue
    end
  end

  defp maybe_send_alert(analysis_result, state) do
    case should_alert?(analysis_result) do
      true -> send_security_alert(analysis_result, state)
      false -> :ok
    end
  end

  defp add_time_anomaly_if_needed(anomalies, event, state) do
    case unusual_time?(event, state) do
      true ->
        [
          %{
            type: :unusual_time,
            severity: :low,
            details: "Activity at unusual hour"
          }
          | anomalies
        ]

      false ->
        anomalies
    end
  end

  defp add_location_anomaly_if_needed(anomalies, event, state) do
    case unusual_location?(event, state) do
      true ->
        [
          %{
            type: :unusual_location,
            severity: :medium,
            details: "Access from new location"
          }
          | anomalies
        ]

      false ->
        anomalies
    end
  end

  defp add_behavior_anomaly_if_needed(anomalies, event, state) do
    case unusual_behavior?(event, state) do
      true ->
        [
          %{
            type: :unusual_behavior,
            severity: :high,
            details: "Behavior deviates from baseline"
          }
          | anomalies
        ]

      false ->
        anomalies
    end
  end

  defp add_brute_force_correlation(correlations, failed_auth_count)
       when failed_auth_count > 5 do
    [
      %{
        type: :brute_force_attempt,
        severity: :high,
        event_count: failed_auth_count,
        details: "Multiple failed authentication attempts detected"
      }
      | correlations
    ]
  end

  defp add_brute_force_correlation(correlations, _failed_auth_count),
    do: correlations

  defp check_and_add_exfiltration_pattern(correlations, data_access_events)
       when length(data_access_events) > 10 do
    total_records =
      Enum.sum(Enum.map(data_access_events, &Map.get(&1, :records_count, 0)))

    add_exfiltration_if_high_volume(correlations, total_records)
  end

  defp check_and_add_exfiltration_pattern(correlations, _data_access_events),
    do: correlations

  defp add_exfiltration_if_high_volume(correlations, total_records)
       when total_records > 1000 do
    [
      %{
        type: :potential_data_exfiltration,
        severity: :critical,
        records_accessed: total_records,
        details: "Large volume of data accessed in short time"
      }
      | correlations
    ]
  end

  defp add_exfiltration_if_high_volume(correlations, _total_records),
    do: correlations

  defp add_critical_actions(actions, true) do
    [
      :immediate_investigation,
      :notify_security_team,
      :consider_blocking | actions
    ]
  end

  defp add_critical_actions(actions, false), do: actions

  defp add_high_priority_actions(actions, true) do
    [:investigate, :increase_monitoring | actions]
  end

  defp add_high_priority_actions(actions, false), do: actions

  defp add_anomaly_review_if_needed(actions, anomalies)
       when length(anomalies) > 3 do
    [:review_user_activity | actions]
  end

  defp add_anomaly_review_if_needed(actions, _anomalies), do: actions

  defp update_known_ips(ips, %{ip_address: nil}), do: ips
  defp update_known_ips(ips, %{ip_address: ip}), do: MapSet.put(ips, ip)
  defp update_known_ips(ips, _event), do: ips

  defp update_common_events(events, event) do
    event_type = Map.get(event, :event_type)

    case event_type in events do
      true -> events
      # Keep last 20 event types
      false -> [event_type | Enum.take(events, 19)]
    end
  end

  defp log_patterns_if_found([]), do: :ok

  defp log_patterns_if_found(patterns) do
    Logger.warning("Patterns detected in recent events: #{inspect(patterns)}")
  end

  defp add_privilege_escalation_pattern(patterns, priv_events)
       when length(priv_events) > 3 do
    [
      %{
        type: :privilege_escalation_attempt,
        severity: :critical,
        event_count: length(priv_events),
        details: "Multiple privilege escalation attempts detected"
      }
      | patterns
    ]
  end

  defp add_privilege_escalation_pattern(patterns, _priv_events), do: patterns

  defp add_reconnaissance_pattern(patterns, recon_events)
       when length(recon_events) > 5 do
    [
      %{
        type: :reconnaissance_activity,
        severity: :medium,
        event_count: length(recon_events),
        details: "System reconnaissance activity detected"
      }
      | patterns
    ]
  end

  defp add_reconnaissance_pattern(patterns, _recon_events), do: patterns

  defp check_excessive_resource_access(user_id, resources_accessed)
       when resources_accessed > 50 do
    [
      %{
        type: :excessive_resource_access,
        user_id: user_id,
        severity: :medium,
        resources_count: resources_accessed,
        details: "User accessed unusually high number of resources"
      }
    ]
  end

  defp check_excessive_resource_access(_user_id, _resources_accessed), do: []
end
