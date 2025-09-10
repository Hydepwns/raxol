defmodule Raxol.Core.Runtime.Plugins.DependencyManager.CommunicationIntegrationTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Runtime.Plugins.DependencyManager
  alias Raxol.Core.Runtime.ProcessStore

  describe "plugin communication during lifecycle" do
    defmodule CommunicatingPluginA do
      @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
      @behaviour Raxol.Plugins.LifecycleBehaviour
      @behaviour Raxol.Plugins.Plugin

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
        ProcessStore.put(:plugin_a_init_message, "A initialized")

        plugin = %Raxol.Plugins.Plugin{
          name: "communicating_plugin_a",
          version: "1.0.0",
          description: "Test plugin A for communication",
          enabled: true,
          config: Map.put(config, :init_message, "A initialized"),
          dependencies: [{:communicating_plugin_b, ">= 1.0.0"}],
          api_version: "1.0.0"
        }

        {:ok, plugin}
      end

      @impl Raxol.Plugins.LifecycleBehaviour
      def start(config) do
        # Send message to plugin B during start
        ProcessStore.put(:plugin_a_start_message, "A started")
        {:ok, Map.put(config, :start_message, "A started")}
      end

      @impl Raxol.Plugins.LifecycleBehaviour
      def stop(config) do
        # Send message to plugin B during stop
        ProcessStore.put(:plugin_a_stop_message, "A stopped")
        {:ok, config}
      end

      @impl true
      def cleanup(config) do
        ProcessStore.put(:communicating_plugin_a_cleanup, true)
        :ok
      end

      @impl true
      def get_api_version, do: "1.0.0"

      @impl true
      def get_dependencies, do: [{:communicating_plugin_b, ">= 1.0.0"}]
    end

    defmodule CommunicatingPluginB do
      @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
      @behaviour Raxol.Plugins.LifecycleBehaviour
      @behaviour Raxol.Plugins.Plugin

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
        ProcessStore.put(:plugin_b_init_message, "B initialized")

        plugin = %Raxol.Plugins.Plugin{
          name: "communicating_plugin_b",
          version: "1.0.0",
          description: "Test plugin B for communication",
          enabled: true,
          config: Map.put(config, :init_message, "B initialized"),
          dependencies: [],
          api_version: "1.0.0"
        }

        {:ok, plugin}
      end

      @impl Raxol.Plugins.LifecycleBehaviour
      def start(config) do
        # Receive message from plugin A during start
        ProcessStore.put(:plugin_b_start_message, "B started")
        {:ok, Map.put(config, :start_message, "B started")}
      end

      @impl Raxol.Plugins.LifecycleBehaviour
      def stop(config) do
        # Receive message from plugin A during stop
        ProcessStore.put(:plugin_b_stop_message, "B stopped")
        {:ok, config}
      end

      @impl true
      def cleanup(config) do
        ProcessStore.put(:communicating_plugin_b_cleanup, true)
        :ok
      end

      @impl true
      def get_api_version, do: "1.0.0"

      @impl true
      def get_dependencies, do: []
    end

    test ~c"handles plugin communication during lifecycle" do
      {:ok, manager} = Raxol.Plugins.Manager.Core.new()

      # Load plugins
      {:ok, updated_manager} =
        Raxol.Plugins.Manager.State.load_plugins(manager, [
          CommunicatingPluginA,
          CommunicatingPluginB
        ])

      # Verify initialization communication
      assert ProcessStore.get(:plugin_b_init_message) == "B initialized"
      assert ProcessStore.get(:plugin_a_init_message) == "A initialized"

      # Verify startup communication
      assert ProcessStore.get(:plugin_b_start_message) == "B started"
      assert ProcessStore.get(:plugin_a_start_message) == "A started"

      # Verify plugin states
      plugin_a_state = updated_manager.loaded_plugins["communicating_plugin_a"]
      plugin_b_state = updated_manager.loaded_plugins["communicating_plugin_b"]

      assert plugin_a_state.config.init_message == "A initialized"
      assert plugin_a_state.config.start_message == "A started"
      assert plugin_b_state.config.init_message == "B initialized"
      assert plugin_b_state.config.start_message == "B started"

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
      assert ProcessStore.get(:plugin_a_stop_message) == "A stopped"
      assert ProcessStore.get(:plugin_b_stop_message) == "B stopped"
    end
  end
end
