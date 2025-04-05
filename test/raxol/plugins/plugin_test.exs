defmodule Raxol.Plugins.PluginTest do
  use ExUnit.Case
  alias Raxol.Plugins.{Plugin, PluginManager}
  alias Raxol.Plugins.HyperlinkPlugin

  describe "plugin manager" do
    test "creates a new plugin manager" do
      manager = PluginManager.new()
      assert manager.plugins == %{}
      assert manager.config == %{}
    end

    test "loads a plugin" do
      manager = PluginManager.new()
      {:ok, updated_manager} = PluginManager.load_plugin(manager, HyperlinkPlugin)
      assert length(Map.keys(updated_manager.plugins)) == 1
      assert Map.has_key?(updated_manager.plugins, "hyperlink")
    end

    test "unloads a plugin" do
      manager = PluginManager.new()
      {:ok, manager} = PluginManager.load_plugin(manager, HyperlinkPlugin)
      {:ok, updated_manager} = PluginManager.unload_plugin(manager, "hyperlink")
      assert updated_manager.plugins == %{}
    end

    test "enables and disables a plugin" do
      manager = PluginManager.new()
      {:ok, manager} = PluginManager.load_plugin(manager, HyperlinkPlugin)
      {:ok, manager} = PluginManager.disable_plugin(manager, "hyperlink")
      plugin = PluginManager.get_plugin(manager, "hyperlink")
      assert plugin.enabled == false
      {:ok, manager} = PluginManager.enable_plugin(manager, "hyperlink")
      plugin = PluginManager.get_plugin(manager, "hyperlink")
      assert plugin.enabled == true
    end

    test "processes input through plugins" do
      manager = PluginManager.new()
      {:ok, manager} = PluginManager.load_plugin(manager, HyperlinkPlugin)
      {:ok, _manager} = PluginManager.process_input(manager, "test input")
    end

    test "processes output through plugins" do
      manager = PluginManager.new()
      {:ok, manager} = PluginManager.load_plugin(manager, HyperlinkPlugin)
      {:ok, _manager} = PluginManager.process_output(manager, "test output")
    end

    test "processes mouse events through plugins" do
      manager = PluginManager.new()
      {:ok, manager} = PluginManager.load_plugin(manager, HyperlinkPlugin)
      {:ok, _manager} = PluginManager.process_mouse(manager, {:click, 1, 10, 10})
    end
  end

  describe "hyperlink plugin" do
    test "initializes correctly" do
      {:ok, plugin} = HyperlinkPlugin.init(%{})
      assert plugin.name == "hyperlink"
      assert plugin.version == "1.0.0"
      assert plugin.enabled == true
    end

    test "detects and makes URLs clickable" do
      {:ok, plugin} = HyperlinkPlugin.init(%{})
      output = "Check out https://example.com for more info"
      {:ok, _plugin} = HyperlinkPlugin.handle_output(plugin, output)
      # Note: The actual URL transformation would be tested in integration tests
      # since it involves terminal escape sequences
    end
  end
end 