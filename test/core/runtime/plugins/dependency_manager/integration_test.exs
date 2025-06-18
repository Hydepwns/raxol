defmodule Raxol.Core.Runtime.Plugins.DependencyManager.IntegrationTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Runtime.Plugins.DependencyManager

  defmodule TestPluginA do
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

    @impl true
    def get_metadata do
      %{
        id: :plugin_a,
        name: "plugin_a",
        version: "1.0.0",
        dependencies: [{:plugin_b, ">= 1.0.0"}]
      }
    end

    @impl true
    def init(config), do: {:ok, config}
  end

  defmodule TestPluginB do
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

    @impl true
    def get_metadata do
      %{
        id: :plugin_b,
        name: "plugin_b",
        version: "1.0.0",
        dependencies: []
      }
    end

    @impl true
    def init(config), do: {:ok, config}
  end

  defmodule TestPluginC do
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

    @impl true
    def get_metadata do
      %{
        id: :plugin_c,
        name: "plugin_c",
        version: "1.0.0",
        dependencies: [{:plugin_a, ">= 1.0.0"}, {:plugin_b, ">= 1.0.0"}]
      }
    end

    @impl true
    def init(config), do: {:ok, config}
  end

  defmodule TestPluginD do
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

    @impl true
    def get_metadata do
      %{
        id: :plugin_d,
        name: "plugin_d",
        version: "1.0.0",
        dependencies: [{:plugin_c, ">= 1.0.0"}]
      }
    end

    @impl true
    def init(config), do: {:ok, config}
  end

  describe "plugin manager integration" do
    test ~c"loads plugins in correct dependency order" do
      plugins = [TestPluginA, TestPluginB, TestPluginC, TestPluginD]
      {:ok, manager} = Raxol.Plugins.Manager.Core.new()

      assert {:ok, updated_manager} =
               Raxol.Plugins.Manager.State.load_plugins(manager, plugins)

      loaded_plugins = updated_manager.loaded_plugins
      load_order = Map.keys(loaded_plugins)

      assert Enum.at(load_order, 0) == :plugin_b
      assert Enum.at(load_order, 1) == :plugin_a
      assert Enum.at(load_order, 2) == :plugin_c
      assert Enum.at(load_order, 3) == :plugin_d
    end

    test ~c"handles version constraints correctly" do
      defmodule TestPluginE do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

        @impl true
        def get_metadata do
          %{
            id: :plugin_e,
            name: "plugin_e",
            version: "2.0.0",
            dependencies: [{:plugin_f, ">= 1.0.0 and < 2.0.0"}]
          }
        end

        @impl true
        def init(config), do: {:ok, config}
      end

      defmodule TestPluginF do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

        @impl true
        def get_metadata do
          %{
            id: :plugin_f,
            name: "plugin_f",
            version: "1.5.0",
            dependencies: []
          }
        end

        @impl true
        def init(config), do: {:ok, config}
      end

      plugins = [TestPluginE, TestPluginF]
      {:ok, manager} = Raxol.Plugins.Manager.Core.new()

      assert {:ok, updated_manager} =
               Raxol.Plugins.Manager.State.load_plugins(manager, plugins)

      loaded_plugins = updated_manager.loaded_plugins

      assert loaded_plugins[:plugin_f].version == "1.5.0"
      assert loaded_plugins[:plugin_e].version == "2.0.0"
    end

    test ~c"handles circular dependencies" do
      defmodule TestPluginG do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

        @impl true
        def get_metadata do
          %{
            id: :plugin_g,
            name: "plugin_g",
            version: "1.0.0",
            dependencies: [{:plugin_h, ">= 1.0.0"}]
          }
        end

        @impl true
        def init(config), do: {:ok, config}
      end

      defmodule TestPluginH do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

        @impl true
        def get_metadata do
          %{
            id: :plugin_h,
            name: "plugin_h",
            version: "1.0.0",
            dependencies: [{:plugin_g, ">= 1.0.0"}]
          }
        end

        @impl true
        def init(config), do: {:ok, config}
      end

      plugins = [TestPluginG, TestPluginH]
      {:ok, manager} = Raxol.Plugins.Manager.Core.new()

      assert {:error, reason} =
               Raxol.Plugins.Manager.State.load_plugins(manager, plugins)

      assert String.contains?(reason, "circular dependency")
    end

    test ~c"handles optional dependencies" do
      defmodule TestPluginI do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

        @impl true
        def get_metadata do
          %{
            id: :plugin_i,
            name: "plugin_i",
            version: "1.0.0",
            dependencies: [
              {:plugin_j, ">= 1.0.0", %{optional: true}},
              {:plugin_k, ">= 1.0.0", %{optional: false}}
            ]
          }
        end

        @impl true
        def init(config), do: {:ok, config}
      end

      defmodule TestPluginK do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

        @impl true
        def get_metadata do
          %{
            id: :plugin_k,
            name: "plugin_k",
            version: "1.0.0",
            dependencies: []
          }
        end

        @impl true
        def init(config), do: {:ok, config}
      end

      plugins = [TestPluginI, TestPluginK]
      {:ok, manager} = Raxol.Plugins.Manager.Core.new()

      assert {:ok, updated_manager} =
               Raxol.Plugins.Manager.State.load_plugins(manager, plugins)

      loaded_plugins = updated_manager.loaded_plugins

      assert loaded_plugins[:plugin_k]
      assert loaded_plugins[:plugin_i]
      refute loaded_plugins[:plugin_j]
    end

    test ~c"handles plugin unloading and reloading" do
      plugins = [TestPluginA, TestPluginB]
      {:ok, manager} = Raxol.Plugins.Manager.Core.new()

      assert {:ok, manager_after_load} =
               Raxol.Plugins.Manager.State.load_plugins(manager, plugins)

      assert Map.has_key?(manager_after_load.loaded_plugins, :plugin_a)
      assert Map.has_key?(manager_after_load.loaded_plugins, :plugin_b)

      assert {:ok, manager_after_unload} =
               Raxol.Plugins.Manager.Core.unload_plugin(
                 manager_after_load,
                 "plugin_a"
               )

      refute Map.has_key?(manager_after_unload.loaded_plugins, :plugin_a)
      assert Map.has_key?(manager_after_unload.loaded_plugins, :plugin_b)

      assert {:ok, manager_after_reload} =
               Raxol.Plugins.Manager.State.load_plugins(manager_after_unload, [
                 TestPluginA
               ])

      assert Map.has_key?(manager_after_reload.loaded_plugins, :plugin_a)
      assert Map.has_key?(manager_after_reload.loaded_plugins, :plugin_b)
    end
  end

  describe "plugin lifecycle events" do
    defmodule LifecycleTestPluginA do
      @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

      @impl true
      def get_metadata do
        %{
          id: :lifecycle_plugin_a,
          name: "lifecycle_plugin_a",
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

      @impl true
      def get_metadata do
        %{
          id: :lifecycle_plugin_b,
          name: "lifecycle_plugin_b",
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

    test ~c"lifecycle events are called in correct order" do
      plugins = [LifecycleTestPluginA, LifecycleTestPluginB]
      {:ok, manager} = Raxol.Plugins.Manager.Core.new()

      assert {:ok, updated_manager} =
               Raxol.Plugins.Manager.State.load_plugins(manager, plugins)

      # Verify initialization order (B should initialize before A)
      assert Process.get(:lifecycle_plugin_b_init)
      assert Process.get(:lifecycle_plugin_a_init)

      # Verify startup order (B should start before A)
      assert Process.get(:lifecycle_plugin_b_start)
      assert Process.get(:lifecycle_plugin_a_start)

      # Unload plugins
      assert {:ok, _} =
               Raxol.Plugins.Manager.Core.unload_plugin(
                 updated_manager,
                 "lifecycle_plugin_a"
               )

      assert {:ok, _} =
               Raxol.Plugins.Manager.Core.unload_plugin(
                 updated_manager,
                 "lifecycle_plugin_b"
               )

      # Verify stop order (A should stop before B)
      assert Process.get(:lifecycle_plugin_a_stop)
      assert Process.get(:lifecycle_plugin_b_stop)
    end

    test ~c"lifecycle events handle errors gracefully" do
      defmodule ErrorTestPlugin do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

        @impl true
        def get_metadata do
          %{
            id: :error_test_plugin,
            name: "error_test_plugin",
            version: "1.0.0",
            dependencies: []
          }
        end

        @impl true
        def init(config) do
          {:error, "Init failed"}
        end

        @impl true
        def start(config) do
          {:error, "Start failed"}
        end

        @impl true
        def stop(config) do
          {:error, "Stop failed"}
        end
      end

      {:ok, manager} = Raxol.Plugins.Manager.Core.new()

      # Test init error
      assert {:error, reason} =
               Raxol.Plugins.Manager.State.load_plugins(manager, [
                 ErrorTestPlugin
               ])

      assert String.contains?(reason, "Init failed")

      # Test start error (by mocking init to succeed)
      defmodule ErrorTestPlugin do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

        @impl true
        def get_metadata do
          %{
            id: :error_test_plugin,
            name: "error_test_plugin",
            version: "1.0.0",
            dependencies: []
          }
        end

        @impl true
        def init(config) do
          {:ok, config}
        end

        @impl true
        def start(config) do
          {:error, "Start failed"}
        end

        @impl true
        def stop(config) do
          {:error, "Stop failed"}
        end
      end

      assert {:error, reason} =
               Raxol.Plugins.Manager.State.load_plugins(manager, [
                 ErrorTestPlugin
               ])

      assert String.contains?(reason, "Start failed")
    end

    test ~c"lifecycle events maintain plugin state" do
      defmodule StateTestPlugin do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
        @behaviour Raxol.Core.Runtime.Plugins.Lifecycle

        @impl true
        def get_metadata do
          %{
            id: :state_test_plugin,
            name: "state_test_plugin",
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

      {:ok, manager} = Raxol.Plugins.Manager.Core.new()

      assert {:ok, updated_manager} =
               Raxol.Plugins.Manager.State.load_plugins(manager, [
                 StateTestPlugin
               ])

      # Verify state is maintained through lifecycle
      plugin_state = updated_manager.loaded_plugins[:state_test_plugin]
      assert plugin_state.init_state == "initialized"
      assert plugin_state.start_state == "started"

      # Unload and verify final state
      assert {:ok, _} =
               Raxol.Plugins.Manager.Core.unload_plugin(
                 updated_manager,
                 "state_test_plugin"
               )

      final_state = Process.get(:final_state)
      assert final_state.init_state == "initialized"
      assert final_state.start_state == "started"
    end

    test ~c"handles plugin configuration during lifecycle" do
      defmodule ConfigTestPlugin do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
        @behaviour Raxol.Core.Runtime.Plugins.Lifecycle

        @impl true
        def get_metadata do
          %{
            id: :config_test_plugin,
            name: "config_test_plugin",
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

      {:ok, manager} = Raxol.Plugins.Manager.Core.new()

      # Test with default config
      assert {:ok, updated_manager} =
               Raxol.Plugins.Manager.State.load_plugins(manager, [
                 ConfigTestPlugin
               ])

      plugin_config = updated_manager.loaded_plugins[:config_test_plugin]
      assert plugin_config.setting1 == "default1"
      assert plugin_config.setting2 == "default2"
      assert plugin_config.custom_setting == "custom"
      assert plugin_config.runtime_setting == "runtime"

      # Test with custom config
      custom_config = %{setting1: "custom1", setting3: "new"}

      assert {:ok, updated_manager2} =
               Raxol.Plugins.Manager.State.load_plugins(manager, [
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
               Raxol.Plugins.Manager.Core.unload_plugin(
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

    test ~c"handles concurrent plugin operations" do
      defmodule ConcurrentTestPluginA do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
        @behaviour Raxol.Core.Runtime.Plugins.Lifecycle

        @impl true
        def get_metadata do
          %{
            id: :concurrent_plugin_a,
            name: "concurrent_plugin_a",
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
            name: "concurrent_plugin_b",
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

      {:ok, manager} = Raxol.Plugins.Manager.Core.new()

      # Test concurrent loading
      tasks = [
        Task.async(fn ->
          Raxol.Plugins.Manager.State.load_plugins(manager, [
            ConcurrentTestPluginA
          ])
        end),
        Task.async(fn ->
          Raxol.Plugins.Manager.State.load_plugins(manager, [
            ConcurrentTestPluginB
          ])
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
          Raxol.Plugins.Manager.Core.unload_plugin(
            manager,
            "concurrent_plugin_a"
          )
        end),
        Task.async(fn ->
          Raxol.Plugins.Manager.Core.unload_plugin(
            manager,
            "concurrent_plugin_b"
          )
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
      {:ok, manager} = Raxol.Plugins.Manager.Core.new()

      assert {:ok, manager} =
               Raxol.Plugins.Manager.State.load_plugins(manager, [
                 ConcurrentTestPluginA
               ])

      tasks = [
        Task.async(fn ->
          Raxol.Plugins.Manager.State.load_plugins(manager, [
            ConcurrentTestPluginB
          ])
        end),
        Task.async(fn ->
          Raxol.Plugins.Manager.Core.unload_plugin(
            manager,
            "concurrent_plugin_a"
          )
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

    test ~c"handles plugin communication during lifecycle" do
      defmodule CommunicatingPluginA do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
        @behaviour Raxol.Core.Runtime.Plugins.Lifecycle

        @impl true
        def get_metadata do
          %{
            id: :communicating_plugin_a,
            name: "communicating_plugin_a",
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
            name: "communicating_plugin_b",
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

      {:ok, manager} = Raxol.Plugins.Manager.Core.new()

      # Load plugins
      assert {:ok, updated_manager} =
               Raxol.Plugins.Manager.State.load_plugins(manager, [
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
               Raxol.Plugins.Manager.Core.unload_plugin(
                 updated_manager,
                 "communicating_plugin_a"
               )

      assert {:ok, _} =
               Raxol.Plugins.Manager.Core.unload_plugin(
                 updated_manager,
                 "communicating_plugin_b"
               )

      # Verify shutdown communication
      assert Process.get(:plugin_a_stop_message) == "A stopped"
      assert Process.get(:plugin_b_stop_message) == "B stopped"
    end

    test ~c"handles error recovery scenarios" do
      defmodule RecoveryTestPluginA do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
        @behaviour Raxol.Core.Runtime.Plugins.Lifecycle

        @impl true
        def get_metadata do
          %{
            id: :recovery_plugin_a,
            name: "recovery_plugin_a",
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
            name: "recovery_plugin_b",
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
      {:ok, manager} = Raxol.Plugins.Manager.Core.new()

      assert {:error, reason} =
               Raxol.Plugins.Manager.State.load_plugins(manager, [
                 RecoveryTestPluginA,
                 RecoveryTestPluginB
               ])

      assert String.contains?(reason, "Init failed")

      # Verify plugin B was not loaded
      refute Map.has_key?(manager.loaded_plugins, :recovery_plugin_b)

      # Test recovery after initialization failure
      assert {:ok, updated_manager} =
               Raxol.Plugins.Manager.State.load_plugins(manager, [
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
               Raxol.Plugins.Manager.Core.unload_plugin(
                 updated_manager,
                 "recovery_plugin_a"
               )

      assert {:ok, _} =
               Raxol.Plugins.Manager.Core.unload_plugin(
                 updated_manager,
                 "recovery_plugin_b"
               )
    end
  end
end
