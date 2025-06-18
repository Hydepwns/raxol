defmodule Raxol.Core.Plugins.Core.ClipboardPluginBehaviour do
  @moduledoc """
  Defines the behaviour for clipboard plugin operations.
  """

  @doc """
  Initializes the clipboard plugin with the given options.
  """
  @callback init(opts :: Keyword.t()) :: {:ok, map()} | {:error, term()}

  @doc """
  Returns the list of commands supported by the clipboard plugin.
  """
  @callback get_commands() :: list(atom())

  @doc """
  Handles a clipboard command with the given arguments and state.
  """
  @callback handle_command(command :: atom(), args :: list(), state :: map()) ::
              {:ok, String.t()} | {:error, String.t()}
end
