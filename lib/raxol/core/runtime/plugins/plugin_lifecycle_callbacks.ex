defmodule Raxol.Core.Runtime.Plugins.PluginLifecycleCallbacks do
  @moduledoc """
  Handles plugin lifecycle callback implementations.
  """

  @doc """
  Cleanup callback for a plugin.
  """
  def cleanup_plugin(_plugin_id, metadata) do
    # Implementation for cleanup_plugin callback
    {:ok, metadata}
  end

  @doc """
  Handle state transition callback.
  """
  def handle_state_transition(_plugin_id, _old_state, new_state) do
    # Implementation for handle_state_transition callback
    {:ok, new_state}
  end

  @doc """
  Initialize plugin callback.
  """
  def init_plugin(_plugin_id, metadata) do
    # Implementation for init_plugin callback
    {:ok, metadata}
  end

  @doc """
  Load plugin by module callback.
  """
  def load_plugin_by_module(
        module,
        metadata,
        config,
        states,
        command_table,
        plugin_manager,
        current_metadata,
        opts
      ) do
    # Implementation for load_plugin_by_module callback
    try do
      # Initialize the plugin module
      case module.init(config) do
        {:ok, plugin_state} ->
          # Extract plugin metadata from the state
          plugin_id = Map.get(plugin_state, :name, "unknown_plugin")

          # Update metadata with the new plugin
          updated_metadata = Map.put(current_metadata, plugin_id, plugin_state)

          # Update states with the new plugin state
          updated_states = Map.put(states, plugin_id, plugin_state)

          # Handle command table - ensure it's a map
          updated_table =
            case command_table do
              table when is_map(table) -> table
              table when is_atom(table) -> %{}  # Convert atom to empty map
              _ -> %{}
            end

          # Also add the plugin to the plugins map (this is needed for enable_plugin to work)
          # We need to get the current plugins map from the metadata
          current_plugins = Map.get(current_metadata, :plugins, %{})
          updated_plugins = Map.put(current_plugins, plugin_id, module)
          updated_metadata_with_plugins = Map.put(updated_metadata, :plugins, updated_plugins)

          {:ok, {updated_metadata_with_plugins, updated_states, updated_table}}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      e ->
        {:error, {:plugin_init_failed, e}}
    end
  end

  @doc """
  Reload plugin callback.
  """
  def reload_plugin(
        _plugin_id,
        metadata,
        _config,
        _states,
        _command_table,
        _plugin_manager,
        _opts
      ) do
    # Implementation for reload_plugin callback
    {:ok, metadata}
  end

  @doc """
  Terminate plugin callback.
  """
  def terminate_plugin(_plugin_id, metadata, _reason) do
    # Implementation for terminate_plugin callback
    {:ok, metadata}
  end
end
