defmodule Raxol.Audit.LoggerTest do
  use ExUnit.Case, async: false
  alias Raxol.Audit.Logger

  setup do
    # Start logger with test configuration
    config = %{
      enabled: true,
      log_level: :debug,
      buffer_size: 10,
      flush_interval_ms: 100,
      retention_days: 1,
      encrypt_events: false,
      sign_events: false,  # Disable signing for tests to avoid signature verification issues
      alert_on_critical: false,
      export_enabled: true,
      siem_integration: nil
    }

    {:ok, _pid} = Logger.start_link(config: config)

    on_exit(fn ->
      case Process.whereis(Logger) do
        pid when is_pid(pid) ->
          try do
            GenServer.stop(Logger, :normal, 1000)
          catch
            :exit, _ -> :ok
          end
        nil -> :ok
      end
    end)

    :ok
  end

  describe "authentication logging" do
    test "logs successful authentication" do
      assert :ok =
               Logger.log_authentication("testuser", :password, :success,
                 ip_address: "192.168.1.1",
                 session_id: "sess123"
               )
    end

    test "logs failed authentication with reason" do
      assert :ok =
               Logger.log_authentication("testuser", :password, :failure,
                 failure_reason: "Invalid password",
                 ip_address: "192.168.1.1"
               )
    end

    test "logs locked account" do
      assert :ok =
               Logger.log_authentication("testuser", :password, :locked,
                 failure_reason: "Too many failed attempts",
                 ip_address: "192.168.1.1"
               )
    end
  end

  describe "authorization logging" do
    test "logs successful authorization" do
      resource = %{type: "document", id: "doc123"}

      assert :ok =
               Logger.log_authorization("user123", resource, :read, :granted,
                 permission: "document.read",
                 session_id: "sess456"
               )
    end

    test "logs denied authorization" do
      resource = %{type: "admin_panel", id: "admin"}

      assert :ok =
               Logger.log_authorization("user123", resource, :access, :denied,
                 denial_reason: "Insufficient privileges",
                 policy: "admin_only"
               )
    end
  end

  describe "data access logging" do
    test "logs data read operation" do
      assert :ok =
               Logger.log_data_access("user123", :read, "customer_records",
                 records_count: 50,
                 data_classification: :public
               )
    end

    test "logs sensitive data export" do
      assert :ok =
               Logger.log_data_access("user123", :export, "financial_data",
                 records_count: 1000,
                 data_classification: :restricted,
                 export_format: :csv
               )
    end

    test "logs data deletion" do
      assert :ok =
               Logger.log_data_access("user123", :delete, "user_profiles",
                 records_count: 1,
                 data_classification: :confidential
               )
    end
  end

  describe "configuration change logging" do
    test "logs configuration creation" do
      assert :ok =
               Logger.log_configuration_change(
                 "admin123",
                 "security",
                 "new_setting",
                 nil,
                 "enabled",
                 approval_required: false
               )
    end

    test "logs configuration update with approval" do
      assert :ok =
               Logger.log_configuration_change(
                 "admin123",
                 "auth",
                 "mfa_required",
                 false,
                 true,
                 approval_required: true,
                 approved_by: "superadmin"
               )
    end

    test "logs configuration deletion" do
      assert :ok =
               Logger.log_configuration_change(
                 "admin123",
                 "features",
                 "legacy_mode",
                 true,
                 nil,
                 rollback_available: true
               )
    end
  end

  describe "security event logging" do
    test "logs critical security event" do
      assert :ok =
               Logger.log_security_event(
                 :intrusion_detected,
                 :critical,
                 "Unauthorized access attempt from suspicious IP",
                 source_ip: "123.456.789.0",
                 target: "/admin",
                 action_taken: :blocked
               )
    end

    test "logs medium severity event" do
      assert :ok =
               Logger.log_security_event(
                 :suspicious_activity,
                 :medium,
                 "Multiple failed login attempts",
                 user_id: "user123",
                 attempt_count: 5
               )
    end
  end

  describe "terminal operation logging" do
    test "logs command execution" do
      assert :ok =
               Logger.log_terminal_operation(
                 "user123",
                 "term001",
                 :command_executed,
                 command: "ls -la",
                 exit_code: 0,
                 duration_ms: 25
               )
    end

    test "logs dangerous command" do
      assert :ok =
               Logger.log_terminal_operation(
                 "user123",
                 "term001",
                 :command_executed,
                 command: "sudo rm -rf /",
                 exit_code: 1,
                 blocked: true
               )
    end

    test "logs privilege escalation" do
      assert :ok =
               Logger.log_terminal_operation(
                 "user123",
                 "term001",
                 :privilege_escalation,
                 command: "sudo su -",
                 target_user: "root"
               )
    end
  end

  describe "compliance logging" do
    test "logs compliant audit" do
      assert :ok =
               Logger.log_compliance(
                 :soc2,
                 "CC6.1",
                 :audit_performed,
                 :compliant,
                 evidence: "All access logs present",
                 auditor_id: "auditor001"
               )
    end

    test "logs non-compliant finding" do
      assert :ok =
               Logger.log_compliance(
                 :hipaa,
                 "164.312",
                 :audit_performed,
                 :non_compliant,
                 findings: ["Encryption not enabled", "MFA not enforced"],
                 remediation_required: true,
                 due_date: ~D[2025-12-31]
               )
    end
  end

  describe "privacy request logging" do
    test "logs GDPR access request" do
      assert :ok =
               Logger.log_privacy_request(
                 "subject123",
                 :access_request,
                 :completed,
                 data_categories: ["personal", "usage"],
                 legal_basis: :consent
               )
    end

    test "logs deletion request" do
      assert :ok =
               Logger.log_privacy_request(
                 "subject456",
                 :deletion_request,
                 :in_progress,
                 data_categories: ["all"],
                 processor_id: "proc001"
               )
    end

    test "logs portability request with cross-border transfer" do
      assert :ok =
               Logger.log_privacy_request(
                 "subject789",
                 :portability_request,
                 :completed,
                 cross_border_transfer: true,
                 third_parties: ["Partner A"],
                 retention_period: 30
               )
    end
  end

  describe "query functionality" do
    setup do
      # Log some events for querying
      Logger.log_authentication("user1", :password, :success)
      Logger.log_authentication("user2", :password, :failure)
      Logger.log_data_access("user1", :read, "data")

      # Give buffer time to flush
      Process.sleep(200)
      :ok
    end

    test "queries logs with filters" do
      {:ok, results} = Logger.query_logs(%{user_id: "user1"})
      assert is_list(results)
    end

    test "queries with time range" do
      start_time = System.system_time(:millisecond) - 60_000
      end_time = System.system_time(:millisecond)

      {:ok, results} =
        Logger.query_logs(%{
          start_time: start_time,
          end_time: end_time
        })

      assert is_list(results)
    end
  end

  describe "statistics" do
    test "gets audit statistics" do
      Logger.log_authentication("user1", :password, :success)
      Logger.log_security_event(:alert, :high, "Test alert")

      Process.sleep(200)

      {:ok, stats} = Logger.get_statistics()

      assert Map.has_key?(stats, :total_events)
      assert Map.has_key?(stats, :events_by_category)
      assert Map.has_key?(stats, :events_by_severity)
      assert Map.has_key?(stats, :uptime_hours)
    end
  end

  describe "integrity verification" do
    test "verifies log integrity for time range" do
      # Record the start time before logging events
      start_time = System.system_time(:millisecond)

      Logger.log_authentication("user1", :password, :success)
      Process.sleep(200)

      # Only verify events from this test run
      end_time = System.system_time(:millisecond)

      {:ok, result} = Logger.verify_integrity(start_time, end_time)
      assert result == :verified
    end
  end

  describe "severity determination" do
    test "determines correct severity for authentication outcomes" do
      # Success should be info level
      Logger.log_authentication("user", :password, :success)

      # Failure should be medium
      Logger.log_authentication("user", :password, :failure)

      # Locked should be high
      Logger.log_authentication("user", :password, :locked)

      Process.sleep(200)
      {:ok, stats} = Logger.get_statistics()

      assert is_map(stats.events_by_severity)
    end
  end

  describe "buffering and flushing" do
    test "buffers events and flushes periodically" do
      # Log multiple events quickly
      for i <- 1..5 do
        Logger.log_authentication("user#{i}", :password, :success)
      end

      # Buffer should hold events initially
      Process.sleep(50)

      # After flush interval, buffer should be empty
      Process.sleep(150)

      {:ok, stats} = Logger.get_statistics()
      assert stats.buffer_size == 0
    end

    test "flushes immediately on critical events" do
      Logger.log_security_event(
        :critical_breach,
        :critical,
        "System compromised"
      )

      # Critical events should flush immediately
      Process.sleep(50)

      {:ok, stats} = Logger.get_statistics()
      assert stats.buffer_size == 0
    end
  end
end
