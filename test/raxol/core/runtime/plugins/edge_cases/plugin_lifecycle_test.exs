defmodule Raxol.Core.Runtime.Plugins.EdgeCases.PluginLifecycleTest do
  use ExUnit.Case
  import Mox

  alias Raxol.Core.Events.Event
  alias Raxol.Core.Runtime.Plugins.LifecycleHelper
  alias Raxol.Test.PluginTestFixtures
  alias Raxol.Core.Runtime.Plugins.EdgeCases.Helper

  setup do
    Helper.setup_test()
  end

  describe "plugin lifecycle events" do
    test "handles plugin termination errors", %{command_registry_table: table} do
      Helper.with_running_manager(
        [command_registry_table: table],
        fn manager_pid ->
          # Setup: Load a plugin that will fail to terminate
          Mox.expect(EdgeCasesLifecycleHelperMock, :terminate_plugin, fn
            _plugin_id, _state, _reason -> {:error, :termination_failed}
            # Default case
            _plugin_id, _state, _reason -> :ok
          end)

          # Load the plugin
          assert {:ok, _loaded_state} =
                   Helper.setup_plugin(
                     manager_pid,
                     PluginTestFixtures.FailingTerminationPlugin,
                     :failing_termination_plugin,
                     %{}
                   )

          # Attempt to unload the plugin
          assert {:error, :termination_failed} =
                   Manager.unload_plugin(
                     manager_pid,
                     :failing_termination_plugin
                   )
        end
      )
    end

    test "handles plugin state transition errors", %{
      command_registry_table: table
    } do
      Helper.with_running_manager(
        [command_registry_table: table],
        fn manager_pid ->
          # Setup: Load a plugin that will fail during state transitions
          Mox.expect(EdgeCasesLifecycleHelperMock, :handle_state_transition, fn
            _plugin_id, :starting, _state -> {:error, :transition_failed}
            # Default case
            _plugin_id, _transition, _state -> {:ok, %{}}
          end)

          # Attempt to load the plugin
          Helper.assert_plugin_load_fails(
            manager_pid,
            PluginTestFixtures.FailingStateTransitionPlugin,
            %{},
            {:error, {:state_transition_failed, :starting}}
          )
        end
      )
    end

    test "handles plugin event handling errors", %{
      command_registry_table: table
    } do
      Helper.with_running_manager(
        [command_registry_table: table],
        fn manager_pid ->
          # Setup: Load a plugin that will fail to handle events
          assert {:ok, _loaded_state} =
                   Helper.setup_plugin(
                     manager_pid,
                     PluginTestFixtures.FailingEventHandlerPlugin,
                     :failing_event_handler_plugin,
                     %{}
                   )

          # Create a test event
          event = %Event{
            type: :test_event,
            data: %{test: "data"},
            timestamp: DateTime.utc_now()
          }

          # Attempt to handle the event
          assert {:error, :event_handling_failed} =
                   Manager.handle_event(
                     manager_pid,
                     :failing_event_handler_plugin,
                     event
                   )
        end
      )
    end

    test "handles plugin cleanup errors", %{command_registry_table: table} do
      Helper.with_running_manager(
        [command_registry_table: table],
        fn manager_pid ->
          # Setup: Load a plugin that will fail during cleanup
          Mox.expect(EdgeCasesLifecycleHelperMock, :cleanup_plugin, fn
            _plugin_id, _state -> {:error, :cleanup_failed}
            # Default case
            _plugin_id, _state -> :ok
          end)

          # Load the plugin
          assert {:ok, _loaded_state} =
                   Helper.setup_plugin(
                     manager_pid,
                     PluginTestFixtures.FailingCleanupPlugin,
                     :failing_cleanup_plugin,
                     %{}
                   )

          # Attempt to unload the plugin
          assert {:error, :cleanup_failed} =
                   Manager.unload_plugin(manager_pid, :failing_cleanup_plugin)
        end
      )
    end
  end
end
