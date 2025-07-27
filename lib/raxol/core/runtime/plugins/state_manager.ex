defmodule Raxol.Core.Runtime.Plugins.StateManager do
  @moduledoc """
  Handles plugin state management operations including getting, setting, and updating plugin states.
  """

  require Raxol.Core.Runtime.Log

  @doc """
  Initializes the state manager with default plugin states.
  """
  def initialize(initial_state \\ %{}) do
    Raxol.Core.Runtime.Log.info(
      "[#{__MODULE__}] Initializing plugin state manager",
      %{}
    )

    default_state = %{
      plugin_states: %{},
      plugin_config: %{},
      metadata: %{},
      command_registry_table: nil
    }

    Map.merge(default_state, initial_state)
  end

  @doc """
  Sets a plugin's state directly.
  """
  def set_plugin_state(plugin_id, new_state, state) do
    Raxol.Core.Runtime.Log.info(
      "[#{__MODULE__}] Setting state for plugin: #{plugin_id}",
      %{plugin_id: plugin_id}
    )

    updated_plugin_states = Map.put(state.plugin_states, plugin_id, new_state)
    %{state | plugin_states: updated_plugin_states}
  end

  @doc """
  Updates a plugin's state using a function.
  """
  def update_plugin_state(plugin_id, update_fun, state)
      when is_function(update_fun, 1) do
    Raxol.Core.Runtime.Log.info(
      "[#{__MODULE__}] Updating state for plugin: #{plugin_id}",
      %{plugin_id: plugin_id}
    )

    current_state = Map.get(state.plugin_states, plugin_id, %{})
    updated_state = update_fun.(current_state)

    updated_plugin_states =
      Map.put(state.plugin_states, plugin_id, updated_state)

    %{state | plugin_states: updated_plugin_states}
  end

  @doc """
  Gets a plugin's current state.
  """
  def get_plugin_state(plugin_id, state) do
    case Map.get(state.plugin_states, plugin_id) do
      nil -> {:error, :plugin_not_found}
      plugin_state -> {:ok, plugin_state}
    end
  end

  @doc """
  Gets a plugin's configuration.
  """
  def get_plugin_config(plugin_name, state) do
    case Map.get(state.plugin_config, plugin_name) do
      nil -> {:error, :plugin_not_found}
      config -> {:ok, config}
    end
  end

  @doc """
  Updates a plugin's configuration.
  """
  def update_plugin_config(plugin_name, config, state) do
    case validate_plugin_config_static(plugin_name, config) do
      :ok ->
        Raxol.Core.Runtime.Log.info(
          "[#{__MODULE__}] Updating config for plugin: #{plugin_name}",
          %{plugin_name: plugin_name}
        )

        updated_plugin_config =
          Map.put(state.plugin_config, plugin_name, config)

        %{state | plugin_config: updated_plugin_config}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "[#{__MODULE__}] Failed to update config for plugin: #{plugin_name}",
          reason,
          nil,
          %{plugin_name: plugin_name, reason: reason}
        )

        {:error, reason}
    end
  end

  @doc """
  Validates a plugin's configuration.
  """
  def validate_plugin_config(plugin_name, config) do
    case validate_plugin_config_static(plugin_name, config) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Updates plugin state with new metadata, states, and table.
  """
  def update_plugin_state(
        state,
        updated_metadata,
        updated_states,
        updated_table
      ) do
    %{
      state
      | metadata: updated_metadata,
        plugin_states: updated_states,
        command_registry_table: updated_table
    }
  end

  # Helper function to validate plugin configuration
  defp validate_plugin_config_static(_plugin_name, config)
       when is_map(config) do
    # Basic validation - ensure config is a map and has required fields
    case config do
      %{enabled: enabled} when is_boolean(enabled) ->
        :ok

      %{} ->
        # Config is valid if it's a map, even without required fields
        :ok

      _ ->
        {:error, :invalid_config_format}
    end
  end

  defp validate_plugin_config_static(_plugin_name, _config) do
    {:error, :invalid_config_format}
  end
end
