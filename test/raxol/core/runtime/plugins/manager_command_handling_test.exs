defmodule Raxol.Core.Runtime.Plugins.ManagerCommandHandlingTest do
  use ExUnit.Case, async: true
  # No Mox needed if using meck for CommandHelper

  # --- Aliases ---
  alias Raxol.Core.Runtime.Plugins.Manager
  alias Raxol.Core.Runtime.Plugins.{CommandHelper, CommandRegistry}

  # --- Setup & Teardown ---
  setup %{test: test_name} do
    # Setup meck for CommandHelper
    :meck.new(CommandHelper, [:passthrough])
    on_exit(fn -> :meck.unload(CommandHelper) end)

    # Unique ETS table for command registry
    table_name = :"#{test_name}_CmdHandlingReg"
    :ets.new(table_name, [:set, :public, :named_table, read_concurrency: true])
    on_exit(fn -> :ets.delete(table_name) end)

    # Minimal start options for manager, focusing on command handling
    start_opts = [
      name: :"#{test_name}_PluginManagerCmdHandling",
      command_registry_table: table_name,
      # Inject the real CommandHelper (which we are mecking)
      command_helper_module: CommandHelper
      # No plugin dirs or other mocks needed if just testing delegation
    ]

    {:ok, pid} = Manager.start_link(start_opts)

    on_exit(fn ->
      if Process.alive?(pid), do: Supervisor.stop(pid, :shutdown, :infinity)
    end)

    {:ok, manager: pid, table: table_name}
  end

  # --- Command Handling Test Cases ---
  describe "Command Handling" do
    test "handle_cast :handle_command delegates to CommandHelper", %{manager: manager, table: table} do
      command_name = "my_plugin:do_thing"
      command_args = [1, 2]

      # Get the internal state required by CommandHelper (might be empty in this minimal setup)
      # Or assume the mecked function doesn't rely on accurate state
      plugins = GenServer.call(manager, :get_plugins) # Assuming API exists
      plugin_states = GenServer.call(manager, :get_plugin_states) # Assuming API exists

      # Expect CommandHelper.handle_command to be called
      :meck.expect(CommandHelper, :handle_command, fn ^command_name, ^command_args, ^table, ^plugins, ^plugin_states ->
        send(self(), {:command_helper_called, table})
        {:ok, %{}} # Simulate successful handling
      end)

      # Cast the command to the manager
      GenServer.cast(manager, {:handle_command, command_name, command_args})

      # Assert that CommandHelper was called with the correct table
      assert_received {:command_helper_called, ^table}
      :meck.verify(CommandHelper)
    end

    # Add more tests here if Manager does more complex command routing
    # e.g., handling specific internal commands before delegating

  end
end
