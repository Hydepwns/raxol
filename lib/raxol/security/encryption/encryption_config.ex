defmodule Raxol.Security.Encryption.Config do
  @moduledoc """
  Configuration and policy management for encryption system.

  This module manages encryption policies, compliance requirements,
  and configuration for different data classifications.

  ## Data Classifications

  - `:restricted` - Highly sensitive (PII, PHI, payment data)
  - `:confidential` - Internal sensitive data
  - `:internal` - Internal use only
  - `:public` - No encryption required

  ## Compliance Profiles

  - `:pci_dss` - Payment Card Industry
  - `:hipaa` - Healthcare data
  - `:gdpr` - EU personal data
  - `:sox` - Financial data
  """

  use GenServer
  require Logger

  alias Raxol.Audit.Logger, as: AuditLogger

  defstruct [
    :policies,
    :compliance_profiles,
    :data_classifications,
    :key_policies,
    :algorithm_preferences,
    :retention_policies
  ]

  @type data_classification :: :restricted | :confidential | :internal | :public
  @type compliance_profile :: :pci_dss | :hipaa | :gdpr | :sox | :custom

  @type encryption_policy :: %{
          classification: data_classification(),
          algorithm: atom(),
          key_type: atom(),
          key_rotation_days: pos_integer(),
          require_mfa: boolean(),
          require_audit: boolean()
        }

  ## Client API

  @doc """
  Starts the encryption configuration service.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets the encryption policy for a data classification.
  """
  def get_policy(config \\ __MODULE__, classification) do
    GenServer.call(config, {:get_policy, classification})
  end

  @doc """
  Sets a custom encryption policy.
  """
  def set_policy(config \\ __MODULE__, classification, policy) do
    GenServer.call(config, {:set_policy, classification, policy})
  end

  @doc """
  Gets the compliance profile configuration.
  """
  def get_compliance_profile(config \\ __MODULE__, profile) do
    GenServer.call(config, {:get_compliance_profile, profile})
  end

  @doc """
  Validates if encryption meets compliance requirements.
  """
  def validate_compliance(config \\ __MODULE__, encryption_params, profile) do
    GenServer.call(config, {:validate_compliance, encryption_params, profile})
  end

  @doc """
  Gets recommended encryption settings for data.
  """
  def get_recommendations(config \\ __MODULE__, data_attributes) do
    GenServer.call(config, {:get_recommendations, data_attributes})
  end

  @doc """
  Updates algorithm preferences.
  """
  def set_algorithm_preference(config \\ __MODULE__, algorithms) do
    GenServer.call(config, {:set_algorithm_preference, algorithms})
  end

  ## GenServer Implementation

  @impl GenServer
  def init(_opts) do
    state = %__MODULE__{
      policies: init_default_policies(),
      compliance_profiles: init_compliance_profiles(),
      data_classifications: init_classifications(),
      key_policies: init_key_policies(),
      algorithm_preferences: init_algorithm_preferences(),
      retention_policies: init_retention_policies()
    }

    Logger.info("Encryption configuration initialized")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:get_policy, classification}, _from, state) do
    policy = Map.get(state.policies, classification, default_policy())
    {:reply, {:ok, policy}, state}
  end

  @impl GenServer
  def handle_call({:set_policy, classification, policy}, _from, state) do
    # Validate policy
    case validate_policy(policy) do
      :ok ->
        new_policies = Map.put(state.policies, classification, policy)
        new_state = %{state | policies: new_policies}

        # Audit configuration change
        audit_config_change(:policy, classification, policy)

        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:get_compliance_profile, profile}, _from, state) do
    profile_config = Map.get(state.compliance_profiles, profile)
    {:reply, {:ok, profile_config}, state}
  end

  @impl GenServer
  def handle_call({:validate_compliance, params, profile}, _from, state) do
    result = validate_against_profile(params, profile, state)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:get_recommendations, attributes}, _from, state) do
    recommendations = generate_recommendations(attributes, state)
    {:reply, {:ok, recommendations}, state}
  end

  @impl GenServer
  def handle_call({:set_algorithm_preference, algorithms}, _from, state) do
    new_state = %{state | algorithm_preferences: algorithms}

    # Audit configuration change
    audit_config_change(:algorithms, nil, algorithms)

    {:reply, :ok, new_state}
  end

  ## Private Functions

  defp init_default_policies do
    %{
      restricted: %{
        algorithm: :aes_256_gcm,
        key_type: :hardware_backed,
        key_rotation_days: 30,
        require_mfa: true,
        require_audit: true,
        min_key_length: 256,
        require_integrity: true
      },
      confidential: %{
        algorithm: :aes_256_gcm,
        key_type: :software,
        key_rotation_days: 90,
        require_mfa: false,
        require_audit: true,
        min_key_length: 256,
        require_integrity: true
      },
      internal: %{
        algorithm: :aes_256_cbc,
        key_type: :software,
        key_rotation_days: 180,
        require_mfa: false,
        require_audit: false,
        min_key_length: 128,
        require_integrity: false
      },
      public: %{
        algorithm: nil,
        key_type: nil,
        key_rotation_days: nil,
        require_mfa: false,
        require_audit: false,
        min_key_length: 0,
        require_integrity: false
      }
    }
  end

  defp init_compliance_profiles do
    %{
      pci_dss: %{
        name: "PCI DSS v4.0",
        requirements: %{
          min_key_length: 256,
          allowed_algorithms: [:aes_256_gcm, :aes_256_cbc],
          key_rotation_days: 365,
          require_key_encryption: true,
          require_audit: true,
          require_integrity: true,
          data_retention_days: 365
        }
      },
      hipaa: %{
        name: "HIPAA",
        requirements: %{
          min_key_length: 256,
          allowed_algorithms: [:aes_256_gcm],
          key_rotation_days: 90,
          require_key_encryption: true,
          require_audit: true,
          require_integrity: true,
          require_access_control: true,
          # 7 years
          data_retention_days: 2555
        }
      },
      gdpr: %{
        name: "GDPR",
        requirements: %{
          min_key_length: 256,
          allowed_algorithms: [:aes_256_gcm, :chacha20_poly1305],
          key_rotation_days: 180,
          require_pseudonymization: true,
          require_audit: true,
          require_deletion: true,
          data_portability: true
        }
      },
      sox: %{
        name: "SOX",
        requirements: %{
          min_key_length: 256,
          allowed_algorithms: [:aes_256_gcm],
          key_rotation_days: 365,
          require_audit: true,
          require_integrity: true,
          # 7 years
          data_retention_days: 2555
        }
      }
    }
  end

  defp init_classifications do
    %{
      restricted: %{
        description: "Highly sensitive data requiring maximum protection",
        examples: ["SSN", "credit cards", "medical records", "passwords"],
        compliance: [:pci_dss, :hipaa, :gdpr]
      },
      confidential: %{
        description: "Sensitive business information",
        examples: ["financial data", "customer lists", "trade secrets"],
        compliance: [:sox, :gdpr]
      },
      internal: %{
        description: "Internal use only",
        examples: ["employee data", "internal reports", "configurations"],
        compliance: []
      },
      public: %{
        description: "Public information",
        examples: ["marketing materials", "public APIs", "documentation"],
        compliance: []
      }
    }
  end

  defp init_key_policies do
    %{
      rotation: %{
        automatic: true,
        grace_period_days: 30,
        notification_days: 7
      },
      storage: %{
        require_hsm: false,
        allow_software_keys: true,
        backup_required: true
      },
      access: %{
        require_dual_control: false,
        require_mfa: true,
        audit_all_access: true
      }
    }
  end

  defp init_algorithm_preferences do
    [
      # Preferred for authenticated encryption
      :aes_256_gcm,
      # Alternative authenticated encryption
      :chacha20_poly1305,
      # Legacy support
      :aes_256_cbc,
      # Streaming encryption
      :aes_256_ctr
    ]
  end

  defp init_retention_policies do
    %{
      # 7 years
      audit_logs: 2555,
      # 1 year after rotation
      encryption_keys: 365,
      # 30 days before permanent deletion
      deleted_data: 30
    }
  end

  defp default_policy do
    %{
      algorithm: :aes_256_gcm,
      key_type: :software,
      key_rotation_days: 90,
      require_mfa: false,
      require_audit: true,
      min_key_length: 256,
      require_integrity: true
    }
  end

  defp validate_policy(policy) do
    with :ok <- validate_key_length(policy.min_key_length),
         :ok <- validate_rotation_period(policy.key_rotation_days),
         :ok <- validate_algorithm(policy.algorithm) do
      :ok
    end
  end

  defp validate_key_length(length) when length < 128,
    do: {:error, :key_too_short}

  defp validate_key_length(_length), do: :ok

  defp validate_rotation_period(days) when days > 365,
    do: {:error, :rotation_period_too_long}

  defp validate_rotation_period(_days), do: :ok

  defp validate_algorithm(algorithm)
       when algorithm in [
              :aes_256_gcm,
              :aes_256_cbc,
              :chacha20_poly1305,
              :aes_256_ctr
            ],
       do: :ok

  defp validate_algorithm(_algorithm), do: {:error, :unsupported_algorithm}

  defp validate_against_profile(params, profile_name, state) do
    profile = Map.get(state.compliance_profiles, profile_name)

    handle_profile_validation(profile != nil, profile, params, state)
  end

  defp generate_recommendations(attributes, state) do
    # Analyze attributes to recommend encryption settings
    classification = determine_classification(attributes)
    policy = Map.get(state.policies, classification, default_policy())

    %{
      classification: classification,
      recommended_algorithm: policy.algorithm,
      key_rotation_days: policy.key_rotation_days,
      additional_controls: recommend_controls(attributes),
      compliance_profiles: applicable_profiles(attributes, state)
    }
  end

  defp determine_classification(attributes) do
    classify_by_content(attributes)
  end

  defp classify_by_content(attributes) do
    determine_classification_level(attributes)
  end

  defp determine_classification_level(attributes) when is_map(attributes) do
    cond_to_pattern_matching({
      contains_pii?(attributes),
      contains_financial?(attributes),
      Map.get(attributes, :internal, false)
    })
  end

  defp cond_to_pattern_matching({true, _, _}), do: :restricted
  defp cond_to_pattern_matching({_, true, _}), do: :confidential
  defp cond_to_pattern_matching({_, _, true}), do: :internal
  defp cond_to_pattern_matching({false, false, false}), do: :public

  defp contains_pii?(attributes) do
    pii_indicators = [
      "ssn",
      "social_security",
      "credit_card",
      "medical",
      "health"
    ]

    Enum.any?(pii_indicators, fn indicator ->
      String.contains?(String.downcase(attributes[:data_type] || ""), indicator)
    end)
  end

  defp contains_financial?(attributes) do
    financial_indicators = ["financial", "payment", "transaction", "account"]

    Enum.any?(financial_indicators, fn indicator ->
      String.contains?(String.downcase(attributes[:data_type] || ""), indicator)
    end)
  end

  defp recommend_controls(attributes) do
    controls = []

    controls = add_pii_controls(contains_pii?(attributes), controls)
    controls = add_searchable_controls(attributes[:searchable], controls)
    controls = add_volume_controls(attributes[:large_volume], controls)

    controls
  end

  defp applicable_profiles(attributes, state) do
    state.data_classifications
    |> Map.get(determine_classification(attributes), %{})
    |> Map.get(:compliance, [])
  end

  defp audit_config_change(type, classification, new_value) do
    AuditLogger.log_configuration_change(
      get_current_user(),
      "encryption_config",
      to_string(type),
      classification,
      new_value,
      approval_required: true,
      approved_by: get_current_user()
    )
  end

  defp get_current_user do
    Raxol.Security.UserContext.ContextServer.get_current_user()
  end

  # Helper functions for refactored if statements
  defp handle_profile_validation(false, _profile, _params, _state) do
    {:error, :unknown_profile}
  end

  defp handle_profile_validation(true, profile, params, _state) do
    requirements = profile.requirements
    violations = []

    # Check key length
    violations =
      check_key_length_violation(
        params[:key_length] && params.key_length < requirements.min_key_length,
        requirements,
        violations
      )

    # Check algorithm
    violations =
      check_algorithm_violation(
        params[:algorithm] &&
          params.algorithm not in requirements.allowed_algorithms,
        profile.name,
        violations
      )

    # Check rotation
    violations =
      check_rotation_violation(
        params[:rotation_days] &&
          params.rotation_days > requirements.key_rotation_days,
        requirements,
        violations
      )

    # Check audit requirement  
    violations =
      check_audit_violation(
        requirements[:require_audit] && !params[:audit_enabled],
        profile.name,
        violations
      )

    format_validation_result(Enum.empty?(violations), violations)
  end

  defp check_key_length_violation(true, requirements, violations) do
    [
      {:key_length, "Minimum #{requirements.min_key_length} bits required"}
      | violations
    ]
  end

  defp check_key_length_violation(false, _requirements, violations),
    do: violations

  defp check_algorithm_violation(true, profile_name, violations) do
    [{:algorithm, "Algorithm not allowed for #{profile_name}"} | violations]
  end

  defp check_algorithm_violation(false, _profile_name, violations),
    do: violations

  defp check_rotation_violation(true, requirements, violations) do
    [
      {:rotation, "Maximum #{requirements.key_rotation_days} days allowed"}
      | violations
    ]
  end

  defp check_rotation_violation(false, _requirements, violations),
    do: violations

  defp check_audit_violation(true, profile_name, violations) do
    [{:audit, "Audit logging required for #{profile_name}"} | violations]
  end

  defp check_audit_violation(false, _profile_name, violations), do: violations

  defp format_validation_result(true, _violations), do: {:ok, :compliant}

  defp format_validation_result(false, violations),
    do: {:error, {:non_compliant, violations}}

  defp add_pii_controls(true, controls),
    do: [:tokenization, :field_encryption | controls]

  defp add_pii_controls(false, controls), do: controls

  defp add_searchable_controls(true, controls),
    do: [:deterministic_encryption | controls]

  defp add_searchable_controls(_, controls), do: controls

  defp add_volume_controls(true, controls),
    do: [:streaming_encryption, :compression | controls]

  defp add_volume_controls(_, controls), do: controls
end
