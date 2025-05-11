defmodule Raxol.Core.Runtime.Plugins.CommandRegistryTest do
  use ExUnit.Case
  import Mox
  alias Raxol.Core.Runtime.Plugins.CommandRegistry

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  # Define mock for TestPlugin
  defmock(TestPlugin, for: Raxol.Plugin)

  setup do
    # Setup test plugin and command table
    plugin_module = TestPlugin
    plugin_state = %{counter: 0}
    command_table = %{}

    # Setup default command responses
    expect(TestPlugin, :commands, fn ->
      [
        {"test_command", fn args, _ctx -> {:ok, args} end, %{description: "Test command"}},
        {"slow_command", fn _args, _ctx ->
          Process.sleep(6000)
          {:ok, :timeout}
        end, %{timeout: 1000}},
        {"error_command", fn _args, _ctx ->
          raise "Test error"
        end, %{description: "Error command"}}
      ]
    end)

    %{
      plugin_module: plugin_module,
      plugin_state: plugin_state,
      command_table: command_table
    }
  end

  describe "register_plugin_commands/3" do
    test "successfully registers valid commands", %{
      plugin_module: plugin_module,
      plugin_state: plugin_state,
      command_table: command_table
    } do
      assert {:ok, updated_table} = CommandRegistry.register_plugin_commands(
        plugin_module, plugin_state, command_table
      )

      # Verify commands were registered
      assert Map.has_key?(updated_table, plugin_module)
      assert length(updated_table[plugin_module]) == 3
    end

    test "handles invalid command name", %{
      plugin_module: plugin_module,
      plugin_state: plugin_state,
      command_table: command_table
    } do
      # Mock plugin with invalid command name
      expect(TestPlugin, :commands, fn ->
        [{"invalid@command", fn args, _ctx -> {:ok, args} end, %{}}]
      end)

      assert {:error, :invalid_command_name_format} = CommandRegistry.register_plugin_commands(
        plugin_module, plugin_state, command_table
      )
    end

    test "handles invalid command handler", %{
      plugin_module: plugin_module,
      plugin_state: plugin_state,
      command_table: command_table
    } do
      # Mock plugin with invalid handler
      expect(TestPlugin, :commands, fn ->
        [{"test_command", fn -> :ok end, %{}}]
      end)

      assert {:error, :invalid_command_handler} = CommandRegistry.register_plugin_commands(
        plugin_module, plugin_state, command_table
      )
    end

    test "handles invalid metadata", %{
      plugin_module: plugin_module,
      plugin_state: plugin_state,
      command_table: command_table
    } do
      # Mock plugin with invalid metadata
      expect(TestPlugin, :commands, fn ->
        [{"test_command", fn args, _ctx -> {:ok, args} end, %{invalid: :field}}]
      end)

      assert {:error, :invalid_metadata_fields} = CommandRegistry.register_plugin_commands(
        plugin_module, plugin_state, command_table
      )
    end

    test "handles command conflicts", %{
      plugin_module: plugin_module,
      plugin_state: plugin_state,
      command_table: command_table
    } do
      # Setup existing command
      command_table = Map.put(command_table, :other_plugin, [
        {"test_command", fn args, _ctx -> {:ok, args} end, %{}}
      ])

      assert {:error, {:command_exists, "test_command"}} = CommandRegistry.register_plugin_commands(
        plugin_module, plugin_state, command_table
      )
    end
  end

  describe "execute_command/3" do
    test "successfully executes command", %{
      plugin_module: plugin_module,
      plugin_state: plugin_state,
      command_table: command_table
    } do
      # Register test command
      {:ok, command_table} = CommandRegistry.register_plugin_commands(
        plugin_module,
        plugin_state,
        command_table
      )

      assert {:ok, %{test: true}} = CommandRegistry.execute_command(
        "test_command",
        %{test: true},
        command_table
      )
    end

    test "handles command timeout", %{
      plugin_module: plugin_module,
      plugin_state: plugin_state,
      command_table: command_table
    } do
      # Register command with timeout
      {:ok, command_table} = CommandRegistry.register_plugin_commands(
        plugin_module,
        plugin_state,
        command_table
      )

      assert {:error, :command_timeout} = CommandRegistry.execute_command(
        "slow_command",
        %{},
        command_table
      )
    end

    test "handles command not found", %{
      command_table: command_table
    } do
      assert {:error, :command_not_found} = CommandRegistry.execute_command(
        "non_existent_command",
        %{},
        command_table
      )
    end

    test "handles execution error", %{
      plugin_module: plugin_module,
      plugin_state: plugin_state,
      command_table: command_table
    } do
      # Register command that raises error
      {:ok, command_table} = CommandRegistry.register_plugin_commands(
        plugin_module,
        plugin_state,
        command_table
      )

      assert {:error, {:execution_failed, "Test error"}} = CommandRegistry.execute_command(
        "error_command",
        %{},
        command_table
      )
    end
  end

  describe "unregister_plugin_commands/2" do
    test "successfully unregisters plugin commands", %{
      plugin_module: plugin_module,
      plugin_state: plugin_state,
      command_table: command_table
    } do
      # Register commands first
      {:ok, command_table} = CommandRegistry.register_plugin_commands(
        plugin_module,
        plugin_state,
        command_table
      )

      assert {:ok, updated_table} = CommandRegistry.unregister_plugin_commands(
        plugin_module,
        command_table
      )

      # Verify commands were unregistered
      refute Map.has_key?(updated_table, plugin_module)
    end

    test "handles non-existent plugin", %{
      command_table: command_table
    } do
      assert :ok = CommandRegistry.unregister_plugin_commands(
        :non_existent_plugin,
        command_table
      )
    end
  end
end
