defmodule Raxol.Core.Runtime.Plugins.PluginCommandHandler.Behaviour do
  @moduledoc """
  Behavior for plugin command handling.
  """

  @doc """
  Handles a command for a plugin.
  """
  @callback handle_command(command :: term(), plugin_state :: term()) ::
              {:ok, term()} | {:error, term()}

  @doc """
  Lists available commands for a plugin.
  """
  @callback list_commands(plugin_state :: term()) :: list(String.t())
end
