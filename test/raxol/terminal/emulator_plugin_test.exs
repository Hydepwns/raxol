defmodule Raxol.Terminal.EmulatorPluginTest do
  use ExUnit.Case
  alias Raxol.Terminal.Emulator
  alias Raxol.Plugins.HyperlinkPlugin

  describe "terminal emulator with plugins" do
    test "loads and uses plugins" do
      # Create a new terminal emulator
      emulator = Emulator.new(80, 24)

      # Load the hyperlink plugin
      {:ok, emulator} = Emulator.load_plugin(emulator, HyperlinkPlugin)

      # Verify the plugin is loaded
      plugins = Emulator.list_plugins(emulator)
      assert length(plugins) == 1
      [plugin] = plugins
      assert plugin.name == "hyperlink"
      assert plugin.enabled == true

      # Write some text with a URL
      emulator = Emulator.write_char(emulator, "Check out https://example.com")

      # Verify the plugin is still loaded and enabled
      plugin = Emulator.get_plugin(emulator, "hyperlink")
      assert plugin != nil
      assert plugin.enabled == true
    end

    test "enables and disables plugins" do
      # Create a new terminal emulator
      emulator = Emulator.new(80, 24)

      # Load the hyperlink plugin
      {:ok, emulator} = Emulator.load_plugin(emulator, HyperlinkPlugin)

      # Disable the plugin
      {:ok, emulator} = Emulator.disable_plugin(emulator, "hyperlink")
      plugin = Emulator.get_plugin(emulator, "hyperlink")
      assert plugin.enabled == false

      # Enable the plugin
      {:ok, emulator} = Emulator.enable_plugin(emulator, "hyperlink")
      plugin = Emulator.get_plugin(emulator, "hyperlink")
      assert plugin.enabled == true
    end

    test "unloads plugins" do
      # Create a new terminal emulator
      emulator = Emulator.new(80, 24)

      # Load the hyperlink plugin
      {:ok, emulator} = Emulator.load_plugin(emulator, HyperlinkPlugin)
      assert length(Emulator.list_plugins(emulator)) == 1

      # Unload the plugin
      {:ok, emulator} = Emulator.unload_plugin(emulator, "hyperlink")
      assert length(Emulator.list_plugins(emulator)) == 0
    end

    test "processes input through plugins" do
      # Create a new terminal emulator
      emulator = Emulator.new(80, 24)

      # Load the hyperlink plugin
      {:ok, emulator} = Emulator.load_plugin(emulator, HyperlinkPlugin)

      # Process some input
      {:ok, emulator} = Emulator.process_input(emulator, "test input")

      # Verify the plugin is still loaded and enabled
      plugin = Emulator.get_plugin(emulator, "hyperlink")
      assert plugin != nil
      assert plugin.enabled == true
    end

    test "processes mouse events through plugins" do
      # Create a new terminal emulator
      emulator = Emulator.new(80, 24)

      # Load the hyperlink plugin
      {:ok, emulator} = Emulator.load_plugin(emulator, HyperlinkPlugin)

      # Process a mouse event
      {:ok, emulator} = Emulator.process_mouse(emulator, {:click, 1, 10, 10})

      # Verify the plugin is still loaded and enabled
      plugin = Emulator.get_plugin(emulator, "hyperlink")
      assert plugin != nil
      assert plugin.enabled == true
    end
  end
end
