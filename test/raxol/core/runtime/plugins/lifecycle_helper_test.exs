defmodule Raxol.Core.Runtime.Plugins.LifecycleHelperTest do
  use ExUnit.Case, async: true
  import Mox

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  # Define mocks
  # Use global Raxol.Core.Runtime.Plugins.LoaderMock defined in test_helper.exs
  defmock(DependencyManagerMock,
    for: Raxol.Core.Runtime.Plugins.DependencyManager.Behaviour
  )

  defmock(CommandHelperMock,
    for: Raxol.Core.Runtime.Plugins.CommandHelper.Behaviour
  )

  alias Raxol.Core.Runtime.Plugins.LifecycleHelper

  setup do
    # Setup test plugin and initial state
    plugin_id = :test_plugin
    plugin_module = TestPlugin
    config = %{test: true}
    initial_state = %{counter: 0, data: "test"}

    # Setup initial maps
    plugins = %{plugin_id => plugin_module}
    metadata = %{plugin_id => %{status: :active}}
    plugin_states = %{plugin_id => initial_state}
    load_order = [plugin_id]
    command_table = %{}
    plugin_config = %{plugin_id => config}

    %{
      plugin_id: plugin_id,
      plugin_module: plugin_module,
      config: config,
      initial_state: initial_state,
      plugins: plugins,
      metadata: metadata,
      plugin_states: plugin_states,
      load_order: load_order,
      command_table: command_table,
      plugin_config: plugin_config
    }
  end

  describe "load_plugin/8" do
    test "loads plugin by ID successfully" do
      # Setup test data
      plugin_id = "test_plugin"
      plugin_module = TestPlugin
      config = %{setting: "value"}

      state_maps = %{
        plugins: %{},
        metadata: %{},
        plugin_states: %{},
        load_order: [],
        plugin_config: %{}
      }

      command_table = :test_command_table

      # Expect Loader to load code
      expect(
        Raxol.Core.Runtime.Plugins.LoaderMock,
        :load_code,
        fn ^plugin_module -> :ok end
      )

      # Expect Loader to extract metadata
      expect(
        Raxol.Core.Runtime.Plugins.LoaderMock,
        :extract_metadata,
        fn ^plugin_module ->
          %{id: plugin_id, version: "1.0.0"}
        end
      )

      # Expect DependencyManager to check dependencies
      expect(DependencyManagerMock, :check_dependencies, fn ^plugin_id, _, _ ->
        :ok
      end)

      # Expect Loader to check behaviour implementation
      expect(
        Raxol.Core.Runtime.Plugins.LoaderMock,
        :behaviour_implemented?,
        fn ^plugin_module, Plugin ->
          true
        end
      )

      # Expect Loader to initialize plugin
      expect(
        Raxol.Core.Runtime.Plugins.LoaderMock,
        :initialize_plugin,
        fn ^plugin_module, ^config ->
          {:ok, %{initialized: true}}
        end
      )

      # Expect CommandHelper to register commands
      expect(CommandHelperMock, :register_plugin_commands, fn ^plugin_module,
                                                              _,
                                                              ^command_table ->
        :ok
      end)

      # Call the function
      {:ok, updated_maps} =
        LifecycleHelper.load_plugin(
          plugin_id,
          config,
          state_maps.plugins,
          state_maps.metadata,
          state_maps.plugin_states,
          state_maps.load_order,
          command_table,
          state_maps.plugin_config
        )

      # Verify results
      assert updated_maps.plugins == %{plugin_id => plugin_module}

      assert updated_maps.metadata == %{
               plugin_id => %{id: plugin_id, version: "1.0.0"}
             }

      assert updated_maps.plugin_states == %{plugin_id => %{initialized: true}}
      assert updated_maps.load_order == [plugin_id]
      assert updated_maps.plugin_config == %{plugin_id => config}
    end

    test "loads plugin by module successfully" do
      # Setup test data
      plugin_module = TestPlugin
      plugin_id = "test_plugin"
      config = %{setting: "value"}

      state_maps = %{
        plugins: %{},
        metadata: %{},
        plugin_states: %{},
        load_order: [],
        plugin_config: %{}
      }

      command_table = :test_command_table

      # Expect Loader to extract metadata
      expect(
        Raxol.Core.Runtime.Plugins.LoaderMock,
        :extract_metadata,
        fn ^plugin_module ->
          %{id: plugin_id, version: "1.0.0"}
        end
      )

      # Expect DependencyManager to check dependencies
      expect(DependencyManagerMock, :check_dependencies, fn ^plugin_id, _, _ ->
        :ok
      end)

      # Expect Loader to check behaviour implementation
      expect(
        Raxol.Core.Runtime.Plugins.LoaderMock,
        :behaviour_implemented?,
        fn ^plugin_module, Plugin ->
          true
        end
      )

      # Expect Loader to initialize plugin
      expect(
        Raxol.Core.Runtime.Plugins.LoaderMock,
        :initialize_plugin,
        fn ^plugin_module, ^config ->
          {:ok, %{initialized: true}}
        end
      )

      # Expect CommandHelper to register commands
      expect(CommandHelperMock, :register_plugin_commands, fn ^plugin_module,
                                                              _,
                                                              ^command_table ->
        :ok
      end)

      # Call the function
      {:ok, updated_maps} =
        LifecycleHelper.load_plugin(
          plugin_module,
          config,
          state_maps.plugins,
          state_maps.metadata,
          state_maps.plugin_states,
          state_maps.load_order,
          command_table,
          state_maps.plugin_config
        )

      # Verify results
      assert updated_maps.plugins == %{plugin_id => plugin_module}

      assert updated_maps.metadata == %{
               plugin_id => %{id: plugin_id, version: "1.0.0"}
             }

      assert updated_maps.plugin_states == %{plugin_id => %{initialized: true}}
      assert updated_maps.load_order == [plugin_id]
      assert updated_maps.plugin_config == %{plugin_id => config}
    end

    test "handles already loaded plugin" do
      # Setup test data
      plugin_id = "test_plugin"
      plugin_module = TestPlugin

      state_maps = %{
        plugins: %{plugin_id => plugin_module},
        metadata: %{},
        plugin_states: %{},
        load_order: [],
        plugin_config: %{}
      }

      # Call the function
      {:error, :already_loaded} =
        LifecycleHelper.load_plugin(
          plugin_id,
          %{},
          state_maps.plugins,
          state_maps.metadata,
          state_maps.plugin_states,
          state_maps.load_order,
          :test_command_table,
          state_maps.plugin_config
        )
    end

    test "handles missing dependencies" do
      # Setup test data
      plugin_id = "test_plugin"
      plugin_module = TestPlugin

      state_maps = %{
        plugins: %{},
        metadata: %{},
        plugin_states: %{},
        load_order: [],
        plugin_config: %{}
      }

      # Expect Loader to load code
      expect(
        Raxol.Core.Runtime.Plugins.LoaderMock,
        :load_code,
        fn ^plugin_module -> :ok end
      )

      # Expect Loader to extract metadata
      expect(
        Raxol.Core.Runtime.Plugins.LoaderMock,
        :extract_metadata,
        fn ^plugin_module ->
          %{id: plugin_id, version: "1.0.0", dependencies: ["missing_plugin"]}
        end
      )

      # Expect DependencyManager to check dependencies
      expect(DependencyManagerMock, :check_dependencies, fn ^plugin_id, _, _ ->
        {:error, :missing_dependencies, ["missing_plugin"]}
      end)

      # Call the function
      {:error, :missing_dependencies, ["missing_plugin"]} =
        LifecycleHelper.load_plugin(
          plugin_id,
          %{},
          state_maps.plugins,
          state_maps.metadata,
          state_maps.plugin_states,
          state_maps.load_order,
          :test_command_table,
          state_maps.plugin_config
        )
    end

    test "handles init failure" do
      # Setup test data
      plugin_id = "test_plugin"
      plugin_module = TestPlugin

      state_maps = %{
        plugins: %{},
        metadata: %{},
        plugin_states: %{},
        load_order: [],
        plugin_config: %{}
      }

      # Expect Loader to load code
      expect(
        Raxol.Core.Runtime.Plugins.LoaderMock,
        :load_code,
        fn ^plugin_module -> :ok end
      )

      # Expect Loader to extract metadata
      expect(
        Raxol.Core.Runtime.Plugins.LoaderMock,
        :extract_metadata,
        fn ^plugin_module ->
          %{id: plugin_id, version: "1.0.0"}
        end
      )

      # Expect DependencyManager to check dependencies
      expect(DependencyManagerMock, :check_dependencies, fn ^plugin_id, _, _ ->
        :ok
      end)

      # Expect Loader to check behaviour implementation
      expect(
        Raxol.Core.Runtime.Plugins.LoaderMock,
        :behaviour_implemented?,
        fn ^plugin_module, Plugin ->
          true
        end
      )

      # Expect Loader to initialize plugin and fail
      expect(
        Raxol.Core.Runtime.Plugins.LoaderMock,
        :initialize_plugin,
        fn ^plugin_module, _ ->
          {:error, :init_failed}
        end
      )

      # Call the function
      {:error, {:init_failed, :init_failed}} =
        LifecycleHelper.load_plugin(
          plugin_id,
          %{},
          state_maps.plugins,
          state_maps.metadata,
          state_maps.plugin_states,
          state_maps.load_order,
          :test_command_table,
          state_maps.plugin_config
        )
    end
  end

  describe "unload_plugin/2" do
    test "unloads plugin successfully" do
      # Setup test data
      plugin_id = "test_plugin"
      plugin_module = TestPlugin

      state_maps = %{
        plugins: %{plugin_id => plugin_module},
        metadata: %{plugin_id => %{version: "1.0.0"}},
        plugin_states: %{plugin_id => %{initialized: true}},
        load_order: [plugin_id],
        plugin_config: %{plugin_id => %{setting: "value"}}
      }

      command_table = :test_command_table

      # Expect CommandHelper to unregister commands
      expect(CommandHelperMock, :unregister_plugin_commands, fn ^plugin_module,
                                                                ^command_table ->
        :ok
      end)

      # Call the function
      {:ok, updated_maps} =
        LifecycleHelper.unload_plugin(plugin_id, state_maps, command_table)

      # Verify results
      assert updated_maps.plugins == %{}
      assert updated_maps.metadata == %{}
      assert updated_maps.plugin_states == %{}
      assert updated_maps.load_order == []
      assert updated_maps.plugin_config == %{}
    end

    test "handles non-existent plugin" do
      # Setup test data
      state_maps = %{
        plugins: %{},
        metadata: %{},
        plugin_states: %{},
        load_order: [],
        plugin_config: %{}
      }

      # Call the function
      {:error, :plugin_not_found} =
        LifecycleHelper.unload_plugin(
          "unknown_plugin",
          state_maps,
          :test_command_table
        )
    end
  end

  describe "reload_plugin_from_disk/8" do
    test "successfully reloads plugin with state persistence", %{
      plugin_id: plugin_id,
      config: config,
      plugins: plugins,
      metadata: metadata,
      plugin_states: plugin_states,
      load_order: load_order,
      command_table: command_table,
      plugin_config: plugin_config
    } do
      # Mock the necessary functions
      expect(TestPlugin, :init, fn cfg ->
        assert Map.has_key?(cfg, :previous_state)
        {:ok, %{counter: 1, data: "reloaded"}}
      end)

      # Reload the plugin
      assert {:ok, updated_maps} =
               LifecycleHelper.reload_plugin_from_disk(
                 plugin_id,
                 config,
                 plugins,
                 metadata,
                 plugin_states,
                 load_order,
                 command_table,
                 plugin_config
               )

      # Verify state persistence
      assert updated_maps.plugin_states[plugin_id].counter == 1
      assert updated_maps.plugin_states[plugin_id].data == "reloaded"
      assert updated_maps.metadata[plugin_id].status == :active
    end

    test "handles plugin not found", %{
      config: config,
      plugins: plugins,
      metadata: metadata,
      plugin_states: plugin_states,
      load_order: load_order,
      command_table: command_table,
      plugin_config: plugin_config
    } do
      assert {:error, :plugin_not_found} =
               LifecycleHelper.reload_plugin_from_disk(
                 :non_existent_plugin,
                 config,
                 plugins,
                 metadata,
                 plugin_states,
                 load_order,
                 command_table,
                 plugin_config
               )
    end

    test "handles initialization failure", %{
      plugin_id: plugin_id,
      config: config,
      plugins: plugins,
      metadata: metadata,
      plugin_states: plugin_states,
      load_order: load_order,
      command_table: command_table,
      plugin_config: plugin_config
    } do
      # Mock initialization failure
      expect(TestPlugin, :init, fn _cfg -> {:error, :init_failed} end)

      assert {:error, :init_failed} =
               LifecycleHelper.reload_plugin_from_disk(
                 plugin_id,
                 config,
                 plugins,
                 metadata,
                 plugin_states,
                 load_order,
                 command_table,
                 plugin_config
               )
    end

    test "handles dependency check failure", %{
      plugin_id: plugin_id,
      config: config,
      plugins: plugins,
      metadata: metadata,
      plugin_states: plugin_states,
      load_order: load_order,
      command_table: command_table,
      plugin_config: plugin_config
    } do
      # Mock dependency check failure
      expect(DependencyManagerMock, :check_dependencies, fn _, _, _ ->
        {:error, :dependency_failed}
      end)

      assert {:error, :dependency_failed} =
               LifecycleHelper.reload_plugin_from_disk(
                 plugin_id,
                 config,
                 plugins,
                 metadata,
                 plugin_states,
                 load_order,
                 command_table,
                 plugin_config
               )
    end

    test "handles command registration failure", %{
      plugin_id: plugin_id,
      config: config,
      plugins: plugins,
      metadata: metadata,
      plugin_states: plugin_states,
      load_order: load_order,
      command_table: command_table,
      plugin_config: plugin_config
    } do
      # Mock successful initialization
      expect(TestPlugin, :init, fn _cfg -> {:ok, %{counter: 1}} end)

      # Mock command registration failure
      expect(CommandHelperMock, :register_plugin_commands, fn _, _, _ ->
        {:error, :registration_failed}
      end)

      assert {:error, :registration_failed} =
               LifecycleHelper.reload_plugin_from_disk(
                 plugin_id,
                 config,
                 plugins,
                 metadata,
                 plugin_states,
                 load_order,
                 command_table,
                 plugin_config
               )
    end
  end

  describe "plugin version compatibility" do
    test "handles incompatible plugin version", %{command_registry_table: table} do
      # Setup test data
      plugin_id = "test_plugin"
      plugin_module = TestPlugin
      config = %{setting: "value"}

      state_maps = %{
        plugins: %{},
        metadata: %{},
        plugin_states: %{},
        load_order: [],
        plugin_config: %{}
      }

      # Expect Loader to extract metadata with incompatible version
      expect(
        Raxol.Core.Runtime.Plugins.LoaderMock,
        :extract_metadata,
        fn ^plugin_module ->
          %{id: plugin_id, version: "2.0.0", min_api_version: "2.0.0"}
        end
      )

      # Call the function with current API version 1.0.0
      {:error, :incompatible_version} =
        LifecycleHelper.load_plugin(
          plugin_id,
          config,
          state_maps.plugins,
          state_maps.metadata,
          state_maps.plugin_states,
          state_maps.load_order,
          table,
          state_maps.plugin_config,
          # Current API version
          "1.0.0"
        )
    end

    test "handles compatible plugin version", %{command_registry_table: table} do
      # Setup test data
      plugin_id = "test_plugin"
      plugin_module = TestPlugin
      config = %{setting: "value"}

      state_maps = %{
        plugins: %{},
        metadata: %{},
        plugin_states: %{},
        load_order: [],
        plugin_config: %{}
      }

      # Expect Loader to extract metadata with compatible version
      expect(
        Raxol.Core.Runtime.Plugins.LoaderMock,
        :extract_metadata,
        fn ^plugin_module ->
          %{id: plugin_id, version: "1.0.0", min_api_version: "1.0.0"}
        end
      )

      # Expect other necessary mocks
      expect(
        Raxol.Core.Runtime.Plugins.LoaderMock,
        :behaviour_implemented?,
        fn ^plugin_module, Plugin -> true end
      )

      expect(
        Raxol.Core.Runtime.Plugins.LoaderMock,
        :initialize_plugin,
        fn ^plugin_module, ^config ->
          {:ok, %{initialized: true}}
        end
      )

      expect(CommandHelperMock, :register_plugin_commands, fn ^plugin_module,
                                                              _,
                                                              ^table ->
        :ok
      end)

      # Call the function with current API version 1.0.0
      {:ok, updated_maps} =
        LifecycleHelper.load_plugin(
          plugin_id,
          config,
          state_maps.plugins,
          state_maps.metadata,
          state_maps.plugin_states,
          state_maps.load_order,
          table,
          state_maps.plugin_config,
          # Current API version
          "1.0.0"
        )

      # Verify results
      assert updated_maps.plugins == %{plugin_id => plugin_module}

      assert updated_maps.metadata == %{
               plugin_id => %{
                 id: plugin_id,
                 version: "1.0.0",
                 min_api_version: "1.0.0"
               }
             }
    end
  end

  describe "plugin state persistence" do
    test "preserves plugin state during reload", %{
      command_registry_table: table
    } do
      # Setup test data
      plugin_id = "test_plugin"
      plugin_module = TestPlugin
      initial_state = %{counter: 1, data: "test"}
      config = %{setting: "value"}

      state_maps = %{
        plugins: %{plugin_id => plugin_module},
        metadata: %{plugin_id => %{version: "1.0.0"}},
        plugin_states: %{plugin_id => initial_state},
        load_order: [plugin_id],
        plugin_config: %{plugin_id => config}
      }

      # Expect CommandHelper to unregister commands
      expect(CommandHelperMock, :unregister_plugin_commands, fn ^plugin_module,
                                                                ^table ->
        :ok
      end)

      # Expect Loader to purge and recompile module
      expect(
        Raxol.Core.Runtime.Plugins.LoaderMock,
        :purge_module,
        fn ^plugin_module -> :ok end
      )

      expect(
        Raxol.Core.Runtime.Plugins.LoaderMock,
        :recompile_module,
        fn ^plugin_module -> :ok end
      )

      # Expect Loader to extract metadata
      expect(
        Raxol.Core.Runtime.Plugins.LoaderMock,
        :extract_metadata,
        fn ^plugin_module ->
          %{id: plugin_id, version: "1.0.1"}
        end
      )

      # Expect Loader to initialize plugin with preserved state
      expect(
        Raxol.Core.Runtime.Plugins.LoaderMock,
        :initialize_plugin,
        fn ^plugin_module, ^config ->
          {:ok, %{initial_state | counter: 2}}
        end
      )

      # Expect CommandHelper to register commands
      expect(CommandHelperMock, :register_plugin_commands, fn ^plugin_module,
                                                              _,
                                                              ^table ->
        :ok
      end)

      # Call the function
      {:ok, updated_maps} =
        LifecycleHelper.reload_plugin_from_disk(
          plugin_id,
          config,
          state_maps.plugins,
          state_maps.metadata,
          state_maps.plugin_states,
          state_maps.load_order,
          table,
          state_maps.plugin_config
        )

      # Verify results
      assert updated_maps.plugin_states[plugin_id].counter == 2
      assert updated_maps.plugin_states[plugin_id].data == "test"
    end
  end

  describe "plugin cleanup" do
    test "performs complete cleanup on unload", %{command_registry_table: table} do
      # Setup test data
      plugin_id = "test_plugin"
      plugin_module = TestPlugin

      state_maps = %{
        plugins: %{plugin_id => plugin_module},
        metadata: %{plugin_id => %{version: "1.0.0"}},
        plugin_states: %{plugin_id => %{initialized: true}},
        load_order: [plugin_id],
        plugin_config: %{plugin_id => %{setting: "value"}}
      }

      # Expect CommandHelper to unregister commands
      expect(CommandHelperMock, :unregister_plugin_commands, fn ^plugin_module,
                                                                ^table ->
        :ok
      end)

      # Expect Loader to cleanup resources
      expect(
        Raxol.Core.Runtime.Plugins.LoaderMock,
        :cleanup_plugin,
        fn ^plugin_module -> :ok end
      )

      # Call the function
      {:ok, updated_maps} =
        LifecycleHelper.unload_plugin(plugin_id, state_maps, table)

      # Verify results
      assert updated_maps.plugins == %{}
      assert updated_maps.metadata == %{}
      assert updated_maps.plugin_states == %{}
      assert updated_maps.load_order == []
      assert updated_maps.plugin_config == %{}
    end
  end

  describe "plugin dependency resolution" do
    test "loads plugins in correct dependency order", %{
      command_registry_table: table
    } do
      # Setup test data
      plugin_a = "plugin_a"
      plugin_b = "plugin_b"
      plugin_c = "plugin_c"
      config = %{setting: "value"}

      state_maps = %{
        plugins: %{},
        metadata: %{},
        plugin_states: %{},
        load_order: [],
        plugin_config: %{}
      }

      # Setup dependency chain: C depends on B depends on A
      expect(Raxol.Core.Runtime.Plugins.LoaderMock, :extract_metadata, fn
        ^plugin_c ->
          %{
            id: plugin_c,
            version: "1.0.0",
            dependencies: [{"plugin_b", ">= 1.0.0"}]
          }

        ^plugin_b ->
          %{
            id: plugin_b,
            version: "1.0.0",
            dependencies: [{"plugin_a", ">= 1.0.0"}]
          }

        ^plugin_a ->
          %{id: plugin_a, version: "1.0.0", dependencies: []}
      end)

      # Expect initialization for each plugin
      for plugin <- [plugin_a, plugin_b, plugin_c] do
        expect(
          Raxol.Core.Runtime.Plugins.LoaderMock,
          :initialize_plugin,
          fn ^plugin, ^config ->
            {:ok, %{initialized: true}}
          end
        )

        expect(CommandHelperMock, :register_plugin_commands, fn ^plugin,
                                                                _,
                                                                ^table ->
          :ok
        end)
      end

      # Load plugins in any order
      {:ok, maps_after_a} =
        LifecycleHelper.load_plugin(
          plugin_a,
          config,
          state_maps.plugins,
          state_maps.metadata,
          state_maps.plugin_states,
          state_maps.load_order,
          table,
          state_maps.plugin_config
        )

      {:ok, maps_after_b} =
        LifecycleHelper.load_plugin(
          plugin_b,
          config,
          maps_after_a.plugins,
          maps_after_a.metadata,
          maps_after_a.plugin_states,
          maps_after_a.load_order,
          table,
          maps_after_a.plugin_config
        )

      {:ok, maps_after_c} =
        LifecycleHelper.load_plugin(
          plugin_c,
          config,
          maps_after_b.plugins,
          maps_after_b.metadata,
          maps_after_b.plugin_states,
          maps_after_b.load_order,
          table,
          maps_after_b.plugin_config
        )

      # Verify load order
      assert maps_after_c.load_order == [plugin_a, plugin_b, plugin_c]
    end
  end

  describe "plugin initialization timeout" do
    test "handles plugin initialization timeout", %{
      command_registry_table: table
    } do
      # Setup test data
      plugin_id = "test_plugin"
      plugin_module = TestPlugin
      config = %{setting: "value"}

      state_maps = %{
        plugins: %{},
        metadata: %{},
        plugin_states: %{},
        load_order: [],
        plugin_config: %{}
      }

      # Expect Loader to extract metadata
      expect(
        Raxol.Core.Runtime.Plugins.LoaderMock,
        :extract_metadata,
        fn ^plugin_module ->
          %{id: plugin_id, version: "1.0.0"}
        end
      )

      # Expect Loader to initialize plugin with timeout
      expect(
        Raxol.Core.Runtime.Plugins.LoaderMock,
        :initialize_plugin,
        fn ^plugin_module, ^config ->
          # Instead of sleep, send a message to self after delay
          Process.send_after(self(), :init_complete, 100)

          receive do
            :init_complete -> {:ok, %{initialized: true}}
          end
        end
      )

      # Call the function with short timeout
      {:error, :init_timeout} =
        LifecycleHelper.load_plugin(
          plugin_id,
          config,
          state_maps.plugins,
          state_maps.metadata,
          state_maps.plugin_states,
          state_maps.load_order,
          table,
          state_maps.plugin_config,
          # Short timeout
          timeout: 50
        )
    end
  end
end
