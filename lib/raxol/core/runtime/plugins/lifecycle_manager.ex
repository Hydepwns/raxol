defmodule Raxol.Core.Runtime.Plugins.LifecycleManager do
  @moduledoc '''
  Handles plugin lifecycle operations including enabling, disabling, and reloading plugins.
  This module is responsible for:
  - Enabling plugins
  - Disabling plugins
  - Reloading plugins
  - Managing plugin states during lifecycle changes
  '''

  require Raxol.Core.Runtime.Log

  @doc '''
  Enables a previously disabled plugin.
  '''
  def enable_plugin(plugin_id, state) do
    case Map.get(state.plugins, plugin_id) do
      nil ->
        {:error, :plugin_not_found}

      plugin ->
        Raxol.Core.Runtime.Log.info_with_context(
          "[#{__MODULE__}] Enabling plugin: #{plugin_id}",
          %{}
        )

        case state.lifecycle_helper_module.enable_plugin(
               plugin,
               state.plugin_states
             ) do
          {:ok, new_plugin_state} ->
            updated_states =
              Map.put(state.plugin_states, plugin_id, new_plugin_state)

            {:ok, %{state | plugin_states: updated_states}}

          {:error, reason} ->
            Raxol.Core.Runtime.Log.error_with_stacktrace(
              "[#{__MODULE__}] Error enabling plugin",
              reason,
              nil,
              %{module: __MODULE__, plugin_id: plugin_id, reason: reason}
            )

            {:error, reason}
        end
    end
  end

  @doc '''
  Disables a plugin temporarily without unloading it.
  '''
  def disable_plugin(plugin_id, state) do
    case Map.get(state.plugins, plugin_id) do
      nil ->
        {:error, :plugin_not_found}

      plugin ->
        Raxol.Core.Runtime.Log.info_with_context(
          "[#{__MODULE__}] Disabling plugin: #{plugin_id}",
          %{}
        )

        case state.lifecycle_helper_module.disable_plugin(
               plugin,
               state.plugin_states
             ) do
          {:ok, new_plugin_state} ->
            updated_states =
              Map.put(state.plugin_states, plugin_id, new_plugin_state)

            {:ok, %{state | plugin_states: updated_states}}

          {:error, reason} ->
            Raxol.Core.Runtime.Log.error_with_stacktrace(
              "[#{__MODULE__}] Error disabling plugin",
              reason,
              nil,
              %{module: __MODULE__, plugin_id: plugin_id, reason: reason}
            )

            {:error, reason}
        end
    end
  end

  @doc '''
  Reloads a plugin by unloading and then loading it again.
  '''
  def reload_plugin(plugin_id, state) do
    case Map.get(state.plugins, plugin_id) do
      nil ->
        {:error, :plugin_not_found}

      _plugin ->
        Raxol.Core.Runtime.Log.info_with_context(
          "[#{__MODULE__}] Reloading plugin: #{plugin_id}",
          %{}
        )
        do_reload_plugin(plugin_id, state)
    end
  end

  defp do_reload_plugin(plugin_id, state) do
    with {:ok, state_after_disable} <- disable_plugin(plugin_id, state),
         {:ok, state_after_enable} <- enable_plugin(plugin_id, state_after_disable) do
      {:ok, state_after_enable}
    else
      {:error, reason} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "[#{__MODULE__}] Error during plugin reload",
          reason,
          nil,
          %{module: __MODULE__, plugin_id: plugin_id, reason: reason}
        )
        {:error, reason}
    end
  end

  @doc '''
  Loads a plugin with the given configuration.
  '''
  def load_plugin(plugin_id, config, state) do
    log_plugin_loading(plugin_id)
    load_and_initialize_plugin(plugin_id, config, state)
  end

  defp log_plugin_loading(plugin_id) do
    Raxol.Core.Runtime.Log.info_with_context(
      "[#{__MODULE__}] Loading plugin: #{plugin_id}",
      %{}
    )
  end

  defp load_and_initialize_plugin(plugin_id, config, state) do
    case state.loader_module.load_plugin(plugin_id, config) do
      {:ok, plugin, metadata} -> initialize_and_update_state(plugin_id, plugin, metadata, config, state)
      {:error, reason} -> handle_load_error(reason, plugin_id)
    end
  end

  defp initialize_and_update_state(plugin_id, plugin, metadata, config, state) do
    case state.lifecycle_helper_module.initialize_plugin(plugin, config) do
      {:ok, initial_state} -> {:ok, update_state_with_plugin(state, plugin_id, plugin, metadata, initial_state)}
      {:error, reason} -> handle_load_error(reason, plugin_id)
    end
  end

  defp update_state_with_plugin(state, plugin_id, plugin, metadata, initial_state) do
    %{state |
      plugins: Map.put(state.plugins, plugin_id, plugin),
      metadata: Map.put(state.metadata, plugin_id, metadata),
      plugin_states: Map.put(state.plugin_states, plugin_id, initial_state),
      load_order: [plugin_id | state.load_order]
    }
  end

  defp handle_load_error(reason, plugin_id) do
    Raxol.Core.Runtime.Log.error_with_stacktrace(
      "[#{__MODULE__}] Error loading plugin",
      reason,
      nil,
      %{module: __MODULE__, plugin_id: plugin_id, reason: reason}
    )
    {:error, reason}
  end
end
