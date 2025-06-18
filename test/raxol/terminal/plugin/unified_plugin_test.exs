defmodule Raxol.Terminal.Plugin.UnifiedPluginTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Plugin.UnifiedPlugin

  setup do
    {:ok, _pid} =
      UnifiedPlugin.start_link(
        plugin_paths: ["test/fixtures/plugins"],
        auto_load: false
      )

    :ok
  end

  describe "basic operations" do
    test 'loads and unloads plugins' do
      # Load theme plugin
      assert {:ok, theme_id} =
               UnifiedPlugin.load_plugin(
                 "test/fixtures/plugins/theme",
                 :theme,
                 name: "Test Theme",
                 version: "1.0.0"
               )

      # Load script plugin
      assert {:ok, script_id} =
               UnifiedPlugin.load_plugin(
                 "test/fixtures/plugins/script",
                 :script,
                 name: "Test Script",
                 version: "1.0.0"
               )

      # Get plugin states
      assert {:ok, theme_state} = UnifiedPlugin.get_plugin_state(theme_id)
      assert {:ok, script_state} = UnifiedPlugin.get_plugin_state(script_id)

      assert theme_state.type == :theme
      assert script_state.type == :script

      # Unload plugins
      assert :ok = UnifiedPlugin.unload_plugin(theme_id)
      assert :ok = UnifiedPlugin.unload_plugin(script_id)

      assert {:error, :plugin_not_found} =
               UnifiedPlugin.get_plugin_state(theme_id)

      assert {:error, :plugin_not_found} =
               UnifiedPlugin.get_plugin_state(script_id)
    end

    test 'handles plugin configuration' do
      # Load plugin with config
      config = %{
        colors: %{
          background: "#000000",
          foreground: "#ffffff"
        },
        font: "monospace"
      }

      assert {:ok, plugin_id} =
               UnifiedPlugin.load_plugin(
                 "test/fixtures/plugins/theme",
                 :theme,
                 name: "Test Theme",
                 version: "1.0.0",
                 config: config
               )

      # Update config
      new_config = %{
        colors: %{
          background: "#ffffff",
          foreground: "#000000"
        },
        font: "sans-serif"
      }

      assert :ok = UnifiedPlugin.update_plugin_config(plugin_id, new_config)

      # Verify config update
      assert {:ok, plugin_state} = UnifiedPlugin.get_plugin_state(plugin_id)
      assert plugin_state.config == new_config
    end
  end

  describe "plugin types" do
    test 'handles theme plugins' do
      assert {:ok, plugin_id} =
               UnifiedPlugin.load_plugin(
                 "test/fixtures/plugins/theme",
                 :theme,
                 name: "Test Theme",
                 version: "1.0.0"
               )

      # Execute theme function
      assert {:ok, result} =
               UnifiedPlugin.execute_plugin_function(
                 plugin_id,
                 :apply_theme,
                 [%{colors: %{background: "#000000"}}]
               )

      assert is_map(result)
    end

    test 'handles script plugins' do
      assert {:ok, plugin_id} =
               UnifiedPlugin.load_plugin(
                 "test/fixtures/plugins/script",
                 :script,
                 name: "Test Script",
                 version: "1.0.0"
               )

      # Execute script function
      assert {:ok, result} =
               UnifiedPlugin.execute_plugin_function(
                 plugin_id,
                 :run_script,
                 ["test_script"]
               )

      assert is_map(result)
    end

    test 'handles extension plugins' do
      assert {:ok, plugin_id} =
               UnifiedPlugin.load_plugin(
                 "test/fixtures/plugins/extension",
                 :extension,
                 name: "Test Extension",
                 version: "1.0.0"
               )

      # Execute extension function
      assert {:ok, result} =
               UnifiedPlugin.execute_plugin_function(
                 plugin_id,
                 :run_extension,
                 ["test_extension"]
               )

      assert is_map(result)
    end
  end

  describe "plugin management" do
    test 'lists plugins with filters' do
      # Load different types of plugins
      assert {:ok, theme_id} =
               UnifiedPlugin.load_plugin(
                 "test/fixtures/plugins/theme",
                 :theme,
                 name: "Test Theme",
                 version: "1.0.0"
               )

      assert {:ok, script_id} =
               UnifiedPlugin.load_plugin(
                 "test/fixtures/plugins/script",
                 :script,
                 name: "Test Script",
                 version: "1.0.0"
               )

      # Get all plugins
      assert {:ok, all_plugins} = UnifiedPlugin.get_plugins()
      assert map_size(all_plugins) == 2

      # Filter by type
      assert {:ok, theme_plugins} = UnifiedPlugin.get_plugins(type: :theme)
      assert map_size(theme_plugins) == 1
      assert Map.has_key?(theme_plugins, theme_id)

      # Filter by status
      assert {:ok, active_plugins} = UnifiedPlugin.get_plugins(status: :active)
      assert map_size(active_plugins) == 2
    end

    test 'handles plugin dependencies' do
      # Load dependent plugin
      assert {:ok, dependent_id} =
               UnifiedPlugin.load_plugin(
                 "test/fixtures/plugins/dependent",
                 :extension,
                 name: "Dependent Plugin",
                 version: "1.0.0",
                 dependencies: ["base_plugin"]
               )

      # Verify plugin is inactive due to missing dependency
      assert {:ok, plugin_state} = UnifiedPlugin.get_plugin_state(dependent_id)
      assert plugin_state.status == :inactive

      # Load base plugin
      assert {:ok, base_id} =
               UnifiedPlugin.load_plugin(
                 "test/fixtures/plugins/base",
                 :extension,
                 name: "Base Plugin",
                 version: "1.0.0"
               )

      # Reload dependent plugin
      assert :ok = UnifiedPlugin.reload_plugin(dependent_id)

      # Verify plugin is now active
      assert {:ok, plugin_state} = UnifiedPlugin.get_plugin_state(dependent_id)
      assert plugin_state.status == :active
    end
  end

  describe "error handling" do
    test 'handles invalid plugin types' do
      assert {:error, :invalid_plugin_type} =
               UnifiedPlugin.load_plugin(
                 "test/fixtures/plugins/invalid",
                 :invalid_type,
                 name: "Invalid Plugin",
                 version: "1.0.0"
               )
    end

    test 'handles invalid plugin formats' do
      assert {:error, :invalid_plugin_format} =
               UnifiedPlugin.load_plugin(
                 "test/fixtures/plugins/invalid",
                 :theme,
                 name: "Invalid Plugin"
                 # Missing required fields
               )
    end

    test 'handles non-existent plugins' do
      assert {:error, :plugin_not_found} =
               UnifiedPlugin.get_plugin_state("non_existent")

      assert {:error, :plugin_not_found} =
               UnifiedPlugin.unload_plugin("non_existent")

      assert {:error, :plugin_not_found} =
               UnifiedPlugin.update_plugin_config("non_existent", %{})
    end

    test 'handles invalid configurations' do
      assert {:ok, plugin_id} =
               UnifiedPlugin.load_plugin(
                 "test/fixtures/plugins/theme",
                 :theme,
                 name: "Test Theme",
                 version: "1.0.0"
               )

      assert {:error, :invalid_config_format} =
               UnifiedPlugin.update_plugin_config(plugin_id, "invalid_config")
    end
  end

  describe "plugin reloading" do
    test 'reloads plugins successfully' do
      # Load plugin
      assert {:ok, plugin_id} =
               UnifiedPlugin.load_plugin(
                 "test/fixtures/plugins/theme",
                 :theme,
                 name: "Test Theme",
                 version: "1.0.0"
               )

      # Update plugin file
      # (In a real test, we would modify the plugin file here)

      # Reload plugin
      assert :ok = UnifiedPlugin.reload_plugin(plugin_id)

      # Verify plugin is still active
      assert {:ok, plugin_state} = UnifiedPlugin.get_plugin_state(plugin_id)
      assert plugin_state.status == :active
    end

    test 'handles reload errors' do
      # Load plugin
      assert {:ok, plugin_id} =
               UnifiedPlugin.load_plugin(
                 "test/fixtures/plugins/theme",
                 :theme,
                 name: "Test Theme",
                 version: "1.0.0"
               )

      # Corrupt plugin file
      # (In a real test, we would corrupt the plugin file here)

      # Attempt to reload
      assert {:error, :reload_failed} = UnifiedPlugin.reload_plugin(plugin_id)

      # Verify plugin is in error state
      assert {:ok, plugin_state} = UnifiedPlugin.get_plugin_state(plugin_id)
      assert plugin_state.status == :error
    end
  end
end
