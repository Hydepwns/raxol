defmodule Raxol.Audit.EventsTest do
  use ExUnit.Case, async: true
  alias Raxol.Audit.Events

  describe "authentication_event/4" do
    test "creates valid authentication event with all fields" do
      event = Events.authentication_event("testuser", :password, :success,
        ip_address: "192.168.1.1",
        session_id: "sess123",
        mfa_used: true
      )

      assert event.username == "testuser"
      assert event.authentication_method == :password
      assert event.outcome == :success
      assert event.ip_address == "192.168.1.1"
      assert event.session_id == "sess123"
      assert event.mfa_used == true
      assert event.event_id != nil
      assert event.timestamp != nil
    end

    test "sets failure reason when outcome is failure" do
      event = Events.authentication_event("testuser", :password, :failure,
        failure_reason: "Invalid password"
      )

      assert event.outcome == :failure
      assert event.failure_reason == "Invalid password"
    end
  end

  describe "data_access_event/4" do
    test "creates valid data access event" do
      event = Events.data_access_event("user123", :read, "customer_records",
        records_count: 100,
        data_classification: :confidential
      )

      assert event.user_id == "user123"
      assert event.operation == :read
      assert event.resource_type == "customer_records"
      assert event.records_count == 100
      assert event.data_classification == :confidential
    end

    test "marks export operations properly" do
      event = Events.data_access_event("user123", :export, "financial_data",
        export_format: :csv,
        records_count: 5000
      )

      assert event.operation == :export
      assert Map.get(event.metadata, :export_format) == :csv
    end
  end

  describe "security_event/4" do
    test "creates security event with proper severity" do
      event = Events.security_event(:intrusion_attempt, :critical, 
        "Unauthorized access attempt detected",
        source_ip: "10.0.0.1",
        target_resource: "/admin"
      )

      assert event.event_type == :intrusion_attempt
      assert event.severity == :critical
      assert event.description == "Unauthorized access attempt detected"
    end

    test "includes threat indicators when provided" do
      event = Events.security_event(:malware_detected, :high,
        "Malicious payload detected",
        threat_indicators: ["suspicious.exe", "backdoor.sh"],
        action_taken: :blocked
      )

      assert event.threat_indicators == ["suspicious.exe", "backdoor.sh"]
      assert event.action_taken == :blocked
    end
  end

  describe "terminal_audit_event/4" do
    test "creates terminal operation event" do
      event = Events.terminal_audit_event("user123", "term001", :command_executed,
        command: "sudo rm -rf /",
        exit_code: 1,
        duration_ms: 150
      )

      assert event.user_id == "user123"
      assert event.terminal_id == "term001"
      assert event.action == :command_executed
      assert event.command == "sudo rm -rf /"
      assert event.exit_code == 1
      assert event.duration_ms == 150
    end

    test "tracks privilege escalation attempts" do
      event = Events.terminal_audit_event("user123", "term001", :privilege_escalation,
        command: "sudo su -",
        elevation_type: :sudo,
        target_user: "root"
      )

      assert event.action == :privilege_escalation
      assert Map.get(event.metadata, :elevation_type) == :sudo
      assert Map.get(event.metadata, :target_user) == "root"
    end
  end

  describe "compliance_event/5" do
    test "creates compliance event for successful audit" do
      event = Events.compliance_event(:soc2, "CC6.1", :audit_performed, :compliant,
        evidence: "Access logs reviewed",
        auditor_id: "auditor001"
      )

      assert event.compliance_framework == :soc2
      assert event.requirement == "CC6.1"
      assert event.activity == :audit_performed
      assert event.status == :compliant
      assert event.evidence == "Access logs reviewed"
    end

    test "tracks non-compliance with remediation requirements" do
      event = Events.compliance_event(:hipaa, "164.312(a)", :audit_performed, :non_compliant,
        findings: ["MFA not enforced", "Encryption at rest missing"],
        remediation_required: true,
        due_date: ~D[2025-12-31]
      )

      assert event.status == :non_compliant
      assert length(event.findings) == 2
      assert event.remediation_required == true
      assert event.due_date == ~D[2025-12-31]
    end
  end

  describe "privacy_event/4" do
    test "creates GDPR data subject request event" do
      event = Events.privacy_event("subject123", :access_request, :completed,
        data_categories: ["personal_info", "usage_data"],
        legal_basis: :consent,
        processor_id: "proc001"
      )

      assert event.data_subject_id == "subject123"
      assert event.request_type == :access_request
      assert event.status == :completed
      assert event.data_categories == ["personal_info", "usage_data"]
      assert event.legal_basis == :consent
    end

    test "tracks cross-border data transfers" do
      event = Events.privacy_event("subject456", :portability_request, :in_progress,
        cross_border_transfer: true,
        third_parties: ["Partner A", "Partner B"],
        retention_period: 365
      )

      assert event.cross_border_transfer == true
      assert length(event.third_parties) == 2
      assert event.retention_period == 365
    end
  end

  describe "configuration_change_event/6" do
    test "creates configuration change event" do
      event = Events.configuration_change_event("admin123", "security", "mfa_enabled",
        false, true,
        approval_required: true,
        approved_by: "admin456"
      )

      assert event.user_id == "admin123"
      assert event.component == "security"
      assert event.setting == "mfa_enabled"
      assert event.old_value == false
      assert event.new_value == true
      assert event.change_type == :update
      assert event.approved_by == "admin456"
    end

    test "detects change types correctly" do
      # Create
      create_event = Events.configuration_change_event("admin", "app", "setting", nil, "value")
      assert create_event.change_type == :create

      # Update
      update_event = Events.configuration_change_event("admin", "app", "setting", "old", "new")
      assert update_event.change_type == :update

      # Delete
      delete_event = Events.configuration_change_event("admin", "app", "setting", "value", nil)
      assert delete_event.change_type == :delete
    end
  end

  describe "event validation" do
    test "all events have required base fields" do
      events = [
        Events.authentication_event("user", :password, :success),
        Events.data_access_event("user", :read, "resource"),
        Events.security_event(:alert, :low, "test"),
        Events.terminal_audit_event("user", "term", :action),
        Events.compliance_event(:soc2, "req", :activity, :status),
        Events.privacy_event("subject", :request, :status)
      ]

      Enum.each(events, fn event ->
        assert event.event_id != nil
        assert event.timestamp != nil
        assert is_integer(event.timestamp)
        assert event.timestamp > 0
      end)
    end

    test "event IDs are unique" do
      events = for _ <- 1..100 do
        Events.authentication_event("user", :password, :success)
      end

      event_ids = Enum.map(events, & &1.event_id)
      assert length(event_ids) == length(Enum.uniq(event_ids))
    end
  end
end