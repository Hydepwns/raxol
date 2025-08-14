defmodule Raxol.Core.Runtime.Plugins.Manager.State do
  @moduledoc """
  Handles plugin state management operations - getting, setting, and updating plugin states.
  """

    require Raxol.Core.Runtime.Log

  @type plugin_id :: String.t()
  @type state :: map()
  @type plugin_state :: map()
  @type result :: {:ok, state()} | {:error, term()}

  @doc """
  Gets the current state of a plugin.
  """
  @spec get_plugin_state(state(), plugin_id()) ::
          {:ok, plugin_state()} | {:error, term()}
  def get_plugin_state(state, plugin_id) do
    case Map.get(state.plugin_states, plugin_id) do
      nil -> {:error, {:plugin_state_not_found, plugin_id}}
      plugin_state -> {:ok, plugin_state}
    end
  end

  @doc """
  Sets the state of a plugin.
  """
  @spec set_plugin_state(state(), plugin_id(), plugin_state()) :: result()
  def set_plugin_state(state, plugin_id, new_state) do
    updated_plugin_states = Map.put(state.plugin_states, plugin_id, new_state)
    updated_state = %{state | plugin_states: updated_plugin_states}
    {:ok, updated_state}
  end

  @doc """
  Updates a plugin using the provided update function.
  """
  @spec update_plugin(state(), plugin_id(), function()) :: result()
  def update_plugin(state, plugin_id, update_fun)
      when is_function(update_fun, 1) do
    case Map.get(state.plugins, plugin_id) do
      nil ->
        {:error, {:plugin_not_found, plugin_id}}

      plugin ->
        try do
          updated_plugin = update_fun.(plugin)
          updated_plugins = Map.put(state.plugins, plugin_id, updated_plugin)
          updated_state = %{state | plugins: updated_plugins}
          {:ok, updated_state}
        rescue
          error ->
            Raxol.Core.Runtime.Log.error_with_stacktrace(
              "Failed to update plugin #{plugin_id}",
              error,
              nil,
              %{module: __MODULE__, plugin_id: plugin_id}
            )

            {:error, {:update_failed, error}}
        end
    end
  end

  @doc """
  Gets plugin configuration.
  """
  @spec get_plugin_config(state(), plugin_id()) ::
          {:ok, map()} | {:error, term()}
  def get_plugin_config(state, plugin_name) do
    case Map.get(state.plugin_config, plugin_name) do
      nil -> {:error, {:plugin_config_not_found, plugin_name}}
      config -> {:ok, config}
    end
  end

  @doc """
  Updates plugin configuration.
  """
  @spec update_plugin_config(state(), plugin_id(), map()) :: result()
  def update_plugin_config(state, plugin_name, config) do
    updated_plugin_config = Map.put(state.plugin_config, plugin_name, config)
    updated_state = %{state | plugin_config: updated_plugin_config}
    {:ok, updated_state}
  end

  @doc """
  Checks if a plugin is loaded.
  """
  @spec plugin_loaded?(state(), plugin_id()) :: boolean()
  def plugin_loaded?(state, plugin_name) do
    Map.has_key?(state.plugins, plugin_name)
  end

  @doc """
  Gets all loaded plugins.
  """
  @spec get_loaded_plugins(state()) :: map()
  def get_loaded_plugins(state) do
    state.plugins
  end

  @doc """
  Lists all plugins with their metadata.
  """
  @spec list_plugins(state()) :: map()
  def list_plugins(state) do
    state.plugins
  end

  @doc """
  Gets a specific plugin by ID.
  """
  @spec get_plugin(state(), plugin_id()) :: {:ok, map()} | {:error, term()}
  def get_plugin(state, plugin_id) do
    case Map.get(state.plugins, plugin_id) do
      nil -> {:error, {:plugin_not_found, plugin_id}}
      plugin -> {:ok, plugin}
    end
  end

  @doc """
  Gets plugin metadata.
  """
  @spec get_metadata(state()) :: map()
  def get_metadata(state) do
    state.metadata
  end

  @doc """
  Gets available commands from all plugins.
  """
  @spec get_commands(state()) :: map()
  def get_commands(state) do
    Enum.reduce(state.plugins, %{}, fn {_id, plugin}, acc ->
      case Map.get(plugin, :commands) do
        nil -> acc
        commands when is_map(commands) -> Map.merge(acc, commands)
        _ -> acc
      end
    end)
  end
end
