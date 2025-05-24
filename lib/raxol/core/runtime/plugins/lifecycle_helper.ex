defmodule Raxol.Core.Runtime.Plugins.LifecycleHelper do
  @moduledoc """
  Helper functions for plugin lifecycle management.
  """

  @behaviour Raxol.Core.Runtime.Plugins.LifecycleHelper.Behaviour

  alias Raxol.Core.Runtime.Plugins.{
    DependencyManager,
    StateManager,
    CommandRegistry,
    Loader
  }

  require Logger

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @doc """
  Loads a plugin by ID or module with improved error handling and state persistence.
  """
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
    with {plugin_id, plugin_module} <-
           resolve_plugin_identity(plugin_id_or_module),
         :ok <- validate_not_loaded(plugin_id, plugins),
         {:ok, plugin_metadata} <- Loader.extract_metadata(plugin_module),
         :ok <-
           DependencyManager.check_dependencies(
             plugin_id,
             plugin_metadata,
             plugins
           ),
         :ok <- validate_behaviour(plugin_module),
         {:ok, initial_state} <-
           Loader.initialize_plugin(plugin_module, config),
         :ok <-
           StateManager.update_plugin_state(plugin_id, initial_state),
         :ok <-
           CommandRegistry.register_plugin_commands(
             plugin_module,
             initial_state,
             command_table
           ) do
      # Register the plugin in the GenServer-based registry
      Raxol.Core.Runtime.Plugins.Registry.register_plugin(
        plugin_id,
        plugin_metadata
      )

      # Update state maps with proper error handling
      updated_maps = %{
        plugins: Map.put(plugins, plugin_id, plugin_module),
        metadata: Map.put(metadata, plugin_id, plugin_metadata),
        plugin_states: Map.put(plugin_states, plugin_id, initial_state),
        load_order: [plugin_id | load_order],
        plugin_config: Map.put(plugin_config, plugin_id, config)
      }

      {:ok, updated_maps}
    else
      {:error, :already_loaded} ->
        {:error, "Plugin #{plugin_id_or_module} is already loaded"}

      {:error, :invalid_plugin} ->
        {:error,
         "Plugin #{plugin_id_or_module} does not implement required behaviour"}

      {:error, :dependency_missing, missing} ->
        {:error,
         "Missing dependency #{missing} for plugin #{plugin_id_or_module}"}

      {:error, :dependency_cycle, cycle} ->
        {:error, "Dependency cycle detected: #{inspect(cycle)}"}

      {:error, reason} ->
        Logger.error(
          "Failed to load plugin #{plugin_id_or_module}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Initializes plugins in the correct order with improved error handling.
  """
  def initialize_plugins(
        plugins,
        metadata,
        config,
        states,
        load_order,
        command_table,
        _opts
      ) do
    # Initialize command table
    table = initialize_command_table(command_table, plugins)

    # Initialize plugins in order with proper error handling
    Enum.reduce_while(
      load_order,
      {:ok, {metadata, states, table}},
      fn plugin_id, {:ok, {meta, sts, tbl}} ->
        case Map.get(plugins, plugin_id) do
          nil ->
            {:cont, {:ok, {meta, sts, tbl}}}

          plugin ->
            case plugin.init(config) do
              {:ok, new_states} ->
                new_meta = Map.put(meta, plugin_id, %{status: :active})
                new_tbl = update_command_table(tbl, plugin)
                {:cont, {:ok, {new_meta, Map.merge(sts, new_states), new_tbl}}}

              {:error, reason} ->
                Logger.error(
                  "Failed to initialize plugin #{plugin_id}: #{inspect(reason)}"
                )

                {:halt, {:error, reason}}
            end
        end
      end
    )
  end

  @doc """
  Reloads a plugin from disk with improved state persistence and error handling.
  """
  def reload_plugin_from_disk(
        plugin_id,
        plugin_module,
        plugin_path,
        plugin_state,
        command_table,
        metadata,
        plugin_manager,
        _current_metadata
      ) do
    try do
      # Reload the module with proper error handling
      with :ok <- :code.purge(plugin_module),
           {:module, ^plugin_module} <- :code.load_file(plugin_module),
           {:ok, updated_state} <- plugin_module.init(plugin_state),
           {:ok, updated_table} <-
             update_command_table(command_table, plugin_module, updated_state) do
        # Update metadata with proper error handling
        updated_metadata =
          Map.put(metadata, plugin_id, %{
            path: plugin_path,
            state: updated_state,
            last_reload: System.system_time()
          })

        {:ok, updated_state, updated_table, updated_metadata}
      else
        {:error, reason} ->
          Logger.error(
            "Failed to reload plugin #{plugin_id}: #{inspect(reason)}"
          )

          {:error, :reload_failed}
      end
    rescue
      e ->
        Logger.error("Failed to reload plugin #{plugin_id}: #{inspect(e)}")
        {:error, :reload_failed}
    end
  end

  @doc """
  Unloads a plugin with improved cleanup and error handling.
  """
  def unload_plugin(plugin_id, metadata, _config, states, command_table, _opts) do
    with {:ok, plugin_metadata} <- Map.fetch(metadata, plugin_id),
         :ok <-
           CommandRegistry.unregister_plugin_commands(plugin_id, command_table) do
      # Unregister the plugin from the GenServer-based registry
      Raxol.Core.Runtime.Plugins.Registry.unregister_plugin(plugin_id)
      # Remove plugin from metadata and states
      meta = Map.delete(metadata, plugin_id)
      sts = Map.delete(states, plugin_id)

      {:ok, {meta, sts, command_table}}
    else
      :error ->
        # Plugin not found, return unchanged state
        {:ok, {metadata, states, command_table}}

      {:error, reason} ->
        Logger.error("Failed to unload plugin #{plugin_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private helper functions

  defp resolve_plugin_identity(plugin_id_or_module) do
    case plugin_id_or_module do
      id when is_binary(id) ->
        case Loader.load_code(id) do
          {:ok, module} -> {:ok, {id, module}}
          error -> error
        end

      module when is_atom(module) ->
        case Loader.extract_metadata(module) do
          {:ok, %{id: id}} -> {:ok, {id, module}}
          error -> error
        end
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

  defp update_command_table(table, plugin, state \\ nil) do
    with {:ok, commands} <- get_plugin_commands(plugin),
         :ok <- register_plugin_commands(table, plugin, commands) do
      {:ok, table}
    else
      {:error, reason} ->
        Logger.error("Failed to update command table: #{inspect(reason)}")
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

  @doc """
  Catch-all for load_plugin/3. Raises a clear error if called with the wrong arity.
  """
  def load_plugin(_a, _b, _c) do
    raise "Raxol.Core.Runtime.Plugins.LifecycleHelper.load_plugin/3 is not implemented. Use load_plugin/8."
  end
end
