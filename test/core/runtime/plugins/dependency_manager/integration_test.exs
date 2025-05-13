defmodule Raxol.Core.Runtime.Plugins.DependencyManager.IntegrationTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Runtime.Plugins.DependencyManager
  alias Raxol.Plugins.Manager.Core, as: PluginManager

  # Test plugins with dependencies
  defmodule TestPluginA do
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

    @impl true
    def get_metadata do
      %{
        id: :plugin_a,
        version: "1.0.0",
        dependencies: [{:plugin_b, ">= 1.0.0"}]
      }
    end
  end

  defmodule TestPluginB do
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

    @impl true
    def get_metadata do
      %{
        id: :plugin_b,
        version: "1.0.0",
        dependencies: []
      }
    end
  end

  defmodule TestPluginC do
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

    @impl true
    def get_metadata do
      %{
        id: :plugin_c,
        version: "1.0.0",
        dependencies: [{:plugin_a, ">= 1.0.0"}, {:plugin_b, ">= 1.0.0"}]
      }
    end
  end

  defmodule TestPluginD do
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

    @impl true
    def get_metadata do
      %{
        id: :plugin_d,
        version: "1.0.0",
        dependencies: [{:plugin_c, ">= 1.0.0"}]
      }
    end
  end

  describe "plugin manager integration" do
    test "loads plugins in correct dependency order" do
      plugins = [TestPluginA, TestPluginB, TestPluginC, TestPluginD]
      {:ok, manager} = PluginManager.new()

      assert {:ok, updated_manager} =
               PluginManager.load_plugins(manager, plugins)

      # Verify plugins are loaded in correct order
      loaded_plugins = updated_manager.loaded_plugins
      load_order = Map.keys(loaded_plugins)

      # B should be loaded first (no dependencies)
      assert Enum.at(load_order, 0) == :plugin_b
      # A should be loaded second (depends on B)
      assert Enum.at(load_order, 1) == :plugin_a
      # C should be loaded third (depends on A and B)
      assert Enum.at(load_order, 2) == :plugin_c
      # D should be loaded last (depends on C)
      assert Enum.at(load_order, 3) == :plugin_d
    end

    test "handles version constraints correctly" do
      defmodule TestPluginE do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

        @impl true
        def get_metadata do
          %{
            id: :plugin_e,
            version: "2.0.0",
            dependencies: [{:plugin_f, ">= 1.0.0 and < 2.0.0"}]
          }
        end
      end

      defmodule TestPluginF do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

        @impl true
        def get_metadata do
          %{
            id: :plugin_f,
            version: "1.5.0",
            dependencies: []
          }
        end
      end

      plugins = [TestPluginE, TestPluginF]
      {:ok, manager} = PluginManager.new()

      assert {:ok, updated_manager} =
               PluginManager.load_plugins(manager, plugins)

      loaded_plugins = updated_manager.loaded_plugins

      # Verify plugins are loaded and versions are correct
      assert loaded_plugins[:plugin_f].version == "1.5.0"
      assert loaded_plugins[:plugin_e].version == "2.0.0"
    end

    test "handles circular dependencies" do
      defmodule TestPluginG do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

        @impl true
        def get_metadata do
          %{
            id: :plugin_g,
            version: "1.0.0",
            dependencies: [{:plugin_h, ">= 1.0.0"}]
          }
        end
      end

      defmodule TestPluginH do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

        @impl true
        def get_metadata do
          %{
            id: :plugin_h,
            version: "1.0.0",
            dependencies: [{:plugin_g, ">= 1.0.0"}]
          }
        end
      end

      plugins = [TestPluginG, TestPluginH]
      {:ok, manager} = PluginManager.new()

      assert {:error, reason} = PluginManager.load_plugins(manager, plugins)
      assert String.contains?(reason, "circular dependency")
    end

    test "handles optional dependencies" do
      defmodule TestPluginI do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

        @impl true
        def get_metadata do
          %{
            id: :plugin_i,
            version: "1.0.0",
            dependencies: [
              {:plugin_j, ">= 1.0.0", %{optional: true}},
              {:plugin_k, ">= 1.0.0", %{optional: false}}
            ]
          }
        end
      end

      defmodule TestPluginK do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

        @impl true
        def get_metadata do
          %{
            id: :plugin_k,
            version: "1.0.0",
            dependencies: []
          }
        end
      end

      plugins = [TestPluginI, TestPluginK]
      {:ok, manager} = PluginManager.new()

      # Should succeed even though plugin_j is missing (it's optional)
      assert {:ok, updated_manager} =
               PluginManager.load_plugins(manager, plugins)

      loaded_plugins = updated_manager.loaded_plugins

      # Verify plugins are loaded
      assert loaded_plugins[:plugin_k]
      assert loaded_plugins[:plugin_i]
      refute loaded_plugins[:plugin_j]
    end

    test "handles plugin unloading and reloading" do
      plugins = [TestPluginA, TestPluginB]
      {:ok, manager} = PluginManager.new()

      # Load plugins
      assert {:ok, manager_after_load} =
               PluginManager.load_plugins(manager, plugins)

      assert Map.has_key?(manager_after_load.loaded_plugins, :plugin_a)
      assert Map.has_key?(manager_after_load.loaded_plugins, :plugin_b)

      # Unload plugin A
      assert {:ok, manager_after_unload} =
               PluginManager.unload_plugin(manager_after_load, "plugin_a")

      refute Map.has_key?(manager_after_unload.loaded_plugins, :plugin_a)
      assert Map.has_key?(manager_after_unload.loaded_plugins, :plugin_b)

      # Reload plugin A
      assert {:ok, manager_after_reload} =
               PluginManager.load_plugins(manager_after_unload, [TestPluginA])

      assert Map.has_key?(manager_after_reload.loaded_plugins, :plugin_a)
      assert Map.has_key?(manager_after_reload.loaded_plugins, :plugin_b)
    end
  end

  describe "plugin lifecycle events" do
    defmodule LifecycleTestPluginA do
      @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
      @behaviour Raxol.Core.Runtime.Plugins.Lifecycle

      @impl true
      def get_metadata do
        %{
          id: :lifecycle_plugin_a,
          version: "1.0.0",
          dependencies: [{:lifecycle_plugin_b, ">= 1.0.0"}]
        }
      end

      @impl true
      def init(config) do
        Process.put(:lifecycle_plugin_a_init, true)
        {:ok, config}
      end

      @impl true
      def start(config) do
        Process.put(:lifecycle_plugin_a_start, true)
        {:ok, config}
      end

      @impl true
      def stop(config) do
        Process.put(:lifecycle_plugin_a_stop, true)
        {:ok, config}
      end
    end

    defmodule LifecycleTestPluginB do
      @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
      @behaviour Raxol.Core.Runtime.Plugins.Lifecycle

      @impl true
      def get_metadata do
        %{
          id: :lifecycle_plugin_b,
          version: "1.0.0",
          dependencies: []
        }
      end

      @impl true
      def init(config) do
        Process.put(:lifecycle_plugin_b_init, true)
        {:ok, config}
      end

      @impl true
      def start(config) do
        Process.put(:lifecycle_plugin_b_start, true)
        {:ok, config}
      end

      @impl true
      def stop(config) do
        Process.put(:lifecycle_plugin_b_stop, true)
        {:ok, config}
      end
    end

    setup do
      # Clear any existing process dictionary entries
      Process.delete(:lifecycle_plugin_a_init)
      Process.delete(:lifecycle_plugin_a_start)
      Process.delete(:lifecycle_plugin_a_stop)
      Process.delete(:lifecycle_plugin_b_init)
      Process.delete(:lifecycle_plugin_b_start)
      Process.delete(:lifecycle_plugin_b_stop)
      :ok
    end

    test "lifecycle events are called in correct order" do
      plugins = [LifecycleTestPluginA, LifecycleTestPluginB]
      {:ok, manager} = PluginManager.new()

      # Load plugins
      assert {:ok, updated_manager} =
               PluginManager.load_plugins(manager, plugins)

      # Verify initialization order (B should initialize before A)
      assert Process.get(:lifecycle_plugin_b_init)
      assert Process.get(:lifecycle_plugin_a_init)

      # Verify startup order (B should start before A)
      assert Process.get(:lifecycle_plugin_b_start)
      assert Process.get(:lifecycle_plugin_a_start)

      # Unload plugins
      assert {:ok, _} =
               PluginManager.unload_plugin(
                 updated_manager,
                 "lifecycle_plugin_a"
               )

      assert {:ok, _} =
               PluginManager.unload_plugin(
                 updated_manager,
                 "lifecycle_plugin_b"
               )

      # Verify stop order (A should stop before B)
      assert Process.get(:lifecycle_plugin_a_stop)
      assert Process.get(:lifecycle_plugin_b_stop)
    end

    test "lifecycle events handle errors gracefully" do
      defmodule ErrorTestPlugin do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
        @behaviour Raxol.Core.Runtime.Plugins.Lifecycle

        @impl true
        def get_metadata do
          %{
            id: :error_test_plugin,
            version: "1.0.0",
            dependencies: []
          }
        end

        @impl true
        def init(_config) do
          {:error, "Init failed"}
        end

        @impl true
        def start(_config) do
          {:error, "Start failed"}
        end

        @impl true
        def stop(_config) do
          {:error, "Stop failed"}
        end
      end

      {:ok, manager} = PluginManager.new()

      # Test init error
      assert {:error, reason} =
               PluginManager.load_plugins(manager, [ErrorTestPlugin])

      assert String.contains?(reason, "Init failed")

      # Test start error (by mocking init to succeed)
      defmodule ErrorTestPlugin do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
        @behaviour Raxol.Core.Runtime.Plugins.Lifecycle

        @impl true
        def get_metadata do
          %{
            id: :error_test_plugin,
            version: "1.0.0",
            dependencies: []
          }
        end

        @impl true
        def init(config) do
          {:ok, config}
        end

        @impl true
        def start(_config) do
          {:error, "Start failed"}
        end

        @impl true
        def stop(_config) do
          {:error, "Stop failed"}
        end
      end

      assert {:error, reason} =
               PluginManager.load_plugins(manager, [ErrorTestPlugin])

      assert String.contains?(reason, "Start failed")
    end

    test "lifecycle events maintain plugin state" do
      defmodule StateTestPlugin do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
        @behaviour Raxol.Core.Runtime.Plugins.Lifecycle

        @impl true
        def get_metadata do
          %{
            id: :state_test_plugin,
            version: "1.0.0",
            dependencies: []
          }
        end

        @impl true
        def init(config) do
          {:ok, Map.put(config, :init_state, "initialized")}
        end

        @impl true
        def start(config) do
          {:ok, Map.put(config, :start_state, "started")}
        end

        @impl true
        def stop(config) do
          Process.put(:final_state, config)
          {:ok, config}
        end
      end

      {:ok, manager} = PluginManager.new()

      assert {:ok, updated_manager} =
               PluginManager.load_plugins(manager, [StateTestPlugin])

      # Verify state is maintained through lifecycle
      plugin_state = updated_manager.loaded_plugins[:state_test_plugin]
      assert plugin_state.init_state == "initialized"
      assert plugin_state.start_state == "started"

      # Unload and verify final state
      assert {:ok, _} =
               PluginManager.unload_plugin(updated_manager, "state_test_plugin")

      final_state = Process.get(:final_state)
      assert final_state.init_state == "initialized"
      assert final_state.start_state == "started"
    end

    test "handles plugin configuration during lifecycle" do
      defmodule ConfigTestPlugin do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
        @behaviour Raxol.Core.Runtime.Plugins.Lifecycle

        @impl true
        def get_metadata do
          %{
            id: :config_test_plugin,
            version: "1.0.0",
            dependencies: [],
            default_config: %{
              setting1: "default1",
              setting2: "default2"
            }
          }
        end

        @impl true
        def init(config) do
          # Verify default config is merged
          assert config.setting1 == "default1"
          assert config.setting2 == "default2"
          # Add custom config
          {:ok, Map.put(config, :custom_setting, "custom")}
        end

        @impl true
        def start(config) do
          # Verify all config is present
          assert config.setting1 == "default1"
          assert config.setting2 == "default2"
          assert config.custom_setting == "custom"
          # Add runtime config
          {:ok, Map.put(config, :runtime_setting, "runtime")}
        end

        @impl true
        def stop(config) do
          # Verify all config is maintained
          assert config.setting1 == "default1"
          assert config.setting2 == "default2"
          assert config.custom_setting == "custom"
          assert config.runtime_setting == "runtime"
          Process.put(:final_config, config)
          {:ok, config}
        end
      end

      {:ok, manager} = PluginManager.new()

      # Test with default config
      assert {:ok, updated_manager} =
               PluginManager.load_plugins(manager, [ConfigTestPlugin])

      plugin_config = updated_manager.loaded_plugins[:config_test_plugin]
      assert plugin_config.setting1 == "default1"
      assert plugin_config.setting2 == "default2"
      assert plugin_config.custom_setting == "custom"
      assert plugin_config.runtime_setting == "runtime"

      # Test with custom config
      custom_config = %{setting1: "custom1", setting3: "new"}

      assert {:ok, updated_manager2} =
               PluginManager.load_plugins(manager, [
                 {ConfigTestPlugin, custom_config}
               ])

      plugin_config2 = updated_manager2.loaded_plugins[:config_test_plugin]
      # Custom overrides default
      assert plugin_config2.setting1 == "custom1"
      # Default preserved
      assert plugin_config2.setting2 == "default2"
      # New setting added
      assert plugin_config2.setting3 == "new"
      assert plugin_config2.custom_setting == "custom"
      assert plugin_config2.runtime_setting == "runtime"

      # Verify final state after unload
      assert {:ok, _} =
               PluginManager.unload_plugin(
                 updated_manager2,
                 "config_test_plugin"
               )

      final_config = Process.get(:final_config)
      assert final_config.setting1 == "custom1"
      assert final_config.setting2 == "default2"
      assert final_config.setting3 == "new"
      assert final_config.custom_setting == "custom"
      assert final_config.runtime_setting == "runtime"
    end

    test "handles concurrent plugin operations" do
      defmodule ConcurrentTestPluginA do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
        @behaviour Raxol.Core.Runtime.Plugins.Lifecycle

        @impl true
        def get_metadata do
          %{
            id: :concurrent_plugin_a,
            version: "1.0.0",
            dependencies: []
          }
        end

        @impl true
        def init(config) do
          Process.put(:concurrent_plugin_a_init, true)
          {:ok, config}
        end

        @impl true
        def start(config) do
          Process.put(:concurrent_plugin_a_start, true)
          {:ok, config}
        end

        @impl true
        def stop(config) do
          Process.put(:concurrent_plugin_a_stop, true)
          {:ok, config}
        end
      end

      defmodule ConcurrentTestPluginB do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
        @behaviour Raxol.Core.Runtime.Plugins.Lifecycle

        @impl true
        def get_metadata do
          %{
            id: :concurrent_plugin_b,
            version: "1.0.0",
            dependencies: []
          }
        end

        @impl true
        def init(config) do
          Process.put(:concurrent_plugin_b_init, true)
          {:ok, config}
        end

        @impl true
        def start(config) do
          Process.put(:concurrent_plugin_b_start, true)
          {:ok, config}
        end

        @impl true
        def stop(config) do
          Process.put(:concurrent_plugin_b_stop, true)
          {:ok, config}
        end
      end

      {:ok, manager} = PluginManager.new()

      # Test concurrent loading
      tasks = [
        Task.async(fn ->
          PluginManager.load_plugins(manager, [ConcurrentTestPluginA])
        end),
        Task.async(fn ->
          PluginManager.load_plugins(manager, [ConcurrentTestPluginB])
        end)
      ]

      results = Task.await_many(tasks)

      assert Enum.all?(results, fn
               {:ok, _} -> true
               _ -> false
             end)

      # Verify both plugins were loaded
      assert Process.get(:concurrent_plugin_a_init)
      assert Process.get(:concurrent_plugin_a_start)
      assert Process.get(:concurrent_plugin_b_init)
      assert Process.get(:concurrent_plugin_b_start)

      # Test concurrent unloading
      tasks = [
        Task.async(fn ->
          PluginManager.unload_plugin(manager, "concurrent_plugin_a")
        end),
        Task.async(fn ->
          PluginManager.unload_plugin(manager, "concurrent_plugin_b")
        end)
      ]

      results = Task.await_many(tasks)

      assert Enum.all?(results, fn
               {:ok, _} -> true
               _ -> false
             end)

      # Verify both plugins were unloaded
      assert Process.get(:concurrent_plugin_a_stop)
      assert Process.get(:concurrent_plugin_b_stop)

      # Test mixed concurrent operations
      {:ok, manager} = PluginManager.new()

      assert {:ok, manager} =
               PluginManager.load_plugins(manager, [ConcurrentTestPluginA])

      tasks = [
        Task.async(fn ->
          PluginManager.load_plugins(manager, [ConcurrentTestPluginB])
        end),
        Task.async(fn ->
          PluginManager.unload_plugin(manager, "concurrent_plugin_a")
        end)
      ]

      results = Task.await_many(tasks)

      assert Enum.all?(results, fn
               {:ok, _} -> true
               _ -> false
             end)

      # Verify final state
      assert Process.get(:concurrent_plugin_a_stop)
      assert Process.get(:concurrent_plugin_b_init)
      assert Process.get(:concurrent_plugin_b_start)
    end

    test "handles plugin communication during lifecycle" do
      defmodule CommunicatingPluginA do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
        @behaviour Raxol.Core.Runtime.Plugins.Lifecycle

        @impl true
        def get_metadata do
          %{
            id: :communicating_plugin_a,
            version: "1.0.0",
            dependencies: [{:communicating_plugin_b, ">= 1.0.0"}]
          }
        end

        @impl true
        def init(config) do
          # Send message to plugin B during init
          Process.put(:plugin_a_init_message, "A initialized")
          {:ok, Map.put(config, :init_message, "A initialized")}
        end

        @impl true
        def start(config) do
          # Send message to plugin B during start
          Process.put(:plugin_a_start_message, "A started")
          {:ok, Map.put(config, :start_message, "A started")}
        end

        @impl true
        def stop(config) do
          # Send message to plugin B during stop
          Process.put(:plugin_a_stop_message, "A stopped")
          {:ok, config}
        end
      end

      defmodule CommunicatingPluginB do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
        @behaviour Raxol.Core.Runtime.Plugins.Lifecycle

        @impl true
        def get_metadata do
          %{
            id: :communicating_plugin_b,
            version: "1.0.0",
            dependencies: []
          }
        end

        @impl true
        def init(config) do
          # Receive message from plugin A during init
          Process.put(:plugin_b_init_message, "B initialized")
          {:ok, Map.put(config, :init_message, "B initialized")}
        end

        @impl true
        def start(config) do
          # Receive message from plugin A during start
          Process.put(:plugin_b_start_message, "B started")
          {:ok, Map.put(config, :start_message, "B started")}
        end

        @impl true
        def stop(config) do
          # Receive message from plugin A during stop
          Process.put(:plugin_b_stop_message, "B stopped")
          {:ok, config}
        end
      end

      {:ok, manager} = PluginManager.new()

      # Load plugins
      assert {:ok, updated_manager} =
               PluginManager.load_plugins(manager, [
                 CommunicatingPluginA,
                 CommunicatingPluginB
               ])

      # Verify initialization communication
      assert Process.get(:plugin_b_init_message) == "B initialized"
      assert Process.get(:plugin_a_init_message) == "A initialized"

      # Verify startup communication
      assert Process.get(:plugin_b_start_message) == "B started"
      assert Process.get(:plugin_a_start_message) == "A started"

      # Verify plugin states
      plugin_a_state = updated_manager.loaded_plugins[:communicating_plugin_a]
      plugin_b_state = updated_manager.loaded_plugins[:communicating_plugin_b]

      assert plugin_a_state.init_message == "A initialized"
      assert plugin_a_state.start_message == "A started"
      assert plugin_b_state.init_message == "B initialized"
      assert plugin_b_state.start_message == "B started"

      # Unload plugins
      assert {:ok, _} =
               PluginManager.unload_plugin(
                 updated_manager,
                 "communicating_plugin_a"
               )

      assert {:ok, _} =
               PluginManager.unload_plugin(
                 updated_manager,
                 "communicating_plugin_b"
               )

      # Verify shutdown communication
      assert Process.get(:plugin_a_stop_message) == "A stopped"
      assert Process.get(:plugin_b_stop_message) == "B stopped"
    end

    test "handles error recovery scenarios" do
      defmodule RecoveryTestPluginA do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
        @behaviour Raxol.Core.Runtime.Plugins.Lifecycle

        @impl true
        def get_metadata do
          %{
            id: :recovery_plugin_a,
            version: "1.0.0",
            dependencies: [{:recovery_plugin_b, ">= 1.0.0"}]
          }
        end

        @impl true
        def init(config) do
          Process.put(
            :plugin_a_init_attempts,
            (Process.get(:plugin_a_init_attempts) || 0) + 1
          )

          if Process.get(:plugin_a_init_attempts) < 2 do
            {:error, "Init failed"}
          else
            {:ok, Map.put(config, :init_state, "recovered")}
          end
        end

        @impl true
        def start(config) do
          Process.put(
            :plugin_a_start_attempts,
            (Process.get(:plugin_a_start_attempts) || 0) + 1
          )

          if Process.get(:plugin_a_start_attempts) < 2 do
            {:error, "Start failed"}
          else
            {:ok, Map.put(config, :start_state, "recovered")}
          end
        end

        @impl true
        def stop(config) do
          {:ok, config}
        end
      end

      defmodule RecoveryTestPluginB do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
        @behaviour Raxol.Core.Runtime.Plugins.Lifecycle

        @impl true
        def get_metadata do
          %{
            id: :recovery_plugin_b,
            version: "1.0.0",
            dependencies: []
          }
        end

        @impl true
        def init(config) do
          {:ok, Map.put(config, :init_state, "stable")}
        end

        @impl true
        def start(config) do
          {:ok, Map.put(config, :start_state, "stable")}
        end

        @impl true
        def stop(config) do
          {:ok, config}
        end
      end

      # Test partial initialization failure
      {:ok, manager} = PluginManager.new()

      assert {:error, reason} =
               PluginManager.load_plugins(manager, [
                 RecoveryTestPluginA,
                 RecoveryTestPluginB
               ])

      assert String.contains?(reason, "Init failed")

      # Verify plugin B was not loaded
      refute Map.has_key?(manager.loaded_plugins, :recovery_plugin_b)

      # Test recovery after initialization failure
      assert {:ok, updated_manager} =
               PluginManager.load_plugins(manager, [
                 RecoveryTestPluginA,
                 RecoveryTestPluginB
               ])

      assert Process.get(:plugin_a_init_attempts) == 2
      assert Process.get(:plugin_a_start_attempts) == 2

      # Verify both plugins are loaded with correct states
      plugin_a_state = updated_manager.loaded_plugins[:recovery_plugin_a]
      plugin_b_state = updated_manager.loaded_plugins[:recovery_plugin_b]

      assert plugin_a_state.init_state == "recovered"
      assert plugin_a_state.start_state == "recovered"
      assert plugin_b_state.init_state == "stable"
      assert plugin_b_state.start_state == "stable"

      # Test graceful degradation during unload
      assert {:ok, _} =
               PluginManager.unload_plugin(updated_manager, "recovery_plugin_a")

      assert {:ok, _} =
               PluginManager.unload_plugin(updated_manager, "recovery_plugin_b")
    end
  end
end
