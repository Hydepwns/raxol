defmodule Raxol.Terminal.Commands.Registry do
  @moduledoc """
  Registry for terminal commands.
  Provides functionality to list and manage available commands.
  """

  @doc """
  Returns a list of available commands.
  """
  def list_commands do
    get_registered_commands()
  end

  @doc false
  defp get_registered_commands do
    [
      "clear",
      "help",
      "exit",
      "ls",
      "cd",
      "pwd"
    ]
  end
end
