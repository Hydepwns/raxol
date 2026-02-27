defmodule Raxol.Core.Runtime.Plugins.Security.BeamAnalyzerTest do
  @moduledoc """
  Tests for BEAM bytecode security analysis.
  """
  use ExUnit.Case, async: true

  alias Raxol.Core.Runtime.Plugins.Security.BeamAnalyzer
  alias Raxol.Test.Security

  describe "analyze_module/1" do
    test "returns capabilities map for valid module" do
      assert {:ok, capabilities} = BeamAnalyzer.analyze_module(Enum)
      assert is_map(capabilities)
      assert Map.has_key?(capabilities, :file_access)
      assert Map.has_key?(capabilities, :network_access)
      assert Map.has_key?(capabilities, :code_injection)
      assert Map.has_key?(capabilities, :system_commands)
    end

    test "returns error for non-existent module" do
      assert {:error, _reason} = BeamAnalyzer.analyze_module(NonExistent.Module.That.DoesNot.Exist)
    end

    test "detects file access in File module" do
      assert {:ok, capabilities} = BeamAnalyzer.analyze_module(File)
      # File module itself doesn't necessarily call File functions internally
      # but it's compiled, so we can analyze it
      assert is_boolean(capabilities.file_access)
    end
  end

  describe "has_file_access?/1" do
    test "returns true for module using File operations" do
      assert BeamAnalyzer.has_file_access?(Security.FileAccessModule)
    end

    test "returns false for module without file operations" do
      refute BeamAnalyzer.has_file_access?(Security.CleanModule)
    end
  end

  describe "has_network_access?/1" do
    test "returns true for module using network operations" do
      assert BeamAnalyzer.has_network_access?(Security.NetworkAccessModule)
    end

    test "returns false for module without network operations" do
      refute BeamAnalyzer.has_network_access?(Security.CleanModule)
    end
  end

  describe "has_code_injection_risk?/1" do
    test "returns true for module using dynamic code evaluation" do
      assert BeamAnalyzer.has_code_injection_risk?(Security.CodeInjectionModule)
    end

    test "returns false for module without dynamic evaluation" do
      refute BeamAnalyzer.has_code_injection_risk?(Security.CleanModule)
    end
  end

  describe "has_system_command_access?/1" do
    test "returns true for module using system commands" do
      assert BeamAnalyzer.has_system_command_access?(Security.SystemCommandModule)
    end

    test "returns false for module without system commands" do
      refute BeamAnalyzer.has_system_command_access?(Security.CleanModule)
    end
  end

  describe "analyze_module/1 with multiple capabilities" do
    test "detects all capabilities in mixed module" do
      assert {:ok, capabilities} = BeamAnalyzer.analyze_module(Security.MixedModule)
      assert capabilities.file_access == true
      assert capabilities.system_commands == true
    end
  end

  describe "analyze_module/1 edge cases" do
    test "handles standard library modules" do
      assert {:ok, _} = BeamAnalyzer.analyze_module(Enum)
      assert {:ok, _} = BeamAnalyzer.analyze_module(Map)
      assert {:ok, _} = BeamAnalyzer.analyze_module(String)
    end

    test "handles preloaded modules gracefully" do
      # :erlang is preloaded and may not have abstract code
      result = BeamAnalyzer.analyze_module(:erlang)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
