defmodule Raxol.Core.Runtime.Plugins.DependencyManagerVersionTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Runtime.Plugins.DependencyManager

  describe "version constraint handling" do
    test "handles simple version constraints" do
      plugin_metadata = %{dependencies: [{"other_plugin", ">= 1.0.0"}]}
      loaded_plugins = %{"other_plugin" => %{version: "1.1.0"}}

      assert :ok == DependencyManager.check_dependencies("my_plugin", plugin_metadata, loaded_plugins)
    end

    test "handles complex version constraints with OR operator" do
      plugin_metadata = %{dependencies: [{"other_plugin", ">= 1.0.0 || >= 2.0.0"}]}
      loaded_plugins = %{"other_plugin" => %{version: "2.1.0"}}

      assert :ok == DependencyManager.check_dependencies("my_plugin", plugin_metadata, loaded_plugins)
    end

    test "handles multiple version constraints" do
      plugin_metadata = %{
        dependencies: [
          {"plugin_a", ">= 1.0.0"},
          {"plugin_b", ">= 2.0.0 || >= 3.0.0"},
          {"plugin_c", "~> 1.0"}
        ]
      }
      loaded_plugins = %{
        "plugin_a" => %{version: "1.1.0"},
        "plugin_b" => %{version: "3.0.0"},
        "plugin_c" => %{version: "1.2.0"}
      }

      assert :ok == DependencyManager.check_dependencies("my_plugin", plugin_metadata, loaded_plugins)
    end

    test "reports version mismatches with detailed information" do
      plugin_metadata = %{dependencies: [{"other_plugin", ">= 2.0.0"}]}
      loaded_plugins = %{"other_plugin" => %{version: "1.0.0"}}

      assert {:error, :version_mismatch, [{"other_plugin", "1.0.0", ">= 2.0.0"}], ["my_plugin"]} ==
               DependencyManager.check_dependencies("my_plugin", plugin_metadata, loaded_plugins)
    end
  end

  describe "version format validation" do
    test "handles invalid version format in loaded plugins" do
      invalid_versions = [
        nil,
        "",
        "not_a_version",
        "1",
        "1.",
        "1.0.",
        "1.0.0.",
        "1.0.0.0",
        "1.0.0.0.0",
        "1.0.0.0.0.0",
        "1.0.0.0.0.0.0",
        "1.0.0.0.0.0.0.0",
        "1.0.0.0.0.0.0.0.0",
        "1.0.0.0.0.0.0.0.0.0",
        "1.0.0.0.0.0.0.0.0.0.0"
      ]

      Enum.each(invalid_versions, fn version ->
        plugins = %{"plugin" => %{version: version}}
        assert {:error, :invalid_version_format, ["plugin"], ["my_plugin"]} =
          DependencyManager.check_dependencies("my_plugin", %{dependencies: [{"plugin", ">= 1.0.0"}]}, plugins)
      end)
    end

    test "handles invalid version requirement format" do
      invalid_requirements = [
        nil,
        "",
        "not_a_requirement",
        ">=",
        ">= ",
        ">= 1",
        ">= 1.",
        ">= 1.0.",
        ">= 1.0.0.",
        ">= 1.0.0.0",
        ">= 1.0.0.0.0",
        ">= 1.0.0.0.0.0",
        ">= 1.0.0.0.0.0.0",
        ">= 1.0.0.0.0.0.0.0",
        ">= 1.0.0.0.0.0.0.0.0",
        ">= 1.0.0.0.0.0.0.0.0.0",
        ">= 1.0.0.0.0.0.0.0.0.0.0",
        ">= 1.0.0 ||",
        ">= 1.0.0 || ",
        ">= 1.0.0 || >=",
        ">= 1.0.0 || >= ",
        ">= 1.0.0 || >= 1",
        ">= 1.0.0 || >= 1.",
        ">= 1.0.0 || >= 1.0.",
        ">= 1.0.0 || >= 1.0.0.",
        ">= 1.0.0 || >= 1.0.0.0",
        ">= 1.0.0 || >= 1.0.0.0.0",
        ">= 1.0.0 || >= 1.0.0.0.0.0",
        ">= 1.0.0 || >= 1.0.0.0.0.0.0",
        ">= 1.0.0 || >= 1.0.0.0.0.0.0.0",
        ">= 1.0.0 || >= 1.0.0.0.0.0.0.0.0",
        ">= 1.0.0 || >= 1.0.0.0.0.0.0.0.0.0",
        ">= 1.0.0 || >= 1.0.0.0.0.0.0.0.0.0.0"
      ]

      Enum.each(invalid_requirements, fn requirement ->
        assert {:error, :invalid_version_requirement, _} =
          DependencyManager.check_dependencies("my_plugin", %{dependencies: [{"plugin", requirement}]}, %{"plugin" => %{version: "1.0.0"}})
      end)
    end

    test "handles conflicting version requirements" do
      conflicts = [
        # Exact version conflicts
        [{"plugin", "1.0.0"}, {"plugin", "2.0.0"}],
        # Range conflicts
        [{"plugin", ">= 1.0.0"}, {"plugin", "<= 0.9.0"}],
        [{"plugin", "~> 1.0"}, {"plugin", "~> 2.0"}],
        # Complex conflicts
        [{"plugin", ">= 1.0.0 || >= 2.0.0"}, {"plugin", "<= 0.9.0"}],
        [{"plugin", "~> 1.0 || ~> 2.0"}, {"plugin", "~> 3.0"}],
        # Multiple conflicts
        [{"plugin", "1.0.0"}, {"plugin", "2.0.0"}, {"plugin", "3.0.0"}],
        [{"plugin", ">= 1.0.0"}, {"plugin", "<= 0.9.0"}, {"plugin", "~> 2.0"}]
      ]

      Enum.each(conflicts, fn deps ->
        assert {:error, :conflicting_requirements, conflicts, ["my_plugin"]} =
          DependencyManager.check_dependencies("my_plugin", %{dependencies: deps}, %{"plugin" => %{version: "1.0.0"}})
        assert length(conflicts) > 0
      end)
    end
  end
end
