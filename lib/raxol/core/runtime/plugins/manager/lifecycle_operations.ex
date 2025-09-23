defmodule Raxol.Core.Runtime.Plugins.PluginManager.LifecycleOperations do
  @moduledoc """
  Lifecycle operations for plugin management.
  Handles loading, unloading, enabling, disabling, and reloading plugins.
  """

  alias Raxol.Core.Runtime.Plugins.LifecycleManager

  @type plugin_id :: String.t()
  @type plugin_config :: map()
  @type state :: map()

  @doc """
  Handles loading a plugin with configuration.
  """
  @spec handle_load_plugin(plugin_id(), plugin_config(), state()) ::
          {:ok, state()} | {:error, term(), state()}
  def handle_load_plugin(plugin_id, config, state) do
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
  @spec handle_load_plugin(plugin_id(), state()) :: {:ok, state()} | {:error, term(), state()}
  def handle_load_plugin(plugin_id, state) do
    operation =
      LifecycleManager.load_plugin(
        plugin_id,
        # default config
        %{},
        state.plugins,
        state.metadata,
        state.plugin_states,
        state.load_order,
        state.command_registry_table,
        state.plugin_config
      )

    handle_plugin_operation(operation, plugin_id, state, "load")
  end

  defp handle_plugin_operation(operation, plugin_id, state, operation_type) do
    send(
      state.runtime_pid,
      {:plugin_operation_attempted, plugin_id, operation_type}
    )

    case operation do
      {:ok, %{plugins: new_plugins, metadata: new_metadata, plugin_states: new_plugin_states, load_order: new_load_order}} ->
        new_state = %{
          state
          | plugins: new_plugins,
            metadata: new_metadata,
            plugin_states: new_plugin_states,
            load_order: new_load_order
        }

        send(
          state.runtime_pid,
          {:plugin_operation_succeeded, plugin_id, operation_type}
        )

        {:ok, new_state}

      {:error, reason} ->
        send(
          state.runtime_pid,
          {:plugin_operation_failed, plugin_id, operation_type, reason}
        )

        {:error, reason, state}
    end
  end

  @doc """
  Handles unloading a plugin.
  """
  @spec handle_unload_plugin(plugin_id(), state()) :: {:ok, state()} | {:error, term(), state()}
  def handle_unload_plugin(plugin_id, state) do
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
  @spec handle_enable_plugin(plugin_id(), state()) :: {:ok, state()} | {:error, term(), state()}
  def handle_enable_plugin(plugin_id, state) do
    operation =
      LifecycleManager.enable_plugin(plugin_id, state)

    handle_plugin_operation(operation, plugin_id, state, "enable")
  end

  @doc """
  Handles disabling an enabled plugin.
  """
  @spec handle_disable_plugin(plugin_id(), state()) :: {:ok, state()} | {:error, term(), state()}
  def handle_disable_plugin(plugin_id, state) do
    operation =
      LifecycleManager.disable_plugin(plugin_id, state)

    handle_plugin_operation(operation, plugin_id, state, "disable")
  end

  @doc """
  Handles reloading a plugin by unloading and loading it again.
  """
  @spec handle_reload_plugin(plugin_id(), state()) :: {:ok, state()} | {:error, term(), state()}
  def handle_reload_plugin(plugin_id, state) do
    operation =
      LifecycleManager.reload_plugin(plugin_id, state)

    handle_plugin_operation(operation, plugin_id, state, "reload")
  end

  @doc """
  Handles loading a plugin by module with configuration.
  """
  @spec handle_load_plugin_by_module(module(), plugin_config(), state()) ::
          {:ok, state()}
  def handle_load_plugin_by_module(module, config, state) do
    plugin_id = to_string(module)

    metadata = %{
      id: plugin_id,
      module: module,
      enabled: true,
      config: config
    }

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

    {:ok, new_state}
  end
end
