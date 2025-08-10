defmodule Raxol.Audit.Events do
  @moduledoc """
  Audit event definitions for compliance and security tracking.
  
  These events capture all security-relevant actions in the system,
  providing a comprehensive audit trail for compliance requirements
  including SOC2, HIPAA, GDPR, and PCI-DSS.
  """
  
  defmodule AuditEvent do
    @moduledoc """
    Base audit event structure with common fields for all audit events.
    """
    
    use Raxol.Architecture.EventSourcing.Event
    
    @enforce_keys [:event_id, :timestamp, :event_type, :severity, :actor, :resource]
    defstruct [
      :event_id,
      :timestamp,
      :event_type,
      :severity,
      :actor,
      :resource,
      :action,
      :outcome,
      :reason,
      :ip_address,
      :user_agent,
      :session_id,
      :correlation_id,
      :metadata,
      :tags
    ]
    
    @type severity :: :critical | :high | :medium | :low | :info
    @type outcome :: :success | :failure | :error | :denied
    
    @type actor :: %{
      user_id: String.t() | nil,
      service_id: String.t() | nil,
      api_key_id: String.t() | nil,
      ip_address: String.t(),
      user_agent: String.t() | nil
    }
    
    @type resource :: %{
      type: String.t(),
      id: String.t(),
      name: String.t() | nil,
      owner: String.t() | nil
    }
    
    @type t :: %__MODULE__{
      event_id: String.t(),
      timestamp: integer(),
      event_type: String.t(),
      severity: severity(),
      actor: actor(),
      resource: resource(),
      action: String.t(),
      outcome: outcome(),
      reason: String.t() | nil,
      ip_address: String.t() | nil,
      user_agent: String.t() | nil,
      session_id: String.t() | nil,
      correlation_id: String.t() | nil,
      metadata: map(),
      tags: [String.t()]
    }
  end
  
  defmodule AuthenticationEvent do
    @moduledoc """
    Audit event for authentication attempts.
    """
    
    use Raxol.Architecture.EventSourcing.Event
    
    defstruct [
      :event_id,
      :timestamp,
      :user_id,
      :username,
      :authentication_method,
      :outcome,
      :failure_reason,
      :ip_address,
      :user_agent,
      :session_id,
      :mfa_used,
      :metadata
    ]
    
    @type authentication_method :: :password | :sso | :api_key | :certificate | :biometric
    @type outcome :: :success | :failure | :locked | :expired
    
    @type t :: %__MODULE__{
      event_id: String.t(),
      timestamp: integer(),
      user_id: String.t() | nil,
      username: String.t(),
      authentication_method: authentication_method(),
      outcome: outcome(),
      failure_reason: String.t() | nil,
      ip_address: String.t(),
      user_agent: String.t() | nil,
      session_id: String.t() | nil,
      mfa_used: boolean(),
      metadata: map()
    }
    
    def validate(event) do
      with :ok <- Raxol.Audit.Events.validate_required(event, [:event_id, :timestamp, :username, :authentication_method, :outcome]),
           :ok <- validate_outcome(event) do
        {:ok, event}
      end
    end
    
    defp validate_outcome(%{outcome: :failure, failure_reason: nil}), do: {:error, :failure_reason_required}
    defp validate_outcome(_), do: :ok
  end
  
  defmodule AuthorizationEvent do
    @moduledoc """
    Audit event for authorization decisions.
    """
    
    defstruct [
      :event_id,
      :timestamp,
      :user_id,
      :resource_type,
      :resource_id,
      :action,
      :permission,
      :outcome,
      :denial_reason,
      :policy_evaluated,
      :ip_address,
      :session_id,
      :metadata
    ]
    
    @type outcome :: :granted | :denied | :error
    
    @type t :: %__MODULE__{
      event_id: String.t(),
      timestamp: integer(),
      user_id: String.t(),
      resource_type: String.t(),
      resource_id: String.t(),
      action: String.t(),
      permission: String.t() | nil,
      outcome: outcome(),
      denial_reason: String.t() | nil,
      policy_evaluated: String.t() | nil,
      ip_address: String.t() | nil,
      session_id: String.t() | nil,
      metadata: map()
    }
  end
  
  defmodule DataAccessEvent do
    @moduledoc """
    Audit event for data access operations.
    """
    
    defstruct [
      :event_id,
      :timestamp,
      :user_id,
      :operation,
      :resource_type,
      :resource_id,
      :data_classification,
      :fields_accessed,
      :records_count,
      :query,
      :outcome,
      :error_message,
      :ip_address,
      :session_id,
      :metadata
    ]
    
    @type operation :: :read | :write | :update | :delete | :export | :import
    @type data_classification :: :public | :internal | :confidential | :restricted
    @type outcome :: :success | :failure | :partial
    
    @type t :: %__MODULE__{
      event_id: String.t(),
      timestamp: integer(),
      user_id: String.t(),
      operation: operation(),
      resource_type: String.t(),
      resource_id: String.t() | nil,
      data_classification: data_classification(),
      fields_accessed: [String.t()] | nil,
      records_count: integer() | nil,
      query: String.t() | nil,
      outcome: outcome(),
      error_message: String.t() | nil,
      ip_address: String.t() | nil,
      session_id: String.t() | nil,
      metadata: map()
    }
  end
  
  defmodule ConfigurationChangeEvent do
    @moduledoc """
    Audit event for system configuration changes.
    """
    
    defstruct [
      :event_id,
      :timestamp,
      :user_id,
      :component,
      :setting,
      :old_value,
      :new_value,
      :change_type,
      :approval_required,
      :approved_by,
      :rollback_available,
      :ip_address,
      :session_id,
      :metadata
    ]
    
    @type change_type :: :create | :update | :delete
    
    @type t :: %__MODULE__{
      event_id: String.t(),
      timestamp: integer(),
      user_id: String.t(),
      component: String.t(),
      setting: String.t(),
      old_value: term() | nil,
      new_value: term() | nil,
      change_type: change_type(),
      approval_required: boolean(),
      approved_by: String.t() | nil,
      rollback_available: boolean(),
      ip_address: String.t() | nil,
      session_id: String.t() | nil,
      metadata: map()
    }
  end
  
  defmodule SecurityEvent do
    @moduledoc """
    Audit event for security-related incidents.
    """
    
    defstruct [
      :event_id,
      :timestamp,
      :event_type,
      :severity,
      :threat_level,
      :source_ip,
      :target_resource,
      :attack_vector,
      :detection_method,
      :response_action,
      :blocked,
      :user_id,
      :description,
      :metadata
    ]
    
    @type event_type :: :intrusion_attempt | :malware_detected | :policy_violation | 
                        :suspicious_activity | :brute_force | :data_exfiltration
    @type severity :: :critical | :high | :medium | :low
    @type threat_level :: :immediate | :high | :moderate | :low
    
    @type t :: %__MODULE__{
      event_id: String.t(),
      timestamp: integer(),
      event_type: event_type(),
      severity: severity(),
      threat_level: threat_level(),
      source_ip: String.t() | nil,
      target_resource: String.t() | nil,
      attack_vector: String.t() | nil,
      detection_method: String.t(),
      response_action: String.t() | nil,
      blocked: boolean(),
      user_id: String.t() | nil,
      description: String.t(),
      metadata: map()
    }
  end
  
  defmodule ComplianceEvent do
    @moduledoc """
    Audit event for compliance-related activities.
    """
    
    defstruct [
      :event_id,
      :timestamp,
      :compliance_framework,
      :requirement,
      :activity,
      :status,
      :evidence,
      :auditor_id,
      :findings,
      :remediation_required,
      :due_date,
      :metadata
    ]
    
    @type compliance_framework :: :soc2 | :hipaa | :gdpr | :pci_dss | :iso27001
    @type status :: :compliant | :non_compliant | :partial | :under_review
    
    @type t :: %__MODULE__{
      event_id: String.t(),
      timestamp: integer(),
      compliance_framework: compliance_framework(),
      requirement: String.t(),
      activity: String.t(),
      status: status(),
      evidence: map() | nil,
      auditor_id: String.t() | nil,
      findings: [String.t()] | nil,
      remediation_required: boolean(),
      due_date: integer() | nil,
      metadata: map()
    }
  end
  
  defmodule TerminalAuditEvent do
    @moduledoc """
    Audit event specific to terminal operations.
    """
    
    defstruct [
      :event_id,
      :timestamp,
      :user_id,
      :terminal_id,
      :action,
      :command,
      :working_directory,
      :environment_variables,
      :output_captured,
      :exit_code,
      :duration_ms,
      :ip_address,
      :session_id,
      :metadata
    ]
    
    @type action :: :command_executed | :file_accessed | :network_connection | 
                    :privilege_escalation | :terminal_resized | :session_shared
    
    @type t :: %__MODULE__{
      event_id: String.t(),
      timestamp: integer(),
      user_id: String.t(),
      terminal_id: String.t(),
      action: action(),
      command: String.t() | nil,
      working_directory: String.t() | nil,
      environment_variables: map() | nil,
      output_captured: boolean(),
      exit_code: integer() | nil,
      duration_ms: integer() | nil,
      ip_address: String.t() | nil,
      session_id: String.t() | nil,
      metadata: map()
    }
    
    def validate(event) do
      with :ok <- Raxol.Audit.Events.validate_required(event, [:event_id, :timestamp, :user_id, :terminal_id, :action]) do
        validate_action_specific(event)
      end
    end
    
    defp validate_action_specific(%{action: :command_executed, command: nil}), 
      do: {:error, :command_required_for_execution}
    defp validate_action_specific(_), do: {:ok, true}
  end
  
  defmodule DataPrivacyEvent do
    @moduledoc """
    Audit event for GDPR and privacy-related operations.
    """
    
    defstruct [
      :event_id,
      :timestamp,
      :data_subject_id,
      :request_type,
      :status,
      :processor_id,
      :data_categories,
      :legal_basis,
      :retention_period,
      :third_parties,
      :cross_border_transfer,
      :metadata
    ]
    
    @type request_type :: :access | :rectification | :erasure | :portability | 
                          :restriction | :consent_given | :consent_withdrawn
    @type status :: :pending | :processing | :completed | :rejected
    
    @type t :: %__MODULE__{
      event_id: String.t(),
      timestamp: integer(),
      data_subject_id: String.t(),
      request_type: request_type(),
      status: status(),
      processor_id: String.t() | nil,
      data_categories: [String.t()] | nil,
      legal_basis: String.t() | nil,
      retention_period: integer() | nil,
      third_parties: [String.t()] | nil,
      cross_border_transfer: boolean(),
      metadata: map()
    }
  end
  
  # Helper functions for creating audit events
  
  @doc """
  Creates an authentication audit event.
  """
  def authentication_event(username, method, outcome, opts \\ []) do
    %AuthenticationEvent{
      event_id: generate_event_id(),
      timestamp: System.system_time(:millisecond),
      username: username,
      authentication_method: method,
      outcome: outcome,
      user_id: Keyword.get(opts, :user_id),
      failure_reason: Keyword.get(opts, :failure_reason),
      ip_address: Keyword.get(opts, :ip_address, "unknown"),
      user_agent: Keyword.get(opts, :user_agent),
      session_id: Keyword.get(opts, :session_id),
      mfa_used: Keyword.get(opts, :mfa_used, false),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end
  
  @doc """
  Creates a data access audit event.
  """
  def data_access_event(user_id, operation, resource_type, opts \\ []) do
    %DataAccessEvent{
      event_id: generate_event_id(),
      timestamp: System.system_time(:millisecond),
      user_id: user_id,
      operation: operation,
      resource_type: resource_type,
      resource_id: Keyword.get(opts, :resource_id),
      data_classification: Keyword.get(opts, :data_classification, :internal),
      fields_accessed: Keyword.get(opts, :fields_accessed),
      records_count: Keyword.get(opts, :records_count),
      query: Keyword.get(opts, :query),
      outcome: Keyword.get(opts, :outcome, :success),
      error_message: Keyword.get(opts, :error_message),
      ip_address: Keyword.get(opts, :ip_address),
      session_id: Keyword.get(opts, :session_id),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end
  
  @doc """
  Creates a terminal audit event.
  """
  def terminal_audit_event(user_id, terminal_id, action, opts \\ []) do
    %TerminalAuditEvent{
      event_id: generate_event_id(),
      timestamp: System.system_time(:millisecond),
      user_id: user_id,
      terminal_id: terminal_id,
      action: action,
      command: Keyword.get(opts, :command),
      working_directory: Keyword.get(opts, :working_directory),
      environment_variables: Keyword.get(opts, :environment_variables),
      output_captured: Keyword.get(opts, :output_captured, false),
      exit_code: Keyword.get(opts, :exit_code),
      duration_ms: Keyword.get(opts, :duration_ms),
      ip_address: Keyword.get(opts, :ip_address),
      session_id: Keyword.get(opts, :session_id),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end
  
  @doc """
  Creates a security event.
  """
  def security_event(event_type, severity, description, opts \\ []) do
    %SecurityEvent{
      event_id: generate_event_id(),
      timestamp: System.system_time(:millisecond),
      event_type: event_type,
      severity: severity,
      threat_level: Keyword.get(opts, :threat_level, :moderate),
      source_ip: Keyword.get(opts, :source_ip),
      target_resource: Keyword.get(opts, :target_resource),
      attack_vector: Keyword.get(opts, :attack_vector),
      detection_method: Keyword.get(opts, :detection_method, "system"),
      response_action: Keyword.get(opts, :response_action),
      blocked: Keyword.get(opts, :blocked, false),
      user_id: Keyword.get(opts, :user_id),
      description: description,
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end
  
  defp generate_event_id do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end
  
  def validate_required(event, fields) do
    missing = Enum.filter(fields, &(Map.get(event, &1) == nil))
    
    if Enum.empty?(missing) do
      :ok
    else
      {:error, {:missing_required_fields, missing}}
    end
  end
end