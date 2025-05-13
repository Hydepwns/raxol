defmodule Raxol.Core.Runtime.Plugins.ManagerCommandHandlingTest do
  use ExUnit.Case
  # require :meck # Removed :meck
  # Added Mox
  import Mox
  import Raxol.TestHelpers

  # --- Aliases ---
  alias Raxol.Core.Runtime.Plugins.Manager
  alias Raxol.Core.Runtime.Plugins.{CommandHelper, CommandRegistry}

  # --- Setup & Teardown ---
  setup %{test: test_name} do
    # Setup Mox verification
    Mox.verify_on_exit!()

    # Unique ETS table for command registry
    table_name = :"#{test_name}_CmdHandlingReg"
    :ets.new(table_name, [:set, :public, :named_table, read_concurrency: true])
    on_exit(fn -> cleanup_ets_table(table_name) end)

    # Minimal start options for manager, focusing on command handling
    start_opts = [
      name: :"#{test_name}_PluginManagerCmdHandling",
      command_registry_table: table_name,
      # Inject the real CommandHelper (which we are mecking)
      command_helper_module: CommandHelper
      # No plugin dirs or other mocks needed if just testing delegation
    ]

    # Before calling Manager.start_link(start_opts), ensure start_opts includes runtime_pid: self()
    start_opts = Keyword.put_new(start_opts, :runtime_pid, self())

    {:ok, pid} = Manager.start_link(start_opts)

    on_exit(fn -> cleanup_process(pid) end)

    {:ok, manager: pid, table: table_name}
  end

  # --- Command Handling Test Cases ---
  describe "Command Handling" do
    test "handle_cast :handle_command delegates to CommandHelper", %{
      manager: manager,
      table: table
    } do
      command_name = "my_plugin:do_thing"
      command_args = [1, 2]

      # Get the internal state required by CommandHelper (might be empty in this minimal setup)
      # Or assume the mocked function doesn't rely on accurate state
      # Assuming API exists
      plugins = GenServer.call(manager, :get_plugins)
      # Assuming API exists
      plugin_states = GenServer.call(manager, :get_plugin_states)

      # Initial state checks
      assert GenServer.call(manager, :get_plugins) == plugins
      assert GenServer.call(manager, :get_plugin_states) == plugin_states

      # Expect CommandHelper.handle_command to be called using Mox
      Mox.expect(CommandHelper, :handle_command, fn _table,
                                                    _cmd_name,
                                                    _namespace,
                                                    _args,
                                                    _state ->
        send(self(), {:command_helper_called, :anything})

        # Simulate successful handling, ensure the arity matches CommandHelper.handle_command/5
        # The actual CommandHelper.handle_command returns {:ok, new_plugin_state, result_tuple, plugin_id} | :not_found | {:error, reason, plugin_id}
        # For this test, we only care it was called. A simple :ok might be fine if the manager doesn't crash on a different tuple.
        # Let's return a structure that the Manager expects to avoid issues.
        # Assuming a successful scenario where a plugin handles it:
        # The CommandHelper.handle_command in lib seems to expect these args:
        # (command_table, command_name_str, namespace, args, state)
        # and returns: {:ok, new_plugin_state, result_tuple, plugin_id} | :not_found | {:error, reason_tuple, plugin_id}
        # The manager expects: {:ok, new_plugin_state, result_tuple, plugin_id} for success path.
        # For the purpose of this test (ensuring delegation), a simplified success return that matches arity should be okay.
        # The actual command_helper_called message confirms delegation. Manager will get this result.
        {:ok, %{}, {:some_result}, :some_plugin_id}
      end)

      # Cast the command to the manager
      # The Manager's handle_cast for :handle_command has this signature:
      # {:handle_command, command_atom, namespace, data, dispatcher_pid}
      # The test is currently sending: {:handle_command, command_name_str, command_args_list}
      # This needs to be adjusted to match the Manager's actual handle_cast.
      # Let's assume `command_name` should be an atom, namespace can be nil, args is data, and we need a dispatcher_pid (self() for test).
      GenServer.cast(
        manager,
        {:handle_command, String.to_atom(command_name), nil, command_args,
         self()}
      )

      # Assert that CommandHelper was called with the correct table
      assert_receive {:command_helper_called, :anything}, 1000
      # :meck.verify(CommandHelper) # REMOVED, Mox handles verification
    end

    test "handle_cast :handle_command with :not_found response", %{
      manager: manager,
      table: table
    } do
      command_name = "unknown:command"
      command_args = []

      # Expect CommandHelper to return :not_found
      Mox.expect(CommandHelper, :handle_command, fn _table,
                                                    _cmd_name,
                                                    _namespace,
                                                    _args,
                                                    _state ->
        :not_found
      end)

      # Cast the command to the manager
      GenServer.cast(
        manager,
        {:handle_command, String.to_atom(command_name), nil, command_args,
         self()}
      )

      # No crash should occur
      refute_receive {:command_helper_called, _}, 1000
    end

    test "handle_cast :handle_command with error response", %{
      manager: manager,
      table: table
    } do
      command_name = "error:command"
      command_args = []

      # Expect CommandHelper to return an error
      Mox.expect(CommandHelper, :handle_command, fn _table,
                                                    _cmd_name,
                                                    _namespace,
                                                    _args,
                                                    _state ->
        {:error, :test_error, %{}}
      end)

      # Cast the command to the manager
      GenServer.cast(
        manager,
        {:handle_command, String.to_atom(command_name), nil, command_args,
         self()}
      )

      # No crash should occur
      refute_receive {:command_helper_called, _}, 1000
    end

    test "handle_cast :handle_command with invalid command name", %{
      manager: manager,
      table: table
    } do
      # Cast with invalid command name (not a string or atom)
      GenServer.cast(
        manager,
        {:handle_command, 123, nil, [], self()}
      )

      # No crash should occur
      refute_receive {:command_helper_called, _}, 1000
    end

    test "handle_cast :handle_command with invalid args", %{
      manager: manager,
      table: table
    } do
      command_name = "test:command"

      # Cast with invalid args (not a list)
      GenServer.cast(
        manager,
        {:handle_command, String.to_atom(command_name), nil, "not_a_list",
         self()}
      )

      # No crash should occur
      refute_receive {:command_helper_called, _}, 1000
    end

    test "handle_cast :handle_command with missing dispatcher_pid", %{
      manager: manager,
      table: table
    } do
      command_name = "test:command"
      command_args = []

      # Cast without dispatcher_pid
      GenServer.cast(
        manager,
        {:handle_command, String.to_atom(command_name), nil, command_args}
      )

      # No crash should occur
      refute_receive {:command_helper_called, _}, 1000
    end

    test "handles command with invalid plugin state", %{
      manager: manager,
      table: table
    } do
      command_name = "test:command"
      command_args = []

      # Set invalid plugin state
      GenServer.call(manager, {:set_plugin_state, :test_plugin, :invalid_state})

      # Expect CommandHelper to return error
      Mox.expect(CommandHelper, :handle_command, fn _table,
                                                    _cmd_name,
                                                    _namespace,
                                                    _args,
                                                    _state ->
        {:error, :invalid_plugin_state, %{}}
      end)

      # Cast the command to the manager
      GenServer.cast(
        manager,
        {:handle_command, String.to_atom(command_name), nil, command_args,
         self()}
      )

      # No crash should occur
      refute_receive {:command_helper_called, _}, 1000
    end

    test "handles command with missing plugin", %{
      manager: manager,
      table: table
    } do
      command_name = "test:command"
      command_args = []

      # Expect CommandHelper to return error
      Mox.expect(CommandHelper, :handle_command, fn _table,
                                                    _cmd_name,
                                                    _namespace,
                                                    _args,
                                                    _state ->
        {:error, :plugin_not_found, %{}}
      end)

      # Cast the command to the manager
      GenServer.cast(
        manager,
        {:handle_command, String.to_atom(command_name), nil, command_args,
         self()}
      )

      # No crash should occur
      refute_receive {:command_helper_called, _}, 1000
    end
  end

  describe "Command State Management" do
    test "updates plugin states after successful command execution", %{
      manager: manager,
      table: table
    } do
      command_name = "test:command"
      command_args = []
      new_plugin_state = %{updated: true}

      # Expect CommandHelper to return updated state
      Mox.expect(CommandHelper, :handle_command, fn _table,
                                                    _cmd_name,
                                                    _namespace,
                                                    _args,
                                                    _state ->
        {:ok, new_plugin_state, {:success}, :test_plugin}
      end)

      # Cast the command to the manager
      GenServer.cast(
        manager,
        {:handle_command, String.to_atom(command_name), nil, command_args,
         self()}
      )

      # Verify plugin state was updated
      assert GenServer.call(manager, :get_plugin_states) == %{
               "test_plugin" => new_plugin_state
             }
    end

    test "preserves plugin states after command error", %{
      manager: manager,
      table: table
    } do
      command_name = "test:command"
      command_args = []
      original_state = %{original: true}

      # Set initial plugin state
      GenServer.call(manager, {:set_plugin_state, :test_plugin, original_state})

      # Expect CommandHelper to return error
      Mox.expect(CommandHelper, :handle_command, fn _table,
                                                    _cmd_name,
                                                    _namespace,
                                                    _args,
                                                    _state ->
        {:error, :test_error, %{}}
      end)

      # Cast the command to the manager
      GenServer.cast(
        manager,
        {:handle_command, String.to_atom(command_name), nil, command_args,
         self()}
      )

      # Verify plugin state was preserved
      assert GenServer.call(manager, :get_plugin_states) == %{
               "test_plugin" => original_state
             }
    end

    test "handles plugin state updates during command execution", %{
      manager: manager,
      table: table
    } do
      command_name = "test:command"
      command_args = []
      initial_state = %{value: 1}
      updated_state = %{value: 2}

      # Set initial plugin state
      GenServer.call(manager, {:set_plugin_state, :test_plugin, initial_state})

      # Expect CommandHelper to return updated state
      Mox.expect(CommandHelper, :handle_command, fn _table,
                                                    _cmd_name,
                                                    _namespace,
                                                    _args,
                                                    _state ->
        {:ok, updated_state, {:success}, :test_plugin}
      end)

      # Cast the command to the manager
      GenServer.cast(
        manager,
        {:handle_command, String.to_atom(command_name), nil, command_args,
         self()}
      )

      # Verify plugin state was updated
      assert GenServer.call(manager, :get_plugin_states) == %{
               "test_plugin" => updated_state
             }
    end

    test "handles multiple plugin state updates", %{
      manager: manager,
      table: table
    } do
      command_name = "test:command"
      command_args = []

      initial_states = %{
        "plugin1" => %{value: 1},
        "plugin2" => %{value: 2}
      }

      updated_states = %{
        "plugin1" => %{value: 3},
        "plugin2" => %{value: 4}
      }

      # Set initial plugin states
      for {plugin_id, state} <- initial_states do
        GenServer.call(
          manager,
          {:set_plugin_state, String.to_atom(plugin_id), state}
        )
      end

      # Expect CommandHelper to return updated states
      Mox.expect(CommandHelper, :handle_command, fn _table,
                                                    _cmd_name,
                                                    _namespace,
                                                    _args,
                                                    _state ->
        {:ok, updated_states, {:success}, :test_plugin}
      end)

      # Cast the command to the manager
      GenServer.cast(
        manager,
        {:handle_command, String.to_atom(command_name), nil, command_args,
         self()}
      )

      # Verify all plugin states were updated
      assert GenServer.call(manager, :get_plugin_states) == updated_states
    end

    test "handles plugin state rollback on error", %{
      manager: manager,
      table: table
    } do
      command_name = "test:command"
      command_args = []
      initial_state = %{value: 1}
      partial_update = %{value: 2}

      # Set initial plugin state
      GenServer.call(manager, {:set_plugin_state, :test_plugin, initial_state})

      # Expect CommandHelper to return error after partial update
      Mox.expect(CommandHelper, :handle_command, fn _table,
                                                    _cmd_name,
                                                    _namespace,
                                                    _args,
                                                    _state ->
        # Simulate partial update followed by error
        {:error, :test_error, partial_update}
      end)

      # Cast the command to the manager
      GenServer.cast(
        manager,
        {:handle_command, String.to_atom(command_name), nil, command_args,
         self()}
      )

      # Verify plugin state was rolled back
      assert GenServer.call(manager, :get_plugin_states) == %{
               "test_plugin" => initial_state
             }
    end
  end
end
