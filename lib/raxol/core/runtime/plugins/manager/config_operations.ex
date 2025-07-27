defmodule Raxol.Core.Runtime.Plugins.Manager.ConfigOperations do
  @moduledoc """
  Configuration management operations for plugin manager.
  Handles plugin configuration retrieval and updates.
  """

  @type plugin_id :: String.t()
  @type plugin_config :: map()
  @type state :: map()

  @doc """
  Gets the configuration for a specific plugin.
  """
  @spec handle_get_plugin_config(plugin_id(), state()) ::
          {:reply, any(), state()}
  def handle_get_plugin_config(plugin_id, state) do
    config = Map.get(state.plugin_config, plugin_id, %{})
    {:reply, config, state}
  end

  @doc """
  Updates the configuration for a specific plugin.
  """
  @spec handle_update_plugin_config(plugin_id(), plugin_config(), state()) ::
          {:reply, :ok, state()}
  def handle_update_plugin_config(plugin_id, config, state) do
    new_plugin_config = Map.put(state.plugin_config, plugin_id, config)
    updated_state = %{state | plugin_config: new_plugin_config}
    {:reply, :ok, updated_state}
  end

  @doc """
  Initializes a plugin with specific configuration.
  """
  @spec handle_initialize_plugin(plugin_id(), plugin_config(), state()) ::
          {:reply, any(), state()}
  def handle_initialize_plugin(plugin_id, config, state) do
    case Map.get(state.plugins, plugin_id) do
      nil ->
        {:reply, {:error, :plugin_not_found}, state}

      plugin_module ->
        # Store the configuration
        new_plugin_config = Map.put(state.plugin_config, plugin_id, config)

        # Initialize plugin state if the module supports it
        initial_state =
          if function_exported?(plugin_module, :init, 1) do
            apply(plugin_module, :init, [config])
          else
            %{}
          end

        new_plugin_states =
          Map.put(state.plugin_states, plugin_id, initial_state)

        updated_state = %{
          state
          | plugin_config: new_plugin_config,
            plugin_states: new_plugin_states
        }

        {:reply, {:ok, plugin_id}, updated_state}
    end
  end

  @doc """
  Initializes the plugin system with given configuration.
  """
  @spec handle_init_with_config(map(), state()) :: {:reply, any(), state()}
  def handle_init_with_config(config, state) do
    # Apply global plugin configuration
    updated_state = %{
      state
      | plugin_config: Map.merge(state.plugin_config, config)
    }

    {:reply, {:ok, updated_state}, updated_state}
  end

  @doc """
  Initializes the plugin system (basic initialization).
  """
  @spec handle_initialize(state()) :: {:reply, any(), state()}
  def handle_initialize(state) do
    {:reply, {:ok, :initialized}, state}
  end
end
