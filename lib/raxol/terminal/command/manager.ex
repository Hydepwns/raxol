defmodule Raxol.Terminal.Command.Manager do
  @moduledoc """
  Manages terminal command history and processing, including command buffer,
  history, and command execution.
  """

  require Logger

  @type t :: %__MODULE__{
          command_history: list(String.t()),
          max_command_history: non_neg_integer(),
          current_command_buffer: String.t(),
          last_key_event: map() | nil
        }

  defstruct command_history: [],
            max_command_history: 100,
            current_command_buffer: "",
            last_key_event: nil

  @doc """
  Creates a new command manager with default values.
  """
  def new(opts \\ []) do
    max_history = Keyword.get(opts, :max_command_history, 100)
    %__MODULE__{max_command_history: max_history}
  end

  @doc """
  Gets the current command buffer.
  """
  def get_command_buffer(%__MODULE__{} = manager) do
    manager.current_command_buffer
  end

  @doc """
  Updates the current command buffer.
  """
  def update_command_buffer(%__MODULE__{} = manager, buffer)
      when is_binary(buffer) do
    %{manager | current_command_buffer: buffer}
  end

  @doc """
  Gets the command history.
  """
  def get_command_history(%__MODULE__{} = manager) do
    manager.command_history
  end

  @doc """
  Adds a command to the history, maintaining the maximum history size.
  """
  def add_to_history(%__MODULE__{} = manager, command)
      when is_binary(command) do
    new_history = [command | manager.command_history]
    limited_history = Enum.take(new_history, manager.max_command_history)
    %{manager | command_history: limited_history}
  end

  @doc """
  Clears the command history.
  """
  def clear_history(%__MODULE__{} = manager) do
    %{manager | command_history: []}
  end

  @doc """
  Gets the last key event.
  """
  def get_last_key_event(%__MODULE__{} = manager) do
    manager.last_key_event
  end

  @doc """
  Updates the last key event.
  """
  def update_last_key_event(%__MODULE__{} = manager, event) do
    %{manager | last_key_event: event}
  end

  @doc """
  Processes a key event and updates the command buffer accordingly.
  Returns {new_manager, command_to_execute} where command_to_execute is nil
  if no command should be executed.
  """
  def process_key_event(%__MODULE__{} = manager, key_event) do
    case key_event do
      # Enter key - execute command
      %{key: :enter} ->
        command = manager.current_command_buffer

        if String.trim(command) != "" do
          new_manager =
            manager
            |> add_to_history(command)
            |> update_command_buffer("")

          {new_manager, command}
        else
          {manager, nil}
        end

      # Backspace key - remove last character
      %{key: :backspace} ->
        new_buffer = String.slice(manager.current_command_buffer, 0..-2)
        {update_command_buffer(manager, new_buffer), nil}

      # Regular character - append to buffer
      %{key: :char, char: char} ->
        new_buffer = manager.current_command_buffer <> char
        {update_command_buffer(manager, new_buffer), nil}

      # Other keys - just update last key event
      _ ->
        {update_last_key_event(manager, key_event), nil}
    end
  end

  @doc """
  Gets a command from history by index (0-based).
  Returns nil if index is out of bounds.
  """
  def get_history_command(%__MODULE__{} = manager, index)
      when is_integer(index) and index >= 0 do
    Enum.at(manager.command_history, index)
  end

  @doc """
  Searches command history for commands matching the given prefix.
  Returns a list of matching commands.
  """
  def search_history(%__MODULE__{} = manager, prefix) when is_binary(prefix) do
    manager.command_history
    |> Enum.filter(&String.starts_with?(&1, prefix))
  end

  @doc """
  Updates the maximum command history size.
  If the new size is smaller than the current history, older commands are removed.
  """
  def update_max_history(%__MODULE__{} = manager, new_size)
      when is_integer(new_size) and new_size > 0 do
    limited_history = Enum.take(manager.command_history, new_size)
    %{manager | max_command_history: new_size, command_history: limited_history}
  end
end
