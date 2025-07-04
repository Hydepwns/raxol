defmodule Raxol.Core.Runtime.TestCommandModule do
  @moduledoc """
  Test implementation of CommandBehaviour that records calls for testing.

  This module is used in tests to verify that commands are executed correctly
  without actually performing the side effects.
  """

  @behaviour Raxol.Core.Runtime.CommandBehaviour

  @doc """
  Starts the test command module with an Agent for state management.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    Agent.start_link(fn -> [] end, name: name)
  end

  @impl Raxol.Core.Runtime.CommandBehaviour
  def execute(command, context) do
    Agent.update(__MODULE__, fn commands -> [{command, context} | commands] end)
    :ok
  end

  @doc """
  Gets all executed commands in reverse chronological order.
  """
  def get_executed_commands do
    Agent.get(__MODULE__, fn commands -> Enum.reverse(commands) end)
  end

  @doc """
  Clears all executed commands.
  """
  def clear_executed_commands do
    Agent.update(__MODULE__, fn _commands -> [] end)
    :ok
  end

  @doc """
  Stops the test command module.
  """
  def stop do
    Agent.stop(__MODULE__)
  end
end
