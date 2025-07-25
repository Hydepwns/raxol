defmodule Raxol.Core.Runtime.Plugins.Manager.StateOperations do
  @moduledoc """
  State management operations for plugin manager.
  Handles plugin state queries, updates, and configuration management.
  """

  @type plugin_id :: String.t()
  @type plugin_state :: map()
  @type state :: map()

  @doc """
  Gets the list of all loaded plugins.
  """
  @spec handle_get_loaded_plugins(state()) :: {:reply, list(), state()}
  def handle_get_loaded_plugins(state) do
    plugins = Map.keys(state.plugins)
    {:reply, plugins, state}
  end

  @doc """
  Gets the state of a specific plugin.
  """
  @spec handle_get_plugin_state(plugin_id(), state()) :: {:reply, any(), state()}
  def handle_get_plugin_state(plugin_id, state) do
    plugin_state = Map.get(state.plugin_states, plugin_id, %{})
    {:reply, plugin_state, state}
  end

  @doc """
  Sets the state of a specific plugin.
  """
  @spec handle_set_plugin_state(plugin_id(), plugin_state(), state()) :: {:reply, :ok, state()}
  def handle_set_plugin_state(plugin_id, new_state, state) do
    new_plugin_states = Map.put(state.plugin_states, plugin_id, new_state)
    updated_state = %{state | plugin_states: new_plugin_states}
    {:reply, :ok, updated_state}
  end

  @doc """
  Updates the state of a specific plugin using an update function.
  """
  @spec handle_update_plugin_state(plugin_id(), function(), state()) :: {:reply, any(), state()}
  def handle_update_plugin_state(plugin_id, update_fun, state) do
    current_state = Map.get(state.plugin_states, plugin_id, %{})
    new_plugin_state = update_fun.(current_state)
    new_plugin_states = Map.put(state.plugin_states, plugin_id, new_plugin_state)
    updated_state = %{state | plugin_states: new_plugin_states}
    {:reply, new_plugin_state, updated_state}
  end

  @doc """
  Gets all plugins.
  """
  @spec handle_get_plugins(state()) :: {:reply, map(), state()}
  def handle_get_plugins(state) do
    {:reply, state.plugins, state}
  end

  @doc """
  Gets all plugin states.
  """
  @spec handle_get_plugin_states(state()) :: {:reply, map(), state()}
  def handle_get_plugin_states(state) do
    {:reply, state.plugin_states, state}
  end

  @doc """
  Lists all plugins with their metadata.
  """
  @spec handle_list_plugins(state()) :: {:reply, list(), state()}
  def handle_list_plugins(state) do
    plugins_with_metadata =
      Enum.map(state.plugins, fn {plugin_id, module} ->
        metadata = Map.get(state.metadata, plugin_id, %{})
        
        %{
          id: plugin_id,
          module: module,
          metadata: metadata,
          enabled: Map.get(metadata, :enabled, true)
        }
      end)

    {:reply, plugins_with_metadata, state}
  end

  @doc """
  Gets a specific plugin by ID.
  """
  @spec handle_get_plugin(plugin_id(), state()) :: {:reply, any(), state()}
  def handle_get_plugin(plugin_id, state) do
    case Map.get(state.plugins, plugin_id) do
      nil ->
        {:reply, {:error, :plugin_not_found}, state}

      module ->
        metadata = Map.get(state.metadata, plugin_id, %{})
        plugin_info = %{
          id: plugin_id,
          module: module,
          metadata: metadata,
          enabled: Map.get(metadata, :enabled, true)
        }
        {:reply, {:ok, plugin_info}, state}
    end
  end

  @doc """
  Checks if a plugin is loaded.
  """
  @spec handle_plugin_loaded?(plugin_id(), state()) :: {:reply, boolean(), state()}
  def handle_plugin_loaded?(plugin_id, state) do
    loaded = Map.has_key?(state.plugins, plugin_id)
    {:reply, loaded, state}
  end

  @doc """
  Gets the full state (for debugging/testing).
  """
  @spec handle_get_full_state(state()) :: {:reply, state(), state()}
  def handle_get_full_state(state) do
    {:reply, state, state}
  end
end