defmodule Raxol.Core.Runtime.Plugins.CommandsTest do
  use ExUnit.Case, async: true
  import Raxol.TestHelpers

  alias Raxol.Core.Runtime.Plugins.{CommandHelper, CommandRegistry}
  alias Raxol.Core.Runtime.Plugins.Manager.State, as: ManagerState

  # Mock command handler for testing
  @moduledoc false
  defmodule TestCommandHandler do
    def execute(args, context) do
      # Return args and context to verify they were passed correctly
      {:ok, %{args: args, context: context}}
    end

    def execute_error(_args, _context) do
      {:error, "Command execution failed"}
    end

    def execute_crash(_args, _context) do
      raise "Command crashed"
    end
  end

  # --- Mocks ---
  @moduledoc false
  defmodule MockPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin
    def get_commands, do: [{:test_cmd, :handle_test_cmd, 1}]

    def handle_test_cmd(arg, state),
      do: {:ok, %{state | handled_arg: arg}, :test_ok}

    # Add other callbacks if needed by LifecycleHelper/Manager
    def init(_), do: {:ok, %{initial: true}}
    def terminate(_, state), do: state
  end

  @moduledoc false
  defmodule MockErrorPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin
    def get_commands, do: [{:error_cmd, :handle_error_cmd, 0}]

    def handle_error_cmd(state) do
      {:error, :test_failure, Map.put(state, :errored, true)}
    end

    def init(_), do: {:ok, %{initial: true}}
    def terminate(_, state), do: state
  end

  @moduledoc false
  defmodule MockCrashPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin
    def get_commands, do: [{:crash_cmd, :handle_crash_cmd, 0}]
    def handle_crash_cmd(_state), do: raise("Plugin Crashed!")
    def init(_), do: {:ok, %{initial: true}}
    def terminate(_, state), do: state
  end

  @moduledoc false
  defmodule MockMessagePlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin
    def get_commands, do: [{:msg_cmd, :handle_msg_cmd, 1}]

    def handle_msg_cmd(arg, state) do
      send(state.test_pid, {:handled, arg, state})
      {:noreply, Map.put(state, :msg_sent, true)}
    end

    def init(_), do: {:ok, %{test_pid: nil}}
    def terminate(_, state), do: state
  end

  # --- Setup ---
  setup _context do
    # Create ETS table for command registry
    table_name = :raxol_command_registry_test
    cleanup_ets_table(table_name)
    :ets.new(table_name, [:set, :public, :named_table, read_concurrency: true])
    on_exit(fn -> cleanup_ets_table(table_name) end)

    # Create a default mock plugin manager state
    manager_state = %ManagerState{
      plugins: %{},
      metadata: %{},
      plugin_states: %{},
      load_order: [],
      initialized: true,
      command_registry_table: table_name,
      plugin_config: %{},
      plugins_dir: "",
      file_watcher_pid: nil,
      file_watching_enabled?: false,
      file_event_timer: nil
    }

    {:ok, command_table: table_name, manager_state: manager_state}
  end

  # --- Tests ---
  describe "Command Registration" do
    test "register_plugin_commands adds commands to the registry", %{
      command_table: table
    } do
      # Register commands from MockPlugin
      CommandHelper.register_plugin_commands(MockPlugin, %{}, table)

      # Verify using CommandRegistry lookup
      assert {:ok, {MockPlugin, :handle_test_cmd, 1}} =
               CommandRegistry.lookup_command(table, MockPlugin, "test_cmd")
    end

    test "unregister_plugin_commands removes commands from the registry", %{
      command_table: table
    } do
      # Register first
      CommandHelper.register_plugin_commands(MockPlugin, %{}, table)

      assert {:ok, _} =
               CommandRegistry.lookup_command(table, MockPlugin, "test_cmd")

      # Then unregister
      CommandHelper.unregister_plugin_commands(table, MockPlugin)

      assert {:error, :not_found} =
               CommandRegistry.lookup_command(table, MockPlugin, "test_cmd")
    end

    test "register_plugin_commands handles empty command list", %{
      command_table: table
    } do
      # Create a plugin with no commands
      defmodule EmptyPlugin do
        @behaviour Raxol.Core.Runtime.Plugins.Plugin
        def get_commands, do: []
        def init(_), do: {:ok, %{}}
        def terminate(_, state), do: state
      end

      # Should not crash
      assert :ok = CommandHelper.register_plugin_commands(EmptyPlugin, %{}, table)
    end

    test "register_plugin_commands handles duplicate command names", %{
      command_table: table
    } do
      # Create two plugins with the same command name
      defmodule DuplicatePlugin1 do
        @behaviour Raxol.Core.Runtime.Plugins.Plugin
        def get_commands, do: [{:dupe_cmd, :handle_dupe_cmd, 1}]
        def handle_dupe_cmd(_arg, state), do: {:ok, state}
        def init(_), do: {:ok, %{}}
        def terminate(_, state), do: state
      end

      defmodule DuplicatePlugin2 do
        @behaviour Raxol.Core.Runtime.Plugins.Plugin
        def get_commands, do: [{:dupe_cmd, :handle_dupe_cmd, 1}]
        def handle_dupe_cmd(_arg, state), do: {:ok, state}
        def init(_), do: {:ok, %{}}
        def terminate(_, state), do: state
      end

      # Register first plugin
      assert :ok = CommandHelper.register_plugin_commands(DuplicatePlugin1, %{}, table)

      # Register second plugin - should overwrite first registration
      assert :ok = CommandHelper.register_plugin_commands(DuplicatePlugin2, %{}, table)

      # Verify only the second plugin's command is registered
      assert {:ok, {DuplicatePlugin2, :handle_dupe_cmd, 1}} =
               CommandRegistry.lookup_command(table, DuplicatePlugin2, "dupe_cmd")
    end

    test "register_plugin_commands handles invalid command specifications", %{
      command_table: table
    } do
      # Create a plugin with invalid command spec
      defmodule InvalidPlugin do
        @behaviour Raxol.Core.Runtime.Plugins.Plugin
        def get_commands, do: [{:invalid_cmd, :non_existent_function, 1}]
        def init(_), do: {:ok, %{}}
        def terminate(_, state), do: state
      end

      # Should handle gracefully
      assert :ok = CommandHelper.register_plugin_commands(InvalidPlugin, %{}, table)
    end

    test "register_plugin_commands validates command names", %{
      command_table: table
    } do
      # Create a plugin with invalid command names
      defmodule InvalidNamePlugin do
        @behaviour Raxol.Core.Runtime.Plugins.Plugin
        def get_commands, do: [
          {:invalid_name_with_spaces, :handle_cmd, 1},
          {:invalid@chars, :handle_cmd, 1},
          {:valid_cmd, :handle_cmd, 1}
        ]
        def handle_cmd(_arg, state), do: {:ok, state}
        def init(_), do: {:ok, %{}}
        def terminate(_, state), do: state
      end

      # Should only register the valid command
      assert :ok = CommandHelper.register_plugin_commands(InvalidNamePlugin, %{}, table)

      # Verify only valid command was registered
      assert {:ok, {InvalidNamePlugin, :handle_cmd, 1}} =
               CommandRegistry.lookup_command(table, InvalidNamePlugin, "valid_cmd")
      assert {:error, :not_found} =
               CommandRegistry.lookup_command(table, InvalidNamePlugin, "invalid_name_with_spaces")
      assert {:error, :not_found} =
               CommandRegistry.lookup_command(table, InvalidNamePlugin, "invalid@chars")
    end

    test "register_plugin_commands handles concurrent registration", %{
      command_table: table
    } do
      # Create two plugins that will register commands concurrently
      defmodule ConcurrentPlugin1 do
        @behaviour Raxol.Core.Runtime.Plugins.Plugin
        def get_commands, do: [{:concurrent_cmd, :handle_cmd, 1}]
        def handle_cmd(_arg, state), do: {:ok, state}
        def init(_), do: {:ok, %{}}
        def terminate(_, state), do: state
      end

      defmodule ConcurrentPlugin2 do
        @behaviour Raxol.Core.Runtime.Plugins.Plugin
        def get_commands, do: [{:concurrent_cmd, :handle_cmd, 1}]
        def handle_cmd(_arg, state), do: {:ok, state}
        def init(_), do: {:ok, %{}}
        def terminate(_, state), do: state
      end

      # Register commands concurrently
      tasks = [
        Task.async(fn -> CommandHelper.register_plugin_commands(ConcurrentPlugin1, %{}, table) end),
        Task.async(fn -> CommandHelper.register_plugin_commands(ConcurrentPlugin2, %{}, table) end)
      ]

      results = Task.await_many(tasks, 5000)
      assert Enum.all?(results, &(&1 == :ok))

      # Verify one of the plugins' command is registered (last writer wins)
      assert {:ok, {plugin, :handle_cmd, 1}} =
               CommandRegistry.lookup_command(table, ConcurrentPlugin1, "concurrent_cmd")
      assert plugin in [ConcurrentPlugin1, ConcurrentPlugin2]
    end
  end

  describe "Command Execution (handle_command)" do
    test "calls the command handler with args and state", %{
      command_table: table,
      manager_state: state
    } do
      plugin_id = "mock_message_plugin"
      initial_plugin_state = %{test_pid: self()}

      manager_state = %{
        state
        | plugins: %{plugin_id => MockMessagePlugin},
          plugin_states: %{plugin_id => initial_plugin_state}
      }

      # Register command
      CommandHelper.register_plugin_commands(
        MockMessagePlugin,
        initial_plugin_state,
        table
      )

      # Execute command
      args = ["hello_arg"]

      assert {:ok, updated_states} =
               CommandHelper.handle_command(
                 table,
                 "msg_cmd",
                 MockMessagePlugin,
                 args,
                 manager_state
               )

      # Assert message received by test process
      assert_receive {:handled, "hello_arg", ^initial_plugin_state}, 500

      # Assert plugin state was updated
      assert updated_states[plugin_id].msg_sent == true
    end

    test "returns :not_found for unknown command", %{
      command_table: table,
      manager_state: state
    } do
      assert :not_found =
               CommandHelper.handle_command(
                 table,
                 "unknown_cmd",
                 nil,
                 [],
                 state
               )
    end

    test "handles error results from command handler", %{
      command_table: table,
      manager_state: state
    } do
      plugin_id = "mock_error_plugin"
      initial_plugin_state = %{initial: true}

      manager_state = %{
        state
        | plugins: %{plugin_id => MockErrorPlugin},
          plugin_states: %{plugin_id => initial_plugin_state}
      }

      # Register command
      CommandHelper.register_plugin_commands(
        MockErrorPlugin,
        initial_plugin_state,
        table
      )

      # Execute command that returns an error
      assert {:error, :test_failure, updated_states} =
               CommandHelper.handle_command(
                 table,
                 "error_cmd",
                 MockErrorPlugin,
                 [],
                 manager_state
               )

      # Assert plugin state was updated within the error tuple
      assert updated_states[plugin_id].errored == true
    end

    test "handles exceptions in command handler", %{
      command_table: table,
      manager_state: state
    } do
      plugin_id = "mock_crash_plugin"
      initial_plugin_state = %{initial: true}

      manager_state = %{
        state
        | plugins: %{plugin_id => MockCrashPlugin},
          plugin_states: %{plugin_id => initial_plugin_state}
      }

      # Register command that crashes
      CommandHelper.register_plugin_commands(
        MockCrashPlugin,
        initial_plugin_state,
        table
      )

      # Execute command that crashes
      assert {:error, :exception, original_states} =
               CommandHelper.handle_command(
                 table,
                 "crash_cmd",
                 MockCrashPlugin,
                 [],
                 manager_state
               )

      # Assert original plugin states are returned on exception
      assert original_states == manager_state.plugin_states
    end

    test "handles command with invalid arguments", %{
      command_table: table,
      manager_state: state
    } do
      plugin_id = "mock_plugin"
      initial_plugin_state = %{initial: true}

      manager_state = %{
        state
        | plugins: %{plugin_id => MockPlugin},
          plugin_states: %{plugin_id => initial_plugin_state}
      }

      # Register command
      CommandHelper.register_plugin_commands(MockPlugin, initial_plugin_state, table)

      # Execute command with invalid args (nil)
      assert {:error, :invalid_args, _updated_states} =
               CommandHelper.handle_command(
                 table,
                 "test_cmd",
                 MockPlugin,
                 nil,
                 manager_state
               )
    end

    test "handles command with missing plugin state", %{
      command_table: table,
      manager_state: state
    } do
      plugin_id = "mock_plugin"

      # Create manager state without plugin state
      manager_state = %{
        state
        | plugins: %{plugin_id => MockPlugin},
          plugin_states: %{}
      }

      # Register command
      CommandHelper.register_plugin_commands(MockPlugin, %{}, table)

      # Execute command
      assert {:error, :missing_plugin_state, _updated_states} =
               CommandHelper.handle_command(
                 table,
                 "test_cmd",
                 MockPlugin,
                 ["arg"],
                 manager_state
               )
    end

    test "handles command with invalid plugin module", %{
      command_table: table,
      manager_state: state
    } do
      plugin_id = "invalid_plugin"
      initial_plugin_state = %{initial: true}

      manager_state = %{
        state
        | plugins: %{plugin_id => :invalid_module},
          plugin_states: %{plugin_id => initial_plugin_state}
      }

      # Execute command with invalid module
      assert {:error, :invalid_plugin_module, _updated_states} =
               CommandHelper.handle_command(
                 table,
                 "test_cmd",
                 :invalid_module,
                 ["arg"],
                 manager_state
               )
    end

    test "validates command arguments before execution", %{
      command_table: table,
      manager_state: state
    } do
      plugin_id = "mock_plugin"
      initial_plugin_state = %{initial: true}

      manager_state = %{
        state
        | plugins: %{plugin_id => MockPlugin},
          plugin_states: %{plugin_id => initial_plugin_state}
      }

      # Register command
      CommandHelper.register_plugin_commands(MockPlugin, initial_plugin_state, table)

      # Test various invalid argument types
      invalid_args = [
        nil,
        "not_a_list",
        %{not: "a_list"},
        {:not, "a_list"},
        [1, "string", %{not: "allowed"}]
      ]

      for args <- invalid_args do
        assert {:error, :invalid_args, _updated_states} =
                 CommandHelper.handle_command(
                   table,
                   "test_cmd",
                   MockPlugin,
                   args,
                   manager_state
                 )
      end
    end

    test "handles command execution timing", %{
      command_table: table,
      manager_state: state
    } do
      plugin_id = "mock_plugin"
      initial_plugin_state = %{initial: true}

      manager_state = %{
        state
        | plugins: %{plugin_id => MockPlugin},
          plugin_states: %{plugin_id => initial_plugin_state}
      }

      # Register command
      CommandHelper.register_plugin_commands(MockPlugin, initial_plugin_state, table)

      # Execute command and measure time
      start_time = System.monotonic_time()
      assert {:ok, _updated_states} =
               CommandHelper.handle_command(
                 table,
                 "test_cmd",
                 MockPlugin,
                 ["arg"],
                 manager_state
               )
      end_time = System.monotonic_time()

      # Verify execution time is reasonable (less than 100ms)
      execution_time = System.convert_time_unit(end_time - start_time, :native, :millisecond)
      assert execution_time < 100, "Command execution took #{execution_time}ms"
    end

    test "handles command cancellation", %{
      command_table: table,
      manager_state: state
    } do
      plugin_id = "mock_plugin"
      initial_plugin_state = %{initial: true}

      manager_state = %{
        state
        | plugins: %{plugin_id => MockPlugin},
          plugin_states: %{plugin_id => initial_plugin_state}
      }

      # Register command
      CommandHelper.register_plugin_commands(MockPlugin, initial_plugin_state, table)

      # Start command execution in a separate process
      task = Task.async(fn ->
        CommandHelper.handle_command(
          table,
          "test_cmd",
          MockPlugin,
          ["arg"],
          manager_state
        )
      end)

      # Cancel the command execution
      Task.shutdown(task, :brutal_kill)

      # Verify the command was cancelled
      assert {:exit, :killed} = Task.await(task, 100)
    end
  end
end
