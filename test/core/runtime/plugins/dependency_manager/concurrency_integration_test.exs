defmodule Raxol.Core.Runtime.Plugins.DependencyManager.ConcurrencyIntegrationTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Runtime.Plugins.DependencyManager

  describe "concurrent plugin operations" do
    defmodule ConcurrentTestPluginA do
      @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
      @behaviour Raxol.Plugins.LifecycleBehaviour
      @behaviour Raxol.Plugins.Plugin

      @impl true
      def get_metadata do
        %{
          id: :concurrent_plugin_a,
          name: "concurrent_plugin_a",
          version: "1.0.0",
          dependencies: []
        }
      end

      def api_version, do: "1.0.0"

      @impl true
      def init(config) do
        # Use a global registry to track initialization
        :ets.insert(:plugin_test_registry, {:concurrent_plugin_a_init, true})

        plugin = %Raxol.Plugins.Plugin{
          name: "concurrent_plugin_a",
          version: "1.0.0",
          description: "Test plugin A for concurrent operations",
          enabled: true,
          config: config,
          dependencies: [],
          api_version: "1.0.0"
        }

        {:ok, plugin}
      end

      @impl Raxol.Plugins.LifecycleBehaviour
      def start(config) do
        :ets.insert(:plugin_test_registry, {:concurrent_plugin_a_start, true})
        {:ok, config}
      end

      @impl Raxol.Plugins.LifecycleBehaviour
      def stop(config) do
        :ets.insert(:plugin_test_registry, {:concurrent_plugin_a_stop, true})
        {:ok, config}
      end

      @impl true
      def cleanup(config) do
        :ets.insert(
          :plugin_test_registry,
          {:concurrent_plugin_a_cleanup, true}
        )

        :ok
      end

      @impl true
      def get_api_version, do: "1.0.0"

      @impl true
      def get_dependencies, do: []
    end

    defmodule ConcurrentTestPluginB do
      @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
      @behaviour Raxol.Plugins.LifecycleBehaviour
      @behaviour Raxol.Plugins.Plugin

      @impl true
      def get_metadata do
        %{
          id: :concurrent_plugin_b,
          name: "concurrent_plugin_b",
          version: "1.0.0",
          dependencies: []
        }
      end

      def api_version, do: "1.0.0"

      @impl true
      def init(config) do
        :ets.insert(:plugin_test_registry, {:concurrent_plugin_b_init, true})

        plugin = %Raxol.Plugins.Plugin{
          name: "concurrent_plugin_b",
          version: "1.0.0",
          description: "Test plugin B for concurrent operations",
          enabled: true,
          config: config,
          dependencies: [],
          api_version: "1.0.0"
        }

        {:ok, plugin}
      end

      @impl Raxol.Plugins.LifecycleBehaviour
      def start(config) do
        :ets.insert(:plugin_test_registry, {:concurrent_plugin_b_start, true})
        {:ok, config}
      end

      @impl Raxol.Plugins.LifecycleBehaviour
      def stop(config) do
        :ets.insert(:plugin_test_registry, {:concurrent_plugin_b_stop, true})
        {:ok, config}
      end

      @impl true
      def cleanup(config) do
        :ets.insert(
          :plugin_test_registry,
          {:concurrent_plugin_b_cleanup, true}
        )

        :ok
      end

      @impl true
      def get_api_version, do: "1.0.0"

      @impl true
      def get_dependencies, do: []
    end

    test ~c"handles concurrent plugin operations" do
      # Setup test registry
      :ets.new(:plugin_test_registry, [:named_table, :set, :public])

      # Test concurrent loading with separate manager instances
      tasks = [
        Task.async(fn ->
          {:ok, manager_a} = Raxol.Plugins.Manager.Core.new()

          Raxol.Plugins.Manager.State.load_plugins(manager_a, [
            ConcurrentTestPluginA
          ])
        end),
        Task.async(fn ->
          {:ok, manager_b} = Raxol.Plugins.Manager.Core.new()

          Raxol.Plugins.Manager.State.load_plugins(manager_b, [
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
      assert :ets.lookup(:plugin_test_registry, :concurrent_plugin_a_init) == [
               concurrent_plugin_a_init: true
             ]

      assert :ets.lookup(:plugin_test_registry, :concurrent_plugin_a_start) == [
               concurrent_plugin_a_start: true
             ]

      assert :ets.lookup(:plugin_test_registry, :concurrent_plugin_b_init) == [
               concurrent_plugin_b_init: true
             ]

      assert :ets.lookup(:plugin_test_registry, :concurrent_plugin_b_start) == [
               concurrent_plugin_b_start: true
             ]

      # Test concurrent unloading with separate manager instances
      tasks = [
        Task.async(fn ->
          {:ok, manager_a} = Raxol.Plugins.Manager.Core.new()

          {:ok, manager_a} =
            Raxol.Plugins.Manager.State.load_plugins(manager_a, [
              ConcurrentTestPluginA
            ])

          Raxol.Plugins.Manager.Core.unload_plugin(
            manager_a,
            "concurrent_plugin_a"
          )
        end),
        Task.async(fn ->
          {:ok, manager_b} = Raxol.Plugins.Manager.Core.new()

          {:ok, manager_b} =
            Raxol.Plugins.Manager.State.load_plugins(manager_b, [
              ConcurrentTestPluginB
            ])

          Raxol.Plugins.Manager.Core.unload_plugin(
            manager_b,
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
      assert :ets.lookup(:plugin_test_registry, :concurrent_plugin_a_stop) == [
               concurrent_plugin_a_stop: true
             ]

      assert :ets.lookup(:plugin_test_registry, :concurrent_plugin_b_stop) == [
               concurrent_plugin_b_stop: true
             ]

      # Test mixed concurrent operations with separate manager instances
      {:ok, manager_a} = Raxol.Plugins.Manager.Core.new()
      {:ok, manager_b} = Raxol.Plugins.Manager.Core.new()

      assert {:ok, manager_a} =
               Raxol.Plugins.Manager.State.load_plugins(manager_a, [
                 ConcurrentTestPluginA
               ])

      tasks = [
        Task.async(fn ->
          Raxol.Plugins.Manager.State.load_plugins(manager_b, [
            ConcurrentTestPluginB
          ])
        end),
        Task.async(fn ->
          Raxol.Plugins.Manager.Core.unload_plugin(
            manager_a,
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
      assert :ets.lookup(:plugin_test_registry, :concurrent_plugin_a_stop) == [
               concurrent_plugin_a_stop: true
             ]

      assert :ets.lookup(:plugin_test_registry, :concurrent_plugin_b_init) == [
               concurrent_plugin_b_init: true
             ]

      assert :ets.lookup(:plugin_test_registry, :concurrent_plugin_b_start) == [
               concurrent_plugin_b_start: true
             ]

      # Cleanup
      :ets.delete(:plugin_test_registry)
    end
  end
end
