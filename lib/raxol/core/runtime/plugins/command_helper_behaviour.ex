defmodule Raxol.Core.Runtime.Plugins.CommandHelper.Behaviour do
  @moduledoc """
  Defines the behaviour for plugin command management.

  This behaviour is responsible for:
  - Registering plugin commands
  - Managing command handlers
  - Validating command specifications
  - Handling command execution
  """

  @doc """
  Registers commands for a plugin.
  """
  @callback register_plugin_commands(
    plugin_module :: module(),
    plugin_state :: map(),
    command_table :: atom()
  ) :: :ok | {:error, any()}

  @doc """
  Unregisters commands for a plugin.
  """
  @callback unregister_plugin_commands(
    plugin_id :: String.t(),
    command_table :: atom()
  ) :: :ok | {:error, any()}

  @doc """
  Validates a plugin's command specifications.
  """
  @callback validate_commands(
    commands :: list(map())
  ) :: :ok | {:error, any()}

  @doc """
  Executes a command for a plugin.
  """
  @callback execute_command(
    command :: atom(),
    args :: list(),
    plugin_module :: module(),
    plugin_state :: map()
  ) :: {:ok, map()} | {:error, any()}

  @doc """
  Gets all registered commands for a plugin.
  """
  @callback get_plugin_commands(
    plugin_id :: String.t(),
    command_table :: atom()
  ) :: {:ok, list(map())} | {:error, any()}
end
