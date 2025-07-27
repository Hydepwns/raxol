defmodule Raxol.Plugins.Lifecycle.ManagerUpdate do
  @moduledoc """
  Handles manager state updates, config persistence, and plugin state management for plugin lifecycle management.
  """

  alias Raxol.Plugins.PluginConfig
  alias Raxol.Plugins.Lifecycle.Dependencies

  def update_manager_with_plugin(manager, plugin, plugin_name, merged_config) do
    case save_plugin_config(manager.config, plugin_name, merged_config) do
      {:ok, saved_config} ->
        {:ok, update_manager_state(manager, plugin, saved_config)}

      {:error, _reason} ->
        # Logging should be handled by caller
        {:ok, update_manager_state(manager, plugin, manager.config)}
    end
  end

  def update_manager_with_plugin(
        manager,
        plugin,
        plugin_name,
        merged_config,
        plugin_state
      ) do
    case save_plugin_config(manager.config, plugin_name, merged_config) do
      {:ok, saved_config} ->
        {:ok,
         update_manager_state_with_plugin_state(
           manager,
           plugin,
           saved_config,
           plugin_state
         )}

      {:error, _reason} ->
        # Logging should be handled by caller
        {:ok,
         update_manager_state_with_plugin_state(
           manager,
           plugin,
           manager.config,
           plugin_state
         )}
    end
  end

  def update_manager_state_with_plugin_state(
        manager,
        plugin,
        config,
        plugin_state
      ) do
    plugin_key = Dependencies.normalize_plugin_key(plugin.name)

    %{
      manager
      | plugins: Map.put(manager.plugins, plugin_key, plugin),
        loaded_plugins: Map.put(manager.loaded_plugins, plugin_key, plugin),
        plugin_states: Map.put(manager.plugin_states, plugin_key, plugin_state),
        config: config
    }
  end

  def save_plugin_config(config, plugin_name, merged_config) do
    updated_config =
      PluginConfig.update_plugin_config(config, plugin_name, merged_config)

    PluginConfig.save(updated_config)
  end

  def update_manager_state(manager, plugin, config) do
    plugin_key = Dependencies.normalize_plugin_key(plugin.name)
    plugin_state = Map.get(manager.plugin_states, plugin_key, %{})

    %{
      manager
      | plugins: Map.put(manager.plugins, plugin_key, plugin),
        loaded_plugins: Map.put(manager.loaded_plugins, plugin_key, plugin),
        plugin_states: Map.put(manager.plugin_states, plugin_key, plugin_state),
        config: config
    }
  end

  def update_manager_state(manager, plugin, config, enabled) do
    plugin_key = Dependencies.normalize_plugin_key(plugin.name)
    plugin_state = Map.get(manager.plugin_states, plugin_key, %{})

    %{
      manager
      | plugins:
          Map.put(manager.plugins, plugin_key, %{plugin | enabled: enabled}),
        plugin_states: Map.put(manager.plugin_states, plugin_key, plugin_state),
        config: config
    }
  end

  def update_and_save_config(manager, name, action) do
    updated_config =
      case action do
        :enable -> PluginConfig.enable_plugin(manager.config, name)
        :disable -> PluginConfig.disable_plugin(manager.config, name)
      end

    case PluginConfig.save(updated_config) do
      {:ok, saved_config} ->
        {:ok, saved_config}

      {:error, _reason} ->
        # Logging should be handled by caller
        {:ok, manager.config}
    end
  end

  def update_manager_with_plugin_config(manager, plugin, updated_config) do
    plugin_with_promoted_config =
      plugin
      |> Map.merge(updated_config)
      |> Map.put(:config, updated_config)

    plugin_key = Dependencies.normalize_plugin_key(plugin.name)

    updated_plugins =
      Map.put(manager.plugins, plugin_key, plugin_with_promoted_config)

    updated_loaded_plugins =
      Map.put(manager.loaded_plugins, plugin_key, plugin_with_promoted_config)

    updated_plugin_states =
      Map.put(manager.plugin_states, plugin_key, plugin_with_promoted_config)

    {:ok,
     %{
       manager
       | plugins: updated_plugins,
         loaded_plugins: updated_loaded_plugins,
         plugin_states: updated_plugin_states
     }}
  end
end
