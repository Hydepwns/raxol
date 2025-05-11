defmodule Raxol.Core.Runtime.Plugins.PluginCommandDispatcher.Behaviour do
  @moduledoc """
  Defines the behaviour for plugin command dispatching.

  This behaviour is responsible for:
  - Dispatching commands to appropriate plugins
  - Managing command execution flow
  - Handling command results and errors
  - Coordinating command responses
  """

  @doc """
  Dispatches a command to the appropriate plugin.
  Returns an updated state and any necessary side effects.
  """
  @callback dispatch_command(
    command_atom :: atom(),
    namespace :: atom(),
    data :: list(),
    dispatcher_pid :: pid(),
    state :: map()
  ) :: {:ok, map()} | {:error, any()}

  @doc """
  Handles command results from plugins.
  """
  @callback handle_command_result(
    command_atom :: atom(),
    result :: any(),
    dispatcher_pid :: pid(),
    state :: map()
  ) :: {:ok, map()} | {:error, any()}

  @doc """
  Handles command errors from plugins.
  """
  @callback handle_command_error(
    command_atom :: atom(),
    error :: any(),
    dispatcher_pid :: pid(),
    state :: map()
  ) :: {:ok, map()} | {:error, any()}

  @doc """
  Handles command timeouts.
  """
  @callback handle_command_timeout(
    command_atom :: atom(),
    dispatcher_pid :: pid(),
    state :: map()
  ) :: {:ok, map()} | {:error, any()}

  @doc """
  Updates the command dispatcher state.
  """
  @callback update_dispatcher_state(
    state :: map(),
    new_state :: map()
  ) :: map()
end
