defmodule Raxol.Core.Runtime.Plugins.PluginCommandHelper.Behaviour do
  @moduledoc """
  Defines the behaviour for plugin command registration and dispatch.

  This behaviour is responsible for:
  - Finding plugins for command handling
  - Registering plugin commands
  - Handling command dispatch
  - Managing command unregistration
  """

  @doc """
  Finds the plugin responsible for handling a command.
  """
  @callback find_plugin_for_command(
              command_table :: atom(),
              command_name :: String.t(),
              namespace :: atom() | nil,
              arity :: integer() | :unknown
            ) :: {:ok, {module(), atom(), integer()}} | :not_found

  @doc """
  Registers the commands exposed by a plugin.
  """
  @callback register_plugin_commands(
              plugin_module :: module(),
              plugin_state :: map(),
              command_table :: atom()
            ) :: :ok

  @doc """
  Handles the dispatching of a command to the appropriate plugin.
  """
  @callback handle_command(
              command_table :: atom(),
              command_name_str :: String.t(),
              namespace :: atom() | nil,
              args :: list(),
              state :: map()
            ) :: {:ok, map()} | :not_found | {:error, any()}

  @doc """
  Unregisters all commands associated with a specific plugin module.
  """
  @callback unregister_plugin_commands(
              command_table :: atom(),
              plugin_module :: module()
            ) :: :ok
end
