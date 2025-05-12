defmodule Raxol.Core.Runtime.Plugins.CommandRegistry do
  @moduledoc """
  Manages command registration and execution for plugins.
  """

  require Logger

  @type command_name :: String.t()
  @type command_handler :: function()
  @type command_metadata :: %{
    optional(:description) => String.t(),
    optional(:usage) => String.t(),
    optional(:aliases) => [String.t()],
    optional(:timeout) => non_neg_integer()
  }
  @type command :: {command_name(), command_handler(), command_metadata()}

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
        Logger.error("Failed to execute command #{command_name}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Creates a new command registry table (as a map).
  Returns the new, empty command table.
  """
  def new do
    %{}
  end

  # Private helper functions

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

  defp validate_command({name, handler, metadata}) do
    with :ok <- validate_command_name(name),
         :ok <- validate_command_handler(handler),
         :ok <- validate_command_metadata(metadata) do
      :ok
    end
  end

  defp validate_command_name(name) do
    cond do
      not is_binary(name) -> {:error, :invalid_command_name}
      String.length(name) == 0 -> {:error, :empty_command_name}
      not String.match?(name, ~r/^[a-zA-Z0-9_-]+$/) -> {:error, :invalid_command_name_format}
      true -> :ok
    end
  end

  defp validate_command_handler(handler) do
    if is_function(handler, 2), do: :ok, else: {:error, :invalid_command_handler}
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
      new_commands = Enum.map(commands, fn {name, handler, metadata} ->
        wrapped_handler = wrap_handler(handler, plugin_state)
        {name, wrapped_handler, metadata}
      end)

      updated_table = Map.put(command_table, plugin_module, new_commands)
      {:ok, updated_table}
    rescue
      e ->
        Logger.error("Failed to register commands: #{inspect(e)}")
        {:error, :registration_failed}
    end
  end

  defp unregister_commands(_commands, command_table, plugin_module) do
    try do
      updated_table = Map.delete(command_table, plugin_module)
      {:ok, updated_table}
    rescue
      e ->
        Logger.error("Failed to unregister commands: #{inspect(e)}")
        {:error, :unregistration_failed}
    end
  end

  defp wrap_handler(handler, plugin_state) do
    fn args, context ->
      try do
        handler.(args, Map.put(context, :plugin_state, plugin_state))
      rescue
        e ->
          Logger.error("Command execution failed: #{inspect(e)}")
          {:error, {:execution_failed, Exception.message(e)}}
      end
    end
  end

  defp find_command(name, command_table) do
    case Enum.find_value(command_table, :error, fn {_, commands} ->
      Enum.find(commands, fn {cmd_name, _, _} -> cmd_name == name end)
    end) do
      {^name, handler, metadata} -> {:ok, {handler, metadata}}
      :error -> {:error, :command_not_found}
    end
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
        Logger.error("Command execution failed: #{inspect(reason)}")
        {:error, {:execution_failed, Exception.message(reason)}}
    end
  end
end
