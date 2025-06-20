defmodule Raxol.Core.Runtime.Plugins.CommandRegistry do
  @moduledoc """
  Manages command registration and execution for plugins.
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

  @impl true
  def new do
    %{}
  end

  @impl true
  def register_command(
        _table_name,
        _namespace,
        command_name,
        module,
        function,
        arity
      ) do
    handler = {module, function, arity}
    metadata = %{}
    {:ok, {command_name, handler, metadata}}
  end

  @impl true
  def unregister_command(_table_name, _namespace, _command_name) do
    {:ok, nil}
  end

  @impl true
  def lookup_command(_table_name, _namespace, _command_name) do
    {:error, :not_found}
  end

  @impl true
  def unregister_commands_by_module(_table_name, _module) do
    {:ok, nil}
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
    try do
      new_commands =
        Enum.map(commands, fn {name, handler, metadata} ->
          wrapped_handler = wrap_handler(handler, plugin_state)
          {name, wrapped_handler, metadata}
        end)

      updated_table = Map.put(command_table, plugin_module, new_commands)
      {:ok, updated_table}
    rescue
      e ->
        Raxol.Core.Runtime.Log.error(
          "Failed to register commands: #{inspect(e)}"
        )

        {:error, :registration_failed}
    end
  end

  defp unregister_commands(_commands, command_table, plugin_module) do
    try do
      updated_table = Map.delete(command_table, plugin_module)
      {:ok, updated_table}
    rescue
      e ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Failed to unregister commands",
          e,
          nil,
          %{plugin_module: plugin_module, module: __MODULE__}
        )

        {:error, :unregistration_failed}
    end
  end

  defp wrap_handler(handler, plugin_state) do
    fn args, context ->
      try do
        handler.(args, Map.put(context, :plugin_state, plugin_state))
      rescue
        e ->
          Raxol.Core.Runtime.Log.error_with_stacktrace(
            "Command execution failed",
            e,
            nil,
            %{plugin_state: plugin_state, module: __MODULE__}
          )

          {:error, {:execution_failed, Exception.message(e)}}
      end
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
    cond do
      not is_map(metadata) -> {:error, :invalid_metadata}
      not valid_metadata_fields?(metadata) -> {:error, :invalid_metadata_fields}
      true -> :ok
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

    try do
      Task.await(Task.async(fn -> handler.(args, context) end), timeout)
    catch
      :exit, {:timeout, _} ->
        {:error, :command_timeout}

      _kind, reason ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Command execution failed in Task.await",
          reason,
          nil,
          %{args: args, module: __MODULE__}
        )

        {:error, {:execution_failed, Exception.message(reason)}}
    end
  end
end
