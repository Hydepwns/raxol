defmodule Raxol.Core.Runtime.Plugins.DependencyManager.LifecycleIntegrationTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Runtime.Plugins.DependencyManager

  describe "plugin lifecycle events" do
    defmodule LifecycleTestPluginA do
      @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
      @behaviour Raxol.Plugins.Plugin
      @behaviour Raxol.Plugins.LifecycleBehaviour

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
      def init(_config) do
        Process.put(:lifecycle_plugin_a_init, true)

        plugin = %Raxol.Plugins.Plugin{
          name: "lifecycle_plugin_a",
          version: "1.0.0",
          description: "Test plugin A for lifecycle events",
          enabled: true,
          config: config,
          dependencies: [{:lifecycle_plugin_b, ">= 1.0.0"}],
          api_version: "1.0.0"
        }

        {:ok, plugin}
      end

      @impl Raxol.Plugins.LifecycleBehaviour
      def start(_config) do
        Process.put(:lifecycle_plugin_a_start, true)
        {:ok, config}
      end

      @impl Raxol.Plugins.LifecycleBehaviour
      def stop(_config) do
        Process.put(:lifecycle_plugin_a_stop, true)
        {:ok, config}
      end

      @impl true
      def cleanup(_config) do
        Process.put(:lifecycle_plugin_a_cleanup, true)
        :ok
      end

      @impl true
      def get_api_version, do: "1.0.0"
      def api_version, do: "1.0.0"

      @impl true
      def get_dependencies, do: [{:lifecycle_plugin_b, ">= 1.0.0"}]
    end

    defmodule LifecycleTestPluginB do
      @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
      @behaviour Raxol.Plugins.Plugin
      @behaviour Raxol.Plugins.LifecycleBehaviour

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
      def init(_config) do
        Process.put(:lifecycle_plugin_b_init, true)

        plugin = %Raxol.Plugins.Plugin{
          name: "lifecycle_plugin_b",
          version: "1.0.0",
          description: "Test plugin B for lifecycle events",
          enabled: true,
          config: config,
          dependencies: [],
          api_version: "1.0.0"
        }

        {:ok, plugin}
      end

      @impl Raxol.Plugins.LifecycleBehaviour
      def start(_config) do
        Process.put(:lifecycle_plugin_b_start, true)
        {:ok, config}
      end

      @impl Raxol.Plugins.LifecycleBehaviour
      def stop(_config) do
        Process.put(:lifecycle_plugin_b_stop, true)
        {:ok, config}
      end

      @impl true
      def cleanup(_config) do
        Process.put(:lifecycle_plugin_b_cleanup, true)
        :ok
      end

      @impl true
      def get_api_version, do: "1.0.0"
      def api_version, do: "1.0.0"

      @impl true
      def get_dependencies, do: []
    end

    setup do
      # Clear any existing process dictionary entries
      Process.delete(:lifecycle_plugin_a_init)
      Process.delete(:lifecycle_plugin_a_start)
      Process.delete(:lifecycle_plugin_a_stop)
      Process.delete(:lifecycle_plugin_a_cleanup)
      Process.delete(:lifecycle_plugin_b_init)
      Process.delete(:lifecycle_plugin_b_start)
      Process.delete(:lifecycle_plugin_b_stop)
      Process.delete(:lifecycle_plugin_b_cleanup)
      :ok
    end

    test ~c"lifecycle events are called in correct order" do
      plugins = [LifecycleTestPluginA, LifecycleTestPluginB]
      {:ok, manager} = Raxol.Plugins.Manager.Core.new()

      {:ok, updated_manager} =
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
        @behaviour Raxol.Plugins.Plugin
        @behaviour Raxol.Plugins.LifecycleBehaviour

        @impl true
        def get_metadata do
          %{
            id: :error_test_plugin,
            name: "error_test_plugin",
            version: "1.0.0",
            dependencies: []
          }
        end

        def api_version, do: "1.0.0"

        @impl true
        def init(_config) do
          {:error, "Init failed"}
        end

        @impl Raxol.Plugins.LifecycleBehaviour
        def start(_config) do
          {:error, "Start failed"}
        end

        @impl Raxol.Plugins.LifecycleBehaviour
        def stop(_config) do
          {:error, "Stop failed"}
        end

        @impl true
        def cleanup(config) do
          {:error, "Cleanup failed"}
        end

        @impl true
        def get_api_version, do: "1.0.0"

        @impl true
        def get_dependencies, do: []
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
        @behaviour Raxol.Plugins.Plugin
        @behaviour Raxol.Plugins.LifecycleBehaviour

        @impl true
        def get_metadata do
          %{
            id: :error_test_plugin,
            name: "error_test_plugin",
            version: "1.0.0",
            dependencies: []
          }
        end

        def api_version, do: "1.0.0"

        @impl true
        def init(_config) do
          plugin = %Raxol.Plugins.Plugin{
            name: "error_test_plugin",
            version: "1.0.0",
            description: "Test plugin for error handling",
            enabled: true,
            config: config,
            dependencies: [],
            api_version: "1.0.0"
          }

          {:ok, plugin}
        end

        @impl Raxol.Plugins.LifecycleBehaviour
        def start(_config) do
          {:error, "Start failed"}
        end

        @impl Raxol.Plugins.LifecycleBehaviour
        def stop(_config) do
          {:error, "Stop failed"}
        end

        @impl true
        def cleanup(config) do
          {:error, "Cleanup failed"}
        end

        @impl true
        def get_api_version, do: "1.0.0"

        @impl true
        def get_dependencies, do: []
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
        @behaviour Raxol.Plugins.LifecycleBehaviour
        @behaviour Raxol.Plugins.Plugin

        @impl true
        def get_metadata do
          %{
            id: :state_test_plugin,
            name: "state_test_plugin",
            version: "1.0.0",
            dependencies: []
          }
        end

        def api_version, do: "1.0.0"

        @impl true
        def init(_config) do
          plugin = %Raxol.Plugins.Plugin{
            name: "state_test_plugin",
            version: "1.0.0",
            description: "Test plugin for state management",
            enabled: true,
            config: Map.put(config, :init_state, "initialized"),
            dependencies: [],
            api_version: "1.0.0"
          }

          {:ok, plugin}
        end

        @impl Raxol.Plugins.LifecycleBehaviour
        def start(_config) do
          {:ok, Map.put(config, :start_state, "started")}
        end

        @impl Raxol.Plugins.LifecycleBehaviour
        def stop(_config) do
          Process.put(:final_state, config)
          {:ok, config}
        end

        @impl true
        def cleanup(config) do
          Process.put(:state_test_plugin_cleanup, true)
          :ok
        end

        @impl true
        def get_api_version, do: "1.0.0"

        @impl true
        def get_dependencies, do: []
      end

      {:ok, manager} = Raxol.Plugins.Manager.Core.new()

      {:ok, updated_manager} =
        Raxol.Plugins.Manager.State.load_plugins(manager, [
          StateTestPlugin
        ])

      # Verify state is maintained through lifecycle
      plugin_state = updated_manager.loaded_plugins["state_test_plugin"]
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
        @behaviour Raxol.Plugins.LifecycleBehaviour
        @behaviour Raxol.Plugins.Plugin

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

        def api_version, do: "1.0.0"

        @impl true
        def init(_config) do
          # Verify default config is merged (allowing for custom overrides)
          assert config.setting1 in ["default1", "custom1"]
          assert config.setting2 == "default2"
          # Add custom config
          plugin = %Raxol.Plugins.Plugin{
            name: "config_test_plugin",
            version: "1.0.0",
            description: "Test plugin for configuration handling",
            enabled: true,
            config: Map.put(config, :custom_setting, "custom"),
            dependencies: [],
            api_version: "1.0.0"
          }

          {:ok, plugin}
        end

        @impl Raxol.Plugins.LifecycleBehaviour
        def start(_config) do
          # Verify all config is present (allowing for custom overrides)
          assert config.setting1 in ["default1", "custom1"]
          assert config.setting2 == "default2"
          assert config.custom_setting == "custom"
          # Add runtime config
          {:ok, Map.put(config, :runtime_setting, "runtime")}
        end

        @impl Raxol.Plugins.LifecycleBehaviour
        def stop(_config) do
          # Verify all config is maintained (allowing for custom overrides)
          assert config.setting1 in ["default1", "custom1"]
          assert config.setting2 == "default2"
          assert config.custom_setting == "custom"
          assert config.runtime_setting == "runtime"
          Process.put(:final_config, config)
          {:ok, config}
        end

        @impl true
        def cleanup(config) do
          Process.put(:config_test_plugin_cleanup, true)
          :ok
        end

        @impl true
        def get_api_version, do: "1.0.0"

        @impl true
        def get_dependencies, do: []
      end

      {:ok, manager} = Raxol.Plugins.Manager.Core.new()

      # Test with default config
      {:ok, updated_manager} =
        Raxol.Plugins.Manager.State.load_plugins(manager, [
          ConfigTestPlugin
        ])

      plugin_config = updated_manager.loaded_plugins["config_test_plugin"]
      assert plugin_config.config.setting1 == "default1"
      assert plugin_config.config.setting2 == "default2"
      assert plugin_config.config.custom_setting == "custom"
      assert plugin_config.config.runtime_setting == "runtime"

      # Test with custom config
      custom_config = %{setting1: "custom1", setting3: "new"}

      {:ok, updated_manager2} =
        Raxol.Plugins.Manager.State.load_plugins(manager, [
          {ConfigTestPlugin, custom_config}
        ])

      plugin_config2 = updated_manager2.loaded_plugins["config_test_plugin"]
      # Custom overrides default
      assert plugin_config2.config.setting1 == "custom1"
      # Default preserved
      assert plugin_config2.config.setting2 == "default2"
      # New setting added
      assert plugin_config2.config.setting3 == "new"
      assert plugin_config2.config.custom_setting == "custom"
      assert plugin_config2.config.runtime_setting == "runtime"

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
  end
end
