defmodule Raxol.Audit.Integration do
  @moduledoc """
  Integration module for hooking audit logging into terminal operations.

  This module provides convenience functions for integrating audit logging
  throughout the Raxol terminal framework.
  """

  alias Raxol.Audit.Logger

  @doc """
  Audits a terminal command execution.
  """
  def audit_command(terminal_id, user_id, command, result) do
    Logger.log_terminal_operation(user_id, terminal_id, :command_executed,
      command: command,
      exit_code: result.exit_code,
      duration_ms: result.duration_ms,
      output_size: byte_size(result.output || "")
    )

    # Check for dangerous commands
    log_dangerous_command_if_needed(
      dangerous_command?(command),
      user_id,
      terminal_id,
      command
    )

    # Check for privilege escalation
    log_privilege_escalation_if_needed(
      privilege_escalation?(command),
      user_id,
      terminal_id,
      command
    )
  end

  @doc """
  Audits terminal session lifecycle events.
  """
  def audit_session_start(terminal_id, user_id, opts \\ []) do
    Logger.log_terminal_operation(
      user_id,
      terminal_id,
      :session_started,
      Keyword.merge(opts,
        timestamp: System.system_time(:millisecond),
        environment: System.get_env()
      )
    )
  end

  def audit_session_end(terminal_id, user_id, opts \\ []) do
    Logger.log_terminal_operation(
      user_id,
      terminal_id,
      :session_ended,
      Keyword.merge(opts,
        timestamp: System.system_time(:millisecond),
        duration_ms: Keyword.get(opts, :duration_ms, 0)
      )
    )
  end

  @doc """
  Audits file operations within terminal.
  """
  def audit_file_operation(
        terminal_id,
        user_id,
        operation,
        file_path,
        opts \\ []
      ) do
    Logger.log_data_access(
      user_id,
      operation,
      "file",
      Keyword.merge(opts,
        resource_id: file_path,
        terminal_id: terminal_id,
        data_classification: classify_file(file_path)
      )
    )

    # Extra logging for sensitive files
    log_sensitive_file_access_if_needed(
      sensitive_file?(file_path),
      user_id,
      terminal_id,
      operation,
      file_path
    )
  end

  @doc """
  Audits authentication attempts for terminal access.
  """
  def audit_authentication(username, method, outcome, opts \\ []) do
    Logger.log_authentication(username, method, outcome, opts)

    # Track failed attempts for account lockout
    handle_authentication_outcome(outcome, username, opts)
  end

  @doc """
  Audits authorization checks for terminal operations.
  """
  def audit_authorization(user_id, resource, action, outcome, opts \\ []) do
    Logger.log_authorization(user_id, resource, action, outcome, opts)

    # Alert on critical resource denial
    log_critical_resource_denial_if_needed(
      outcome == :denied and critical_resource?(resource),
      user_id,
      resource,
      action
    )
  end

  @doc """
  Audits configuration changes in the terminal.
  """
  def audit_config_change(
        user_id,
        component,
        setting,
        old_value,
        new_value,
        opts \\ []
      ) do
    Logger.log_configuration_change(
      user_id,
      component,
      setting,
      old_value,
      new_value,
      opts
    )

    # Alert on security-relevant changes
    log_security_config_change_if_needed(
      security_relevant_setting?(setting),
      user_id,
      component,
      setting,
      old_value,
      new_value
    )
  end

  @doc """
  Audits clipboard operations for data loss prevention.
  """
  def audit_clipboard_operation(
        terminal_id,
        user_id,
        operation,
        content_summary,
        opts \\ []
      ) do
    Logger.log_data_access(
      user_id,
      operation,
      "clipboard",
      Keyword.merge(opts,
        terminal_id: terminal_id,
        content_size: byte_size(content_summary || ""),
        data_classification: classify_content(content_summary)
      )
    )

    # Check for potential data exfiltration
    log_potential_data_exfiltration_if_needed(
      large_clipboard_content?(content_summary),
      user_id,
      terminal_id,
      operation,
      content_summary
    )
  end

  @doc """
  Audits network connections from terminal.
  """
  def audit_network_connection(
        terminal_id,
        user_id,
        host,
        port,
        direction,
        opts \\ []
      ) do
    Logger.log_terminal_operation(
      user_id,
      terminal_id,
      :network_connection,
      Keyword.merge(opts,
        host: host,
        port: port,
        direction: direction
      )
    )

    # Check for suspicious connections
    log_suspicious_connection_if_needed(
      suspicious_host?(host) or suspicious_port?(port),
      user_id,
      terminal_id,
      host,
      port,
      direction
    )
  end

  ## Pattern Matching Helper Functions for Security Logging

  defp log_dangerous_command_if_needed(false, _user_id, _terminal_id, _command),
    do: :ok

  defp log_dangerous_command_if_needed(true, user_id, terminal_id, command) do
    Logger.log_security_event(
      :dangerous_command,
      :high,
      "Dangerous command executed: #{command}",
      user_id: user_id,
      terminal_id: terminal_id,
      command: command
    )
  end

  defp log_privilege_escalation_if_needed(
         false,
         _user_id,
         _terminal_id,
         _command
       ),
       do: :ok

  defp log_privilege_escalation_if_needed(true, user_id, terminal_id, command) do
    Logger.log_terminal_operation(user_id, terminal_id, :privilege_escalation,
      command: command,
      elevation_type: detect_elevation_type(command)
    )
  end

  defp log_sensitive_file_access_if_needed(
         false,
         _user_id,
         _terminal_id,
         _operation,
         _file_path
       ),
       do: :ok

  defp log_sensitive_file_access_if_needed(
         true,
         user_id,
         terminal_id,
         operation,
         file_path
       ) do
    Logger.log_security_event(
      :sensitive_file_access,
      :medium,
      "Access to sensitive file: #{file_path}",
      user_id: user_id,
      terminal_id: terminal_id,
      operation: operation,
      file_path: file_path
    )
  end

  defp handle_authentication_outcome(:failure, username, opts),
    do: track_failed_attempt(username, opts)

  defp handle_authentication_outcome(_outcome, _username, _opts), do: :ok

  defp log_critical_resource_denial_if_needed(
         false,
         _user_id,
         _resource,
         _action
       ),
       do: :ok

  defp log_critical_resource_denial_if_needed(true, user_id, resource, action) do
    Logger.log_security_event(
      :critical_resource_denied,
      :high,
      "Access denied to critical resource",
      user_id: user_id,
      resource: resource,
      action: action
    )
  end

  defp log_security_config_change_if_needed(
         false,
         _user_id,
         _component,
         _setting,
         _old_value,
         _new_value
       ),
       do: :ok

  defp log_security_config_change_if_needed(
         true,
         user_id,
         component,
         setting,
         old_value,
         new_value
       ) do
    Logger.log_security_event(
      :security_config_changed,
      :medium,
      "Security configuration modified: #{setting}",
      user_id: user_id,
      component: component,
      old_value: sanitize_value(old_value),
      new_value: sanitize_value(new_value)
    )
  end

  defp log_potential_data_exfiltration_if_needed(
         false,
         _user_id,
         _terminal_id,
         _operation,
         _content_summary
       ),
       do: :ok

  defp log_potential_data_exfiltration_if_needed(
         true,
         user_id,
         terminal_id,
         operation,
         content_summary
       ) do
    Logger.log_security_event(
      :potential_data_exfiltration,
      :medium,
      "Large clipboard operation detected",
      user_id: user_id,
      terminal_id: terminal_id,
      operation: operation,
      size: byte_size(content_summary || "")
    )
  end

  defp log_suspicious_connection_if_needed(
         false,
         _user_id,
         _terminal_id,
         _host,
         _port,
         _direction
       ),
       do: :ok

  defp log_suspicious_connection_if_needed(
         true,
         user_id,
         terminal_id,
         host,
         port,
         direction
       ) do
    Logger.log_security_event(
      :suspicious_connection,
      :high,
      "Suspicious network connection detected",
      user_id: user_id,
      terminal_id: terminal_id,
      host: host,
      port: port,
      direction: direction
    )
  end

  ## Helper Functions

  defp dangerous_command?(command) do
    dangerous_patterns = [
      ~r/rm\s+-rf\s+\//,
      ~r/dd\s+.*of=\/dev\//,
      ~r/mkfs/,
      ~r/>\s*\/dev\/null\s*2>&1/,
      ~r/curl.*\|\s*(bash|sh)/,
      ~r/wget.*\|\s*(bash|sh)/
    ]

    Enum.any?(dangerous_patterns, &Regex.match?(&1, command))
  end

  defp privilege_escalation?(command) do
    escalation_patterns = [
      ~r/^sudo\s+/,
      ~r/^su\s+/,
      ~r/^doas\s+/,
      ~r/chmod\s+[u\+s]/,
      ~r/setuid/
    ]

    Enum.any?(escalation_patterns, &Regex.match?(&1, command))
  end

  # Helper functions for pattern matching refactoring

  defp detect_elevation_type("sudo" <> _rest), do: :sudo
  defp detect_elevation_type("su" <> _rest), do: :su
  defp detect_elevation_type("doas" <> _rest), do: :doas
  defp detect_elevation_type(_command), do: :other

  defp sensitive_file?(path) do
    sensitive_patterns = [
      ~r/\.ssh\//,
      ~r/\.gnupg\//,
      ~r/\.aws\//,
      ~r/\.env$/,
      ~r/passwd$/,
      ~r/shadow$/,
      ~r/\.key$/,
      ~r/\.pem$/,
      ~r/\.crt$/
    ]

    Enum.any?(sensitive_patterns, &Regex.match?(&1, path))
  end

  defp classify_file(path) do
    case {sensitive_file?(path), String.contains?(path, "config"),
          String.contains?(path, "log")} do
      {true, _, _} -> :restricted
      {false, true, _} -> :confidential
      {false, false, true} -> :internal
      {false, false, false} -> :public
    end
  end

  defp classify_content(nil), do: :public

  defp classify_content(content) when is_binary(content) do
    case {String.contains?(content, "password"),
          String.contains?(content, "token"),
          String.contains?(content, "key")} do
      {true, _, _} -> :restricted
      {false, true, _} -> :restricted
      {false, false, true} -> :confidential
      {false, false, false} -> :public
    end
  end

  defp classify_content(_content), do: :public

  defp critical_resource?(%{type: type}) do
    type in ["admin", "system", "security", "audit"]
  end

  defp critical_resource?(_), do: false

  defp security_relevant_setting?(setting) do
    security_settings = [
      "authentication",
      "authorization",
      "encryption",
      "mfa",
      "password_policy",
      "session_timeout",
      "audit_level"
    ]

    Enum.any?(security_settings, &String.contains?(to_string(setting), &1))
  end

  defp sanitize_value(value) when is_binary(value) do
    value
    |> String.replace(~r/password=\S+/, "password=***")
    |> String.replace(~r/token=\S+/, "token=***")
    |> String.replace(~r/key=\S+/, "key=***")
  end

  defp sanitize_value(value), do: value

  defp large_clipboard_content?(content) when is_binary(content) do
    # 10KB threshold
    byte_size(content) > 10_000
  end

  defp large_clipboard_content?(_), do: false

  defp suspicious_host?(host) do
    suspicious_domains = [
      "malware.com",
      "phishing.net",
      "botnet.org"
    ]

    Enum.any?(suspicious_domains, &String.contains?(host, &1))
  end

  defp suspicious_port?(port) do
    # Common malware/backdoor ports
    suspicious_ports = [31337, 12345, 4444, 5555, 6666, 7777]
    port in suspicious_ports
  end

  defp track_failed_attempt(username, opts) do
    # This integrates with the existing account lockout mechanism in Raxol.Auth
    ip = Keyword.get(opts, :ip_address)
    Logger.debug("Tracking failed attempt for #{username} from #{ip}")

    # Log security event for audit trail
    Logger.log_security_event(
      :failed_authentication,
      :medium,
      "Failed authentication attempt",
      username: username,
      ip_address: ip,
      user_agent: Keyword.get(opts, :user_agent),
      timestamp: DateTime.utc_now()
    )

    # Note: Account lockout logic is handled automatically in Raxol.Auth.authenticate_user_password/2
    # which updates failed_login_attempts and sets locked_until when attempts >= 5
    :ok
  end

  @doc """
  Example usage in a terminal handler.
  """
  def example_usage do
    # Audit session start
    audit_session_start("term001", "user123",
      ip_address: "192.168.1.100",
      client: "iTerm2"
    )

    # Audit command execution
    command_result = %{
      exit_code: 0,
      duration_ms: 125,
      output: "Command output here..."
    }

    audit_command("term001", "user123", "ls -la /etc", command_result)

    # Audit file operation
    audit_file_operation("term001", "user123", :read, "/etc/passwd",
      bytes_read: 2048
    )

    # Audit configuration change
    audit_config_change(
      "admin",
      "terminal",
      "colors.background",
      "#000000",
      "#FFFFFF",
      approved_by: "superadmin"
    )

    # Audit session end
    audit_session_end("term001", "user123",
      duration_ms: 3_600_000,
      commands_executed: 42
    )
  end
end
