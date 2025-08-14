defmodule Raxol.Core.Runtime.Plugins.CommandRegistry do
  @moduledoc """
  Manages command registration and execution for plugins.
  
  REFACTORED: All try/rescue/catch blocks replaced with functional patterns.
  """

  @behaviour Raxol.Core.Runtime.Plugins.PluginCommandRegistry.Behaviour

  require Raxol.Core.Runtime.Log

  @type command_name :: String.t()
  @type command_handler :: function()
  @type command_metadata :: %{
          optional(:description) => String.t(),
          optional(:usage) => String.t(),
          optional(:aliases) => [String.t()],
          optional(:timeout) => non_neg_integer()
        }
  @type command :: {command_name(), command_handler(), command_metadata()}

  @impl Raxol.Core.Runtime.Plugins.PluginCommandRegistry.Behaviour
  def new do
    %{}
  end

  @impl Raxol.Core.Runtime.Plugins.PluginCommandRegistry.Behaviour
  def register_command(
        table_name,
        namespace,
        command_name,
        module,
        function,
        arity
      ) do
    handler = {module, function, arity}
    metadata = %{}

    # Store the command in the table
    case table_name do
      table when is_map(table) ->
        # If table is a map, store commands by namespace
        namespace_commands = Map.get(table, namespace, [])

        updated_commands = [
          {command_name, handler, metadata} | namespace_commands
        ]

        updated_table = Map.put(table, namespace, updated_commands)
        {:ok, updated_table}

      _ ->
        # If table is not a map, return error
        {:error, :invalid_table}
    end
  end

  @impl Raxol.Core.Runtime.Plugins.PluginCommandRegistry.Behaviour
  def unregister_command(table_name, namespace, command_name) do
    case table_name do
      table when is_map(table) ->
        namespace_commands = Map.get(table, namespace, [])

        updated_commands =
          Enum.reject(namespace_commands, fn {name, _, _} ->
            name == command_name
          end)

        if updated_commands == namespace_commands do
          {:error, :not_found}
        else
          updated_table = Map.put(table, namespace, updated_commands)
          {:ok, updated_table}
        end

      _ ->
        {:error, :invalid_table}
    end
  end

  @impl Raxol.Core.Runtime.Plugins.PluginCommandRegistry.Behaviour
  def lookup_command(table_name, namespace, command_name) do
    case table_name do
      table when is_map(table) ->
        namespace_commands = Map.get(table, namespace, [])

        case Enum.find(namespace_commands, fn {name, _, _} ->
               name == command_name
             end) do
          nil ->
            {:error, :not_found}

          {_name, {module, function, arity}, _metadata} ->
            # Create a function that calls the module function
            handler = fn args, state ->
              apply(module, function, [args, state])
            end

            {:ok, {module, handler, arity}}
        end

      _ ->
        {:error, :invalid_table}
    end
  end

  @impl Raxol.Core.Runtime.Plugins.PluginCommandRegistry.Behaviour
  def unregister_commands_by_module(table_name, module) do
    case table_name do
      table when is_map(table) ->
        # Remove all commands for this module
        updated_table = Map.delete(table, module)
        {:ok, updated_table}

      _ ->
        {:error, :invalid_table}
    end
  end

  @doc """
  Registers commands for a plugin.
  """
  def register_plugin_commands(plugin_module, plugin_state, command_table) do
    with {:ok, commands} <- get_plugin_commands(plugin_module),
         :ok <- validate_commands(commands),
         :ok <- check_command_conflicts(commands, command_table) do
      register_commands(commands, plugin_module, plugin_state, command_table)
    end
  end

  @doc """
  Unregisters all commands for a plugin.
  """
  def unregister_plugin_commands(plugin_module, command_table) do
    case Map.get(command_table, plugin_module) do
      nil -> :ok
      commands -> unregister_commands(commands, command_table, plugin_module)
    end
  end

  @doc """
  Executes a command with proper error handling and timeout.
  """
  def execute_command(command_name, args, command_table) do
    case find_command(command_name, command_table) do
      {:ok, {handler, metadata}} ->
        execute_with_timeout(handler, args, metadata)

      {:error, reason} = error ->
        Raxol.Core.Runtime.Log.error(
          "Failed to execute command #{command_name}: #{inspect(reason)}"
        )

        error
    end
  end

  @doc """
  Looks up the handler for a command name and namespace (plugin module).
  Returns {:ok, {module, function, arity}} or {:error, :not_found}.
  """
  def find_command(command_name, command_table) do
    command_table
    |> Enum.find_value({:error, :not_found}, fn {_namespace, commands} ->
      commands
      |> Enum.find(fn {name, _handler, _metadata} -> name == command_name end)
      |> case do
        nil -> nil
        {_name, handler, metadata} -> {:ok, {handler, metadata}}
      end
    end)
  end

  defp check_command_conflicts(commands, command_table) do
    Enum.reduce_while(commands, :ok, fn {name, _, _}, :ok ->
      if command_exists?(name, command_table) do
        {:halt, {:error, {:command_exists, name}}}
      else
        {:cont, :ok}
      end
    end)
  end

  defp command_exists?(name, command_table) do
    Enum.any?(command_table, fn {_, commands} ->
      Enum.any?(commands, fn {cmd_name, _, _} -> cmd_name == name end)
    end)
  end

  defp register_commands(commands, plugin_module, plugin_state, command_table) do
    with {:ok, new_commands} <- safe_map_commands(commands, plugin_state) do
      updated_table = Map.put(command_table, plugin_module, new_commands)
      {:ok, updated_table}
    else
      {:error, reason} ->
        Raxol.Core.Runtime.Log.error(
          "Failed to register commands: #{inspect(reason)}"
        )
        {:error, :registration_failed}
    end
  end

  defp safe_map_commands(commands, plugin_state) do
    # Use Task to safely map commands with error isolation
    task = Task.async(fn ->
      Enum.map(commands, fn {name, handler, metadata} ->
        wrapped_handler = wrap_handler(handler, plugin_state)
        {name, wrapped_handler, metadata}
      end)
    end)
    
    case Task.yield(task, 1000) || Task.shutdown(task, :brutal_kill) do
      {:ok, new_commands} -> {:ok, new_commands}
      nil -> {:error, :mapping_timeout}
      {:exit, reason} -> {:error, {:mapping_failed, reason}}
    end
  end

  defp unregister_commands(_commands, command_table, plugin_module) do
    # Use functional approach for safe deletion
    task = Task.async(fn ->
      Map.delete(command_table, plugin_module)
    end)
    
    case Task.yield(task, 100) || Task.shutdown(task, :brutal_kill) do
      {:ok, updated_table} -> 
        {:ok, updated_table}
      nil -> 
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Failed to unregister commands - timeout",
          :timeout,
          nil,
          %{plugin_module: plugin_module, module: __MODULE__}
        )
        {:error, :unregistration_failed}
      {:exit, reason} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Failed to unregister commands",
          reason,
          nil,
          %{plugin_module: plugin_module, module: __MODULE__}
        )
        {:error, :unregistration_failed}
    end
  end

  defp wrap_handler(handler, plugin_state) do
    fn args, context ->
      safe_execute_handler(handler, args, Map.put(context, :plugin_state, plugin_state))
    end
  end

  defp safe_execute_handler(handler, args, context) do
    # Use Task for safe execution with error isolation
    task = Task.async(fn ->
      handler.(args, context)
    end)
    
    case Task.yield(task, 5000) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} -> 
        result
      nil ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Command execution timeout",
          :timeout,
          nil,
          %{plugin_state: context.plugin_state, module: __MODULE__}
        )
        {:error, {:execution_failed, "Command execution timeout"}}
      {:exit, reason} ->
        error_msg = format_error_message(reason)
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Command execution failed",
          reason,
          nil,
          %{plugin_state: context.plugin_state, module: __MODULE__}
        )
        {:error, {:execution_failed, error_msg}}
    end
  end

  defp get_plugin_commands(plugin_module) do
    case plugin_module.commands() do
      commands when is_list(commands) -> {:ok, commands}
      _ -> {:error, :invalid_commands}
    end
  end

  defp validate_commands(commands) do
    Enum.reduce_while(commands, :ok, fn command, :ok ->
      case validate_command(command) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_command(command) do
    with :ok <- validate_command_handler(command.handler),
         :ok <- validate_command_metadata(command.metadata) do
      :ok
    end
  end

  defp validate_command_handler(handler) do
    if is_function(handler, 2),
      do: :ok,
      else: {:error, :invalid_command_handler}
  end

  defp validate_command_metadata(metadata) do
    with true <- is_map(metadata),
         true <- valid_metadata_fields?(metadata) do
      :ok
    else
      false -> {:error, :invalid_metadata_fields}
    end
  end

  defp valid_metadata_fields?(metadata) do
    Enum.all?(metadata, fn {key, value} ->
      case key do
        :description -> is_binary(value)
        :usage -> is_binary(value)
        :aliases -> is_list(value) and Enum.all?(value, &is_binary/1)
        :timeout -> is_integer(value) and value > 0
        _ -> false
      end
    end)
  end

  defp execute_with_timeout(handler, args, metadata) do
    timeout = Map.get(metadata, :timeout, 5000)

    context = %{
      timestamp: System.system_time(),
      metadata: metadata
    }

    # Use Task.async/yield instead of Task.await with try/catch
    task = Task.async(fn -> handler.(args, context) end)
    
    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} ->
        result
      
      nil ->
        # Timeout occurred
        {:error, :command_timeout}
      
      {:exit, reason} ->
        # Task crashed
        error_msg = format_error_message(reason)
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Command execution failed in Task",
          reason,
          nil,
          %{args: args, module: __MODULE__}
        )
        {:error, {:execution_failed, error_msg}}
    end
  end

  defp format_error_message(reason) when is_binary(reason), do: reason
  defp format_error_message(%{message: msg}), do: msg
  defp format_error_message({:timeout, _}), do: "Command execution timeout"
  defp format_error_message(reason), do: inspect(reason)
end