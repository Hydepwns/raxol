defmodule Raxol.Core.Runtime.Plugins.LifecycleManager do
  @moduledoc """
  Handles plugin lifecycle operations including enabling, disabling, and reloading plugins.
  This module is responsible for:
  - Enabling plugins
  - Disabling plugins
  - Reloading plugins
  - Managing plugin states during lifecycle changes
  """

  require Logger

  @doc """
  Enables a previously disabled plugin.
  """
  def enable_plugin(plugin_id, state) do
    case Map.get(state.plugins, plugin_id) do
      nil ->
        {:error, :plugin_not_found}

      plugin ->
        Logger.info("[#{__MODULE__}] Enabling plugin: #{plugin_id}")

        case state.lifecycle_helper_module.enable_plugin(
               plugin,
               state.plugin_states
             ) do
          {:ok, new_plugin_state} ->
            updated_states =
              Map.put(state.plugin_states, plugin_id, new_plugin_state)

            {:ok, %{state | plugin_states: updated_states}}

          {:error, reason} ->
            Logger.error(
              "[#{__MODULE__}] Failed to enable plugin #{plugin_id}: #{inspect(reason)}"
            )

            {:error, reason}
        end
    end
  end

  @doc """
  Disables a plugin temporarily without unloading it.
  """
  def disable_plugin(plugin_id, state) do
    case Map.get(state.plugins, plugin_id) do
      nil ->
        {:error, :plugin_not_found}

      plugin ->
        Logger.info("[#{__MODULE__}] Disabling plugin: #{plugin_id}")

        case state.lifecycle_helper_module.disable_plugin(
               plugin,
               state.plugin_states
             ) do
          {:ok, new_plugin_state} ->
            updated_states =
              Map.put(state.plugin_states, plugin_id, new_plugin_state)

            {:ok, %{state | plugin_states: updated_states}}

          {:error, reason} ->
            Logger.error(
              "[#{__MODULE__}] Failed to disable plugin #{plugin_id}: #{inspect(reason)}"
            )

            {:error, reason}
        end
    end
  end

  @doc """
  Reloads a plugin by unloading and then loading it again.
  """
  def reload_plugin(plugin_id, state) do
    case Map.get(state.plugins, plugin_id) do
      nil ->
        {:error, :plugin_not_found}

      plugin ->
        Logger.info("[#{__MODULE__}] Reloading plugin: #{plugin_id}")

        # First disable the plugin
        case disable_plugin(plugin_id, state) do
          {:ok, state_after_disable} ->
            # Then re-enable it
            case enable_plugin(plugin_id, state_after_disable) do
              {:ok, state_after_enable} ->
                {:ok, state_after_enable}

              {:error, reason} ->
                Logger.error(
                  "[#{__MODULE__}] Failed to re-enable plugin #{plugin_id} after reload: #{inspect(reason)}"
                )

                {:error, reason}
            end

          {:error, reason} ->
            Logger.error(
              "[#{__MODULE__}] Failed to disable plugin #{plugin_id} for reload: #{inspect(reason)}"
            )

            {:error, reason}
        end
    end
  end

  @doc """
  Loads a plugin with the given configuration.
  """
  def load_plugin(plugin_id, config, state) do
    Logger.info("[#{__MODULE__}] Loading plugin: #{plugin_id}")

    case state.loader_module.load_plugin(plugin_id, config) do
      {:ok, plugin, metadata} ->
        # Initialize the plugin
        case state.lifecycle_helper_module.initialize_plugin(plugin, config) do
          {:ok, initial_state} ->
            # Update state with new plugin
            updated_state = %{
              state
              | plugins: Map.put(state.plugins, plugin_id, plugin),
                metadata: Map.put(state.metadata, plugin_id, metadata),
                plugin_states:
                  Map.put(state.plugin_states, plugin_id, initial_state),
                load_order: [plugin_id | state.load_order]
            }

            {:ok, updated_state}

          {:error, reason} ->
            Logger.error(
              "[#{__MODULE__}] Failed to initialize plugin #{plugin_id}: #{inspect(reason)}"
            )

            {:error, reason}
        end

      {:error, reason} ->
        Logger.error(
          "[#{__MODULE__}] Failed to load plugin #{plugin_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end
end
