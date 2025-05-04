defmodule Raxol.Plugins.PluginSystemTest do
  use ExUnit.Case

  alias Raxol.Plugins.HyperlinkPlugin
  alias Raxol.Plugins.ImagePlugin
  alias Raxol.Plugins.PluginManager
  alias Raxol.Plugins.SearchPlugin
  alias Raxol.Plugins.ThemePlugin
  alias Raxol.Terminal.Emulator

  describe "Plugin Manager" do
    test "creates a new plugin manager" do
      manager = PluginManager.new()
      assert manager.plugins == %{}
      assert manager.config == %{}
    end

    test "loads a plugin" do
      {:ok, manager} = PluginManager.new(%{plugins: [TestPlugin]})

      {:ok, updated_manager} =
        PluginManager.load_plugin(manager, HyperlinkPlugin)

      assert Map.has_key?(updated_manager.plugins, "hyperlink")
      assert updated_manager.plugins["hyperlink"].enabled == true
    end

    test "unloads a plugin" do
      manager = PluginManager.new()

      {:ok, manager_with_plugin} =
        PluginManager.load_plugin(manager, HyperlinkPlugin)

      {:ok, updated_manager} =
        PluginManager.unload_plugin(manager_with_plugin, "hyperlink")

      assert updated_manager.plugins == %{}
    end

    test "enables a plugin" do
      manager = PluginManager.new()

      {:ok, manager_with_plugin} =
        PluginManager.load_plugin(manager, HyperlinkPlugin)

      {:ok, updated_manager} =
        PluginManager.disable_plugin(manager_with_plugin, "hyperlink")

      assert updated_manager.plugins["hyperlink"].enabled == false

      {:ok, enabled_manager} =
        PluginManager.enable_plugin(updated_manager, "hyperlink")

      assert enabled_manager.plugins["hyperlink"].enabled == true
    end

    test "disables a plugin" do
      manager = PluginManager.new()

      {:ok, manager_with_plugin} =
        PluginManager.load_plugin(manager, HyperlinkPlugin)

      assert manager_with_plugin.plugins["hyperlink"].enabled == true

      {:ok, updated_manager} =
        PluginManager.disable_plugin(manager_with_plugin, "hyperlink")

      assert updated_manager.plugins["hyperlink"].enabled == false
    end

    test "processes output through plugins" do
      manager = PluginManager.new()

      {:ok, manager_with_plugin} =
        PluginManager.load_plugin(manager, HyperlinkPlugin)

      # Test with a URL in the output
      {:ok, updated_manager, transformed_output} =
        PluginManager.process_output(
          manager_with_plugin,
          "Visit https://example.com"
        )

      assert String.contains?(transformed_output, "\e]8;;https://example.com")

      # Test with no URL in the output
      {:ok, updated_manager, _} =
        PluginManager.process_output(updated_manager, "Hello, World!")
    end

    test "processes input through plugins" do
      manager = PluginManager.new()

      {:ok, manager_with_plugin} =
        PluginManager.load_plugin(manager, SearchPlugin)

      # Test with a search command
      {:ok, updated_manager} =
        PluginManager.process_input(manager_with_plugin, "/search example")

      assert updated_manager.plugins["search"].search_term == "example"
    end

    test "processes mouse events through plugins" do
      manager = PluginManager.new()

      {:ok, manager_with_plugin} =
        PluginManager.load_plugin(manager, HyperlinkPlugin)

      # Test with a mouse event
      {:ok, updated_manager} =
        PluginManager.process_mouse(manager_with_plugin, {:click, 1, 2, 1})

      assert updated_manager.plugins["hyperlink"].enabled == true
    end
  end

  describe "Hyperlink Plugin" do
    test "initializes correctly" do
      {:ok, plugin} = HyperlinkPlugin.init()
      assert plugin.name == "hyperlink"
      assert plugin.enabled == true
    end

    test "detects and transforms URLs" do
      {:ok, plugin} = HyperlinkPlugin.init()

      # Test with a URL
      {:ok, updated_plugin, transformed_output} =
        HyperlinkPlugin.handle_output(plugin, "Visit https://example.com")

      assert String.contains?(transformed_output, "\e]8;;https://example.com")

      # Test with no URL
      {:ok, updated_plugin} =
        HyperlinkPlugin.handle_output(updated_plugin, "Hello, World!")
    end
  end

  describe "Theme Plugin" do
    test "initializes correctly" do
      {:ok, plugin} = ThemePlugin.init()
      assert plugin.name == "theme"
      assert plugin.enabled == true
      assert plugin.current_theme == ThemePlugin.__struct__().current_theme
    end

    test "changes theme" do
      {:ok, plugin} = ThemePlugin.init()

      # Test changing to a valid theme
      {:ok, updated_plugin} = ThemePlugin.change_theme(plugin, "solarized_dark")
      assert updated_plugin.current_theme.background == {0, 43, 54}

      # Test changing to an invalid theme
      {:error, _} = ThemePlugin.change_theme(plugin, "invalid_theme")
    end

    test "lists available themes" do
      themes = ThemePlugin.list_themes()
      assert "default" in themes
      assert "solarized_dark" in themes
      assert "solarized_light" in themes
      assert "dracula" in themes
    end
  end

  describe "Search Plugin" do
    test "initializes correctly" do
      {:ok, plugin} = SearchPlugin.init()
      assert plugin.name == "search"
      assert plugin.enabled == true
      assert plugin.search_term == nil
      assert plugin.search_results == []
      assert plugin.current_result_index == 0
    end

    test "handles search commands" do
      {:ok, plugin} = SearchPlugin.init()

      # Test starting a search
      {:ok, updated_plugin} =
        SearchPlugin.handle_input(plugin, "/search example")

      assert updated_plugin.search_term == "example"

      # Test navigating search results
      {:ok, plugin_with_results} = %{
        updated_plugin
        | search_results: ["result1", "result2"]
      }

      {:ok, next_plugin} =
        SearchPlugin.handle_input(plugin_with_results, "/next")

      assert next_plugin.current_result_index == 1

      {:ok, prev_plugin} = SearchPlugin.handle_input(next_plugin, "/prev")
      assert prev_plugin.current_result_index == 0

      # Test clearing search
      {:ok, cleared_plugin} = SearchPlugin.handle_input(prev_plugin, "/clear")
      assert cleared_plugin.search_term == nil
      assert cleared_plugin.search_results == []
      assert cleared_plugin.current_result_index == 0
    end

    test "highlights search terms" do
      {:ok, plugin} = SearchPlugin.init()

      highlighted = SearchPlugin.highlight_search_term("Hello, World!", "World")
      assert highlighted == "Hello, \e[43mWorld\e[0m!"
    end
  end

  describe "Emulator with Plugins" do
    test "loads and uses plugins" do
      emulator = Emulator.new(80, 24)

      # Load plugins
      {:ok, emulator} = Emulator.load_plugin(emulator, HyperlinkPlugin)
      {:ok, emulator} = Emulator.load_plugin(emulator, ImagePlugin)
      {:ok, emulator} = Emulator.load_plugin(emulator, ThemePlugin)
      {:ok, emulator} = Emulator.load_plugin(emulator, SearchPlugin)

      # Verify plugins are loaded
      plugins = Emulator.list_plugins(emulator)
      assert length(plugins) == 4

      # Test plugin functionality
      emulator = Emulator.process_input(emulator, "/theme solarized_dark")
      emulator = Emulator.process_input(emulator, "/search example")

      # Write text with a URL
      emulator = Emulator.write_string(emulator, "Visit https://example.com")

      # Verify the URL was transformed
      cell = Enum.at(Enum.at(emulator.screen_buffer, 0), 6)
      assert String.contains?(cell, "\e]8;;https://example.com")
    end
  end
end
