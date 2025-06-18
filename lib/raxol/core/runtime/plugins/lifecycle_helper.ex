defmodule Raxol.Core.Runtime.Plugins.LifecycleHelper do
  @moduledoc '''
  Helper functions for plugin lifecycle management.
  '''

  @behaviour Raxol.Core.Runtime.Plugins.LifecycleHelper.Behaviour

  alias Raxol.Core.Runtime.Plugins.{
    DependencyManager,
    StateManager,
    CommandRegistry,
    Loader
  }

  require Raxol.Core.Runtime.Log

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def load_plugin(
        plugin_id_or_module,
        config,
        plugins,
        metadata,
        plugin_states,
        load_order,
        command_table,
        plugin_config
      ) do
    with {plugin_id, plugin_module} <- resolve_plugin_identity(plugin_id_or_module),
         :ok <- validate_plugin(plugin_id, plugin_module, plugins),
         {:ok, plugin_metadata} <- Loader.extract_metadata(plugin_module),
         {:ok, updated_maps} <- initialize_and_register_plugin(%{
           plugin_id: plugin_id,
           plugin_module: plugin_module,
           plugin_metadata: plugin_metadata,
           config: config,
           plugins: plugins,
           metadata: metadata,
           plugin_states: plugin_states,
           load_order: load_order,
           command_table: command_table,
           plugin_config: plugin_config
         }) do
      {:ok, updated_maps}
    else
      {:error, :already_loaded} -> {:error, "Plugin #{plugin_id_or_module} is already loaded"}
      {:error, :invalid_plugin} -> {:error, "Plugin #{plugin_id_or_module} does not implement required behaviour"}
      {:error, :dependency_missing, missing} -> {:error, "Missing dependency #{missing} for plugin #{plugin_id_or_module}"}
      {:error, :dependency_cycle, cycle} -> {:error, "Dependency cycle detected: #{inspect(cycle)}"}
      {:error, reason} -> handle_load_error(reason, plugin_id_or_module)
    end
  end

  defp initialize_and_register_plugin(%{
    plugin_id: plugin_id,
    plugin_module: plugin_module,
    plugin_metadata: plugin_metadata,
    config: config,
    plugins: plugins,
    metadata: metadata,
    plugin_states: plugin_states,
    load_order: load_order,
    command_table: command_table,
    plugin_config: plugin_config
  }) do
    with {:ok, initial_state} <- initialize_plugin_state(plugin_module, config),
         :ok <- register_plugin_components(%{
           plugin_id: plugin_id,
           plugin_module: plugin_module,
           initial_state: initial_state,
           command_table: command_table,
           plugin_metadata: plugin_metadata,
           plugins: plugins,
           metadata: metadata,
           plugin_states: plugin_states,
           load_order: load_order,
           plugin_config: plugin_config
         }) do
      build_updated_maps(%{
        plugin_id: plugin_id,
        plugin_module: plugin_module,
        plugin_metadata: plugin_metadata,
        initial_state: initial_state,
        config: config,
        plugins: plugins,
        metadata: metadata,
        plugin_states: plugin_states,
        load_order: load_order,
        plugin_config: plugin_config
      })
    end
  end

  defp initialize_plugin_state(plugin_module, config) do
    plugin_module.init(config)
  end

  defp register_plugin_components(%{
    plugin_id: plugin_id,
    plugin_module: plugin_module,
    initial_state: initial_state,
    command_table: command_table,
    plugin_metadata: plugin_metadata,
    plugins: plugins,
    metadata: metadata,
    plugin_states: plugin_states,
    load_order: load_order,
    plugin_config: plugin_config
  }) do
    with :ok <- update_plugin_state(plugin_id, initial_state, plugins, metadata, plugin_states, load_order, plugin_config),
         :ok <- register_commands(plugin_module, initial_state, command_table) do
      register_plugin(plugin_id, plugin_metadata)
    end
  end

  defp build_updated_maps(%{
    plugin_id: plugin_id,
    plugin_module: plugin_module,
    plugin_metadata: plugin_metadata,
    initial_state: initial_state,
    config: config,
    plugins: plugins,
    metadata: metadata,
    plugin_states: plugin_states,
    load_order: load_order,
    plugin_config: plugin_config
  }) do
    %{
      plugins: Map.put(plugins, plugin_id, plugin_module),
      metadata: Map.put(metadata, plugin_id, plugin_metadata),
      plugin_states: Map.put(plugin_states, plugin_id, initial_state),
      load_order: [plugin_id | load_order],
      plugin_config: Map.put(plugin_config, plugin_id, config)
    }
  end

  defp validate_plugin(plugin_id, plugin_module, plugins) do
    validate_not_loaded(plugin_id, plugins)
    |> and_then(fn :ok -> validate_behaviour(plugin_module) end)
  end

  defp and_then(:ok, fun), do: fun.()
  defp and_then(error, _fun), do: error

  defp validate_dependencies(plugin_id, plugin_metadata, plugins) do
    DependencyManager.check_dependencies(plugin_id, plugin_metadata, plugins)
  end

  defp update_plugin_state(plugin_id, initial_state, plugins, metadata, plugin_states, load_order, plugin_config) do
    StateManager.update_plugin_state(plugin_id, initial_state, %{
      plugins: plugins,
      metadata: metadata,
      plugin_states: plugin_states,
      load_order: load_order,
      plugin_config: plugin_config
    })
  end

  defp register_commands(plugin_module, initial_state, command_table) do
    CommandRegistry.register_plugin_commands(plugin_module, initial_state, command_table)
  end

  defp register_plugin(plugin_id, plugin_metadata) do
    Raxol.Core.Runtime.Plugins.Registry.register_plugin(plugin_id, plugin_metadata)
  end

  defp handle_load_error(reason, plugin_id_or_module) do
    Raxol.Core.Runtime.Log.error_with_stacktrace(
      "Failed to load plugin",
      reason,
      nil,
      %{
        module: __MODULE__,
        plugin_id_or_module: plugin_id_or_module,
        reason: reason
      }
    )
    {:error, reason}
  end

  @impl true
  def initialize_plugins(
        plugins,
        metadata,
        config,
        states,
        load_order,
        command_table,
        _opts
      ) do
    table = initialize_command_table(command_table, plugins)
    Enum.reduce_while(
      load_order,
      {:ok, {metadata, states, table}},
      &initialize_plugin(&1, &2, plugins, config)
    )
  end

  defp initialize_plugin(plugin_id, {:ok, {meta, sts, tbl}}, plugins, plugin_config) do
    case Map.get(plugins, plugin_id) do
      nil -> {:cont, {:ok, {meta, sts, tbl}}}
      plugin -> handle_plugin_init(plugin, plugin_id, meta, sts, tbl, plugin_config)
    end
  end

  defp handle_plugin_init(plugin, plugin_id, meta, sts, tbl, plugin_config) do
    case plugin.init(Map.get(plugin_config, plugin_id, %{})) do
      {:ok, new_states} ->
        new_meta = Map.put(meta, plugin_id, %{status: :active})
        new_tbl = update_command_table(tbl, plugin)
        {:cont, {:ok, {new_meta, Map.merge(sts, new_states), new_tbl}}}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Failed to initialize plugin",
          reason,
          nil,
          %{module: __MODULE__, plugin_id: plugin_id, reason: reason}
        )
        {:halt, {:error, reason}}
    end
  end

  @impl true
  def reload_plugin_from_disk(
        plugin_id,
        plugin_module,
        plugin_path,
        plugin_state,
        command_table,
        metadata,
        _plugin_manager,
        _opts
      ) do
    try do
      with :ok <- reload_module(plugin_module),
           {:ok, updated_state} <- initialize_plugin_state(plugin_module, plugin_state),
           {:ok, updated_table} <- update_command_table(command_table, plugin_module, updated_state) do
        {:ok, updated_state, updated_table, update_metadata(metadata, plugin_id, plugin_path, updated_state)}
      else
        {:error, reason} -> handle_reload_error(reason, plugin_id)
      end
    rescue
      e -> handle_reload_exception(e, plugin_id)
    end
  end

  defp reload_module(plugin_module) do
    with :ok <- :code.purge(plugin_module),
         {:module, ^plugin_module} <- :code.load_file(plugin_module) do
      :ok
    end
  end

  defp initialize_plugin_state(plugin_module, plugin_state) do
    plugin_module.init(plugin_state)
  end

  defp update_metadata(metadata, plugin_id, plugin_path, updated_state) do
    Map.put(metadata, plugin_id, %{
      path: plugin_path,
      state: updated_state,
      last_reload: System.system_time()
    })
  end

  defp handle_reload_error(reason, plugin_id) do
    Raxol.Core.Runtime.Log.error_with_stacktrace(
      "Failed to reload plugin",
      reason,
      nil,
      %{module: __MODULE__, plugin_id: plugin_id, reason: reason}
    )
    {:error, :reload_failed}
  end

  defp handle_reload_exception(e, plugin_id) do
    Raxol.Core.Runtime.Log.error(
      "Failed to reload plugin (exception)",
      %{module: __MODULE__, plugin_id: plugin_id, error: inspect(e)}
    )
    {:error, :reload_failed}
  end

  @impl true
  def unload_plugin(plugin_id, metadata, _config, states, command_table, _opts) do
    with {:ok, _plugin_metadata} <- Map.fetch(metadata, plugin_id),
         :ok <- unregister_plugin_commands(plugin_id, command_table) do
      cleanup_plugin_state(plugin_id, metadata, states, command_table)
    else
      :error -> {:ok, {metadata, states, command_table}}
      {:error, reason} -> handle_unload_error(reason, plugin_id)
    end
  end

  defp unregister_plugin_commands(plugin_id, command_table) do
    CommandRegistry.unregister_plugin_commands(plugin_id, command_table)
  end

  defp cleanup_plugin_state(plugin_id, metadata, states, command_table) do
    Raxol.Core.Runtime.Plugins.Registry.unregister_plugin(plugin_id)
    meta = Map.delete(metadata, plugin_id)
    sts = Map.delete(states, plugin_id)
    {:ok, {meta, sts, command_table}}
  end

  defp handle_unload_error(reason, plugin_id) do
    Raxol.Core.Runtime.Log.error_with_stacktrace(
      "Failed to unload plugin",
      reason,
      nil,
      %{module: __MODULE__, plugin_id: plugin_id, reason: reason}
    )
    {:error, reason}
  end

  @impl true
  def cleanup_plugin(_plugin_id, metadata) do
    # Implementation for cleanup_plugin callback
    {:ok, metadata}
  end

  @impl true
  def handle_state_transition(_plugin_id, _old_state, new_state) do
    # Implementation for handle_state_transition callback
    {:ok, new_state}
  end

  @impl true
  def init_plugin(_plugin_id, metadata) do
    # Implementation for init_plugin callback
    {:ok, metadata}
  end

  @impl true
  def load_plugin_by_module(
        module,
        metadata,
        _config,
        _states,
        _command_table,
        _plugin_manager,
        _current_metadata,
        _opts
      ) do
    # Implementation for load_plugin_by_module callback
    {:ok, {module, metadata}}
  end

  @impl true
  def reload_plugin(
        _plugin_id,
        metadata,
        _config,
        _states,
        _command_table,
        _plugin_manager,
        _opts
      ) do
    # Implementation for reload_plugin callback
    {:ok, metadata}
  end

  @impl true
  def terminate_plugin(_plugin_id, metadata, _reason) do
    # Implementation for terminate_plugin callback
    {:ok, metadata}
  end

  # Private helper functions

  defp resolve_plugin_identity(id) do
    case Raxol.Core.Runtime.Plugins.Loader.load_code(id) do
      :ok -> {:ok, {id, nil}}
      {:error, :module_not_found} -> {:error, :module_not_found}
    end
  end

  defp validate_not_loaded(plugin_id, plugins) do
    if Map.has_key?(plugins, plugin_id) do
      {:error, :already_loaded}
    else
      :ok
    end
  end

  defp validate_behaviour(plugin_module) do
    if Loader.behaviour_implemented?(
         plugin_module,
         Raxol.Core.Runtime.Plugins.Plugin
       ) do
      :ok
    else
      {:error, :invalid_plugin}
    end
  end

  defp initialize_command_table(table, _plugins) do
    table
  end

  defp update_command_table(table, plugin, _state \\ nil) do
    with {:ok, commands} <- get_plugin_commands(plugin),
         :ok <- register_plugin_commands(table, plugin, commands) do
      {:ok, table}
    else
      {:error, reason} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Failed to update command table",
          reason,
          nil,
          %{module: __MODULE__, reason: reason}
        )

        {:error, reason}
    end
  end

  defp get_plugin_commands(plugin) do
    if function_exported?(plugin, :get_commands, 0) do
      {:ok, plugin.get_commands()}
    else
      {:ok, []}
    end
  end

  defp register_plugin_commands(table, plugin, commands) do
    Enum.reduce_while(commands, :ok, fn {name, function, arity}, :ok ->
      case CommandRegistry.register_command(
             table,
             plugin,
             Atom.to_string(name),
             plugin,
             function,
             arity
           ) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  @doc '''
  Catch-all for load_plugin/3. Raises a clear error if called with the wrong arity.
  '''
  def load_plugin(_a, _b, _c) do
    raise "Raxol.Core.Runtime.Plugins.LifecycleHelper.load_plugin/3 is not implemented. Use load_plugin/8."
  end
end
