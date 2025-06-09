defmodule Raxol.Terminal.Commands.History do
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

      iex> history = History.new(1000)
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

      iex> history = History.new(1000)
      iex> history = History.add(history, "ls -la")
      iex> history.commands
      ["ls -la"]
  """
  def add(%__MODULE__{} = history, command) when is_binary(command) do
    commands = [command | history.commands]
    commands = Enum.take(commands, history.max_size)

    %{history | commands: commands, current_index: -1, current_input: ""}
  end

  @doc """
  Retrieves the previous command in history.

  ## Examples

      iex> history = History.new(1000)
      iex> history = History.add(history, "ls -la")
      iex> history = History.add(history, "cd /tmp")
      iex> History.previous(history)
      {"cd /tmp", %History{...}}
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

      iex> history = History.new(1000)
      iex> history = History.add(history, "ls -la")
      iex> history = History.add(history, "cd /tmp")
      iex> {_, history} = History.previous(history)
      iex> History.next(history)
      {"ls -la", %History{...}}
  """
  def next(%__MODULE__{} = history) do
    case history.current_index - 1 >= -1 do
      true ->
        new_index = history.current_index - 1

        command =
          if new_index == -1,
            do: history.current_input,
            else: Enum.at(history.commands, new_index)

        {command, %{history | current_index: new_index}}

      false ->
        {nil, history}
    end
  end

  @doc """
  Saves the current input state.

  ## Examples

      iex> history = History.new(1000)
      iex> history = History.save_input(history, "ls -l")
      iex> history.current_input
      "ls -l"
  """
  def save_input(%__MODULE__{} = history, input) when is_binary(input) do
    %{history | current_input: input}
  end

  @doc """
  Clears the command history.

  ## Examples

      iex> history = History.new(1000)
      iex> history = History.add(history, "ls -la")
      iex> history = History.clear(history)
      iex> history.commands
      []
  """
  def clear(%__MODULE__{} = history) do
    %{history | commands: [], current_index: -1, current_input: ""}
  end

  @doc """
  Returns the current command history as a list.

  ## Examples

      iex> history = History.new(1000)
      iex> history = History.add(history, "ls -la")
      iex> history = History.add(history, "cd /tmp")
      iex> History.list(history)
      ["cd /tmp", "ls -la"]
  """
  def list(%__MODULE__{} = history) do
    history.commands
  end

  @doc """
  Adds to the emulator's command history if the input is a newline (10),
  or appends to the current command buffer if it's a printable character.
  Returns the updated emulator struct.
  """
  def maybe_add_to_history(emulator, 10) do
    # On newline, add the current buffer to history if not empty, then clear buffer
    cmd = String.trim(emulator.current_command_buffer)

    if cmd != "" do
      updated_history =
        [cmd | emulator.command_history]
        |> Enum.take(emulator.max_command_history)

      %{emulator | command_history: updated_history, current_command_buffer: ""}
    else
      %{emulator | current_command_buffer: ""}
    end
  end

  def maybe_add_to_history(emulator, char)
      when is_integer(char) and char >= 32 and char <= 0x10FFFF do
    # Append printable character to current_command_buffer
    new_buffer = emulator.current_command_buffer <> <<char::utf8>>
    %{emulator | current_command_buffer: new_buffer}
  end

  def maybe_add_to_history(emulator, _), do: emulator

  @doc """
  Updates the maximum size of the command history. Truncates the history if needed.
  """
  def update_size(%__MODULE__{} = history, new_size)
      when is_integer(new_size) and new_size > 0 do
    commands = Enum.take(history.commands, new_size)

    %{
      history
      | commands: commands,
        max_size: new_size,
        current_index: min(history.current_index, new_size - 1)
    }
  end
end
