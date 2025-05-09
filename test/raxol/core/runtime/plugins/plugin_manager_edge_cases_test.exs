defmodule Raxol.Core.Runtime.Plugins.PluginManagerEdgeCasesTest do
  use ExUnit.Case, async: false
  require Logger
  import Mox

  alias Raxol.Core.Events.Event

  alias Raxol.Core.Runtime.Plugins.{
    Manager,
    Loader,
    LifecycleHelper,
    CommandRegistry
  }

  # --- Mox Mock Definition ---
  # Define Mox mock for LifecycleHelper since it has a behaviour
  Mox.defmock(EdgeCasesLifecycleHelperMock,
    for: Raxol.Core.Runtime.Plugins.LifecycleHelperBehaviour
  )

  # Test plugin module that implements the required behaviours
  defmodule TestPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin

    def init(opts) do
      {:ok,
       %{
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
        new_state = %{
          state
          | event_count: state.event_count + 1,
            last_input: input
        }

        {:ok, new_state}
      end
    end

    def handle_output(output, state) do
      if state.crash_on == :output do
        raise "Intentional crash in handle_output"
      else
        new_state = %{
          state
          | event_count: state.event_count + 1,
            last_output: output
        }

        {:ok, new_state, "Modified: #{output}"}
      end
    end

    def handle_mouse(event, state) do
      if state.crash_on == :mouse do
        raise "Intentional crash in handle_mouse"
      else
        new_state = %{
          state
          | event_count: state.event_count + 1,
            last_mouse: event
        }

        {:ok, new_state}
      end
    end

    def handle_placeholder(tag, content, options, state) do
      if state.crash_on == :placeholder do
        raise "Intentional crash in handle_placeholder"
      else
        new_state = %{
          state
          | event_count: state.event_count + 1,
            last_placeholder: {tag, content, options}
        }

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
    # Use Mox stubbing for LifecycleHelper
    # We use stub_with because Manager calls LifecycleHelper functions directly
    # Stubbing needs to happen *before* the Manager starts if it calls these on init
    # Since this setup runs before each test, this should be fine.
    Mox.stub_with(EdgeCasesLifecycleHelperMock, LifecycleHelper)
    Mox.verify_on_exit!()

    # Create ETS table for command registry
    :ets.new(:raxol_command_registry, [
      :set,
      :public,
      :named_table,
      read_concurrency: true
    ])

    on_exit(fn ->
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
      # Setup: Plugin init will fail (Now using Mox expect)
      Mox.expect(EdgeCasesLifecycleHelperMock, :init_plugin, fn
        TestPlugin, _opts -> {:error, :init_failed}
        # Default case for other plugins if any
        _module, _opts -> {:ok, %{}}
      end)

      # Execute: Start Manager and try to load the plugin
      {:ok, pid} = Manager.start_link([])
      {:error, reason} = Manager.load_plugin(TestPlugin, %{})

      # Verify: Manager should report the init failure
      assert reason == :init_failed

      # Verify: Manager is still functioning
      assert Process.alive?(pid)

      # Cleanup
      if Process.alive?(pid), do: GenServer.stop(pid)
    end

    test "handles plugin module loading errors" do
      # Setup: Loader will fail to load the module using Mox
      Mox.expect(Loader, :load_plugin_module, fn
        TestPlugin -> {:error, :not_found}
        # Default case
        _ -> {:ok, nil}
      end)

      # Execute: Start Manager and try to load the plugin
      {:ok, pid} = Manager.start_link([])
      {:error, reason} = Manager.load_plugin(TestPlugin, %{})

      # Verify: Manager should report the loading failure
      assert reason == :not_found

      # Verify: Manager is still functioning
      assert Process.alive?(pid)

      # Cleanup
      if Process.alive?(pid), do: GenServer.stop(pid)
    end

    test "handles dependency resolution failures" do
      # Setup: LifecycleHelper will check dependencies (Now using Mox expect)
      Mox.expect(EdgeCasesLifecycleHelperMock, :check_dependencies, fn
        _plugin_id,
        %{dependencies: [{:missing_plugin, ">= 1.0.0"}]},
        _available_plugins ->
          {:error, :missing_dependencies, :missing_plugin}

        # Default case
        _plugin_id, _metadata, _available_plugins ->
          {:ok}
      end)

      # Execute: Start Manager and try to load the plugin with dependencies
      {:ok, pid} = Manager.start_link([])

      # Expect Loader to return the dependencies using Mox
      Mox.expect(Loader, :load_plugin_metadata, fn
        DependentPlugin ->
          {:ok, DependentPlugin}
      end)

      {:error, reason, missing} = Manager.load_plugin(DependentPlugin, %{})

      # Verify: Manager should report the dependency failure
      assert reason == :missing_dependencies
      assert missing == :missing_plugin

      # Verify: Manager is still functioning
      assert Process.alive?(pid)

      # Cleanup
      if Process.alive?(pid), do: GenServer.stop(pid)
    end

    test "handles plugin init timeout (simulated via mock)" do
      # In this test, we simulate a timeout by having the EdgeCasesLifecycleHelperMock's
      # init_plugin function never return a value (or take too long).
      # We use Mox.stub_with for direct control over the mock's behavior.
      # Configure EdgeCasesLifecycleHelperMock to simulate a hanging init_plugin
      Mox.stub_with(EdgeCasesLifecycleHelperMock, %{
        init_plugin: fn _module, _opts ->
          # Simulate a hanging process
          Process.sleep(:infinity)
          # This will never be reached, but Mox expects a return value structure
          # In a real scenario, the GenServer.call would time out.
          {:error, :timeout_simulated_never_reached}
        end,
        # Provide default implementations for other functions if Manager calls them
        # Default ok
        check_dependencies: fn _, _, _ -> {:ok, []} end,
        # Default ok
        terminate_plugin: fn _, _, _ -> :ok end
      })

      # Attempt to load the plugin, expecting a timeout
      {:ok, pid} = Manager.start_link([])
      {:error, reason} = Manager.load_plugin(TestPlugin, %{})

      # Verify: Should handle the timeout gracefully
      assert reason == :timeout_simulated_never_reached
      assert Process.alive?(pid)
      if Process.alive?(pid), do: GenServer.stop(pid)
    end

    test "handles plugin command execution errors (BadReturnPlugin)" do
      # Stub LifecycleHelper for this specific test if needed, or rely on global stub
      # For this test, we want init_plugin to succeed.
      Mox.expect(EdgeCasesLifecycleHelperMock, :init_plugin, fn TestPlugin,
                                                                opts ->
        {:ok, opts}
      end)

      Mox.stub_with(EdgeCasesLifecycleHelperMock, %{
        init_plugin: fn _mod, opts ->
          {:ok,
           %{
             plugin_id: :bad_return_plugin,
             module: BadReturnPlugin,
             config: opts,
             state: %{}
           }}
        end,
        # Ensure other functions are stubbed if called by Manager.initialize or other paths
        check_dependencies: fn _, _, _ -> {:ok, []} end,
        terminate_plugin: fn _, _, _ -> :ok end
      })

      # Start with no plugins initially
      {:ok, pid} = Manager.start_link(plugins: [])
      {:error, reason} = Manager.load_plugin(BadReturnPlugin, %{})

      # Verify: Should handle the bad return gracefully
      assert reason == :timeout_simulated_never_reached
      assert Process.alive?(pid)
      if Process.alive?(pid), do: GenServer.stop(pid)
    end

    test "handles plugin command not found" do
      # Setup: Load a plugin (TestPlugin)
      # Stubbing init_plugin to successfully initialize TestPlugin
      Mox.stub_with(EdgeCasesLifecycleHelperMock, %{
        init_plugin: fn _mod, opts ->
          {:ok,
           %{
             plugin_id: :test_plugin,
             module: TestPlugin,
             config: opts,
             state: TestPlugin.init!(opts)
           }}
        end,
        check_dependencies: fn _, _, _ -> {:ok, []} end,
        terminate_plugin: fn _, _, _ -> :ok end
      })

      {:ok, _pid} = Manager.start_link(plugins: [{TestPlugin, %{}}])
      # {:error, reason} = Manager.load_plugin(TestPlugin, %{})
    end
  end

  describe "plugin event handling edge cases" do
    # Skip: Manager.process_input/2 is no longer the API for input processing
    @tag :skip
    test "handles plugin input handler crashes" do
      # Setup: Prepare manager with test plugin configured to crash on input
      {:ok, pid} = Manager.start_link([])

      # Setup the plugin to crash on input
      # Use Mox expect for init_plugin
      Mox.expect(EdgeCasesLifecycleHelperMock, :init_plugin, fn
        TestPlugin, _opts ->
          {:ok, %{name: "test_plugin", enabled: true, crash_on: :input}}

        # Default case for other plugins if any
        _module, _opts ->
          {:ok, %{}}
      end)

      {:ok, _} = Manager.load_plugin(TestPlugin, %{})

      # Execute: Process input that will trigger crash
      result = Manager.process_input(pid, "test input")

      # Verify: Should handle the crash gracefully
      assert {:ok, _} = result

      # Verify: Manager is still alive
      assert Process.alive?(pid)

      # Cleanup
      if Process.alive?(pid), do: GenServer.stop(pid)
    end

    # Skip: Manager.process_output/2 is no longer the API for output processing
    @tag :skip
    test "handles plugin output handler crashes" do
      # Setup: Prepare manager with test plugin configured to crash on output
      {:ok, pid} = Manager.start_link([])

      # Setup the plugin to crash on output
      # Use Mox expect for init_plugin
      Mox.expect(EdgeCasesLifecycleHelperMock, :init_plugin, fn
        TestPlugin, _opts ->
          {:ok, %{name: "test_plugin", enabled: true, crash_on: :output}}

        # Default case for other plugins if any
        _module, _opts ->
          {:ok, %{}}
      end)

      {:ok, _} = Manager.load_plugin(TestPlugin, %{})

      # Execute: Process output that will trigger crash
      result = Manager.process_output(pid, "test output")

      # Verify: Should handle the crash gracefully
      assert {:ok, _, output} = result
      # Original output should be returned
      assert output == "test output"

      # Verify: Manager is still alive
      assert Process.alive?(pid)

      # Cleanup
      if Process.alive?(pid), do: GenServer.stop(pid)
    end

    # Skip: Manager.process_mouse/3 is no longer the API for mouse processing
    @tag :skip
    test "handles plugin mouse handler crashes" do
      # Setup: Prepare manager with test plugin configured to crash on mouse event
      {:ok, pid} = Manager.start_link([])

      # Setup the plugin to crash on mouse
      # Use Mox expect for init_plugin
      Mox.expect(EdgeCasesLifecycleHelperMock, :init_plugin, fn
        TestPlugin, _opts ->
          {:ok, %{name: "test_plugin", enabled: true, crash_on: :mouse}}

        # Default case for other plugins if any
        _module, _opts ->
          {:ok, %{}}
      end)

      {:ok, _} = Manager.load_plugin(TestPlugin, %{})

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

    # Skip: Manager.process_placeholder/4 is no longer the API for placeholder processing
    @tag :skip
    test "handles plugin placeholder handler crashes" do
      # Setup: Prepare manager with test plugin configured to crash on placeholder
      {:ok, pid} = Manager.start_link([])

      # Setup the plugin to crash on placeholder
      # Use Mox expect for init_plugin
      Mox.expect(EdgeCasesLifecycleHelperMock, :init_plugin, fn
        TestPlugin, _opts ->
          {:ok, %{name: "test_plugin", enabled: true, crash_on: :placeholder}}

        # Default case for other plugins if any
        _module, _opts ->
          {:ok, %{}}
      end)

      {:ok, _} = Manager.load_plugin(TestPlugin, %{})

      # Execute: Process placeholder that will trigger crash
      result = Manager.process_placeholder(pid, "chart", "data", %{})

      # Verify: Should handle the crash gracefully
      # Default to nil for placeholder content
      assert {:ok, _manager, nil} = result

      # Verify: Manager is still alive
      assert Process.alive?(pid)

      # Cleanup
      if Process.alive?(pid), do: GenServer.stop(pid)
    end

    # Skip: Manager.process_input/2 etc are no longer the API for event processing
    @tag :skip
    test "handles invalid return values from event handlers" do
      # Setup: Prepare manager with bad return plugin
      {:ok, pid} = Manager.start_link([])

      # Allow the plugin to load
      # Use Mox expect for init_plugin
      Mox.expect(EdgeCasesLifecycleHelperMock, :init_plugin, fn
        BadReturnPlugin, _opts ->
          {:ok, %{}}

        # Default case for other plugins if any
        _module, _opts ->
          {:ok, %{}}
      end)

      {:ok, _} = Manager.load_plugin(BadReturnPlugin, %{})

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
      # Use Mox expect for init_plugin
      Mox.expect(EdgeCasesLifecycleHelperMock, :init_plugin, fn
        TestPlugin, _opts ->
          {:ok, %{name: "test_plugin", enabled: true}}

        # Default case for other plugins if any
        _module, _opts ->
          {:ok, %{}}
      end)

      {:ok, _} = Manager.load_plugin(TestPlugin, %{})

      # Setup: Make reloading fail
      # Use Mox expect for reload_plugin_from_disk
      Mox.expect(
        EdgeCasesLifecycleHelperMock,
        :reload_plugin_from_disk,
        1,
        fn _id,
           _module,
           _path,
           _plugin_states,
           _plugin_manager,
           _event_handler,
           _cell_processor,
           _cmd_helper ->
          {:error, :recompile_failed}
        end
      )

      # Execute: Attempt to reload the plugin
      result = Manager.reload_plugin(:test_plugin)

      # Verify: Should report the reload failure
      assert {:error, :recompile_failed} = result

      # Verify: Manager is still alive
      assert Process.alive?(pid)

      # Cleanup
      if Process.alive?(pid), do: GenServer.stop(pid)
    end

    test "handles reload failures gracefully when trying to reload a non-existent plugin" do
      # Setup: Prepare manager
      {:ok, pid} = Manager.start_link([])

      # Execute: Try to reload a non-existent plugin
      result = Manager.reload_plugin(:non_existent_plugin)

      # Verify: Reload should fail
      assert {:error, :plugin_not_found} = result

      # Verify: Manager is still alive
      assert Process.alive?(pid)

      # Cleanup
      if Process.alive?(pid), do: GenServer.stop(pid)
    end
  end

  describe "concurrent operations" do
    # Skip: Tests removed Manager APIs (execute_command, process_*)
    @tag :skip
    test "handles concurrent plugin operations" do
      # Setup: Prepare manager
      {:ok, pid} = Manager.start_link([])

      # Mix of operations
      ops = [
        fn -> Manager.load_plugin(TestPlugin, %{}) end,
        fn -> Manager.load_plugin(DependentPlugin, %{}) end,
        fn -> Manager.process_input(pid, "test input") end,
        fn -> Manager.process_output(pid, "test output") end,
        fn -> Manager.execute_command(pid, :test_cmd, ["payload"]) end
      ]

      # Execute ops concurrently
      tasks =
        for _ <- 1..5 do
          Task.async(fn ->
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

  describe "plugin termination errors" do
    test "handles plugin terminate failure gracefully" do
      # Setup: Plugin terminate will fail
      Mox.expect(EdgeCasesLifecycleHelperMock, :terminate_plugin, fn
        :test_plugin, :shutdown, _state -> {:error, :terminate_failed}
      end)

      # Stub init_plugin to succeed for TestPlugin
      Mox.stub(EdgeCasesLifecycleHelperMock, :init_plugin, fn TestPlugin,
                                                              opts ->
        {:ok,
         %{
           plugin_id: :test_plugin,
           module: TestPlugin,
           config: opts,
           state: TestPlugin.init!(opts)
         }}
      end)

      # Ensure check_dependencies is stubbed
      Mox.stub(EdgeCasesLifecycleHelperMock, :check_dependencies, fn _, _, _ ->
        {:ok, []}
      end)

      # Execute: Start Manager, load plugin, then stop Manager
      {:ok, pid} = Manager.start_link([])
      {:error, reason} = Manager.load_plugin(TestPlugin, %{})

      # Verify: Should handle the terminate failure gracefully
      assert reason == :terminate_failed

      # Verify: Manager is still alive
      assert Process.alive?(pid)

      # Cleanup
      if Process.alive?(pid), do: GenServer.stop(pid)
    end

    test "handles plugin terminate timeout (simulated)" do
      # Configure EdgeCasesLifecycleHelperMock to simulate a hanging terminate_plugin
      Mox.stub_with(EdgeCasesLifecycleHelperMock, %{
        init_plugin: fn _module, opts ->
          {:ok,
           %{
             plugin_id: :test_plugin,
             module: TestPlugin,
             config: opts,
             state: TestPlugin.init!(opts)
           }}
        end,
        # Default ok
        check_dependencies: fn _, _, _ -> {:ok, []} end,
        terminate_plugin: fn _plugin_id, _reason, _state ->
          # Simulate hanging
          Process.sleep(:infinity)
          # Will not be reached
          :ok
        end
      })

      # Start Manager and load TestPlugin
      {:ok, pid} = Manager.start_link([])
      {:error, reason} = Manager.load_plugin(TestPlugin, %{})

      # Verify: Should handle the terminate timeout gracefully
      assert reason == :timeout_simulated_never_reached

      # Verify: Manager is still alive
      assert Process.alive?(pid)

      # Cleanup
      if Process.alive?(pid), do: GenServer.stop(pid)
    end
  end

  describe "manager robustness to plugin crashes" do
    setup do
      # Stub LifecycleHelper for these tests
      Mox.stub_with(EdgeCasesLifecycleHelperMock, %{
        init_plugin: fn _mod, opts ->
          {:ok,
           %{
             plugin_id: :test_plugin,
             module: TestPlugin,
             config: opts,
             state: TestPlugin.init!(opts)
           }}
        end,
        check_dependencies: fn _, _, _ -> {:ok, []} end,
        # Default ok for termination
        terminate_plugin: fn _, _, _ -> :ok end
      })

      :ok
    end

    # Skip: Tests removed Manager APIs (execute_command, process_*)
    @tag :skip
    test "handles concurrent plugin operations" do
      # Setup: Prepare manager
      {:ok, pid} = Manager.start_link([])

      # Mix of operations
      ops = [
        fn -> Manager.load_plugin(TestPlugin, %{}) end,
        fn -> Manager.load_plugin(DependentPlugin, %{}) end,
        fn -> Manager.process_input(pid, "test input") end,
        fn -> Manager.process_output(pid, "test output") end,
        fn -> Manager.execute_command(pid, :test_cmd, ["payload"]) end
      ]

      # Execute ops concurrently
      tasks =
        for _ <- 1..5 do
          Task.async(fn ->
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
