defmodule Raxol.Core.Runtime.Plugins.Security.CapabilityDetector do
  @moduledoc """
  High-level capability detection for plugins.

  This module provides a simple interface to detect what capabilities a plugin
  requires and whether those capabilities are permitted by the current security policy.

  ## Usage

      # Detect all capabilities
      capabilities = CapabilityDetector.detect_capabilities(MyPlugin)
      # => %{
      #   file_access: true,
      #   network_access: false,
      #   code_injection: false,
      #   system_commands: false
      # }

      # Check against policy
      policy = %{allow_file_access: false, allow_network: true}
      case CapabilityDetector.validate_against_policy(MyPlugin, policy) do
        :ok -> # Plugin is safe according to policy
        {:error, :file_access_denied} -> # Plugin requires file access but policy denies it
      end

  """

  alias Raxol.Core.Runtime.Plugins.Security.BeamAnalyzer

  @type capability :: :file_access | :network_access | :code_injection | :system_commands
  @type capabilities :: %{capability() => boolean()}
  @type policy :: %{
          optional(:allow_file_access) => boolean(),
          optional(:allow_network_access) => boolean(),
          optional(:allow_code_injection) => boolean(),
          optional(:allow_system_commands) => boolean()
        }

  @default_policy %{
    allow_file_access: false,
    allow_network_access: false,
    allow_code_injection: false,
    allow_system_commands: false
  }

  @doc """
  Detects all capabilities of a module.

  Returns a map indicating which security-sensitive capabilities the module has.
  """
  @spec detect_capabilities(module()) :: {:ok, capabilities()} | {:error, term()}
  def detect_capabilities(module) do
    BeamAnalyzer.analyze_module(module)
  end

  @doc """
  Validates a module's capabilities against a security policy.

  Returns `:ok` if the module's capabilities are within policy bounds,
  or an error tuple describing the violation.
  """
  @spec validate_against_policy(module(), policy()) :: :ok | {:error, atom()}
  def validate_against_policy(module, policy \\ @default_policy) do
    case detect_capabilities(module) do
      {:ok, capabilities} ->
        check_policy_compliance(capabilities, policy)

      {:error, :no_abstract_code} ->
        # Module compiled without debug_info - cannot validate
        # Policy decision: reject by default for safety
        {:error, :cannot_analyze}

      {:error, reason} ->
        {:error, {:analysis_failed, reason}}
    end
  end

  @doc """
  Generates a human-readable report of a module's capabilities.
  """
  @spec capability_report(module()) :: String.t()
  def capability_report(module) do
    case detect_capabilities(module) do
      {:ok, capabilities} ->
        format_capability_report(module, capabilities)

      {:error, reason} ->
        "Failed to analyze #{inspect(module)}: #{inspect(reason)}"
    end
  end

  @doc """
  Returns the default security policy.

  By default, all sensitive capabilities are denied.
  """
  @spec default_policy() :: policy()
  def default_policy, do: @default_policy

  @doc """
  Returns a permissive policy that allows all capabilities.

  Use with caution - only for trusted plugins.
  """
  @spec permissive_policy() :: policy()
  def permissive_policy do
    %{
      allow_file_access: true,
      allow_network_access: true,
      allow_code_injection: true,
      allow_system_commands: true
    }
  end

  @doc """
  Creates a custom policy allowing only specified capabilities.
  """
  @spec create_policy([capability()]) :: policy()
  def create_policy(allowed_capabilities) do
    Enum.reduce(allowed_capabilities, @default_policy, fn capability, policy ->
      case capability do
        :file_access -> Map.put(policy, :allow_file_access, true)
        :network_access -> Map.put(policy, :allow_network_access, true)
        :code_injection -> Map.put(policy, :allow_code_injection, true)
        :system_commands -> Map.put(policy, :allow_system_commands, true)
      end
    end)
  end

  # --- Private Implementation ---

  defp check_policy_compliance(capabilities, policy) do
    violations = find_policy_violations(capabilities, policy)

    case violations do
      [] -> :ok
      [violation | _] -> {:error, violation}
    end
  end

  defp find_policy_violations(capabilities, policy) do
    []
    |> check_capability(capabilities, policy, :file_access, :allow_file_access, :file_access_denied)
    |> check_capability(capabilities, policy, :network_access, :allow_network_access, :network_access_denied)
    |> check_capability(capabilities, policy, :code_injection, :allow_code_injection, :code_injection_denied)
    |> check_capability(capabilities, policy, :system_commands, :allow_system_commands, :system_commands_denied)
  end

  defp check_capability(violations, capabilities, policy, cap_key, policy_key, error) do
    has_capability = Map.get(capabilities, cap_key, false)
    is_allowed = Map.get(policy, policy_key, false)

    case {has_capability, is_allowed} do
      {true, false} -> [error | violations]
      _ -> violations
    end
  end

  defp format_capability_report(module, capabilities) do
    header = "Capability Report for #{inspect(module)}\n" <> String.duplicate("=", 50) <> "\n\n"

    body =
      capabilities
      |> Enum.map(fn {capability, has_it} ->
        status = if has_it, do: "[X]", else: "[ ]"
        description = capability_description(capability)
        "#{status} #{description}"
      end)
      |> Enum.join("\n")

    summary =
      "\n\n" <>
        String.duplicate("-", 50) <>
        "\n" <>
        "Total sensitive capabilities: #{count_capabilities(capabilities)}"

    header <> body <> summary
  end

  defp capability_description(:file_access), do: "File System Access"
  defp capability_description(:network_access), do: "Network Access"
  defp capability_description(:code_injection), do: "Dynamic Code Evaluation"
  defp capability_description(:system_commands), do: "System Command Execution"

  defp count_capabilities(capabilities) do
    capabilities
    |> Map.values()
    |> Enum.count(& &1)
  end
end
