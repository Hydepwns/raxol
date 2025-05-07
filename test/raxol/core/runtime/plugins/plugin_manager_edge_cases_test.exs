defmodule Raxol.Core.Runtime.Plugins.PluginManagerEdgeCasesTest do
  use ExUnit.Case, async: false
  require Logger

  alias Raxol.Core.Events.Event
  alias Raxol.Core.Runtime.Plugins.{Manager, Loader, LifecycleHelper, CommandRegistry}

  # Test plugin module that implements the required behaviours
  defmodule TestPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin

    def init(opts) do
      {:ok, %{
        name: "test_plugin",
        enabled: true,
        version: "1.0.0",
        options: opts,
        event_count: 0,
        crash_on: nil
      }}
    end

    def terminate(_reason, state) do
      # Return state to verify it was called with the correct state
      state
    end

    def get_commands do
      [
        {:test_cmd, :handle_test_cmd, 1},
        {:crash_cmd, :handle_crash_cmd, 0}
      ]
    end

    def handle_test_cmd(arg, state) do
      new_state = Map.put(state, :last_arg, arg)
      {:ok, new_state, {:result, arg}}
    end

    def handle_crash_cmd(state) do
      raise "Intentional crash in TestPlugin.handle_crash_cmd"
    end

    def handle_input(input, state) do
      if state.crash_on == :input do
        raise "Intentional crash in handle_input"
      else
        new_state = %{state | event_count: state.event_count + 1, last_input: input}
        {:ok, new_state}
      end
    end

    def handle_output(output, state) do
      if state.crash_on == :output do
        raise "Intentional crash in handle_output"
      else
        new_state = %{state | event_count: state.event_count + 1, last_output: output}
        {:ok, new_state, "Modified: #{output}"}
      end
    end

    def handle_mouse(event, state) do
      if state.crash_on == :mouse do
        raise "Intentional crash in handle_mouse"
      else
        new_state = %{state | event_count: state.event_count + 1, last_mouse: event}
        {:ok, new_state}
      end
    end

    def handle_placeholder(tag, content, options, state) do
      if state.crash_on == :placeholder do
        raise "Intentional crash in handle_placeholder"
      else
        new_state = %{state | event_count: state.event_count + 1, last_placeholder: {tag, content, options}}
        {:ok, new_state, "Rendered: #{tag} - #{content}"}
      end
    end
  end

  # Broken plugin that fails to implement required functions
  defmodule BrokenPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin

    def init(_opts), do: {:ok, %{}}
    def terminate(_reason, state), do: state
    def get_commands, do: [{:broken_cmd, :handle_broken_cmd, 1}]

    # Missing implementation of handle_broken_cmd/2
  end

  # Plugin with bad return values
  defmodule BadReturnPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin

    def init(_opts), do: {:ok, %{}}
    def terminate(_reason, state), do: state
    def get_commands, do: [{:bad_return_cmd, :handle_bad_return_cmd, 1}]

    def handle_bad_return_cmd(_arg, state) do
      # Return wrong format
      :unexpected_return
    end

    def handle_input(_input, state) do
      # Wrong return format
      :not_ok
    end

    def handle_output(_output, state) do
      # Wrong return format
      [:not, :a, :tuple]
    end
  end

  # Plugin with invalid dependencies
  defmodule DependentPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

    def init(_opts), do: {:ok, %{}}
    def terminate(_reason, state), do: state
    def get_commands, do: []

    def id, do: :dependent_plugin
    def version, do: "1.0.0"
    def dependencies, do: [{:missing_plugin, ">= 1.0.0"}]

    def metadata do
      %{
        id: :dependent_plugin,
        version: "1.0.0",
        dependencies: [{:missing_plugin, ">= 1.0.0"}]
      }
    end
  end

  setup do
    # We'll mock the modules that PluginManager depends on
    :meck.new(Loader, [:passthrough])
    :meck.new(LifecycleHelper, [:passthrough])
    :meck.new(CommandRegistry, [:passthrough])

    # Create ETS table for command registry
    :ets.new(:raxol_command_registry, [:set, :public, :named_table, read_concurrency: true])

    on_exit(fn ->
      :meck.unload(Loader)
      :meck.unload(LifecycleHelper)
      :meck.unload(CommandRegistry)

      # Clean up ETS table if it exists
      try do
        :ets.delete(:raxol_command_registry)
      rescue
        ArgumentError -> :ok
      end
    end)

    :ok
  end

  describe "plugin loading errors" do
    test "handles plugin init failure gracefully" do
      # Setup: Plugin init will fail
      :meck.expect(LifecycleHelper, :init_plugin, fn
        TestPlugin, _opts -> {:error, :init_failed}
        _, _ -> {:ok, %{}} # Default case
      end)

      # Execute: Start Manager and try to load the plugin
      {:ok, pid} = Manager.start_link([])
      {:error, reason} = Manager.load_plugin(pid, TestPlugin)

      # Verify: Manager should report the init failure
      assert reason == :init_failed

      # Verify: Manager is still functioning
      assert Process.alive?(pid)

      # Cleanup
      if Process.alive?(pid), do: GenServer.stop(pid)
    end

    test "handles plugin module loading errors" do
      # Setup: Loader will fail to load the module
      :meck.expect(Loader, :load_plugin_module, fn
        TestPlugin -> {:error, :not_found}
        _ -> {:ok, nil} # Default case
      end)

      # Execute: Start Manager and try to load the plugin
      {:ok, pid} = Manager.start_link([])
      {:error, reason} = Manager.load_plugin(pid, TestPlugin)

      # Verify: Manager should report the loading failure
      assert reason == :not_found

      # Verify: Manager is still functioning
      assert Process.alive?(pid)

      # Cleanup
      if Process.alive?(pid), do: GenServer.stop(pid)
    end

    test "handles dependency resolution failures" do
      # Setup: LifecycleHelper will check dependencies
      :meck.expect(LifecycleHelper, :check_dependencies, fn
        [{:missing_plugin, ">= 1.0.0"}], _available_plugins ->
          {:error, :dependency_not_found, :missing_plugin}
        _, _ -> {:ok} # Default case
      end)

      # Execute: Start Manager and try to load the plugin with dependencies
      {:ok, pid} = Manager.start_link([])

      # Expect Loader to return the dependencies
      :meck.expect(Loader, :load_plugin_metadata, fn
        DependentPlugin ->
          {:ok, DependentPlugin}
      end)

      {:error, reason, missing} = Manager.load_plugin(pid, DependentPlugin)

      # Verify: Manager should report the dependency failure
      assert reason == :dependency_not_found
      assert missing == :missing_plugin

      # Verify: Manager is still functioning
      assert Process.alive?(pid)

      # Cleanup
      if Process.alive?(pid), do: GenServer.stop(pid)
    end
  end

  describe "command handling edge cases" do
    test "handles missing command handlers" do
      # Setup: Prepare manager with broken plugin
      {:ok, pid} = Manager.start_link([])

      # Allow the plugin to load, but it will be broken
      :meck.expect(LifecycleHelper, :init_plugin, fn BrokenPlugin, _opts ->
        {:ok, %{broken: true}}
      end)

      {:ok, _} = Manager.load_plugin(pid, BrokenPlugin)

      # Execute: Try to execute a command from the broken plugin
      result = Manager.execute_command(pid, :broken_cmd, ["test"])

      # Verify: Should handle the missing function gracefully
      assert {:error, :handler_not_found} = result

      # Verify: Manager is still alive
      assert Process.alive?(pid)

      # Cleanup
      if Process.alive?(pid), do: GenServer.stop(pid)
    end

    test "handles command handler crashes" do
      # Setup: Prepare manager with test plugin
      {:ok, pid} = Manager.start_link([])

      # Allow the plugin to load
      :meck.expect(LifecycleHelper, :init_plugin, fn TestPlugin, _opts ->
        {:ok, %{name: "test_plugin", enabled: true}}
      end)

      {:ok, _} = Manager.load_plugin(pid, TestPlugin)

      # Execute: Try to execute a command that will crash
      result = Manager.execute_command(pid, :crash_cmd, [])

      # Verify: Should handle the crash gracefully
      assert {:error, :execution_failed} = result

      # Verify: Manager is still alive
      assert Process.alive?(pid)

      # Cleanup
      if Process.alive?(pid), do: GenServer.stop(pid)
    end

    test "handles unexpected command return values" do
      # Setup: Prepare manager with bad return plugin
      {:ok, pid} = Manager.start_link([])

      # Allow the plugin to load
      :meck.expect(LifecycleHelper, :init_plugin, fn BadReturnPlugin, _opts ->
        {:ok, %{}}
      end)

      {:ok, _} = Manager.load_plugin(pid, BadReturnPlugin)

      # Execute: Try to execute a command with bad return value
      result = Manager.execute_command(pid, :bad_return_cmd, ["test"])

      # Verify: Should handle the bad return gracefully
      assert {:error, :invalid_return} = result

      # Verify: Manager is still alive
      assert Process.alive?(pid)

      # Cleanup
      if Process.alive?(pid), do: GenServer.stop(pid)
    end
  end

  describe "plugin event handling edge cases" do
    test "handles plugin input handler crashes" do
      # Setup: Prepare manager with test plugin set to crash on input
      {:ok, pid} = Manager.start_link([])

      # Setup the plugin to crash on input
      :meck.expect(LifecycleHelper, :init_plugin, fn TestPlugin, _opts ->
        {:ok, %{name: "test_plugin", enabled: true, crash_on: :input}}
      end)

      {:ok, _} = Manager.load_plugin(pid, TestPlugin)

      # Execute: Process input that will trigger crash
      result = Manager.process_input(pid, "test input")

      # Verify: Should handle the crash gracefully
      assert {:ok, _} = result

      # Verify: Manager is still alive
      assert Process.alive?(pid)

      # Cleanup
      if Process.alive?(pid), do: GenServer.stop(pid)
    end

    test "handles plugin output handler crashes" do
      # Setup: Prepare manager with test plugin set to crash on output
      {:ok, pid} = Manager.start_link([])

      # Setup the plugin to crash on output
      :meck.expect(LifecycleHelper, :init_plugin, fn TestPlugin, _opts ->
        {:ok, %{name: "test_plugin", enabled: true, crash_on: :output}}
      end)

      {:ok, _} = Manager.load_plugin(pid, TestPlugin)

      # Execute: Process output that will trigger crash
      result = Manager.process_output(pid, "test output")

      # Verify: Should handle the crash gracefully
      assert {:ok, _, output} = result
      assert output == "test output" # Original output should be returned

      # Verify: Manager is still alive
      assert Process.alive?(pid)

      # Cleanup
      if Process.alive?(pid), do: GenServer.stop(pid)
    end

    test "handles plugin mouse handler crashes" do
      # Setup: Prepare manager with test plugin set to crash on mouse
      {:ok, pid} = Manager.start_link([])

      # Setup the plugin to crash on mouse
      :meck.expect(LifecycleHelper, :init_plugin, fn TestPlugin, _opts ->
        {:ok, %{name: "test_plugin", enabled: true, crash_on: :mouse}}
      end)

      {:ok, _} = Manager.load_plugin(pid, TestPlugin)

      # Execute: Process mouse event that will trigger crash
      event = {:click, 10, 20, :left}
      result = Manager.process_mouse(pid, event, %{})

      # Verify: Should handle the crash gracefully
      assert {:ok, _} = result

      # Verify: Manager is still alive
      assert Process.alive?(pid)

      # Cleanup
      if Process.alive?(pid), do: GenServer.stop(pid)
    end

    test "handles plugin placeholder handler crashes" do
      # Setup: Prepare manager with test plugin set to crash on placeholder
      {:ok, pid} = Manager.start_link([])

      # Setup the plugin to crash on placeholder
      :meck.expect(LifecycleHelper, :init_plugin, fn TestPlugin, _opts ->
        {:ok, %{name: "test_plugin", enabled: true, crash_on: :placeholder}}
      end)

      {:ok, _} = Manager.load_plugin(pid, TestPlugin)

      # Execute: Process placeholder that will trigger crash
      result = Manager.process_placeholder(pid, "chart", "data", %{})

      # Verify: Should handle the crash gracefully
      assert {:ok, _manager, nil} = result # Default to nil for placeholder content

      # Verify: Manager is still alive
      assert Process.alive?(pid)

      # Cleanup
      if Process.alive?(pid), do: GenServer.stop(pid)
    end

    test "handles invalid return values from event handlers" do
      # Setup: Prepare manager with bad return plugin
      {:ok, pid} = Manager.start_link([])

      # Allow the plugin to load
      :meck.expect(LifecycleHelper, :init_plugin, fn BadReturnPlugin, _opts ->
        {:ok, %{}}
      end)

      {:ok, _} = Manager.load_plugin(pid, BadReturnPlugin)

      # Execute: Process input with bad return
      result = Manager.process_input(pid, "test input")

      # Verify: Should handle the bad return gracefully
      assert {:ok, _} = result

      # Execute: Process output with bad return
      result = Manager.process_output(pid, "test output")

      # Verify: Should handle the bad return and return original output
      assert {:ok, _, "test output"} = result

      # Verify: Manager is still alive
      assert Process.alive?(pid)

      # Cleanup
      if Process.alive?(pid), do: GenServer.stop(pid)
    end
  end

  describe "plugin reloading edge cases" do
    test "handles reload failures gracefully" do
      # Setup: Prepare manager with test plugin
      {:ok, pid} = Manager.start_link([])

      # Allow the plugin to load
      :meck.expect(LifecycleHelper, :init_plugin, fn TestPlugin, _opts ->
        {:ok, %{name: "test_plugin", enabled: true}}
      end)

      {:ok, _} = Manager.load_plugin(pid, TestPlugin)

      # Setup: Make reloading fail
      :meck.expect(LifecycleHelper, :reload_plugin_from_disk, fn _id, _module, _path, _plugin_states, _plugin_manager, _event_handler, _cell_processor, _cmd_helper ->
        {:error, :recompile_failed}
      end)

      # Execute: Attempt to reload the plugin
      result = Manager.reload_plugin(pid, :test_plugin)

      # Verify: Should report the reload failure
      assert {:error, :recompile_failed} = result

      # Verify: Manager is still alive
      assert Process.alive?(pid)

      # Cleanup
      if Process.alive?(pid), do: GenServer.stop(pid)
    end
  end

  describe "concurrent operations" do
    test "handles concurrent plugin operations" do
      # Setup: Prepare manager
      {:ok, pid} = Manager.start_link([])

      # Allow plugins to load
      :meck.expect(LifecycleHelper, :init_plugin, fn
        TestPlugin, _opts -> {:ok, %{name: "test_plugin", enabled: true}}
        DependentPlugin, _opts -> {:ok, %{name: "dependent_plugin", enabled: true}}
      end)

      # Expect dependencies to be OK
      :meck.expect(LifecycleHelper, :check_dependencies, fn _, _ -> {:ok} end)

      # Execute: Start multiple concurrent operations
      tasks = for _ <- 1..5 do
        Task.async(fn ->
          # Mix of operations
          ops = [
            fn -> Manager.load_plugin(pid, TestPlugin) end,
            fn -> Manager.load_plugin(pid, DependentPlugin) end,
            fn -> Manager.process_input(pid, "test input") end,
            fn -> Manager.process_output(pid, "test output") end,
            fn -> Manager.execute_command(pid, :test_cmd, ["arg"]) end
          ]

          # Pick a random operation and execute it
          op = Enum.random(ops)
          op.()
        end)
      end

      # Wait for all tasks to complete
      results = Task.await_many(tasks, 1000)

      # Verify: Manager should still be alive
      assert Process.alive?(pid)

      # Cleanup
      if Process.alive?(pid), do: GenServer.stop(pid)
    end
  end
end
