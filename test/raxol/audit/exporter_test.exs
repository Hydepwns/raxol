defmodule Raxol.Audit.ExporterTest do
  use ExUnit.Case, async: false
  alias Raxol.Audit.{Exporter, Storage}

  setup do
    # Start storage first
    storage_config = %{
      storage_path: "test/audit_export_test",
      compress_logs: false
    }
    
    {:ok, _storage} = Storage.start_link(storage_config)
    
    # Start exporter
    exporter_config = %{
      export_path: "test/audit_exports"
    }
    
    {:ok, _exporter} = Exporter.start_link(exporter_config)
    
    # Store some test events
    events = create_test_events()
    Storage.store_batch(events)
    
    on_exit(fn ->
      if Process.whereis(Exporter), do: GenServer.stop(Exporter)
      if Process.whereis(Storage), do: GenServer.stop(Storage)
      File.rm_rf!("test/audit_export_test")
      File.rm_rf!("test/audit_exports")
    end)

    :ok
  end

  describe "JSON export" do
    test "exports events as JSON" do
      {:ok, json_data} = Exporter.export(:json, %{})
      
      assert is_binary(json_data)
      {:ok, decoded} = Jason.decode(json_data)
      assert is_list(decoded)
      assert length(decoded) > 0
    end

    test "exports with metadata included" do
      {:ok, json_data} = Exporter.export(:json, %{}, include_metadata: true)
      
      {:ok, decoded} = Jason.decode(json_data)
      first_event = hd(decoded)
      assert Map.has_key?(first_event, "metadata")
    end

    test "exports without metadata" do
      {:ok, json_data} = Exporter.export(:json, %{}, include_metadata: false)
      
      {:ok, decoded} = Jason.decode(json_data)
      first_event = hd(decoded)
      refute Map.has_key?(first_event, "metadata")
    end
  end

  describe "CSV export" do
    test "exports events as CSV" do
      {:ok, csv_data} = Exporter.export(:csv, %{})
      
      assert is_binary(csv_data)
      lines = String.split(csv_data, "\n", trim: true)
      assert length(lines) > 1  # Header + data
      
      # Check header exists
      header = hd(lines)
      assert String.contains?(header, "event_id")
      assert String.contains?(header, "timestamp")
    end

    test "CSV values are properly formatted" do
      {:ok, csv_data} = Exporter.export(:csv, %{event_type: :authentication})
      
      lines = String.split(csv_data, "\n", trim: true)
      # Should have header + at least one data row
      assert length(lines) >= 2
    end
  end

  describe "CEF export" do
    test "exports events in CEF format" do
      {:ok, cef_data} = Exporter.export(:cef, %{})
      
      assert is_binary(cef_data)
      lines = String.split(cef_data, "\n", trim: true)
      
      Enum.each(lines, fn line ->
        # CEF format: CEF:Version|Vendor|Product|Version|EventID|Name|Severity|Extension
        assert String.starts_with?(line, "CEF:")
        assert String.contains?(line, "|Raxol|Terminal|")
      end)
    end

    test "CEF messages include required fields" do
      {:ok, cef_data} = Exporter.export(:cef, %{event_type: :authentication})
      
      lines = String.split(cef_data, "\n", trim: true)
      first_line = hd(lines)
      
      assert String.contains?(first_line, "rt=")  # Timestamp
      assert String.contains?(first_line, "duser=")  # User
    end
  end

  describe "LEEF export" do
    test "exports events in LEEF format" do
      {:ok, leef_data} = Exporter.export(:leef, %{})
      
      assert is_binary(leef_data)
      lines = String.split(leef_data, "\n", trim: true)
      
      Enum.each(lines, fn line ->
        assert String.starts_with?(line, "LEEF:")
        assert String.contains?(line, "|Raxol|Terminal|")
      end)
    end

    test "LEEF messages include required fields" do
      {:ok, leef_data} = Exporter.export(:leef, %{event_type: :authorization})
      
      lines = String.split(leef_data, "\n", trim: true)
      first_line = hd(lines)
      
      assert String.contains?(first_line, "devTime=")
      assert String.contains?(first_line, "severity=")
    end
  end

  describe "Syslog export" do
    test "exports events in RFC 5424 syslog format" do
      {:ok, syslog_data} = Exporter.export(:syslog, %{})
      
      assert is_binary(syslog_data)
      lines = String.split(syslog_data, "\n", trim: true)
      
      Enum.each(lines, fn line ->
        # RFC 5424: <priority>version timestamp hostname app-name procid msgid [structured-data] msg
        assert Regex.match?(~r/^<\d+>1 /, line)
        assert String.contains?(line, "raxol-audit")
      end)
    end

    test "calculates correct syslog priority" do
      {:ok, syslog_data} = Exporter.export(:syslog, %{severity: :critical})
      
      lines = String.split(syslog_data, "\n", trim: true)
      
      Enum.each(lines, fn line ->
        # Extract priority value
        [_, priority | _] = Regex.run(~r/^<(\d+)>/, line)
        priority_int = String.to_integer(priority)
        
        # Facility 16 (local0) * 8 + severity
        assert priority_int >= 128  # 16 * 8
        assert priority_int <= 135  # 16 * 8 + 7
      end)
    end
  end

  describe "XML export" do
    test "exports events as XML" do
      {:ok, xml_data} = Exporter.export(:xml, %{})
      
      assert is_binary(xml_data)
      assert String.starts_with?(xml_data, "<?xml version=\"1.0\"")
      assert String.contains?(xml_data, "<AuditLog")
      assert String.contains?(xml_data, "<Events>")
      assert String.contains?(xml_data, "</Events>")
      assert String.contains?(xml_data, "</AuditLog>")
    end

    test "XML events contain required elements" do
      {:ok, xml_data} = Exporter.export(:xml, %{event_type: :data_access})
      
      assert String.contains?(xml_data, "<EventID>")
      assert String.contains?(xml_data, "<Timestamp>")
      assert String.contains?(xml_data, "<Type>")
      assert String.contains?(xml_data, "<Severity>")
    end

    test "XML special characters are escaped" do
      # Create event with special characters
      event = %{
        event_id: "special",
        timestamp: System.system_time(:millisecond),
        description: "Test & <special> \"characters\" 'here'"
      }
      Storage.store_batch([event])
      
      {:ok, xml_data} = Exporter.export(:xml, %{event_id: "special"})
      
      assert String.contains?(xml_data, "&amp;")
      assert String.contains?(xml_data, "&lt;")
      assert String.contains?(xml_data, "&gt;")
      assert String.contains?(xml_data, "&quot;")
    end
  end

  describe "PDF export" do
    test "exports events as PDF (HTML template)" do
      {:ok, pdf_data} = Exporter.export(:pdf, %{})
      
      assert is_binary(pdf_data)
      # For now, just HTML template
      assert String.contains?(pdf_data, "<html>")
      assert String.contains?(pdf_data, "Audit Report")
    end
  end

  describe "export options" do
    test "compresses export data when requested" do
      {:ok, compressed} = Exporter.export(:json, %{}, compress: true)
      
      assert is_binary(compressed)
      # Compressed data should start with gzip magic number
      <<0x1F, 0x8B, _rest::binary>> = compressed
    end

    test "encrypts export data when requested" do
      {:ok, encrypted_json} = Exporter.export(:json, %{}, encrypt: true)
      
      {:ok, encrypted_data} = Jason.decode(encrypted_json)
      assert encrypted_data["encrypted"] == true
      assert Map.has_key?(encrypted_data, "data")
      assert Map.has_key?(encrypted_data, "key")
      assert Map.has_key?(encrypted_data, "iv")
    end

    test "signs export data when requested" do
      {:ok, signed_json} = Exporter.export(:json, %{}, sign: true)
      
      {:ok, signed_data} = Jason.decode(signed_json)
      assert Map.has_key?(signed_data, "data")
      assert Map.has_key?(signed_data, "signature")
      assert signed_data["algorithm"] == "SHA256"
    end
  end

  describe "compliance reports" do
    test "generates SOC2 compliance report" do
      time_range = {
        System.system_time(:millisecond) - 86_400_000,
        System.system_time(:millisecond)
      }
      
      {:ok, report} = Exporter.generate_compliance_report(:soc2, time_range)
      
      assert is_binary(report)
      {:ok, decoded} = Jason.decode(report)
      assert decoded["framework"] == "SOC 2 Type II"
      assert is_list(decoded["controls"])
    end

    test "generates HIPAA compliance report" do
      time_range = {
        System.system_time(:millisecond) - 86_400_000,
        System.system_time(:millisecond)
      }
      
      {:ok, report} = Exporter.generate_compliance_report(:hipaa, time_range)
      
      {:ok, decoded} = Jason.decode(report)
      assert decoded["framework"] == "HIPAA"
      assert is_list(decoded["safeguards"])
    end

    test "generates GDPR compliance report" do
      time_range = {
        System.system_time(:millisecond) - 86_400_000,
        System.system_time(:millisecond)
      }
      
      {:ok, report} = Exporter.generate_compliance_report(:gdpr, time_range)
      
      {:ok, decoded} = Jason.decode(report)
      assert decoded["framework"] == "GDPR"
      assert is_list(decoded["articles"])
    end

    test "generates PCI DSS compliance report" do
      time_range = {
        System.system_time(:millisecond) - 86_400_000,
        System.system_time(:millisecond)
      }
      
      {:ok, report} = Exporter.generate_compliance_report(:pci_dss, time_range)
      
      {:ok, decoded} = Jason.decode(report)
      assert decoded["framework"] == "PCI DSS v4.0"
      assert is_list(decoded["requirements"])
    end
  end

  describe "scheduled exports" do
    test "schedules an export for later processing" do
      schedule_config = %{
        format: :json,
        filters: %{},
        interval: :daily,
        destination: "/tmp/audit_export.json"
      }
      
      assert :ok = Exporter.schedule_export(schedule_config)
    end

    test "processes scheduled exports" do
      schedule_config = %{
        format: :csv,
        filters: %{event_type: :authentication},
        execute_now: true
      }
      
      assert :ok = Exporter.schedule_export(schedule_config)
      
      # Trigger queue processing
      send(Process.whereis(Exporter), :process_queue)
      Process.sleep(100)
    end
  end

  # Helper functions
  
  defp create_test_events do
    [
      %{
        event_id: "auth1",
        timestamp: System.system_time(:millisecond),
        event_type: :authentication,
        user_id: "alice",
        username: "alice",
        outcome: :success,
        severity: :info,
        ip_address: "192.168.1.1",
        metadata: %{extra: "data"}
      },
      %{
        event_id: "auth2",
        timestamp: System.system_time(:millisecond),
        event_type: :authentication,
        user_id: "bob",
        username: "bob",
        outcome: :failure,
        severity: :medium,
        ip_address: "192.168.1.2"
      },
      %{
        event_id: "authz1",
        timestamp: System.system_time(:millisecond),
        event_type: :authorization,
        user_id: "alice",
        action: :read,
        outcome: :granted,
        severity: :low,
        resource_type: "document",
        resource_id: "doc123"
      },
      %{
        event_id: "data1",
        timestamp: System.system_time(:millisecond),
        event_type: :data_access,
        user_id: "charlie",
        operation: :export,
        severity: :high,
        records_count: 1000,
        data_classification: :confidential
      },
      %{
        event_id: "sec1",
        timestamp: System.system_time(:millisecond),
        event_type: :security,
        severity: :critical,
        description: "Potential intrusion detected",
        threat_indicators: ["suspicious_ip"],
        action_taken: :blocked
      }
    ]
  end
end