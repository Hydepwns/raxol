defmodule Raxol.Terminal.EmulatorPluginLifecycleTest do
  use ExUnit.Case
  import Raxol.Test.EventAssertions

  alias Raxol.Core.Runtime.Plugins.Manager
  alias Raxol.Plugins.HyperlinkPlugin
  alias Raxol.Terminal.Emulator
  alias Raxol.Test.MockPlugins.MockDependencyPlugin
  alias Raxol.Test.MockPlugins.MockDependentPlugin
  alias Raxol.Test.MockPlugins.MockIncompatibleVersionPlugin
  alias Raxol.Test.MockPlugins.MockOnInitCrashPlugin
  alias Raxol.Test.MockPlugins.MockOnTerminateCrashPlugin

  setup context do
    reloading_enabled = Keyword.has_key?(context[:tags] || [], :enable_plugin_reloading)

    {:ok, _pid} =
      Manager.start_link(
        command_registry_table: :test_command_registry,
        plugin_config: %{},
        enable_plugin_reloading: reloading_enabled,
        runtime_pid: self()
      )

    :ok = Manager.initialize()
    emulator = Emulator.new(80, 24)
    on_exit(fn -> :ets.delete(:test_command_registry) end)
    {:ok, %{emulator: emulator}}
  end

  describe "plugin lifecycle" do
    test "loads and enables a plugin", %{emulator: _emulator} do
      assert :ok = Manager.load_plugin("mock_dependency_plugin", %{})
      assert :ok = Manager.enable_plugin("mock_dependency_plugin")
    end

    test "disables and reloads a plugin", %{emulator: _emulator} do
      assert :ok = Manager.load_plugin("mock_dependency_plugin", %{})
      assert :ok = Manager.disable_plugin("mock_dependency_plugin")
      assert :ok = Manager.reload_plugin("mock_dependency_plugin")
    end

    test "handles plugin init crash gracefully", %{emulator: _emulator} do
      assert match?(
               {:error, _},
               Manager.load_plugin("mock_on_init_crash_plugin", %{})
             )
    end

    test "handles plugin terminate crash gracefully", %{emulator: _emulator} do
      assert :ok = Manager.load_plugin("mock_on_terminate_crash_plugin", %{})
      # Trigger plugin termination (unload or reload)
      result = Manager.reload_plugin("mock_on_terminate_crash_plugin")

      case result do
        :ok -> assert true
        {:error, _} -> assert true
        _ -> flunk("Unexpected result: #{inspect(result)}")
      end
    end
  end
end
