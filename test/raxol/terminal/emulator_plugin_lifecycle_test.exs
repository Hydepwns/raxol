defmodule Raxol.Terminal.EmulatorPluginLifecycleTest do
  use ExUnit.Case
  @moduletag :integration

  alias Raxol.Terminal.Emulator
  alias Raxol.Core.Runtime.Plugins.PluginManager, as: Manager

  setup context do
    reloading_enabled =
      Keyword.has_key?(context[:tags] || [], :enable_plugin_reloading)

    # Start ErrorRecovery if not already running
    case Process.whereis(Raxol.Core.ErrorRecovery) do
      nil ->
        {:ok, _} = Raxol.Core.ErrorRecovery.start_link(name: Raxol.Core.ErrorRecovery)
      _pid ->
        :ok
    end

    {:ok, _pid} =
      Manager.start_link(
        name: Manager,
        command_registry_table: :test_command_registry,
        plugin_config: %{},
        enable_plugin_reloading: reloading_enabled,
        runtime_pid: self()
      )

    :ok = Manager.initialize()
    emulator = Emulator.new(80, 24)

    on_exit(fn ->
      # Safely delete ETS table if it exists
      try do
        :ets.delete(:test_command_registry)
      catch
        # Table doesn't exist
        :error, :badarg -> :ok
      end
    end)

    {:ok, %{emulator: emulator}}
  end

  describe "plugin lifecycle" do
    test "loads and enables a plugin", %{emulator: _emulator} do
      assert :ok =
               Manager.load_plugin_by_module(
                 Raxol.Test.MockPlugins.MockDependencyPlugin,
                 %{}
               )

      assert :ok = Manager.enable_plugin("mock_dependency_plugin")
    end

    test "disables and reloads a plugin", %{emulator: _emulator} do
      assert :ok =
               Manager.load_plugin_by_module(
                 Raxol.Test.MockPlugins.MockDependencyPlugin,
                 %{}
               )

      assert :ok = Manager.disable_plugin("mock_dependency_plugin")
      assert :ok = Manager.reload_plugin("mock_dependency_plugin")
    end

    test "handles plugin init crash gracefully", %{emulator: _emulator} do
      assert match?(
               {:error, _},
               Manager.load_plugin_by_module(
                 Raxol.Test.MockPlugins.MockOnInitCrashPlugin,
                 %{}
               )
             )
    end

    test "handles plugin terminate crash gracefully", %{emulator: _emulator} do
      assert :ok =
               Manager.load_plugin_by_module(
                 Raxol.Test.MockPlugins.MockOnTerminateCrashPlugin,
                 %{}
               )

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
