defmodule Raxol.Core.Runtime.Plugins.VersionConstraintTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Runtime.Plugins.DependencyManager
  alias Raxol.Core.Runtime.Plugins.DependencyManagerTestHelper

  describe "version constraint handling" do
    test "handles simple version constraints" do
      plugin_metadata = %{dependencies: [{"other_plugin", ">= 1.0.0"}]}
      loaded_plugins = %{"other_plugin" => %{version: "1.1.0"}}

      assert :ok ==
               DependencyManager.check_dependencies(
                 "my_plugin",
                 plugin_metadata,
                 loaded_plugins
               )
    end

    test "handles complex version constraints with OR operator" do
      plugin_metadata = %{
        dependencies: [{"other_plugin", ">= 1.0.0 || >= 2.0.0"}]
      }

      loaded_plugins = %{"other_plugin" => %{version: "2.1.0"}}

      assert :ok ==
               DependencyManager.check_dependencies(
                 "my_plugin",
                 plugin_metadata,
                 loaded_plugins
               )
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

      assert :ok ==
               DependencyManager.check_dependencies(
                 "my_plugin",
                 plugin_metadata,
                 loaded_plugins
               )
    end

    test "reports version mismatches with detailed information" do
      plugin_metadata = %{dependencies: [{"other_plugin", ">= 2.0.0"}]}
      loaded_plugins = %{"other_plugin" => %{version: "1.0.0"}}

      assert {:error, :version_mismatch,
              [{"other_plugin", "1.0.0", ">= 2.0.0"}],
              ["my_plugin"]} ==
               DependencyManager.check_dependencies(
                 "my_plugin",
                 plugin_metadata,
                 loaded_plugins
               )
    end

    test "handles invalid version formats" do
      plugin_metadata = %{dependencies: [{"other_plugin", "invalid_version"}]}
      loaded_plugins = %{"other_plugin" => %{version: "1.0.0"}}

      assert {:error, :version_mismatch,
              [{"other_plugin", "1.0.0", "invalid_version"}],
              ["my_plugin"]} ==
               DependencyManager.check_dependencies(
                 "my_plugin",
                 plugin_metadata,
                 loaded_plugins
               )
    end

    test "handles invalid version requirement formats" do
      plugin_metadata = %{
        dependencies: [{"other_plugin", ">= 1.0.0 || invalid"}]
      }

      loaded_plugins = %{"other_plugin" => %{version: "1.0.0"}}

      assert {:error, :version_mismatch,
              [{"other_plugin", "1.0.0", ">= 1.0.0 || invalid"}],
              ["my_plugin"]} ==
               DependencyManager.check_dependencies(
                 "my_plugin",
                 plugin_metadata,
                 loaded_plugins
               )
    end

    test "handles empty version strings" do
      plugin_metadata = %{
        dependencies: [
          {"plugin_a", ""},
          {"plugin_b", "   "},
          {"plugin_c", nil}
        ]
      }

      loaded_plugins = %{
        "plugin_a" => %{version: "1.0.0"},
        "plugin_b" => %{version: "1.0.0"},
        "plugin_c" => %{version: "1.0.0"}
      }

      assert {:error, :invalid_version_requirement, invalid_reqs, ["my_plugin"]} =
               DependencyManager.check_dependencies(
                 "my_plugin",
                 plugin_metadata,
                 loaded_plugins
               )

      assert length(invalid_reqs) == 3
    end

    test "handles missing version in loaded plugins" do
      plugin_metadata = %{dependencies: [{"plugin_a", ">= 1.0.0"}]}
      # Missing version field
      loaded_plugins = %{"plugin_a" => %{}}

      assert {:error, :missing_version, ["plugin_a"], ["my_plugin"]} ==
               DependencyManager.check_dependencies(
                 "my_plugin",
                 plugin_metadata,
                 loaded_plugins
               )
    end

    test "handles invalid version format in loaded plugins" do
      plugin_metadata = %{dependencies: [{"plugin_a", ">= 1.0.0"}]}
      loaded_plugins = %{"plugin_a" => %{version: "invalid"}}

      assert {:error, :invalid_version_format, ["plugin_a"], ["my_plugin"]} ==
               DependencyManager.check_dependencies(
                 "my_plugin",
                 plugin_metadata,
                 loaded_plugins
               )
    end
  end
end
