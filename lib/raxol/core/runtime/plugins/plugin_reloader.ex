defmodule Raxol.Core.Runtime.Plugins.PluginReloader do
  @moduledoc """
  Handles plugin reloading operations.
  This module is responsible for:
  - Reloading plugins from disk
  - Managing plugin state during reloads
  - Handling reload failures and recovery
  """

  @behaviour Raxol.Core.Runtime.Plugins.PluginReloader.Behaviour

  require Raxol.Core.Runtime.Log

  @impl true
  def reload_plugin_from_disk(
        plugin_id,
        plugin_module,
        plugin_state,
        plugins,
        metadata,
        plugin_states,
        load_order,
        command_table
      ) do
    try do
      # Reload the module with proper error handling
      with :ok <- :code.purge(plugin_module),
           {:module, ^plugin_module} <- :code.load_file(plugin_module),
           {:ok, updated_state} <- plugin_module.init(plugin_state) do
        # Update metadata with proper error handling
        updated_metadata =
          Map.put(metadata, plugin_id, %{
            path: Map.get(metadata, plugin_id).path,
            state: updated_state,
            last_reload: System.system_time()
          })

        {:ok, %{
          module: plugin_module,
          state: updated_state,
          metadata: updated_metadata
        }}
      else
        {:error, reason} ->
          Raxol.Core.Runtime.Log.error_with_stacktrace(
            "Failed to reload plugin",
            reason,
            nil,
            %{module: __MODULE__, plugin_id: plugin_id, reason: reason}
          )

          {:error, :reload_failed}
      end
    rescue
      e ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Failed to reload plugin (exception)",
          e,
          __STACKTRACE__,
          %{module: __MODULE__, plugin_id: plugin_id}
        )

        {:error, :reload_failed}
    end
  end

  @impl true
  def can_reload?(plugin_id, plugins, metadata) do
    case Map.get(plugins, plugin_id) do
      nil -> false
      _plugin -> true
    end
  end

  @impl true
  def get_reload_state(plugin_id, plugins, metadata) do
    case Map.get(metadata, plugin_id) do
      nil -> {:error, :plugin_not_found}
      plugin_metadata -> {:ok, plugin_metadata}
    end
  end

  @impl true
  def handle_reload_error(plugin_id, error, plugins, metadata, plugin_states) do
    Raxol.Core.Runtime.Log.error_with_stacktrace(
      "Plugin reload error",
      error,
      nil,
      %{module: __MODULE__, plugin_id: plugin_id, error: error}
    )

    {:error, error}
  end

  @impl true
  def coordinate_reload(plugin_id, plugins, metadata, plugin_states, load_order, command_table) do
    case reload_plugin_from_disk(
           plugin_id,
           Map.get(plugins, plugin_id),
           Map.get(plugin_states, plugin_id),
           plugins,
           metadata,
           plugin_states,
           load_order,
           command_table
         ) do
      {:ok, updated_plugin_info} ->
        {:ok, updated_plugin_info}

      {:error, reason} ->
        handle_reload_error(plugin_id, reason, plugins, metadata, plugin_states)
    end
  end

  @impl true
  def reload_plugin(plugin_id, state) do
    if !state.initialized do
      {:error, :not_initialized, state}
    else
      Raxol.Core.Runtime.Log.info(
        "[#{__MODULE__}] Reloading plugin: #{plugin_id}"
      )

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

  @impl true
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
            %{
              module: __MODULE__,
              plugin_id: plugin_id_atom,
              plugin_id_string: plugin_id_string
            }
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
