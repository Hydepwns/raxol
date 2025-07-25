defmodule Raxol.Core.Runtime.Plugins.Manager.LifecycleOperations do
  @moduledoc """
  Lifecycle operations for plugin management.
  Handles loading, unloading, enabling, disabling, and reloading plugins.
  """

  alias Raxol.Core.Runtime.Plugins.LifecycleManager

  @type plugin_id :: String.t()
  @type plugin_config :: map()
  @type plugin_state :: map()
  @type state :: map()

  @doc """
  Handles loading a plugin with configuration.
  """
  @spec handle_load_plugin(plugin_id(), plugin_config(), state()) :: {:reply, any(), state()}
  def handle_load_plugin(plugin_id, config, state) do
    # Send plugin load attempted event
    send(state.runtime_pid, {:plugin_load_attempted, plugin_id})

    operation =
      LifecycleManager.load_plugin(
        plugin_id,
        config,
        state.plugins,
        state.metadata,
        state.plugin_states,
        state.load_order,
        state.command_registry_table,
        state.plugin_config
      )

    handle_plugin_operation(operation, plugin_id, state, "load")
  end

  @doc """
  Handles loading a plugin without custom configuration.
  """
  @spec handle_load_plugin(plugin_id(), state()) :: {:reply, any(), state()}
  def handle_load_plugin(plugin_id, state) do
    case LifecycleManager.load_plugin(
           plugin_id,
           # default config
           %{},
           state.plugins,
           state.metadata,
           state.plugin_states,
           state.load_order,
           state.command_registry_table,
           state.plugin_config
         ) do
      {:ok, new_plugins, new_metadata, new_plugin_states, new_load_order} ->
        new_state = %{
          state
          | plugins: new_plugins,
            metadata: new_metadata,
            plugin_states: new_plugin_states,
            load_order: new_load_order
        }

        {:reply, {:ok, plugin_id}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @doc """
  Handles unloading a plugin.
  """
  @spec handle_unload_plugin(plugin_id(), state()) :: {:reply, any(), state()}
  def handle_unload_plugin(plugin_id, state) do
    # Send plugin unload attempted event
    send(state.runtime_pid, {:plugin_unload_attempted, plugin_id})

    operation =
      LifecycleManager.unload_plugin(
        plugin_id,
        state.plugins,
        state.metadata,
        state.plugin_states,
        state.load_order,
        state.command_registry_table
      )

    handle_plugin_operation(operation, plugin_id, state, "unload")
  end

  @doc """
  Handles enabling a disabled plugin.
  """
  @spec handle_enable_plugin(plugin_id(), state()) :: {:reply, any(), state()}
  def handle_enable_plugin(plugin_id, state) do
    case Map.get(state.plugins, plugin_id) do
      nil ->
        {:reply, {:error, :plugin_not_found}, state}

      _plugin ->
        new_metadata = Map.put(state.metadata, plugin_id, %{enabled: true})
        new_state = %{state | metadata: new_metadata}
        {:reply, {:ok, plugin_id}, new_state}
    end
  end

  @doc """
  Handles disabling an enabled plugin.
  """
  @spec handle_disable_plugin(plugin_id(), state()) :: {:reply, any(), state()}
  def handle_disable_plugin(plugin_id, state) do
    case Map.get(state.plugins, plugin_id) do
      nil ->
        {:reply, {:error, :plugin_not_found}, state}

      _plugin ->
        new_metadata = Map.put(state.metadata, plugin_id, %{enabled: false})
        new_state = %{state | metadata: new_metadata}
        {:reply, {:ok, plugin_id}, new_state}
    end
  end

  @doc """
  Handles reloading a plugin by unloading and loading it again.
  """
  @spec handle_reload_plugin(plugin_id(), state()) :: {:reply, any(), state()}
  def handle_reload_plugin(plugin_id, state) do
    with {:ok, _} <- handle_unload_plugin(plugin_id, state),
         {:ok, _} <- handle_load_plugin(plugin_id, state) do
      {:reply, {:ok, plugin_id}, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @doc """
  Handles loading a plugin by module with configuration.
  """
  @spec handle_load_plugin_by_module(module(), plugin_config(), state()) :: {:reply, any(), state()}
  def handle_load_plugin_by_module(module, config, state) do
    plugin_id = to_string(module)

    # Create basic metadata for the module-based plugin
    metadata = %{
      id: plugin_id,
      module: module,
      enabled: true,
      config: config
    }

    # Store the plugin and its metadata
    new_plugins = Map.put(state.plugins, plugin_id, module)
    new_metadata = Map.put(state.metadata, plugin_id, metadata)
    new_plugin_states = Map.put(state.plugin_states, plugin_id, %{})
    new_load_order = [plugin_id | state.load_order]

    new_state = %{
      state
      | plugins: new_plugins,
        metadata: new_metadata,
        plugin_states: new_plugin_states,
        load_order: new_load_order
    }

    {:reply, {:ok, plugin_id}, new_state}
  end

  # Private helper function
  defp handle_plugin_operation(operation, plugin_id, state, operation_type) do
    case operation do
      {:ok, new_plugins, new_metadata, new_plugin_states, new_load_order} ->
        new_state = %{
          state
          | plugins: new_plugins,
            metadata: new_metadata,
            plugin_states: new_plugin_states,
            load_order: new_load_order
        }

        # TODO: Properly update the state with the returned values
        {:reply, {:ok, plugin_id}, new_state}

      {:error, reason} ->
        # Send plugin operation failed event
        send(state.runtime_pid, {:plugin_operation_failed, plugin_id, operation_type, reason})
        {:reply, {:error, reason}, state}
    end
  end
end