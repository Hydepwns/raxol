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

      assert manager.config == %Raxol.Plugins.PluginConfig{
               enabled_plugins: [],
               plugin_configs: %{}
             }

      assert manager.api_version == "1.0"
    end

    # test "loads a plugin" do
    #   {:ok, manager} = PluginManager.new(%{plugins: [TestPlugin]}) # Incorrect usage
    #
    #   {:ok, updated_manager} =
    #     PluginManager.load_plugin(manager, HyperlinkPlugin)
    #
    #   assert Map.has_key?(updated_manager.plugins, "hyperlink")
    #   assert updated_manager.plugins["hyperlink"].enabled == true
    # end

    # TODO: Test loading plugin with specific config
    # TODO: Test loading plugin with dependencies

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
      # Create a basic emulator struct
      emulator = %Emulator{}

      {:ok, manager_with_plugin} =
        PluginManager.load_plugin(manager, HyperlinkPlugin)

      # Test with a mouse event, passing the arguments in the correct order
      # process_mouse(manager, event, emulator_state)
      {:ok, updated_manager} =
        PluginManager.process_mouse(
          manager_with_plugin,
          {:click, 1, 2, 1},
          emulator
        )

      # Assertion might need refinement depending on what process_mouse actually does
      # For now, just assert the plugin is still loaded/enabled
      assert Map.has_key?(updated_manager.plugins, "hyperlink")
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

    # Test case: Hyperlink Plugin processes output via PluginManager
    test "Hyperlink Plugin processes output via PluginManager" do
      manager = PluginManager.new()
      {:ok, manager} = PluginManager.load_plugin(manager, HyperlinkPlugin)

      input_text = "Check this link: https://example.com and continue."

      # Process the output string through the PluginManager
      result = PluginManager.process_output(manager, input_text)

      # Expect a 3-tuple {:ok, updated_manager, transformed_output}
      assert match?({:ok, %PluginManager{}, _transformed_output}, result)

      # Verify the output was transformed
      {:ok, _final_manager, transformed_output} = result
      # Check for the OSC 8 start sequence and URL
      assert String.contains?(
               transformed_output,
               "\e]8;;https://example.com\e\\"
             )

      # Check for the URL text itself followed by the OSC 8 termination sequence
      assert String.contains?(
               transformed_output,
               "https://example.com\e]8;;\e\\"
             )
    end
  end

  describe "Theme Plugin" do
    test "initializes correctly" do
      {:ok, plugin} = ThemePlugin.init()
      assert plugin.name == "theme"
      assert plugin.enabled == true
      assert is_map(plugin.current_theme.colors)

      assert plugin.current_theme.colors.background ==
               Raxol.UI.Theming.Theme.default_theme().colors.background

      assert plugin.current_theme.colors.foreground ==
               Raxol.UI.Theming.Theme.default_theme().colors.foreground
    end

    test "changes theme" do
      {:ok, plugin} = ThemePlugin.init()

      # Register a new theme for testing
      new_theme_attrs = %{
        id: :test_theme,
        name: "Test Theme",
        colors: %{
          background: "#123456",
          foreground: "#654321"
        }
      }

      :ok = ThemePlugin.register_theme(new_theme_attrs)

      # Test changing to a valid theme
      {:ok, updated_plugin} = ThemePlugin.change_theme(plugin, :test_theme)
      assert updated_plugin.current_theme.name == "Test Theme"
      assert updated_plugin.current_theme.colors.background == "#123456"

      # Test changing to an invalid theme
      assert {:error, _} = ThemePlugin.change_theme(plugin, :invalid_theme)
    end

    test "lists available themes" do
      themes = ThemePlugin.list_themes()
      assert Enum.any?(themes, fn t -> t.name == "Default Theme" end)
    end

    test "registers a new theme and retrieves it" do
      theme_attrs = %{
        id: :custom_theme,
        name: "Custom Theme",
        colors: %{
          background: "#abcdef",
          foreground: "#fedcba"
        }
      }

      :ok = ThemePlugin.register_theme(theme_attrs)
      themes = ThemePlugin.list_themes()
      assert Enum.any?(themes, fn t -> t.name == "Custom Theme" end)
      {:ok, plugin} = ThemePlugin.init(%{theme: :custom_theme})
      assert plugin.current_theme.name == "Custom Theme"
      assert plugin.current_theme.colors.background == "#abcdef"
    end

    test "get_theme/1 returns the current theme struct" do
      {:ok, plugin} = ThemePlugin.init()
      theme = ThemePlugin.get_theme(plugin)
      assert is_map(theme)
      assert Map.has_key?(theme, :colors)
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
      plugin_with_results =
        Map.put(updated_plugin, :search_results, ["result1", "result2"])

      {:ok, next_plugin} =
        SearchPlugin.handle_input(plugin_with_results, "/n")

      assert next_plugin.current_result_index == 1

      {:ok, prev_plugin} = SearchPlugin.handle_input(next_plugin, "/N")
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

  # Test suite for Emulator integration with plugins
  describe "Emulator with Plugins" do
    # Test case: load and use various plugins with the emulator
    test "loads and uses plugins" do
      emulator = Emulator.new(80, 24)

      # Get the initial plugin manager
      plugin_manager = emulator.plugin_manager

      # Load plugins using PluginManager
      {:ok, plugin_manager} =
        PluginManager.load_plugin(plugin_manager, HyperlinkPlugin)

      {:ok, plugin_manager} =
        PluginManager.load_plugin(plugin_manager, ImagePlugin)

      {:ok, plugin_manager} =
        PluginManager.load_plugin(plugin_manager, ThemePlugin)

      {:ok, plugin_manager} =
        PluginManager.load_plugin(plugin_manager, SearchPlugin)

      # Update the emulator with the modified plugin manager
      emulator = %{emulator | plugin_manager: plugin_manager}

      # Verify plugins are loaded (via PluginManager directly)
      plugins = PluginManager.list_plugins(plugin_manager)
      assert length(plugins) == 4
    end
  end
end
