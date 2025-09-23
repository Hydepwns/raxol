defmodule Raxol.Core.Runtime.Plugins.PluginCommandManager do
  @moduledoc """
  Handles registration and management of plugin commands.
  """

  alias Raxol.Core.Runtime.Plugins.CommandRegistry

  require Raxol.Core.Runtime.Log

  @doc """
  Initializes the command table.
  """
  def initialize_command_table(table, _plugins) do
    table
  end

  @doc """
  Updates the command table with commands from a plugin.
  """
  def update_command_table(table, plugin, _state \\ nil) do
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

  @doc """
  Registers commands for a plugin.
  """
  def register_commands(plugin_module, initial_state, command_table) do
    CommandRegistry.register_plugin_commands(
      plugin_module,
      initial_state,
      command_table
    )
  end

  @doc """
  Unregisters commands for a plugin.
  """
  def unregister_plugin_commands(plugin_id, command_table) do
    CommandRegistry.unregister_plugin_commands(plugin_id, command_table)
  end

  @doc """
  Gets commands from a plugin module.
  """
  def get_plugin_commands(plugin) do
    case function_exported?(plugin, :get_commands, 0) do
      true -> {:ok, plugin.get_commands()}
      false -> {:ok, []}
    end
  end

  @doc """
  Registers plugin commands in the command table.
  """
  def register_plugin_commands(table, plugin, commands) do
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
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end
end
