defmodule Raxol.Terminal.CommandHistory do
  @moduledoc """
  Manages command history for the terminal emulator.
  
  This module provides functionality for:
  - Storing and retrieving command history
  - Navigating through command history
  - Persisting command history
  - Managing history size limits
  """

  @type t :: %__MODULE__{
    commands: [String.t()],
    current_index: integer(),
    max_size: non_neg_integer(),
    current_input: String.t()
  }

  defstruct [
    :commands,
    :current_index,
    :max_size,
    :current_input
  ]

  @doc """
  Creates a new command history manager.
  
  ## Examples
  
      iex> history = CommandHistory.new(1000)
      iex> history.max_size
      1000
  """
  def new(max_size) when is_integer(max_size) and max_size > 0 do
    %__MODULE__{
      commands: [],
      current_index: -1,
      max_size: max_size,
      current_input: ""
    }
  end

  @doc """
  Adds a command to the history.
  
  ## Examples
  
      iex> history = CommandHistory.new(1000)
      iex> history = CommandHistory.add(history, "ls -la")
      iex> history.commands
      ["ls -la"]
  """
  def add(%__MODULE__{} = history, command) when is_binary(command) do
    commands = [command | history.commands]
    commands = Enum.take(commands, history.max_size)
    
    %{history | 
      commands: commands,
      current_index: -1,
      current_input: ""
    }
  end

  @doc """
  Retrieves the previous command in history.
  
  ## Examples
  
      iex> history = CommandHistory.new(1000)
      iex> history = CommandHistory.add(history, "ls -la")
      iex> history = CommandHistory.add(history, "cd /tmp")
      iex> CommandHistory.previous(history)
      {"cd /tmp", %CommandHistory{...}}
  """
  def previous(%__MODULE__{} = history) do
    case history.current_index + 1 < length(history.commands) do
      true ->
        new_index = history.current_index + 1
        command = Enum.at(history.commands, new_index)
        {command, %{history | current_index: new_index}}
      false ->
        {nil, history}
    end
  end

  @doc """
  Retrieves the next command in history.
  
  ## Examples
  
      iex> history = CommandHistory.new(1000)
      iex> history = CommandHistory.add(history, "ls -la")
      iex> history = CommandHistory.add(history, "cd /tmp")
      iex> {_, history} = CommandHistory.previous(history)
      iex> CommandHistory.next(history)
      {"ls -la", %CommandHistory{...}}
  """
  def next(%__MODULE__{} = history) do
    case history.current_index - 1 >= -1 do
      true ->
        new_index = history.current_index - 1
        command = if new_index == -1, do: history.current_input, else: Enum.at(history.commands, new_index)
        {command, %{history | current_index: new_index}}
      false ->
        {nil, history}
    end
  end

  @doc """
  Saves the current input state.
  
  ## Examples
  
      iex> history = CommandHistory.new(1000)
      iex> history = CommandHistory.save_input(history, "ls -l")
      iex> history.current_input
      "ls -l"
  """
  def save_input(%__MODULE__{} = history, input) when is_binary(input) do
    %{history | current_input: input}
  end

  @doc """
  Clears the command history.
  
  ## Examples
  
      iex> history = CommandHistory.new(1000)
      iex> history = CommandHistory.add(history, "ls -la")
      iex> history = CommandHistory.clear(history)
      iex> history.commands
      []
  """
  def clear(%__MODULE__{} = history) do
    %{history | 
      commands: [],
      current_index: -1,
      current_input: ""
    }
  end

  @doc """
  Returns the current command history as a list.
  
  ## Examples
  
      iex> history = CommandHistory.new(1000)
      iex> history = CommandHistory.add(history, "ls -la")
      iex> history = CommandHistory.add(history, "cd /tmp")
      iex> CommandHistory.list(history)
      ["cd /tmp", "ls -la"]
  """
  def list(%__MODULE__{} = history) do
    history.commands
  end
end 