defmodule Raxol.Terminal.EmulatorPluginTest do
  use ExUnit.Case
  import Raxol.Test.EventAssertions

  # TODO: Rewrite tests to align with current Emulator/PluginManager/Parser API.
  # The original tests were based on a deprecated direct plugin management API
  # within the Emulator module.
  @moduledoc false
  # Skipping entire file due to outdated API usage
  @tag :skip

  alias Raxol.Core.Runtime.Plugins.Manager
  alias Raxol.Plugins.HyperlinkPlugin
  alias Raxol.Terminal.Emulator

  setup do
    # Start the plugin manager with test configuration
    {:ok, _pid} = Manager.start_link(
      command_registry_table: :test_command_registry,
      plugin_config: %{},
      enable_plugin_reloading: false
    )

    # Initialize the plugin system
    :ok = Manager.initialize()

    # Create a new emulator
    emulator = Emulator.new(80, 24)

    {:ok, %{emulator: emulator}}
  end

  describe "plugin lifecycle" do
    test "loads and uses plugins", %{emulator: emulator} do
      # Load the hyperlink plugin through the plugin manager
      assert :ok = Manager.load_plugin(HyperlinkPlugin, %{})

      # Verify the plugin is loaded
      assert {:ok, plugins} = Manager.list_plugins()
      assert length(plugins) == 1
      [{plugin_id, metadata}] = plugins
      assert metadata.name == "hyperlink"
      assert metadata.enabled == true

      # Write some text with a URL
      {:ok, emulator} = Emulator.write_char(emulator, "Check out https://example.com")

      # Verify the plugin is still loaded and enabled
      assert {:ok, plugin} = Manager.get_plugin(plugin_id)
      assert plugin.enabled == true
    end

    test "enables and disables plugins", %{emulator: emulator} do
      # Load the hyperlink plugin
      assert :ok = Manager.load_plugin(HyperlinkPlugin, %{})
      assert {:ok, plugins} = Manager.list_plugins()
      [{plugin_id, _}] = plugins

      # Disable the plugin
      assert :ok = Manager.disable_plugin(plugin_id)
      assert {:ok, plugin} = Manager.get_plugin(plugin_id)
      assert plugin.enabled == false

      # Enable the plugin
      assert :ok = Manager.enable_plugin(plugin_id)
      assert {:ok, plugin} = Manager.get_plugin(plugin_id)
      assert plugin.enabled == true
    end

    test "unloads plugins", %{emulator: emulator} do
      # Load the hyperlink plugin
      assert :ok = Manager.load_plugin(HyperlinkPlugin, %{})
      assert {:ok, plugins} = Manager.list_plugins()
      [{plugin_id, _}] = plugins
      assert length(plugins) == 1

      # Unload the plugin
      assert :ok = Manager.reload_plugin(plugin_id)
      assert {:ok, plugins} = Manager.list_plugins()
      assert length(plugins) == 0
    end

    test "handles plugin dependencies", %{emulator: emulator} do
      # Load a plugin with dependencies
      assert {:error, :missing_dependency} = Manager.load_plugin(:dependent_plugin, %{})

      # Load the dependency first
      assert :ok = Manager.load_plugin(:dependency_plugin, %{})

      # Now load the dependent plugin
      assert :ok = Manager.load_plugin(:dependent_plugin, %{})
    end

    test "validates plugin versions", %{emulator: emulator} do
      # Try to load a plugin with incompatible version
      assert {:error, :incompatible_version} = Manager.load_plugin(:incompatible_plugin, %{})
    end
  end

  describe "plugin events" do
    test "processes input through plugins", %{emulator: emulator} do
      # Load the hyperlink plugin
      assert :ok = Manager.load_plugin(HyperlinkPlugin, %{})
      assert {:ok, plugins} = Manager.list_plugins()
      [{plugin_id, _}] = plugins

      # Process some input
      {:ok, emulator} = Emulator.process_input(emulator, "test input")

      # Verify the plugin is still loaded and enabled
      assert {:ok, plugin} = Manager.get_plugin(plugin_id)
      assert plugin.enabled == true
    end

    test "processes mouse events through plugins", %{emulator: emulator} do
      # Load the hyperlink plugin
      assert :ok = Manager.load_plugin(HyperlinkPlugin, %{})
      assert {:ok, plugins} = Manager.list_plugins()
      [{plugin_id, _}] = plugins

      # Process a mouse event
      {:ok, emulator} = Emulator.process_mouse(emulator, {:click, 1, 10, 10})

      # Verify the plugin is still loaded and enabled
      assert {:ok, plugin} = Manager.get_plugin(plugin_id)
      assert plugin.enabled == true
    end

    test "handles terminal events", %{emulator: emulator} do
      # Load the hyperlink plugin
      assert :ok = Manager.load_plugin(HyperlinkPlugin, %{})
      assert {:ok, plugins} = Manager.list_plugins()
      [{plugin_id, _}] = plugins

      # Process a terminal event
      {:ok, emulator} = Emulator.process_terminal_event(emulator, :resize, {100, 50})

      # Verify the plugin handled the event
      assert {:ok, plugin} = Manager.get_plugin(plugin_id)
      assert plugin.enabled == true
    end

    test "handles custom events", %{emulator: emulator} do
      # Load the hyperlink plugin
      assert :ok = Manager.load_plugin(HyperlinkPlugin, %{})
      assert {:ok, plugins} = Manager.list_plugins()
      [{plugin_id, _}] = plugins

      # Process a custom event
      {:ok, emulator} = Emulator.process_custom_event(emulator, :custom_event, %{data: "test"})

      # Verify the plugin handled the event
      assert {:ok, plugin} = Manager.get_plugin(plugin_id)
      assert plugin.enabled == true
    end
  end

  describe "plugin commands" do
    test "registers and executes commands", %{emulator: emulator} do
      # Load the hyperlink plugin
      assert :ok = Manager.load_plugin(HyperlinkPlugin, %{})
      assert {:ok, plugins} = Manager.list_plugins()
      [{plugin_id, _}] = plugins

      # Register a command
      assert :ok = Manager.register_command(plugin_id, :test_command, &test_command_handler/3)

      # Execute the command
      assert {:ok, _result} = Manager.execute_command(plugin_id, :test_command, %{})
    end

    test "validates command parameters", %{emulator: emulator} do
      # Load the hyperlink plugin
      assert :ok = Manager.load_plugin(HyperlinkPlugin, %{})
      assert {:ok, plugins} = Manager.list_plugins()
      [{plugin_id, _}] = plugins

      # Try to execute command with invalid parameters
      assert {:error, :invalid_parameters} = Manager.execute_command(plugin_id, :test_command, %{invalid: true})
    end
  end

  describe "plugin state" do
    test "manages plugin state", %{emulator: emulator} do
      # Load the hyperlink plugin
      assert :ok = Manager.load_plugin(HyperlinkPlugin, %{})
      assert {:ok, plugins} = Manager.list_plugins()
      [{plugin_id, _}] = plugins

      # Update plugin state
      assert :ok = Manager.update_plugin_state(plugin_id, %{test: true})

      # Verify state update
      assert {:ok, plugin} = Manager.get_plugin(plugin_id)
      assert plugin.state.test == true
    end

    test "persists plugin state", %{emulator: emulator} do
      # Load the hyperlink plugin
      assert :ok = Manager.load_plugin(HyperlinkPlugin, %{})
      assert {:ok, plugins} = Manager.list_plugins()
      [{plugin_id, _}] = plugins

      # Update and persist state
      assert :ok = Manager.update_plugin_state(plugin_id, %{test: true})
      assert :ok = Manager.persist_plugin_state(plugin_id)

      # Reload plugin and verify state
      assert :ok = Manager.reload_plugin(plugin_id)
      assert {:ok, plugin} = Manager.get_plugin(plugin_id)
      assert plugin.state.test == true
    end
  end

  describe "plugin metadata" do
    test "retrieves plugin metadata", %{emulator: emulator} do
      # Load the hyperlink plugin
      assert :ok = Manager.load_plugin(HyperlinkPlugin, %{})
      assert {:ok, plugins} = Manager.list_plugins()
      [{plugin_id, _}] = plugins

      # Get plugin metadata
      assert {:ok, metadata} = Manager.get_plugin_metadata(plugin_id)
      assert metadata.name == "hyperlink"
      assert metadata.version != nil
      assert metadata.dependencies != nil
    end

    test "validates plugin configuration", %{emulator: emulator} do
      # Try to load plugin with invalid configuration
      assert {:error, :invalid_configuration} = Manager.load_plugin(HyperlinkPlugin, %{invalid: true})
    end
  end

  describe "error handling" do
    test "handles plugin load errors gracefully", %{emulator: emulator} do
      # Try to load an invalid plugin
      assert {:error, _reason} = Manager.load_plugin(:invalid_plugin, %{})

      # Verify no plugins are loaded
      assert {:ok, plugins} = Manager.list_plugins()
      assert length(plugins) == 0
    end

    test "handles plugin crash recovery", %{emulator: emulator} do
      # Load a plugin that might crash
      assert :ok = Manager.load_plugin(:crashy_plugin, %{})
      assert {:ok, plugins} = Manager.list_plugins()
      [{plugin_id, _}] = plugins

      # Trigger a crash
      assert :ok = Manager.execute_command(plugin_id, :crash, %{})

      # Verify plugin is reloaded
      # assert_event_received :plugin_crashed, %{plugin_id: ^plugin_id}, 1000
      # assert_event_received :plugin_reloaded, %{plugin_id: ^plugin_id}, 1000
    end
  end

  # Helper function for command handler test
  defp test_command_handler(_plugin_id, _command, _params) do
    {:ok, %{result: "success"}}
  end
end
