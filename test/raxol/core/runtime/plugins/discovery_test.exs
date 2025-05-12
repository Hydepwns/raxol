defmodule Raxol.Core.Runtime.Plugins.DiscoveryTest do
  use ExUnit.Case
  import Mox

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  describe "initialize/1" do
    test "initializes plugin system successfully" do
      # Setup test state
      state = %{
        plugin_dirs: ["test/plugins"],
        plugins_dir: "priv/plugins",
        initialized: false,
        command_registry_table: nil,
        loader_module: Raxol.Core.Runtime.Plugins.LoaderMock,
        lifecycle_helper_module: Raxol.Core.Runtime.Plugins.FileWatcherMock,
        plugins: %{},
        metadata: %{},
        plugin_states: %{},
        plugin_paths: %{},
        reverse_plugin_paths: %{},
        load_order: []
      }

      # Expect FileWatcher setup
      expect(Raxol.Core.Runtime.Plugins.FileWatcherMock, :setup_file_watching, fn ^state ->
        {:ok, %{state | file_watching_enabled?: true}}
      end)

      # Expect plugin discovery
      expect(Raxol.Core.Runtime.Plugins.LoaderMock, :discover_plugins, fn dirs ->
        assert dirs == ["priv/plugins", "test/plugins"]
        {:ok, []}
      end)

      # Call the function
      {:ok, new_state} = Discovery.initialize(state)

      # Verify results
      assert new_state.initialized == true
      assert is_atom(new_state.command_registry_table)
      assert new_state.file_watching_enabled? == true
    end

    test "handles plugin discovery failure" do
      # Setup test state
      state = %{
        plugin_dirs: ["test/plugins"],
        plugins_dir: "priv/plugins",
        initialized: false,
        command_registry_table: nil,
        loader_module: Raxol.Core.Runtime.Plugins.LoaderMock,
        lifecycle_helper_module: Raxol.Core.Runtime.Plugins.FileWatcherMock,
        plugins: %{},
        metadata: %{},
        plugin_states: %{},
        plugin_paths: %{},
        reverse_plugin_paths: %{},
        load_order: []
      }

      # Expect FileWatcher setup
      expect(Raxol.Core.Runtime.Plugins.FileWatcherMock, :setup_file_watching, fn ^state ->
        {:ok, %{state | file_watching_enabled?: true}}
      end)

      # Expect plugin discovery to fail
      expect(Raxol.Core.Runtime.Plugins.LoaderMock, :discover_plugins, fn dirs ->
        assert dirs == ["priv/plugins", "test/plugins"]
        {:error, :discovery_failed}
      end)

      # Call the function
      {:error, reason} = Discovery.initialize(state)

      # Verify error
      assert reason == :discovery_failed
    end
  end

  describe "discover_plugins/1" do
    test "discovers plugins in all directories" do
      # Setup test state
      state = %{
        plugin_dirs: ["test/plugins"],
        plugins_dir: "priv/plugins"
      }

      # Expect discovery in each directory
      expect(Raxol.Core.Runtime.Plugins.LoaderMock, :discover_plugins_in_dir, fn "priv/plugins", ^state ->
        {:ok, %{state | plugins: %{"plugin1" => :plugin1}}}
      end)

      expect(Raxol.Core.Runtime.Plugins.LoaderMock, :discover_plugins_in_dir, fn "test/plugins", state ->
        {:ok, %{state | plugins: %{"plugin2" => :plugin2}}}
      end)

      # Call the function
      {:ok, new_state} = Discovery.discover_plugins(state)

      # Verify results
      assert new_state.plugins == %{
        "plugin1" => :plugin1,
        "plugin2" => :plugin2
      }
    end

    test "stops on first discovery failure" do
      # Setup test state
      state = %{
        plugin_dirs: ["test/plugins"],
        plugins_dir: "priv/plugins"
      }

      # Expect first discovery to fail
      expect(Raxol.Core.Runtime.Plugins.LoaderMock, :discover_plugins_in_dir, fn "priv/plugins", ^state ->
        {:error, :discovery_failed}
      end)

      # Call the function
      {:error, reason} = Discovery.discover_plugins(state)

      # Verify error
      assert reason == :discovery_failed
    end
  end

  describe "list_plugins/1" do
    test "returns plugins in load order" do
      # Setup test state
      state = %{
        load_order: ["plugin1", "plugin2"],
        metadata: %{
          "plugin1" => %{name: "Plugin 1"},
          "plugin2" => %{name: "Plugin 2"}
        }
      }

      # Call the function
      plugins = Discovery.list_plugins(state)

      # Verify results
      assert plugins == [
        {"plugin1", %{name: "Plugin 1"}},
        {"plugin2", %{name: "Plugin 2"}}
      ]
    end
  end

  describe "get_plugin/2" do
    test "returns plugin when found" do
      # Setup test state
      state = %{
        plugins: %{"test_plugin" => :test_plugin},
        metadata: %{"test_plugin" => %{name: "Test Plugin"}}
      }

      # Call the function
      {:ok, plugin} = Discovery.get_plugin("test_plugin", state)

      # Verify results
      assert plugin == :test_plugin
    end

    test "returns error when plugin not found" do
      # Setup test state
      state = %{
        plugins: %{},
        metadata: %{}
      }

      # Call the function
      {:error, reason} = Discovery.get_plugin("unknown_plugin", state)

      # Verify error
      assert reason == :plugin_not_found
    end
  end
end
