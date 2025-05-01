defmodule Raxol.Core.Runtime.Plugins.CommandsTest do
  use ExUnit.Case, async: true

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
    def handle_test_cmd(arg, state), do: {:ok, %{state | handled_arg: arg}, :test_ok}
    # Add other callbacks if needed by LifecycleHelper/Manager
    def init(_), do: {:ok, %{initial: true}}
    def terminate(_, state), do: state
  end

  @moduledoc false
  defmodule MockErrorPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin
    def get_commands, do: [{:error_cmd, :handle_error_cmd, 0}]
    def handle_error_cmd(state), do: {:error, :test_failure, %{state | errored: true}}
    def init(_), do: {:ok, %{initial: true}}
    def terminate(_, state), do: state
  end

  @moduledoc false
  defmodule MockCrashPlugin do
     @behaviour Raxol.Core.Runtime.Plugins.Plugin
    def get_commands, do: [{:crash_cmd, :handle_crash_cmd, 0}]
    def handle_crash_cmd(_state), do: raise "Plugin Crashed!"
    def init(_), do: {:ok, %{initial: true}}
    def terminate(_, state), do: state
  end

  @moduledoc false
  defmodule MockMessagePlugin do
     @behaviour Raxol.Core.Runtime.Plugins.Plugin
    def get_commands, do: [{:msg_cmd, :handle_msg_cmd, 1}]
    # Sends message back to caller (test process)
    def handle_msg_cmd(arg, state) do
      send(state.test_pid, {:handled, arg, state})
      {:noreply, %{state | msg_sent: true}}
    end
    def init(_), do: {:ok, %{test_pid: nil}} # test_pid will be set in state
    def terminate(_, state), do: state
  end

  # --- Setup ---
  setup context do
    # Create ETS table for command registry
    table_name = context.command_table || :raxol_command_registry
    try do
      :ets.delete(table_name)
    rescue
      ArgumentError -> :ok # Ignore if table doesn't exist
    end
    :ets.new(table_name, [:set, :public, :named_table, read_concurrency: true])

    # Create a mock plugin manager state
    manager_state = context.manager_state || %ManagerState{
      plugins: %{}, # Populated per test
      metadata: %{},
      plugin_states: %{}, # Populated per test
      load_order: [],
      initialized: true,
      command_registry_table: table_name,
      plugin_config: %{},
      plugins_dir: "",
      file_watcher_pid: nil,
      file_watching_enabled?: false,
      file_event_timer: nil
    }

    on_exit(fn ->
      try do
        :ets.delete(table_name)
      rescue
        ArgumentError -> :ok # Ignore if already deleted
      end
    end)

    {:ok, command_table: table_name, manager_state: manager_state}
  end

  # --- Tests ---
  describe "Command Registration" do
    test "register_plugin_commands adds commands to the registry", %{command_table: table} do
      # Register commands from MockPlugin
      CommandHelper.register_plugin_commands(MockPlugin, %{}, table)

      # Verify using CommandRegistry lookup
      assert {:ok, {MockPlugin, :handle_test_cmd, 1}} = CommandRegistry.lookup_command(table, "test_cmd", MockPlugin)
    end

    test "unregister_plugin_commands removes commands from the registry", %{command_table: table} do
      # Register first
      CommandHelper.register_plugin_commands(MockPlugin, %{}, table)
      assert {:ok, _} = CommandRegistry.lookup_command(table, "test_cmd", MockPlugin)

      # Then unregister
      CommandHelper.unregister_plugin_commands(table, MockPlugin)
      assert {:error, :not_found} = CommandRegistry.lookup_command(table, "test_cmd", MockPlugin)
    end
  end

  describe "Command Execution (handle_command)" do
    test "calls the command handler with args and state", %{command_table: table, manager_state: state} do
      plugin_id = "mock_message_plugin"
      initial_plugin_state = %{test_pid: self()}
      manager_state = %{
        state |
        plugins: %{plugin_id => MockMessagePlugin},
        plugin_states: %{plugin_id => initial_plugin_state}
      }

      # Register command
      CommandHelper.register_plugin_commands(MockMessagePlugin, initial_plugin_state, table)

      # Execute command
      args = ["hello_arg"]
      assert {:ok, updated_states} = CommandHelper.handle_command(table, "msg_cmd", MockMessagePlugin, args, manager_state)

      # Assert message received by test process
      assert_receive {:handled, "hello_arg", ^initial_plugin_state}, 500

      # Assert plugin state was updated
      assert updated_states[plugin_id].msg_sent == true
    end

    test "returns :not_found for unknown command", %{command_table: table, manager_state: state} do
      assert :not_found = CommandHelper.handle_command(table, "unknown_cmd", nil, [], state)
    end

    test "handles error results from command handler", %{command_table: table, manager_state: state} do
      plugin_id = "mock_error_plugin"
      initial_plugin_state = %{initial: true}
      manager_state = %{
        state |
        plugins: %{plugin_id => MockErrorPlugin},
        plugin_states: %{plugin_id => initial_plugin_state}
      }

      # Register command
      CommandHelper.register_plugin_commands(MockErrorPlugin, initial_plugin_state, table)

      # Execute command that returns an error
      assert {:error, :test_failure, updated_states} = CommandHelper.handle_command(table, "error_cmd", MockErrorPlugin, [], manager_state)

      # Assert plugin state was updated within the error tuple
      assert updated_states[plugin_id].errored == true
    end

    test "handles exceptions in command handler", %{command_table: table, manager_state: state} do
      plugin_id = "mock_crash_plugin"
      initial_plugin_state = %{initial: true}
      manager_state = %{
        state |
        plugins: %{plugin_id => MockCrashPlugin},
        plugin_states: %{plugin_id => initial_plugin_state}
      }

      # Register command that crashes
      CommandHelper.register_plugin_commands(MockCrashPlugin, initial_plugin_state, table)

      # Execute command that crashes
      assert {:error, :exception, original_states} = CommandHelper.handle_command(table, "crash_cmd", MockCrashPlugin, [], manager_state)

      # Assert original plugin states are returned on exception
      assert original_states == manager_state.plugin_states
    end
  end
end
