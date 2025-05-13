defmodule Raxol.Core.Runtime.Plugins.EdgeCases.PluginLoadingTest do
  use ExUnit.Case
  import Mox

  alias Raxol.Core.Runtime.Plugins.{Loader, LifecycleHelper}
  alias Raxol.Test.PluginTestFixtures
  alias Raxol.Core.Runtime.Plugins.EdgeCases.Helper

  setup do
    Helper.setup_test()
  end

  describe "plugin loading errors" do
    test "handles plugin init failure gracefully", %{
      command_registry_table: table
    } do
      Helper.with_running_manager(
        [command_registry_table: table],
        fn manager_pid ->
          # Setup: Plugin init will fail
          Mox.expect(EdgeCasesLifecycleHelperMock, :init_plugin, fn
            PluginTestFixtures.TestPlugin, _opts -> {:error, :init_failed}
            # Default case for other plugins if any
            _module, _opts -> {:ok, %{}}
          end)

          Helper.assert_plugin_load_fails(
            manager_pid,
            PluginTestFixtures.TestPlugin,
            %{},
            {:error, {:init_failed, :init_failed}}
          )
        end
      )
    end

    test "handles plugin module loading errors", %{
      command_registry_table: table
    } do
      Helper.with_running_manager(
        [command_registry_table: table],
        fn manager_pid ->
          # Setup: Loader will fail to load the module using Mox
          Mox.expect(Loader, :load_plugin_module, fn
            PluginTestFixtures.TestPlugin -> {:error, :not_found}
            # Default case
            _ -> {:ok, nil}
          end)

          Helper.assert_plugin_load_fails(
            manager_pid,
            PluginTestFixtures.TestPlugin,
            %{},
            {:error, {:module_load_failed, :not_found}}
          )
        end
      )
    end

    test "handles plugin init timeout (simulated via mock)", %{
      command_registry_table: table
    } do
      Helper.with_running_manager(
        [command_registry_table: table],
        fn manager_pid ->
          # Use the stub module instead of a map
          Mox.stub_with(
            EdgeCasesLifecycleHelperMock,
            EdgeCasesLifecycleHelperTimeoutStub
          )

          Helper.assert_plugin_load_fails(
            manager_pid,
            PluginTestFixtures.TestPlugin,
            %{},
            {:error, :init_timeout}
          )
        end
      )
    end
  end
end

defmodule EdgeCasesLifecycleHelperTimeoutStub do
  @behaviour Raxol.Core.Runtime.Plugins.LifecycleHelper.Behaviour

  def init_plugin(_module, _opts) do
    # Use a timer to simulate a timeout that matches the actual timeout in the code
    Process.send_after(self(), :timeout_simulated, 6000)

    receive do
      :timeout_simulated -> {:error, :timeout_simulated}
    end
  end

  def check_dependencies(_, _, _), do: {:ok, []}
  def terminate_plugin(_, _, _), do: :ok

  # Stub implementations for required callbacks
  def load_plugin(_, _, _, _, _, _, _, _), do: {:error, :not_implemented}
  def unload_plugin(_, _, _, _, _, _), do: {:error, :not_implemented}
  def reload_plugin(_, _, _, _, _, _, _), do: {:error, :not_implemented}
  def initialize_plugins(_, _, _, _, _, _, _), do: {:error, :not_implemented}
  def reload_plugin_from_disk(_, _, _, _, _, _, _, _), do: {:error, :not_implemented}
  def load_plugin_by_module(_, _, _, _, _, _, _, _), do: {:error, :not_implemented}
end
