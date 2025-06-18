defmodule Raxol.Plugins.PluginConfigTest do
  use ExUnit.Case

  @moduledoc '''
  Tests for plugin configuration functionality including loading, saving,
  and managing plugin settings.
  '''

  alias Raxol.Plugins.PluginConfig

  describe "plugin configuration" do
    test 'creates a new plugin configuration' do
      config = PluginConfig.new()
      assert config.plugin_configs == %{}
      assert config.enabled_plugins == []
    end

    test 'loads and saves plugin configuration' do
      # Create initial config
      config = PluginConfig.new()

      config =
        PluginConfig.update_plugin_config(config, "test_plugin", %{
          setting: "value"
        })

      config = PluginConfig.enable_plugin(config, "test_plugin")

      # Save config
      {:ok, saved_config} = PluginConfig.save(config)
      assert saved_config.plugin_configs["test_plugin"] == %{setting: "value"}
      assert "test_plugin" in saved_config.enabled_plugins

      # Load config
      {:ok, loaded_config} = PluginConfig.load()
      assert loaded_config.plugin_configs["test_plugin"] == %{setting: "value"}
      assert "test_plugin" in loaded_config.enabled_plugins
    end

    test 'gets plugin configuration' do
      config = PluginConfig.new()

      config =
        PluginConfig.update_plugin_config(config, "test_plugin", %{
          setting: "value"
        })

      plugin_config = PluginConfig.get_plugin_config(config, "test_plugin")
      assert plugin_config == %{setting: "value"}

      # Non-existent plugin should return empty map
      plugin_config = PluginConfig.get_plugin_config(config, "nonexistent")
      assert plugin_config == %{}
    end

    test 'updates plugin configuration' do
      config = PluginConfig.new()

      config =
        PluginConfig.update_plugin_config(config, "test_plugin", %{
          setting: "value"
        })

      config =
        PluginConfig.update_plugin_config(config, "test_plugin", %{
          setting: "new_value"
        })

      plugin_config = PluginConfig.get_plugin_config(config, "test_plugin")
      assert plugin_config == %{setting: "new_value"}
    end

    test 'enables and disables plugins' do
      config = PluginConfig.new()

      # Enable plugin
      config = PluginConfig.enable_plugin(config, "test_plugin")
      assert PluginConfig.is_plugin_enabled?(config, "test_plugin")

      # Enable again (should not duplicate)
      config = PluginConfig.enable_plugin(config, "test_plugin")
      assert length(config.enabled_plugins) == 1

      # Disable plugin
      config = PluginConfig.disable_plugin(config, "test_plugin")
      refute PluginConfig.is_plugin_enabled?(config, "test_plugin")
    end

    test 'handles loading non-existent configuration file' do
      # Set HOME to a temporary directory to ensure clean state
      System.put_env("HOME", System.tmp_dir!())

      {:ok, config} = PluginConfig.load()
      assert config.plugin_configs == %{}
      assert config.enabled_plugins == []
    end
  end
end
