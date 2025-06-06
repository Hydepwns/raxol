defmodule Raxol.Core.Runtime.Plugins.PluginReloader do
  @moduledoc """
  Handles plugin reloading operations.
  This module is responsible for:
  - Reloading plugins from disk
  - Managing plugin state during reloads
  - Handling reload failures and recovery
  """

  require Raxol.Core.Runtime.Log

  @doc """
  Reloads a plugin from disk.
  """
  def reload_plugin(plugin_id, state) do
    if !state.initialized do
      {:error, :not_initialized, state}
    else
      Raxol.Core.Runtime.Log.info("[#{__MODULE__}] Reloading plugin: #{plugin_id}")

      case state.lifecycle_helper_module.reload_plugin_from_disk(
             plugin_id,
             state.plugins,
             state.metadata,
             state.plugin_states,
             state.load_order,
             state.command_registry_table,
             state.plugin_config,
             state.plugin_paths
           ) do
        {:ok, updated_plugin_info} ->
          new_plugins =
            Map.put(state.plugins, plugin_id, updated_plugin_info.module)

          new_plugin_states =
            Map.put(state.plugin_states, plugin_id, updated_plugin_info.state)

          new_plugin_config =
            Map.put(state.plugin_config, plugin_id, updated_plugin_info.config)

          new_metadata =
            Map.put(state.metadata, plugin_id, updated_plugin_info.metadata)

          Raxol.Core.Runtime.Log.info(
            "[#{__MODULE__}] Plugin #{plugin_id} reloaded successfully."
          )

          {:ok,
           %{
             state
             | plugins: new_plugins,
               plugin_states: new_plugin_states,
               plugin_config: new_plugin_config,
               metadata: new_metadata
           }}

        {:error, reason} ->
          Raxol.Core.Runtime.Log.error_with_stacktrace(
            "Failed to reload plugin",
            reason,
            nil,
            %{module: __MODULE__, plugin_id: plugin_id, reason: reason}
          )
          {:error, reason, state}
      end
    end
  end

  @doc """
  Reloads a plugin by its string ID.
  """
  def reload_plugin_by_id(plugin_id_string, state) do
    Raxol.Core.Runtime.Log.info(
      "[#{__MODULE__}] Received request to reload plugin by string ID: #{plugin_id_string}"
    )

    plugin_id_atom = String.to_atom(plugin_id_string)

    case Map.get(state.plugins, plugin_id_atom) do
      nil ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "[#{__MODULE__}] Cannot reload plugin atom :#{plugin_id_atom} (from string '#{plugin_id_string}'): Not found.",
          nil,
          nil,
          %{module: __MODULE__, plugin_id_string: plugin_id_string}
        )

        {:error, :plugin_not_found, state}

      _old_module ->
        plugin_path = Map.get(state.plugin_paths, plugin_id_atom)

        if is_nil(plugin_path) do
          Raxol.Core.Runtime.Log.error_with_stacktrace(
            "[#{__MODULE__}] Cannot reload plugin atom :#{plugin_id_atom}: Original path not found.",
            nil,
            nil,
            %{module: __MODULE__, plugin_id: plugin_id_atom, plugin_id_string: plugin_id_string}
          )

          {:error, :path_not_found, state}
        else
          case state.lifecycle_helper_module.reload_plugin_from_disk(
                 plugin_id_atom,
                 state.plugins,
                 state.metadata,
                 state.plugin_states,
                 state.load_order,
                 state.command_registry_table,
                 state.plugin_config,
                 state.plugin_paths
               ) do
            {:ok, updated_plugin_info} ->
              new_plugins =
                Map.put(
                  state.plugins,
                  plugin_id_atom,
                  updated_plugin_info.module
                )

              new_plugin_states =
                Map.put(
                  state.plugin_states,
                  plugin_id_atom,
                  updated_plugin_info.state
                )

              new_plugin_config =
                Map.put(
                  state.plugin_config,
                  plugin_id_atom,
                  updated_plugin_info.config
                )

              new_metadata =
                Map.put(
                  state.metadata,
                  plugin_id_atom,
                  updated_plugin_info.metadata
                )

              Raxol.Core.Runtime.Log.info(
                "[#{__MODULE__}] Plugin atom :#{plugin_id_atom} reloaded successfully."
              )

              {:ok,
               %{
                 state
                 | plugins: new_plugins,
                   plugin_states: new_plugin_states,
                   plugin_config: new_plugin_config,
                   metadata: new_metadata
               }}

            {:error, reason} ->
              Raxol.Core.Runtime.Log.error_with_stacktrace(
                "[#{__MODULE__}] Failed to reload plugin atom :#{plugin_id_atom}",
                reason,
                nil,
                %{module: __MODULE__, plugin_id: plugin_id_atom, reason: reason}
              )
              {:error, reason, state}
          end
        end
    end
  end
end
