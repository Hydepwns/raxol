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

  # Alias the new fixtures module
  alias Raxol.Test.PluginTestFixtures

  # --- Mox Mock Definition ---
  # Define Mox mock for LifecycleHelper since it has a behaviour
  Mox.defmock(EdgeCasesLifecycleHelperMock,
    for: Raxol.Core.Runtime.Plugins.LifecycleHelperBehaviour
  )

  # Test plugin module definitions are now in PluginTestFixtures
  # defmodule TestPlugin do ... end
  # defmodule BrokenPlugin do ... end
  # defmodule BadReturnPlugin do ... end
  # defmodule DependentPlugin do ... end

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
      with_running_manager([], fn manager_pid ->
        # Setup: Plugin init will fail
        Mox.expect(EdgeCasesLifecycleHelperMock, :init_plugin, fn
          PluginTestFixtures.TestPlugin, _opts -> {:error, :init_failed}
          # Default case for other plugins if any
          _module, _opts -> {:ok, %{}}
        end)

        assert_plugin_load_fails(
          manager_pid,
          PluginTestFixtures.TestPlugin,
          %{},
          {:error, :init_failed}
        )
      end)
    end

    test "handles plugin module loading errors" do
      with_running_manager([], fn manager_pid ->
        # Setup: Loader will fail to load the module using Mox
        Mox.expect(Loader, :load_plugin_module, fn
          PluginTestFixtures.TestPlugin -> {:error, :not_found}
          # Default case
          _ -> {:ok, nil}
        end)

        assert_plugin_load_fails(
          manager_pid,
          PluginTestFixtures.TestPlugin,
          %{},
          {:error, :not_found}
        )
      end)
    end

    test "handles dependency resolution failures" do
      with_running_manager([], fn manager_pid ->
        # Setup: LifecycleHelper will check dependencies
        Mox.expect(EdgeCasesLifecycleHelperMock, :check_dependencies, fn
          _plugin_id,
          %{dependencies: [{:missing_plugin, ">= 1.0.0"}]},
          _available_plugins ->
            {:error, :missing_dependencies, :missing_plugin}

          # Default case
          _plugin_id, _metadata, _available_plugins ->
            {:ok}
        end)

        # Expect Loader to return the dependencies using Mox
        Mox.expect(Loader, :load_plugin_metadata, fn
          PluginTestFixtures.DependentPlugin ->
            {:ok, PluginTestFixtures.DependentPlugin}
        end)

        assert_plugin_load_fails(
          manager_pid,
          PluginTestFixtures.DependentPlugin,
          %{},
          {:error, :missing_dependencies, :missing_plugin}
        )
      end)
    end

    test "handles plugin init timeout (simulated via mock)" do
      with_running_manager([], fn manager_pid ->
        # Configure EdgeCasesLifecycleHelperMock to simulate a hanging init_plugin
        Mox.stub_with(EdgeCasesLifecycleHelperMock, %{
          init_plugin: fn _module, _opts ->
            Process.sleep(:infinity)
            # Unreachable
            {:error, :timeout_simulated_never_reached}
          end,
          check_dependencies: fn _, _, _ -> {:ok, []} end,
          terminate_plugin: fn _, _, _ -> :ok end
        })

        assert_plugin_load_fails(
          manager_pid,
          PluginTestFixtures.TestPlugin,
          %{},
          {:error, :timeout}
        )
      end)
    end

    test "handles plugin command execution errors (BadReturnPlugin)" do
      with_running_manager([], fn manager_pid ->
        # Load BadReturnPlugin using the setup_plugin helper
        assert {:ok, _loaded_state} =
                 setup_plugin(
                   manager_pid,
                   PluginTestFixtures.BadReturnPlugin,
                   :bad_return_plugin,
                   %{}
                 )

        execute_command_and_verify(
          manager_pid,
          :bad_return_plugin,
          :bad_return_cmd,
          ["test_arg"],
          [
            {:error,
             {:command_error, :bad_return_plugin, :bad_return_cmd,
              :bad_plugin_return_value}},
            {:error,
             {:command_error, :bad_return_cmd, :bad_plugin_return_value}},
            {:error, :command_failed}
          ]
        )
      end)
    end

    test "handles plugin command not found" do
      with_running_manager([], fn manager_pid ->
        # Setup: Load TestPlugin using the helper
        assert {:ok, _loaded_state} =
                 setup_plugin(
                   manager_pid,
                   PluginTestFixtures.TestPlugin,
                   :test_plugin,
                   %{}
                 )

        execute_command_and_verify(
          manager_pid,
          :test_plugin,
          :non_existent_cmd,
          ["test_arg"],
          [
            {:error,
             {:command_error, :test_plugin, :non_existent_cmd, :not_found}},
            {:error, {:command_not_found, :test_plugin, :non_existent_cmd}},
            {:error, :command_not_found}
          ]
        )
      end)
    end
  end

  describe "plugin event handling edge cases" do
    # Setup for this describe block is removed, tests will manage their own manager lifecycle
    # and plugin loading as needed.

    test "handles plugin input handler crashes" do
      with_running_manager([], fn manager_pid ->
        crashing_plugin_module = PluginTestFixtures.CrashingPlugin
        crashing_plugin_id = :crashing_plugin
        # Matches conceptual CrashingPlugin
        crashing_plugin_namespace = :crashing_plugin_commands

        # Load the crashing plugin
        assert {:ok, _} =
                 setup_plugin(
                   manager_pid,
                   crashing_plugin_module,
                   crashing_plugin_id,
                   %{}
                 )

        dispatch_command_and_assert_manager_alive(
          manager_pid,
          :trigger_input_crash,
          crashing_plugin_namespace,
          "PluginManager GenServer should remain alive after a plugin's input handler crashes (triggered by command)"
        )
      end)
    end

    @tag :skip
    test "handles plugin output handler crashes" do
      with_running_manager([], fn manager_pid ->
        crashing_plugin_module = PluginTestFixtures.CrashingPlugin
        crashing_plugin_id = :crashing_plugin
        # Matches conceptual CrashingPlugin
        crashing_plugin_namespace = :crashing_plugin_commands

        # Load the crashing plugin
        assert {:ok, _} =
                 setup_plugin(
                   manager_pid,
                   crashing_plugin_module,
                   crashing_plugin_id,
                   %{}
                 )

        dispatch_command_and_assert_manager_alive(
          manager_pid,
          :trigger_output_crash,
          crashing_plugin_namespace,
          "PluginManager GenServer should remain alive after a plugin's output handler crashes (triggered by command)"
        )
      end)
    end

    # Skip: Manager.process_mouse/3 is no longer the API for mouse processing
    @tag :skip
    test "handles plugin mouse handler crashes" do
      # Setup: Prepare manager with test plugin configured to crash on mouse event
      {:ok, pid} = Manager.start_link([])

      # Setup the plugin to crash on mouse
      # Use Mox expect for init_plugin
      Mox.expect(EdgeCasesLifecycleHelperMock, :init_plugin, fn
        PluginTestFixtures.TestPlugin, _opts ->
          {:ok, %{name: "test_plugin", enabled: true, crash_on: :mouse}}

        # Default case for other plugins if any
        _module, _opts ->
          {:ok, %{}}
      end)

      {:ok, _} = Manager.load_plugin(PluginTestFixtures.TestPlugin, %{})

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
        PluginTestFixtures.TestPlugin, _opts ->
          {:ok, %{name: "test_plugin", enabled: true, crash_on: :placeholder}}

        # Default case for other plugins if any
        _module, _opts ->
          {:ok, %{}}
      end)

      {:ok, _} = Manager.load_plugin(PluginTestFixtures.TestPlugin, %{})

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
        PluginTestFixtures.BadReturnPlugin, _opts ->
          {:ok, %{}}

        # Default case for other plugins if any
        _module, _opts ->
          {:ok, %{}}
      end)

      {:ok, _} = Manager.load_plugin(PluginTestFixtures.BadReturnPlugin, %{})

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
      with_running_manager([], fn manager_pid ->
        # Allow the plugin to load initially
        Mox.expect(EdgeCasesLifecycleHelperMock, :init_plugin, fn
          PluginTestFixtures.TestPlugin, _opts ->
            {:ok,
             %{
               name: "test_plugin",
               enabled: true,
               module: PluginTestFixtures.TestPlugin,
               state: %{}
             }}

          _module, _opts ->
            # Default case
            {:ok, %{}}
        end)

        # Ensure load_plugin is called with the manager_pid
        assert {:ok, _} =
                 Manager.load_plugin(
                   manager_pid,
                   PluginTestFixtures.TestPlugin,
                   %{}
                 )

        # Setup: Make reloading fail
        Mox.expect(
          EdgeCasesLifecycleHelperMock,
          :reload_plugin_from_disk,
          1,
          # Expecting the plugin_id from the loaded plugin state
          # Ensure the correct manager_pid is passed
          fn :test_plugin,
             PluginTestFixtures.TestPlugin,
             _path,
             _plugin_states,
             ^manager_pid,
             _event_handler,
             _cell_processor,
             _cmd_helper ->
            {:error, :recompile_failed}
          end
        )

        # Execute: Attempt to reload the plugin
        # Assuming reload_plugin takes manager_pid and plugin_id
        result = Manager.reload_plugin(manager_pid, :test_plugin)

        # Verify: Should report the reload failure
        assert {:error, :recompile_failed} = result
        assert Process.alive?(manager_pid)
      end)
    end

    test "handles reload failures gracefully when trying to reload a non-existent plugin" do
      with_running_manager([], fn manager_pid ->
        # Execute: Try to reload a non-existent plugin
        result = Manager.reload_plugin(manager_pid, :non_existent_plugin)

        # Verify: Reload should fail
        assert {:error, :plugin_not_found} = result
        assert Process.alive?(manager_pid)
      end)
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
        fn -> Manager.load_plugin(PluginTestFixtures.TestPlugin, %{}) end,
        fn -> Manager.load_plugin(PluginTestFixtures.DependentPlugin, %{}) end,
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
      Mox.stub(
        EdgeCasesLifecycleHelperMock,
        :init_plugin,
        fn PluginTestFixtures.TestPlugin, opts ->
          {:ok,
           %{
             plugin_id: :test_plugin,
             module: PluginTestFixtures.TestPlugin,
             config: opts,
             state: PluginTestFixtures.TestPlugin.init!(opts)
           }}
        end
      )

      # Ensure check_dependencies is stubbed
      Mox.stub(EdgeCasesLifecycleHelperMock, :check_dependencies, fn _, _, _ ->
        {:ok, []}
      end)

      # Execute: Start Manager, load plugin, then stop Manager
      {:ok, pid} = Manager.start_link([])
      {:error, reason} = Manager.load_plugin(PluginTestFixtures.TestPlugin, %{})

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
             module: PluginTestFixtures.TestPlugin,
             config: opts,
             state: PluginTestFixtures.TestPlugin.init!(opts)
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
      {:error, reason} = Manager.load_plugin(PluginTestFixtures.TestPlugin, %{})

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
             module: PluginTestFixtures.TestPlugin,
             config: opts,
             state: PluginTestFixtures.TestPlugin.init!(opts)
           }}
        end,
        check_dependencies: fn _, _, _ -> {:ok, []} end,
        # Default ok for termination
        terminate_plugin: fn _, _, _ -> :ok end
      })

      :ok
    end
  end

  # Helper to run a test with a managed PluginManager process
  defp with_running_manager(manager_opts \\ [], func) do
    {:ok, manager_pid} = Manager.start_link(manager_opts)

    try do
      func.(manager_pid)
    after
      # Ensure manager is stopped even if the test fails
      if Process.alive?(manager_pid), do: GenServer.stop(manager_pid)
    end
  end

  # --- New Helper Functions ---

  defp setup_plugin(
         manager_pid,
         plugin_module,
         plugin_id_atom,
         initial_opts \\ %{}
       ) do
    plugin_init_fun = fn mod, opts ->
      # Attempt to call init! first, then init if init! is not defined or fails for arity reasons
      initial_plugin_state =
        try do
          apply(mod, :init!, [opts])
        rescue
          UndefinedFunctionError -> apply(mod, :init, [opts])
        end

      resolved_state =
        if is_tuple(initial_plugin_state) and
             elem(initial_plugin_state, 0) == :ok do
          elem(initial_plugin_state, 1)
        else
          # Assuming init! or a direct state return from init
          initial_plugin_state
        end

      {:ok,
       %{
         plugin_id: plugin_id_atom,
         module: mod,
         config: opts,
         state: resolved_state
       }}
    end

    # Stub common LifecycleHelper functions needed for loading
    Mox.stub_with(EdgeCasesLifecycleHelperMock, %{
      init_plugin: plugin_init_fun,
      # Default stub for successful dependency check
      check_dependencies: fn _, _, _ -> {:ok, []} end,
      # Default stub for successful termination
      terminate_plugin: fn _, _, _ -> :ok end
    })

    Manager.load_plugin(manager_pid, plugin_module, initial_opts)
  end

  defp dispatch_command_and_assert_manager_alive(
         manager_pid,
         command_name,
         namespace,
         data \\ %{},
         assertion_message
       ) do
    GenServer.cast(
      manager_pid,
      {:handle_command, command_name, namespace, data, self()}
    )

    # Allow time for async processing and potential crash
    Process.sleep(150)
    assert Process.alive?(manager_pid), assertion_message
  end

  defp assert_matches_any_pattern(term, patterns) when is_list(patterns) do
    assert Enum.any?(patterns, &match?(&1, term)),
           "Term #{inspect(term)} did not match any of the expected patterns: #{inspect(patterns)}"
  end

  # Helper for executing a command and verifying the outcome and manager liveness
  defp execute_command_and_verify(
         manager_pid,
         plugin_id_atom,
         command_name,
         command_args,
         expected_patterns
       ) do
    result =
      Manager.execute_command(
        manager_pid,
        plugin_id_atom,
        command_name,
        command_args
      )

    assert_matches_any_pattern(result, expected_patterns)

    assert Process.alive?(manager_pid),
           "PluginManager should be alive after command execution: #{command_name}"
  end

  # Helper for asserting plugin load failures while ensuring manager liveness
  # Note: Mox expectations/stubs to cause the failure must be set up *before* calling this helper.
  defp assert_plugin_load_fails(
         manager_pid,
         plugin_module,
         load_opts,
         expected_error_result
       ) do
    actual_result = Manager.load_plugin(manager_pid, plugin_module, load_opts)

    assert actual_result == expected_error_result,
           "Expected loading #{inspect(plugin_module)} to result in #{inspect(expected_error_result)}, but got #{inspect(actual_result)}"

    assert Process.alive?(manager_pid),
           "PluginManager should be alive after a failed load of #{inspect(plugin_module)}"
  end
end
