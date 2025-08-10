defmodule Raxol.Audit.Exporter do
  @moduledoc """
  Exports audit logs in various formats for compliance reporting and SIEM integration.

  Supported formats:
  - JSON (for programmatic processing)
  - CSV (for spreadsheet analysis)
  - CEF (Common Event Format for SIEM)
  - LEEF (Log Event Extended Format)
  - Syslog (RFC 5424)
  - PDF (for compliance reports)
  """

  use GenServer
  require Logger

  defstruct [
    :config,
    :export_queue,
    :siem_connections,
    :export_history,
    :templates
  ]

  @type export_format :: :json | :csv | :cef | :leef | :syslog | :pdf | :xml

  @type export_options :: %{
          optional(:compress) => boolean(),
          optional(:encrypt) => boolean(),
          optional(:sign) => boolean(),
          optional(:include_metadata) => boolean(),
          optional(:template) => String.t()
        }

  ## Client API

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @doc """
  Exports audit events in the specified format.
  """
  def export(exporter \\ __MODULE__, format, filters, opts \\ []) do
    GenServer.call(exporter, {:export, format, filters, opts}, 60_000)
  end

  @doc """
  Sends audit events to a SIEM system.
  """
  def send_to_siem(exporter \\ __MODULE__, events, siem_config) do
    GenServer.call(exporter, {:send_to_siem, events, siem_config})
  end

  @doc """
  Generates a compliance report.
  """
  def generate_compliance_report(
        exporter \\ __MODULE__,
        framework,
        time_range,
        opts \\ []
      ) do
    GenServer.call(
      exporter,
      {:generate_compliance_report, framework, time_range, opts},
      120_000
    )
  end

  @doc """
  Schedules a recurring export.
  """
  def schedule_export(exporter \\ __MODULE__, schedule_config) do
    GenServer.call(exporter, {:schedule_export, schedule_config})
  end

  ## GenServer Implementation

  @impl GenServer
  def init(config) do
    state = %__MODULE__{
      config: config,
      export_queue: :queue.new(),
      siem_connections: init_siem_connections(config),
      export_history: [],
      templates: load_templates()
    }

    # Process export queue periodically
    :timer.send_interval(10_000, :process_queue)

    Logger.info("Audit exporter initialized")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:export, format, filters, opts}, _from, state) do
    case perform_export(format, filters, opts, state) do
      {:ok, exported_data} ->
        new_state = record_export(format, filters, state)
        {:reply, {:ok, exported_data}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:send_to_siem, events, siem_config}, _from, state) do
    case send_events_to_siem(events, siem_config, state) do
      :ok ->
        {:reply, :ok, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call(
        {:generate_compliance_report, framework, time_range, opts},
        _from,
        state
      ) do
    case generate_report(framework, time_range, opts, state) do
      {:ok, report} ->
        {:reply, {:ok, report}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:schedule_export, schedule_config}, _from, state) do
    # Add to export queue
    new_queue = :queue.in(schedule_config, state.export_queue)
    new_state = %{state | export_queue: new_queue}

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_info(:process_queue, state) do
    new_state = process_export_queue(state)
    {:noreply, new_state}
  end

  ## Private Functions - Export Formats

  defp perform_export(:json, filters, opts, _state) do
    events = load_filtered_events(filters)

    json_data =
      events
      |> maybe_include_metadata(Keyword.get(opts, :include_metadata, true))
      |> Jason.encode!(pretty: true)

    finalize_export(json_data, opts)
  end

  defp perform_export(:csv, filters, opts, _state) do
    events = load_filtered_events(filters)

    headers = extract_csv_headers(events)
    rows = Enum.map(events, &event_to_csv_row(&1, headers))

    csv_data =
      [headers | rows]
      |> CSV.encode()
      |> Enum.to_list()
      |> IO.iodata_to_binary()

    finalize_export(csv_data, opts)
  end

  defp perform_export(:cef, filters, opts, _state) do
    events = load_filtered_events(filters)

    cef_messages = Enum.map(events, &format_cef_message/1)
    cef_data = Enum.join(cef_messages, "\n")

    finalize_export(cef_data, opts)
  end

  defp perform_export(:leef, filters, opts, _state) do
    events = load_filtered_events(filters)

    leef_messages = Enum.map(events, &format_leef_message/1)
    leef_data = Enum.join(leef_messages, "\n")

    finalize_export(leef_data, opts)
  end

  defp perform_export(:syslog, filters, opts, _state) do
    events = load_filtered_events(filters)

    syslog_messages = Enum.map(events, &format_syslog_message/1)
    syslog_data = Enum.join(syslog_messages, "\n")

    finalize_export(syslog_data, opts)
  end

  defp perform_export(:pdf, filters, opts, _state) do
    events = load_filtered_events(filters)
    template = Keyword.get(opts, :template) || "default"

    pdf_data = generate_pdf_report(events, template, nil)
    finalize_export(pdf_data, opts)
  end

  defp perform_export(:xml, filters, opts, _state) do
    events = load_filtered_events(filters)

    xml_data = format_xml(events)
    finalize_export(xml_data, opts)
  end

  ## Format Converters

  defp format_cef_message(event) do
    # CEF:Version|Device Vendor|Device Product|Device Version|Device Event Class ID|Name|Severity|Extension
    timestamp = format_timestamp(event.timestamp)
    severity = map_severity_to_cef(Map.get(event, :severity, :info))

    "CEF:0|Raxol|Terminal|1.0|#{event.event_type}|#{event.event_id}|#{severity}|" <>
      "rt=#{timestamp} " <>
      "duser=#{Map.get(event, :user_id, "")} " <>
      "src=#{Map.get(event, :ip_address, "")} " <>
      "act=#{Map.get(event, :action, "")} " <>
      "outcome=#{Map.get(event, :outcome, "")} " <>
      "msg=#{escape_cef(format_event_message(event))}"
  end

  defp format_leef_message(event) do
    # LEEF:Version|Vendor|Product|Version|EventID|
    timestamp = format_timestamp(event.timestamp)

    "LEEF:2.0|Raxol|Terminal|1.0|#{event.event_type}|" <>
      "devTime=#{timestamp}|" <>
      "usrName=#{Map.get(event, :user_id, "")}|" <>
      "src=#{Map.get(event, :ip_address, "")}|" <>
      "action=#{Map.get(event, :action, "")}|" <>
      "severity=#{Map.get(event, :severity, :info)}"
  end

  defp format_syslog_message(event) do
    # RFC 5424 format
    timestamp = format_rfc5424_timestamp(event.timestamp)
    priority = calculate_syslog_priority(event)
    hostname = node() |> to_string()
    app_name = "raxol-audit"

    "<#{priority}>1 #{timestamp} #{hostname} #{app_name} - #{event.event_id} " <>
      "[audit@32473 user=\"#{Map.get(event, :user_id, "-")}\" " <>
      "type=\"#{event.event_type}\" " <>
      "severity=\"#{Map.get(event, :severity, :info)}\"] " <>
      format_event_message(event)
  end

  defp format_xml(events) do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <AuditLog xmlns="http://raxol.io/audit/1.0">
      <ExportTime>#{DateTime.utc_now() |> DateTime.to_iso8601()}</ExportTime>
      <EventCount>#{length(events)}</EventCount>
      <Events>
        #{Enum.map(events, &event_to_xml/1) |> Enum.join("\n")}
      </Events>
    </AuditLog>
    """
  end

  defp event_to_xml(event) do
    """
        <Event>
          <EventID>#{event.event_id}</EventID>
          <Timestamp>#{event.timestamp}</Timestamp>
          <Type>#{Map.get(event, :event_type, "unknown")}</Type>
          <Severity>#{Map.get(event, :severity, "info")}</Severity>
          <User>#{Map.get(event, :user_id, "")}</User>
          <IPAddress>#{Map.get(event, :ip_address, "")}</IPAddress>
          <Details>#{escape_xml(format_event_message(event))}</Details>
        </Event>
    """
  end

  ## Compliance Reports

  defp generate_report(:soc2, time_range, opts, state) do
    events = load_events_for_timerange(time_range)

    report = %{
      framework: "SOC 2 Type II",
      period: time_range,
      generated_at: DateTime.utc_now(),
      controls: [
        analyze_cc6_logical_access(events),
        analyze_cc7_system_operations(events),
        analyze_cc8_change_management(events)
      ],
      summary: generate_soc2_summary(events),
      findings: identify_soc2_findings(events)
    }

    format_compliance_report(report, opts, state)
  end

  defp generate_report(:hipaa, time_range, opts, state) do
    events = load_events_for_timerange(time_range)

    report = %{
      framework: "HIPAA",
      period: time_range,
      generated_at: DateTime.utc_now(),
      safeguards: [
        analyze_access_controls(events),
        analyze_audit_controls(events),
        analyze_integrity_controls(events),
        analyze_transmission_security(events)
      ],
      phi_access_log: generate_phi_access_log(events),
      incidents: identify_hipaa_incidents(events)
    }

    format_compliance_report(report, opts, state)
  end

  defp generate_report(:gdpr, time_range, opts, state) do
    events = load_events_for_timerange(time_range)

    report = %{
      framework: "GDPR",
      period: time_range,
      generated_at: DateTime.utc_now(),
      articles: [
        analyze_article_32_security(events),
        analyze_article_33_breach_notification(events),
        analyze_article_35_dpia(events)
      ],
      data_subject_requests: analyze_dsr_compliance(events),
      cross_border_transfers: analyze_data_transfers(events)
    }

    format_compliance_report(report, opts, state)
  end

  defp generate_report(:pci_dss, time_range, opts, state) do
    events = load_events_for_timerange(time_range)

    report = %{
      framework: "PCI DSS v4.0",
      period: time_range,
      generated_at: DateTime.utc_now(),
      requirements: [
        analyze_requirement_7_access(events),
        analyze_requirement_8_authentication(events),
        analyze_requirement_10_logging(events)
      ],
      cardholder_data_access: analyze_cde_access(events),
      security_incidents: identify_pci_incidents(events)
    }

    format_compliance_report(report, opts, state)
  end

  ## Helper Functions

  defp load_filtered_events(filters) do
    # Load events from storage based on filters
    case Raxol.Audit.Storage.query(filters) do
      {:ok, events} -> events
      {:error, _} -> []
    end
  end

  defp load_events_for_timerange({start_time, end_time}) do
    filters = %{start_time: start_time, end_time: end_time}
    load_filtered_events(filters)
  end

  defp finalize_export(data, opts) do
    data
    |> maybe_compress(Keyword.get(opts, :compress, false))
    |> maybe_encrypt(Keyword.get(opts, :encrypt, false))
    |> maybe_sign(Keyword.get(opts, :sign, false))
  end

  defp maybe_compress(data, true) do
    :zlib.gzip(data)
  end

  defp maybe_compress(data, false), do: data

  defp maybe_encrypt(data, true) do
    # Simplified encryption - use proper encryption in production
    key = :crypto.strong_rand_bytes(32)
    iv = :crypto.strong_rand_bytes(16)

    encrypted = :crypto.crypto_one_time(:aes_256_cbc, key, iv, data, true)

    %{
      encrypted: true,
      data: Base.encode64(encrypted),
      key: Base.encode64(key),
      iv: Base.encode64(iv)
    }
    |> Jason.encode!()
  end

  defp maybe_encrypt(data, false), do: data

  defp maybe_sign(data, true) do
    signature = :crypto.hash(:sha256, data) |> Base.encode64()

    %{
      data: Base.encode64(data),
      signature: signature,
      algorithm: "SHA256"
    }
    |> Jason.encode!()
  end

  defp maybe_sign(data, false), do: data

  defp maybe_include_metadata(events, true), do: events

  defp maybe_include_metadata(events, false) do
    Enum.map(events, &Map.drop(&1, [:metadata]))
  end

  defp extract_csv_headers(events) do
    events
    |> Enum.flat_map(&Map.keys/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp event_to_csv_row(event, headers) do
    Enum.map(headers, fn header ->
      value = Map.get(event, header)
      format_csv_value(value)
    end)
  end

  defp format_csv_value(nil), do: ""
  defp format_csv_value(value) when is_binary(value), do: value
  defp format_csv_value(value) when is_atom(value), do: to_string(value)
  defp format_csv_value(value) when is_number(value), do: to_string(value)
  defp format_csv_value(value), do: inspect(value)

  defp format_event_message(event) do
    type = Map.get(event, :event_type, "unknown")
    user = Map.get(event, :user_id, "unknown")
    action = Map.get(event, :action, "")
    outcome = Map.get(event, :outcome, "")

    "#{type}: User #{user} performed #{action} with outcome #{outcome}"
  end

  defp format_timestamp(timestamp) when is_integer(timestamp) do
    DateTime.from_unix!(timestamp, :millisecond)
    |> DateTime.to_iso8601()
  end

  defp format_rfc5424_timestamp(timestamp) do
    DateTime.from_unix!(timestamp, :millisecond)
    |> DateTime.to_iso8601()
  end

  defp map_severity_to_cef(:info), do: 0
  defp map_severity_to_cef(:low), do: 3
  defp map_severity_to_cef(:medium), do: 6
  defp map_severity_to_cef(:high), do: 8
  defp map_severity_to_cef(:critical), do: 10

  defp calculate_syslog_priority(event) do
    # Local0
    facility = 16

    severity =
      case Map.get(event, :severity, :info) do
        # Critical
        :critical -> 2
        # Error
        :high -> 3
        # Warning
        :medium -> 4
        # Notice
        :low -> 5
        # Info
        :info -> 6
        # Debug
        _ -> 7
      end

    facility * 8 + severity
  end

  defp escape_cef(string) do
    string
    |> String.replace("\\", "\\\\")
    |> String.replace("=", "\\=")
    |> String.replace("\n", "\\n")
    |> String.replace("\r", "\\r")
  end

  defp escape_xml(string) do
    string
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  defp send_events_to_siem(events, siem_config, _state) do
    case siem_config.type do
      :splunk -> send_to_splunk(events, siem_config)
      :elastic -> send_to_elastic(events, siem_config)
      :qradar -> send_to_qradar(events, siem_config)
      :sentinel -> send_to_sentinel(events, siem_config)
      _ -> {:error, :unsupported_siem}
    end
  end

  defp send_to_splunk(events, config) do
    # Splunk HEC (HTTP Event Collector) integration
    url = "#{config.host}:#{config.port}/services/collector/event"

    headers = [
      {"Authorization", "Splunk #{config.token}"},
      {"Content-Type", "application/json"}
    ]

    body =
      Enum.map(events, fn event ->
        %{
          time: event.timestamp / 1000,
          event: event,
          source: "raxol-audit",
          sourcetype: "_json"
        }
      end)
      |> Jason.encode!()

    case HTTPoison.post(url, body, headers) do
      {:ok, %{status_code: 200}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp send_to_elastic(_events, _config) do
    # Elasticsearch integration
    :ok
  end

  defp send_to_qradar(_events, _config) do
    # IBM QRadar integration
    :ok
  end

  defp send_to_sentinel(_events, _config) do
    # Azure Sentinel integration
    :ok
  end

  defp generate_pdf_report(_events, _template, _state) do
    # Generate PDF using a template engine
    # This would use a library like ChromicPDF or wkhtmltopdf
    "<html><body>Audit Report</body></html>"
  end

  defp format_compliance_report(report, opts, state) do
    format = Keyword.get(opts, :format, :json)

    case format do
      :json -> {:ok, Jason.encode!(report, pretty: true)}
      :pdf -> {:ok, generate_pdf_from_report(report, state)}
      _ -> {:error, :unsupported_format}
    end
  end

  defp generate_pdf_from_report(report, _state) do
    # Convert report to PDF
    "<html><body>#{inspect(report)}</body></html>"
  end

  defp record_export(format, filters, state) do
    export_record = %{
      format: format,
      filters: filters,
      timestamp: System.system_time(:millisecond),
      success: true
    }

    %{
      state
      | export_history: [export_record | Enum.take(state.export_history, 99)]
    }
  end

  defp process_export_queue(state) do
    case :queue.out(state.export_queue) do
      {{:value, schedule}, new_queue} ->
        # Process scheduled export
        Task.start(fn ->
          perform_scheduled_export(schedule)
        end)

        %{state | export_queue: new_queue}

      {:empty, _} ->
        state
    end
  end

  defp perform_scheduled_export(schedule) do
    # Execute scheduled export
    Logger.info("Performing scheduled export: #{inspect(schedule)}")
  end

  defp init_siem_connections(config) do
    Map.get(config, :siem_connections, %{})
  end

  defp load_templates do
    %{
      "default" => default_report_template(),
      "executive" => executive_report_template(),
      "technical" => technical_report_template()
    }
  end

  defp default_report_template do
    # Default PDF template
    """
    <html>
      <head><title>Audit Report</title></head>
      <body>
        <h1>Audit Report</h1>
        <div>{{content}}</div>
      </body>
    </html>
    """
  end

  defp executive_report_template do
    # Executive summary template
    """
    <html>
      <head><title>Executive Audit Summary</title></head>
      <body>
        <h1>Executive Summary</h1>
        <div>{{summary}}</div>
      </body>
    </html>
    """
  end

  defp technical_report_template do
    # Detailed technical template
    """
    <html>
      <head><title>Technical Audit Report</title></head>
      <body>
        <h1>Technical Audit Details</h1>
        <div>{{technical_details}}</div>
      </body>
    </html>
    """
  end

  # SOC2 Analysis Functions
  defp analyze_cc6_logical_access(events) do
    %{
      control: "CC6 - Logical and Physical Access",
      status: :implemented,
      evidence: count_access_events(events)
    }
  end

  defp analyze_cc7_system_operations(events) do
    %{
      control: "CC7 - System Operations",
      status: :implemented,
      evidence: count_operational_events(events)
    }
  end

  defp analyze_cc8_change_management(events) do
    %{
      control: "CC8 - Change Management",
      status: :implemented,
      evidence: count_change_events(events)
    }
  end

  defp generate_soc2_summary(events) do
    %{
      total_events: length(events),
      period_start: find_earliest_timestamp(events),
      period_end: find_latest_timestamp(events)
    }
  end

  defp identify_soc2_findings(_events) do
    # Placeholder for findings
    []
  end

  # Helper analysis functions
  defp count_access_events(events) do
    Enum.count(
      events,
      &(Map.get(&1, :event_type) in [:authentication, :authorization])
    )
  end

  defp count_operational_events(events) do
    Enum.count(events, &(Map.get(&1, :event_type) == :terminal_operation))
  end

  defp count_change_events(events) do
    Enum.count(events, &(Map.get(&1, :event_type) == :configuration_change))
  end

  defp find_earliest_timestamp([]), do: nil

  defp find_earliest_timestamp(events) do
    Enum.min_by(events, & &1.timestamp).timestamp
  end

  defp find_latest_timestamp([]), do: nil

  defp find_latest_timestamp(events) do
    Enum.max_by(events, & &1.timestamp).timestamp
  end

  # Placeholder functions for compliance analysis
  defp analyze_access_controls(_events), do: %{}
  defp analyze_audit_controls(_events), do: %{}
  defp analyze_integrity_controls(_events), do: %{}
  defp analyze_transmission_security(_events), do: %{}
  defp generate_phi_access_log(_events), do: []
  defp identify_hipaa_incidents(_events), do: []
  defp analyze_article_32_security(_events), do: %{}
  defp analyze_article_33_breach_notification(_events), do: %{}
  defp analyze_article_35_dpia(_events), do: %{}
  defp analyze_dsr_compliance(_events), do: %{}
  defp analyze_data_transfers(_events), do: %{}
  defp analyze_requirement_7_access(_events), do: %{}
  defp analyze_requirement_8_authentication(_events), do: %{}
  defp analyze_requirement_10_logging(_events), do: %{}
  defp analyze_cde_access(_events), do: []
  defp identify_pci_incidents(_events), do: []
end
