defmodule Raxol.Core.Runtime.Plugins.EdgeCases.PluginDependencyTest do
  use ExUnit.Case
  import Mox

  alias Raxol.Core.Runtime.Plugins.LifecycleHelper
  alias Raxol.Test.PluginTestFixtures
  alias Raxol.Core.Runtime.Plugins.EdgeCases.Helper

  setup do
    Helper.setup_test()
  end

  describe "plugin dependency resolution" do
    test "handles dependency resolution failures", %{command_registry_table: table} do
      Helper.with_running_manager([command_registry_table: table], fn manager_pid ->
        # Setup: LifecycleHelper will check dependencies
        Mox.expect(EdgeCasesLifecycleHelperMock, :check_dependencies, fn
          _plugin_id,
          %{dependencies: [{"missing_plugin", ">= 1.0.0"}]},
          _available_plugins ->
            {:error, :missing_dependencies, ["missing_plugin"], ["my_plugin"]}

          _plugin_id,
          %{dependencies: [{"version_mismatch", ">= 2.0.0"}]},
          _available_plugins ->
            {:error, :version_mismatch, [{"version_mismatch", "1.0.0", ">= 2.0.0"}], ["my_plugin"]}

          _plugin_id,
          %{dependencies: [{"circular_dependency", ">= 1.0.0"}]},
          _available_plugins ->
            {:error, :circular_dependency, ["circular_dependency", "my_plugin"], ["my_plugin", "circular_dependency"]}

          # Default case
          _plugin_id, _metadata, _available_plugins ->
            {:ok}
        end)

        # Test missing dependency
        Helper.assert_plugin_load_fails(
          manager_pid,
          PluginTestFixtures.DependentPlugin,
          %{},
          {:error, {:dependency_check_failed, {:missing_dependencies, ["missing_plugin"], ["my_plugin"]}}}
        )

        # Test version mismatch
        Helper.assert_plugin_load_fails(
          manager_pid,
          PluginTestFixtures.VersionMismatchPlugin,
          %{},
          {:error, {:dependency_check_failed, {:version_mismatch, [{"version_mismatch", "1.0.0", ">= 2.0.0"}], ["my_plugin"]}}}
        )

        # Test circular dependency
        Helper.assert_plugin_load_fails(
          manager_pid,
          PluginTestFixtures.CircularDependencyPlugin,
          %{},
          {:error, {:dependency_check_failed, {:circular_dependency, ["circular_dependency", "my_plugin"], ["my_plugin", "circular_dependency"]}}}
        )
      end)
    end

    test "handles dependency load failures", %{command_registry_table: table} do
      Helper.with_running_manager([command_registry_table: table], fn manager_pid ->
        # Setup: Load a plugin that depends on a failing plugin
        Mox.expect(EdgeCasesLifecycleHelperMock, :check_dependencies, fn
          _plugin_id, _metadata, _available_plugins -> {:ok}
        end)

        # First load the dependency that will fail
        Helper.assert_plugin_load_fails(
          manager_pid,
          PluginTestFixtures.FailingDependencyPlugin,
          %{},
          {:error, {:init_failed, :dependency_init_failed}}
        )

        # Then try to load the dependent plugin
        Helper.assert_plugin_load_fails(
          manager_pid,
          PluginTestFixtures.DependentPlugin,
          %{},
          {:error, {:dependency_load_failed, :failing_dependency}}
        )
      end)
    end

    test "handles dependency version conflicts", %{command_registry_table: table} do
      Helper.with_running_manager([command_registry_table: table], fn manager_pid ->
        # Setup: Load plugins with conflicting version requirements
        Mox.expect(EdgeCasesLifecycleHelperMock, :check_dependencies, fn
          _plugin_id,
          %{dependencies: [{"conflicting_dep", ">= 2.0.0"}]},
          _available_plugins ->
            {:error, :version_conflict, [
              {"conflicting_dep", "1.0.0", ">= 2.0.0"},
              {"conflicting_dep", "3.0.0", ">= 2.0.0"}
            ], ["plugin_a", "plugin_b"]}

          # Default case
          _plugin_id, _metadata, _available_plugins ->
            {:ok}
        end)

        Helper.assert_plugin_load_fails(
          manager_pid,
          PluginTestFixtures.VersionConflictPlugin,
          %{},
          {:error, {:dependency_check_failed, {
            :version_conflict,
            [
              {"conflicting_dep", "1.0.0", ">= 2.0.0"},
              {"conflicting_dep", "3.0.0", ">= 2.0.0"}
            ],
            ["plugin_a", "plugin_b"]
          }}}
        )
      end)
    end
  end
end
