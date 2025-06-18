defmodule Raxol.Core.Runtime.Plugins.PluginCommandHandler.Behaviour do
  @moduledoc '''
  Defines the behaviour for plugin command handling.

  This behaviour is responsible for:
  - Processing command requests
  - Executing commands through plugins
  - Managing command results and error handling
  - Handling command timeouts and errors
  '''

  @doc '''
  Handles a command request by delegating to the appropriate plugin.
  Returns an updated state and any necessary side effects.
  '''
  @callback handle_command(
              command_atom :: atom(),
              namespace :: atom(),
              data :: list(),
              dispatcher_pid :: pid(),
              state :: map()
            ) :: {:ok, map()} | {:error, any()}

  @doc '''
  Handles command results.
  '''
  @callback handle_command_result(
              command_atom :: atom(),
              result :: any(),
              dispatcher_pid :: pid(),
              state :: map()
            ) :: {:ok, map()} | {:error, any()}

  @doc '''
  Handles command errors.
  '''
  @callback handle_command_error(
              command_atom :: atom(),
              error :: any(),
              dispatcher_pid :: pid(),
              state :: map()
            ) :: {:ok, map()} | {:error, any()}

  @doc '''
  Handles command timeouts.
  '''
  @callback handle_command_timeout(
              command_atom :: atom(),
              dispatcher_pid :: pid(),
              state :: map()
            ) :: {:ok, map()} | {:error, any()}

  @doc '''
  Updates the command handler state.
  '''
  @callback update_command_state(
              state :: map(),
              new_state :: map()
            ) :: map()
end
