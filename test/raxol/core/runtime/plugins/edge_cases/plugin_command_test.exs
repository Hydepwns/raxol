defmodule Raxol.Core.Runtime.Plugins.EdgeCases.PluginCommandTest do
  use ExUnit.Case
  import Mox

  alias Raxol.Test.PluginTestFixtures
  alias Raxol.Core.Runtime.Plugins.EdgeCases.Helper

  setup do
    Helper.setup_test()
  end

  describe "plugin command execution errors" do
    test "handles plugin command execution errors (BadReturnPlugin)", %{
      command_registry_table: table
    } do
      Helper.with_running_manager(
        [command_registry_table: table],
        fn manager_pid ->
          # Load BadReturnPlugin using the setup_plugin helper
          assert {:ok, _loaded_state} =
                   Helper.setup_plugin(
                     manager_pid,
                     PluginTestFixtures.BadReturnPlugin,
                     :bad_return_plugin,
                     %{}
                   )

          # Test command execution with proper error handling
          Helper.execute_command_and_verify(
            manager_pid,
            :bad_return_plugin,
            :bad_return_cmd,
            ["test_arg"],
            [
              {:error, {:unexpected_plugin_return, :unexpected_return}},
              {:error,
               {:command_error, :bad_return_plugin, :bad_return_cmd,
                :unexpected_return}},
              {:error, :command_failed}
            ],
            table
          )

          # Test input handler with proper error handling
          Helper.execute_command_and_verify(
            manager_pid,
            :bad_return_plugin,
            :handle_input,
            ["test_input"],
            [
              {:error, {:unexpected_plugin_return, :not_ok}},
              {:error,
               {:command_error, :bad_return_plugin, :handle_input, :not_ok}},
              {:error, :command_failed}
            ],
            table
          )

          # Test output handler with proper error handling
          Helper.execute_command_and_verify(
            manager_pid,
            :bad_return_plugin,
            :handle_output,
            ["test_output"],
            [
              {:error, {:unexpected_plugin_return, [:not, :a, :tuple]}},
              {:error,
               {:command_error, :bad_return_plugin, :handle_output,
                [:not, :a, :tuple]}},
              {:error, :command_failed}
            ],
            table
          )
        end
      )
    end

    test "handles plugin command not found", %{command_registry_table: table} do
      Helper.with_running_manager(
        [command_registry_table: table],
        fn manager_pid ->
          # Setup: Load TestPlugin using the helper
          assert {:ok, _loaded_state} =
                   Helper.setup_plugin(
                     manager_pid,
                     PluginTestFixtures.TestPlugin,
                     :test_plugin,
                     %{}
                   )

          Helper.execute_command_and_verify(
            manager_pid,
            :test_plugin,
            :non_existent_cmd,
            ["test_arg"],
            [
              {:error,
               {:command_error, :test_plugin, :non_existent_cmd, :not_found}},
              {:error, {:command_not_found, :test_plugin, :non_existent_cmd}},
              {:error, :command_not_found}
            ],
            table
          )
        end
      )
    end
  end
end
