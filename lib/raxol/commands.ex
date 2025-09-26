defmodule Raxol.Commands do
  @moduledoc """
  Command registration and management system for Raxol plugins.

  This module provides a centralized way to register and manage commands
  that can be executed from the terminal prompt or through plugin interactions.
  """

  use GenServer

  @doc """
  Starts the command manager.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  @doc """
  Registers a command with the given name and handler module.

  ## Parameters
  - `command_name`: The name of the command as a string
  - `handler_module`: The module that implements the command logic

  ## Returns
  - `:ok` on success
  - `{:error, reason}` on failure
  """
  def register(command_name, handler_module) do
    GenServer.call(__MODULE__, {:register, command_name, handler_module})
  end

  @doc """
  Unregisters a command by name.

  ## Parameters
  - `command_name`: The name of the command to unregister

  ## Returns
  - `:ok` on success
  - `{:error, reason}` if command not found
  """
  def unregister(command_name) do
    GenServer.call(__MODULE__, {:unregister, command_name})
  end

  @doc """
  Lists all registered commands.

  ## Returns
  A map of command names to handler modules.
  """
  def list_commands do
    GenServer.call(__MODULE__, :list_commands)
  end

  @doc """
  Executes a command with the given arguments.

  ## Parameters
  - `command_name`: The name of the command to execute
  - `args`: List of arguments for the command

  ## Returns
  - `{:ok, result}` on success
  - `{:error, reason}` on failure or if command not found
  """
  def execute(command_name, args \\ []) do
    GenServer.call(__MODULE__, {:execute, command_name, args})
  end

  # GenServer callbacks

  @impl true
  def init(:ok) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:register, command_name, handler_module}, _from, commands) do
    case Map.has_key?(commands, command_name) do
      true ->
        {:reply, {:error, "Command already registered"}, commands}
      false ->
        new_commands = Map.put(commands, command_name, handler_module)
        {:reply, :ok, new_commands}
    end
  end

  @impl true
  def handle_call({:unregister, command_name}, _from, commands) do
    case Map.pop(commands, command_name) do
      {nil, _} ->
        {:reply, {:error, "Command not found"}, commands}
      {_, new_commands} ->
        {:reply, :ok, new_commands}
    end
  end

  @impl true
  def handle_call(:list_commands, _from, commands) do
    {:reply, commands, commands}
  end

  @impl true
  def handle_call({:execute, command_name, args}, _from, commands) do
    case Map.get(commands, command_name) do
      nil ->
        {:reply, {:error, "Command not found"}, commands}
      handler_module ->
        result = try do
          if function_exported?(handler_module, :execute_command, 2) do
            handler_module.execute_command(command_name, args)
          else
            {:error, "Handler module does not implement execute_command/2"}
          end
        rescue
          error -> {:error, "Command execution failed: #{inspect(error)}"}
        end
        {:reply, result, commands}
    end
  end
end