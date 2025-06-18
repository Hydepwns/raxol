defmodule Raxol.Core.Runtime.Plugins.PluginCommandRegistry.Behaviour do
  @moduledoc """
  Defines the behaviour for plugin command registration.

  This behaviour is responsible for:
  - Registering plugin commands
  - Managing command lookups
  - Handling command unregistration
  - Maintaining command metadata
  """

  @type command_name :: String.t()
  @type namespace :: atom() | nil
  @type command_key :: {namespace(), command_name()}
  @type command_entry :: {module(), atom(), integer() | nil}
  @type table_name :: atom()

  @doc """
  Creates a new command registry table.
  Returns the name of the created table.
  """
  @callback new() :: table_name()

  @doc """
  Registers a command provided by a plugin.
  """
  @callback register_command(
              table_name(),
              namespace(),
              command_name(),
              module(),
              atom(),
              integer() | nil
            ) :: :ok | {:error, :already_registered}

  @doc """
  Unregisters a command.
  """
  @callback unregister_command(
              table_name(),
              namespace(),
              command_name()
            ) :: :ok

  @doc """
  Looks up the handler for a command name and namespace.
  """
  @callback lookup_command(
              table_name(),
              namespace(),
              command_name()
            ) :: {:ok, command_entry()} | {:error, :not_found}

  @doc """
  Unregisters all commands associated with a specific module.
  """
  @callback unregister_commands_by_module(
              table_name(),
              module()
            ) :: :ok
end
