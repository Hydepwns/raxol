defmodule Raxol.Core.Runtime.Plugins.Security.CapabilityDetectorTest do
  @moduledoc """
  Tests for high-level capability detection and policy enforcement.
  """
  use ExUnit.Case, async: true

  alias Raxol.Core.Runtime.Plugins.Security.CapabilityDetector
  alias Raxol.Test.Security

  describe "detect_capabilities/1" do
    test "returns capabilities for valid module" do
      assert {:ok, capabilities} = CapabilityDetector.detect_capabilities(Enum)
      assert is_map(capabilities)
      assert Map.has_key?(capabilities, :file_access)
      assert Map.has_key?(capabilities, :network_access)
      assert Map.has_key?(capabilities, :code_injection)
      assert Map.has_key?(capabilities, :system_commands)
    end

    test "returns error for non-existent module" do
      result = CapabilityDetector.detect_capabilities(NonExistent.Module.Here)
      assert match?({:error, _}, result)
    end

    test "detects file access" do
      assert {:ok, capabilities} = CapabilityDetector.detect_capabilities(Security.FileAccessModule)
      assert capabilities.file_access == true
    end

    test "detects network access" do
      assert {:ok, capabilities} = CapabilityDetector.detect_capabilities(Security.NetworkAccessModule)
      assert capabilities.network_access == true
    end
  end

  describe "validate_against_policy/2" do
    test "returns :ok when capabilities within policy" do
      policy = CapabilityDetector.create_policy([:file_access])
      assert :ok = CapabilityDetector.validate_against_policy(Security.FileAccessModule, policy)
    end

    test "returns error when file access denied by policy" do
      policy = CapabilityDetector.default_policy()
      assert {:error, :file_access_denied} = CapabilityDetector.validate_against_policy(Security.FileAccessModule, policy)
    end

    test "returns error when network access denied by policy" do
      policy = CapabilityDetector.default_policy()
      assert {:error, :network_access_denied} = CapabilityDetector.validate_against_policy(Security.NetworkAccessModule, policy)
    end

    test "returns :ok for clean module with default policy" do
      policy = CapabilityDetector.default_policy()
      assert :ok = CapabilityDetector.validate_against_policy(Security.CleanModule, policy)
    end

    test "returns :ok with permissive policy for any module" do
      policy = CapabilityDetector.permissive_policy()
      assert :ok = CapabilityDetector.validate_against_policy(Security.FileAccessModule, policy)
      assert :ok = CapabilityDetector.validate_against_policy(Security.NetworkAccessModule, policy)
    end

    test "uses default policy when none provided" do
      # FileAccessModule has file access, default policy denies it
      assert {:error, :file_access_denied} = CapabilityDetector.validate_against_policy(Security.FileAccessModule)
    end
  end

  describe "default_policy/0" do
    test "returns policy denying all capabilities" do
      policy = CapabilityDetector.default_policy()
      assert policy.allow_file_access == false
      assert policy.allow_network_access == false
      assert policy.allow_code_injection == false
      assert policy.allow_system_commands == false
    end
  end

  describe "permissive_policy/0" do
    test "returns policy allowing all capabilities" do
      policy = CapabilityDetector.permissive_policy()
      assert policy.allow_file_access == true
      assert policy.allow_network_access == true
      assert policy.allow_code_injection == true
      assert policy.allow_system_commands == true
    end
  end

  describe "create_policy/1" do
    test "creates policy with specified capabilities allowed" do
      policy = CapabilityDetector.create_policy([:file_access, :network_access])
      assert policy.allow_file_access == true
      assert policy.allow_network_access == true
      assert policy.allow_code_injection == false
      assert policy.allow_system_commands == false
    end

    test "creates empty policy when given empty list" do
      policy = CapabilityDetector.create_policy([])
      assert policy == CapabilityDetector.default_policy()
    end

    test "creates policy for single capability" do
      policy = CapabilityDetector.create_policy([:system_commands])
      assert policy.allow_system_commands == true
      assert policy.allow_file_access == false
    end
  end

  describe "capability_report/1" do
    test "returns string report for valid module" do
      report = CapabilityDetector.capability_report(Security.FileAccessModule)
      assert is_binary(report)
      assert report =~ "Capability Report"
      assert report =~ "File System Access"
    end

    test "reports detected capabilities with checkmark" do
      report = CapabilityDetector.capability_report(Security.FileAccessModule)
      assert report =~ "[X] File System Access"
    end

    test "reports missing capabilities without checkmark" do
      report = CapabilityDetector.capability_report(Security.CleanModule)
      assert report =~ "[ ] File System Access"
      assert report =~ "[ ] Network Access"
    end

    test "returns error message for invalid module" do
      report = CapabilityDetector.capability_report(NonExistent.Module.Here)
      assert report =~ "Failed to analyze"
    end

    test "includes capability count" do
      report = CapabilityDetector.capability_report(Security.CleanModule)
      assert report =~ "Total sensitive capabilities: 0"
    end
  end

  describe "policy validation edge cases" do
    test "handles module with multiple violations" do
      # MixedModule has both file and system command access
      policy = CapabilityDetector.default_policy()
      result = CapabilityDetector.validate_against_policy(Security.MixedModule, policy)
      # Should return the first violation found
      assert match?({:error, violation} when violation in [:file_access_denied, :system_commands_denied], result)
    end

    test "handles partial policy allowing some capabilities" do
      policy = CapabilityDetector.create_policy([:file_access])
      # MixedModule has both file and system command access
      # File is allowed but system commands are not
      result = CapabilityDetector.validate_against_policy(Security.MixedModule, policy)
      assert {:error, :system_commands_denied} = result
    end
  end
end
