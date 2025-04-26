defmodule Raxol.Core.Runtime.Plugins.ManagerTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Runtime.Plugins.Manager

  # Mock plugin for testing
  defmodule TestPlugin do
    def init(opts) do
      {:ok, Map.put(opts, :initialized, true)}
    end

    def enable(state) do
      {:ok, Map.put(state, :enabled, true)}
    end

    def disable(state) do
      {:ok, Map.put(state, :enabled, false)}
    end

    def unload(state) do
      send(self(), {:plugin_unloaded, state})
      :ok
    end
  end

  setup do
    # Start Manager process with clean state for each test
    start_supervised!(Manager)
    :ok
  end

  describe "plugin_manager" do
    test "initialize starts with empty plugin list" do
      :ok = Manager.initialize()
      assert [] = Manager.list_plugins()
    end

    test "loads discovered plugins" do
      # Mock the private discover_plugins function to return our test plugin
      :meck.new(Manager, [:passthrough])

      :meck.expect(Manager, :discover_plugins, fn ->
        [{"test_plugin", %{name: "Test Plugin", version: "1.0.0"}, TestPlugin}]
      end)

      :ok = Manager.initialize()
      plugins = Manager.list_plugins()

      assert length(plugins) == 1
      plugin = List.first(plugins)
      assert plugin.id == "test_plugin"
      assert plugin.metadata.name == "Test Plugin"

      :meck.unload(Manager)
    end

    test "get_plugin returns plugin data" do
      # Mock the private functions to return our test plugin
      :meck.new(Manager, [:passthrough])

      :meck.expect(Manager, :discover_plugins, fn ->
        [{"test_plugin", %{name: "Test Plugin", version: "1.0.0"}, TestPlugin}]
      end)

      # Initialize with our test plugin
      :ok = Manager.initialize()

      # Get the plugin
      {:ok, plugin_data} = Manager.get_plugin("test_plugin")

      assert plugin_data.metadata.name == "Test Plugin"
      assert plugin_data.metadata.version == "1.0.0"

      :meck.unload(Manager)
    end

    test "enable_plugin and disable_plugin change plugin state" do
      # Mock the private functions and plugin storage
      :meck.new(Manager, [:passthrough])

      :meck.expect(Manager, :discover_plugins, fn ->
        [{"test_plugin", %{name: "Test Plugin"}, TestPlugin}]
      end)

      # Initialize and mock the internal state
      :ok = Manager.initialize()

      # Test enabling plugin (would actually call the plugin module in real code)
      :ok = Manager.enable_plugin("test_plugin")
      {:ok, plugin_data} = Manager.get_plugin("test_plugin")
      assert plugin_data.state[:enabled] == true

      # Test disabling plugin
      :ok = Manager.disable_plugin("test_plugin")
      {:ok, plugin_data} = Manager.get_plugin("test_plugin")
      assert plugin_data.state[:enabled] == false

      :meck.unload(Manager)
    end

    test "reload_plugin unloads and reloads a plugin" do
      # Mock functions
      :meck.new(Manager, [:passthrough])

      :meck.expect(Manager, :discover_plugins, fn ->
        [{"test_plugin", %{name: "Test Plugin"}, TestPlugin}]
      end)

      # Mock reload from disk to return a new plugin state
      :meck.expect(Manager, :reload_plugin_from_disk, fn _plugin_id, _state ->
        {:ok, TestPlugin, %{name: "Reloaded Plugin"}, %{reloaded: true}}
      end)

      # Initialize with mocked functions
      :ok = Manager.initialize()

      # Test reloading
      :ok = Manager.reload_plugin("test_plugin")

      # Verify plugin has been reloaded with new metadata
      {:ok, plugin_data} = Manager.get_plugin("test_plugin")
      assert plugin_data.metadata.name == "Reloaded Plugin"
      assert plugin_data.state.reloaded == true

      :meck.unload(Manager)
    end
  end
end
