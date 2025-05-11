defmodule Raxol.Core.Runtime.Plugins.PluginManagerEdgeCasesTest do
  use ExUnit.Case
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
    for: Raxol.Core.Runtime.Plugins.LifecycleHelper.Behaviour
  )

  setup do
    # Reset Mox for each test
    Mox.stub_with(EdgeCasesLifecycleHelperMock, LifecycleHelper)
    Mox.verify_on_exit!()

    # Create a unique ETS table name for each test
    table_name = :"command_registry_#{:rand.uniform(1000000)}"
    :ets.new(table_name, [:set, :public, :named_table, read_concurrency: true])

    # Store the table name in the test context
    {:ok, %{command_registry_table: table_name}}
  end

  describe "plugin loading errors" do
    test "handles plugin init failure gracefully", %{command_registry_table: table} do
      with_running_manager([command_registry_table: table], fn manager_pid ->
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
          {:error, {:init_failed, :init_failed}}
        )
      end)
    end

    test "handles plugin module loading errors", %{command_registry_table: table} do
      with_running_manager([command_registry_table: table], fn manager_pid ->
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
          {:error, {:module_load_failed, :not_found}}
        )
      end)
    end

    test "handles dependency resolution failures", %{command_registry_table: table} do
      with_running_manager([command_registry_table: table], fn manager_pid ->
        # Setup: LifecycleHelper will check dependencies
        Mox.expect(EdgeCasesLifecycleHelperMock, :check_dependencies, fn
          _plugin_id,
          %{dependencies: [{"missing_plugin", ">= 1.0.0"}]},
          _available_plugins ->
            {:error, :missing_dependencies, ["missing_plugin"], ["my_plugin"]}

          _plugin_id,
          %{dependencies: [{"version_mismatch", ">= 2.0.0"}]},
          _available_plugins ->
            {:error, :version_mismatch, [{"version_mismatch", "1.0.0", ">= 2.0.0"}], ["my_plugin"]}

          _plugin_id,
          %{dependencies: [{"circular_dependency", ">= 1.0.0"}]},
          _available_plugins ->
            {:error, :circular_dependency, ["circular_dependency", "my_plugin"], ["my_plugin", "circular_dependency"]}

          # Default case
          _plugin_id, _metadata, _available_plugins ->
            {:ok}
        end)

        # Test missing dependency
        assert_plugin_load_fails(
          manager_pid,
          PluginTestFixtures.DependentPlugin,
          %{},
          {:error, {:dependency_check_failed, {:missing_dependencies, ["missing_plugin"], ["my_plugin"]}}}
        )

        # Test version mismatch
        assert_plugin_load_fails(
          manager_pid,
          PluginTestFixtures.VersionMismatchPlugin,
          %{},
          {:error, {:dependency_check_failed, {:version_mismatch, [{"version_mismatch", "1.0.0", ">= 2.0.0"}], ["my_plugin"]}}}
        )

        # Test circular dependency
        assert_plugin_load_fails(
          manager_pid,
          PluginTestFixtures.CircularDependencyPlugin,
          %{},
          {:error, {:dependency_check_failed, {:circular_dependency, ["circular_dependency", "my_plugin"], ["my_plugin", "circular_dependency"]}}}
        )
      end)
    end

    test "handles plugin init timeout (simulated via mock)", %{command_registry_table: table} do
      with_running_manager([command_registry_table: table], fn manager_pid ->
        # Configure EdgeCasesLifecycleHelperMock to simulate a hanging init_plugin
        Mox.stub_with(EdgeCasesLifecycleHelperMock, %{
          init_plugin: fn _module, _opts ->
            # Use a timer to simulate a timeout that matches the actual timeout in the code
            Process.send_after(self(), :timeout_simulated, 6000)
            receive do
              :timeout_simulated -> {:error, :timeout_simulated}
            end
          end,
          check_dependencies: fn _, _, _ -> {:ok, []} end,
          terminate_plugin: fn _, _, _ -> :ok end
        })

        assert_plugin_load_fails(
          manager_pid,
          PluginTestFixtures.TestPlugin,
          %{},
          {:error, :init_timeout}
        )
      end)
    end

    test "handles plugin command execution errors (BadReturnPlugin)", %{command_registry_table: table} do
      with_running_manager([command_registry_table: table], fn manager_pid ->
        # Load BadReturnPlugin using the setup_plugin helper
        assert {:ok, _loaded_state} =
                 setup_plugin(
                   manager_pid,
                   PluginTestFixtures.BadReturnPlugin,
                   :bad_return_plugin,
                   %{}
                 )

        # Test command execution with proper error handling
        execute_command_and_verify(
          manager_pid,
          :bad_return_plugin,
          :bad_return_cmd,
          ["test_arg"],
          [
            {:error, {:unexpected_plugin_return, :unexpected_return}},
            {:error, {:command_error, :bad_return_plugin, :bad_return_cmd, :unexpected_return}},
            {:error, :command_failed}
          ]
        )

        # Test input handler with proper error handling
        execute_command_and_verify(
          manager_pid,
          :bad_return_plugin,
          :handle_input,
          ["test_input"],
          [
            {:error, {:unexpected_plugin_return, :not_ok}},
            {:error, {:command_error, :bad_return_plugin, :handle_input, :not_ok}},
            {:error, :command_failed}
          ]
        )

        # Test output handler with proper error handling
        execute_command_and_verify(
          manager_pid,
          :bad_return_plugin,
          :handle_output,
          ["test_output"],
          [
            {:error, {:unexpected_plugin_return, [:not, :a, :tuple]}},
            {:error, {:command_error, :bad_return_plugin, :handle_output, [:not, :a, :tuple]}},
            {:error, :command_failed}
          ]
        )
      end)
    end

    test "handles plugin command not found", %{command_registry_table: table} do
      with_running_manager([command_registry_table: table], fn manager_pid ->
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
            {:error, {:command_error, :test_plugin, :non_existent_cmd, :not_found}},
            {:error, {:command_not_found, :test_plugin, :non_existent_cmd}},
            {:error, :command_not_found}
          ]
        )
      end)
    end

    test "handles invalid plugin metadata", %{command_registry_table: table} do
      with_running_manager([command_registry_table: table], fn manager_pid ->
        # Setup: Loader will return invalid metadata
        Mox.expect(Loader, :load_plugin_metadata, fn
          PluginTestFixtures.InvalidMetadataPlugin ->
            {:ok, %{
              id: nil,  # Invalid: missing required field
              version: "not_a_semver",  # Invalid: not a valid semver
              dependencies: [
                {:invalid_dependency, "invalid_version"},  # Invalid: wrong format
                {:missing_required_field, nil},  # Invalid: missing required field
                {:invalid_type, 123}  # Invalid: wrong type
              ],
              # Missing required fields
              name: nil,
              description: nil,
              author: nil
            }}
          # Default case
          _ -> {:ok, %{id: :test, version: "1.0.0", dependencies: []}}
        end)

        # Test loading with invalid metadata
        assert_plugin_load_fails(
          manager_pid,
          PluginTestFixtures.InvalidMetadataPlugin,
          %{},
          {:error, {:invalid_metadata, [
            :missing_required_field,
            :invalid_version_format,
            :invalid_dependency_format,
            :invalid_field_type
          ]}}
        )

        # Verify the plugin was not loaded
        assert {:error, :plugin_not_found} = Manager.get_plugin(:invalid_metadata_plugin)
      end)
    end
  end

  describe "plugin event handling edge cases" do
    test "handles plugin input handler crashes", %{command_registry_table: table} do
      with_running_manager([command_registry_table: table], fn manager_pid ->
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
          %{},
          "PluginManager GenServer should remain alive after a plugin's input handler crashes (triggered by command)"
        )
      end)
    end

    test "handles plugin output handler crashes", %{command_registry_table: table} do
      with_running_manager([command_registry_table: table], fn manager_pid ->
        crashing_plugin_module = PluginTestFixtures.CrashingPlugin
        crashing_plugin_id = :crashing_plugin
        crashing_plugin_namespace = :crashing_plugin_commands

        # Load the crashing plugin
        assert {:ok, _} =
                 setup_plugin(
                   manager_pid,
                   crashing_plugin_module,
                   crashing_plugin_id,
                   %{crash_on: :output}
                 )

        # Send output event that should trigger crash
        output = "test output"
        result = Manager.process_output(manager_pid, output)

        # Verify manager handles crash gracefully
        assert {:ok, _manager, ^output} = result
        assert Process.alive?(manager_pid)

        # Verify event was logged
        assert_receive {:log, :warning, "Plugin " <> _}, 1000
      end)
    end

    test "handles plugin mouse handler crashes", %{command_registry_table: table} do
      with_running_manager([command_registry_table: table], fn manager_pid ->
        crashing_plugin_module = PluginTestFixtures.CrashingPlugin
        crashing_plugin_id = :crashing_plugin
        crashing_plugin_namespace = :crashing_plugin_commands

        # Load the crashing plugin
        assert {:ok, _} =
                 setup_plugin(
                   manager_pid,
                   crashing_plugin_module,
                   crashing_plugin_id,
                   %{crash_on: :mouse}
                 )

        # Send mouse event that should trigger crash
        event = {:click, 10, 20, :left}
        result = Manager.process_mouse(manager_pid, event, %{})

        # Verify manager handles crash gracefully
        assert {:ok, _manager} = result
        assert Process.alive?(manager_pid)

        # Verify event was logged
        assert_receive {:log, :warning, "Plugin " <> _}, 1000
      end)
    end

    test "handles plugin placeholder handler crashes", %{command_registry_table: table} do
      with_running_manager([command_registry_table: table], fn manager_pid ->
        crashing_plugin_module = PluginTestFixtures.CrashingPlugin
        crashing_plugin_id = :crashing_plugin
        crashing_plugin_namespace = :crashing_plugin_commands

        # Load the crashing plugin
        assert {:ok, _} =
                 setup_plugin(
                   manager_pid,
                   crashing_plugin_module,
                   crashing_plugin_id,
                   %{crash_on: :placeholder}
                 )

        # Send placeholder event that should trigger crash
        result = Manager.process_placeholder(manager_pid, "chart", "data", %{})

        # Verify manager handles crash gracefully
        assert {:ok, _manager, nil} = result
        assert Process.alive?(manager_pid)

        # Verify event was logged
        assert_receive {:log, :warning, "Plugin " <> _}, 1000
      end)
    end

    test "handles invalid return values from event handlers", %{command_registry_table: table} do
      with_running_manager([command_registry_table: table], fn manager_pid ->
        # Load the bad return plugin
        assert {:ok, _} =
                 setup_plugin(
                   manager_pid,
                   PluginTestFixtures.BadReturnPlugin,
                   :bad_return_plugin,
                   %{}
                 )

        # Test input handler with invalid return
        result = Manager.process_input(manager_pid, "test input")
        assert {:ok, _manager} = result
        assert Process.alive?(manager_pid)
        assert_receive {:log, :warning, "Plugin " <> _}, 1000

        # Test output handler with invalid return
        result = Manager.process_output(manager_pid, "test output")
        assert {:ok, _manager, "test output"} = result
        assert Process.alive?(manager_pid)
        assert_receive {:log, :warning, "Plugin " <> _}, 1000

        # Test mouse handler with invalid return
        result = Manager.process_mouse(manager_pid, {:click, 10, 20, :left}, %{})
        assert {:ok, _manager} = result
        assert Process.alive?(manager_pid)
        assert_receive {:log, :warning, "Plugin " <> _}, 1000

        # Test placeholder handler with invalid return
        result = Manager.process_placeholder(manager_pid, "chart", "data", %{})
        assert {:ok, _manager, nil} = result
        assert Process.alive?(manager_pid)
        assert_receive {:log, :warning, "Plugin " <> _}, 1000
      end)
    end
  end

  describe "plugin reloading edge cases" do
    test "handles reload failures gracefully", %{command_registry_table: table} do
      with_running_manager([command_registry_table: table], fn manager_pid ->
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

    test "handles reload failures gracefully when trying to reload a non-existent plugin", %{command_registry_table: table} do
      with_running_manager([command_registry_table: table], fn manager_pid ->
        # Execute: Try to reload a non-existent plugin
        result = Manager.reload_plugin(manager_pid, :non_existent_plugin)

        # Verify: Reload should fail
        assert {:error, :plugin_not_found} = result
        assert Process.alive?(manager_pid)
      end)
    end
  end

  describe "concurrent operations" do
    test "handles concurrent plugin operations", %{command_registry_table: table} do
      with_running_manager([command_registry_table: table], fn manager_pid ->
        # Define concurrent operations
        ops = [
          # Load plugins
          fn -> setup_plugin(manager_pid, PluginTestFixtures.TestPlugin, :test_plugin, %{}) end,
          fn -> setup_plugin(manager_pid, PluginTestFixtures.DependentPlugin, :dependent_plugin, %{}) end,
          # Process events
          fn -> Manager.process_input(manager_pid, "test input") end,
          fn -> Manager.process_output(manager_pid, "test output") end,
          fn -> Manager.process_mouse(manager_pid, {:click, 10, 20, :left}, %{}) end,
          fn -> Manager.process_placeholder(manager_pid, "chart", "data", %{}) end,
          # Execute commands
          fn -> Manager.execute_command(manager_pid, :test_plugin, :test_cmd, ["payload"]) end,
          fn -> Manager.execute_command(manager_pid, :dependent_plugin, :dependent_cmd, ["payload"]) end
        ]

        # Execute operations concurrently
        tasks =
          for _ <- 1..10 do
            Task.async(fn ->
              # Pick a random operation and execute it
              op = Enum.random(ops)
              op.()
            end)
          end

        # Wait for all tasks to complete
        results = Task.await_many(tasks, 5000)

        # Verify all operations completed
        assert Enum.all?(results, fn
          {:ok, _} -> true
          {:ok, _, _} -> true
          {:error, _} -> true
          _ -> false
        end)

        # Verify manager is still alive
        assert Process.alive?(manager_pid)
      end)
    end
  end

  describe "plugin termination errors" do
    test "handles plugin terminate failure gracefully", %{command_registry_table: table} do
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
      {:ok, pid} = Manager.start_link([command_registry_table: table])
      {:error, reason} = Manager.load_plugin(PluginTestFixtures.TestPlugin, %{})

      # Verify: Should handle the terminate failure gracefully
      assert reason == :terminate_failed

      # Verify: Manager is still alive
      assert Process.alive?(pid)

      # Cleanup
      if Process.alive?(pid), do: GenServer.stop(pid)
    end

    test "handles plugin terminate timeout (simulated)", %{command_registry_table: table} do
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
          # Instead of infinite sleep, wait for a message that will never come
          receive do
            :terminate_plugin -> :ok
          end
        end
      })

      # Start Manager and load TestPlugin
      {:ok, pid} = Manager.start_link([command_registry_table: table])
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

  # --- Helper Functions ---

  defp setup_plugin(
         manager_pid,
         plugin_module,
         plugin_id_atom,
         initial_opts \\ %{}
       ) do
    plugin_init_fun = fn mod, opts ->
      # First try init/1, then fall back to init!/1 if init/1 is not defined
      initial_plugin_state =
        try do
          apply(mod, :init, [opts])
        rescue
          UndefinedFunctionError -> apply(mod, :init!, [opts])
        end

      # Handle both {:ok, state} and direct state returns
      resolved_state =
        case initial_plugin_state do
          {:ok, state} -> state
          state when is_map(state) -> state
          _ -> raise "Plugin init must return {:ok, state} or a state map"
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

  defp dispatch_command_and_assert_manager_alive(manager_pid, command_name, namespace, data, assertion_message) do
    GenServer.cast(
      manager_pid,
      {:handle_command, command_name, namespace, data, self()}
    )

    # Wait for command processing to complete with a more reasonable timeout
    assert_receive {:command_processed, ^manager_pid, ^command_name}, 5000
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

    # Wait for command processing to complete with a more reasonable timeout
    assert_receive {:command_processed, ^manager_pid, ^command_name}, 5000

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

    # Wait for plugin load attempt to complete with a more reasonable timeout
    assert_receive {:plugin_load_attempted, ^manager_pid, ^plugin_module}, 5000

    assert actual_result == expected_error_result,
           "Expected loading #{inspect(plugin_module)} to result in #{inspect(expected_error_result)}, but got #{inspect(actual_result)}"

    assert Process.alive?(manager_pid),
           "PluginManager should be alive after a failed load of #{inspect(plugin_module)}"
  end
end
