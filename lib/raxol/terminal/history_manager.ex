defmodule Raxol.Terminal.HistoryManager do
  @moduledoc """
  Manages terminal command history operations including history storage, retrieval, and navigation.
  This module is responsible for handling all history-related operations in the terminal.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.HistoryBuffer
  require Raxol.Core.Runtime.Log

  @doc """
  Gets the history buffer instance.
  Returns the history buffer.
  """
  @spec get_buffer(Emulator.t()) :: HistoryBuffer.t()
  def get_buffer(emulator) do
    emulator.history_buffer
  end

  @doc """
  Updates the history buffer instance.
  Returns the updated emulator.
  """
  @spec update_buffer(Emulator.t(), HistoryBuffer.t()) :: Emulator.t()
  def update_buffer(emulator, buffer) do
    %{emulator | history_buffer: buffer}
  end

  @doc """
  Adds a command to the history.
  Returns the updated emulator.
  """
  @spec add_command(Emulator.t(), String.t()) :: Emulator.t()
  def add_command(emulator, command) do
    buffer = HistoryBuffer.add_command(emulator.history_buffer, command)
    update_buffer(emulator, buffer)
  end

  @doc """
  Gets the command at the specified index.
  Returns {:ok, command} or {:error, reason}.
  """
  @spec get_command_at(Emulator.t(), integer()) :: {:ok, String.t()} | {:error, String.t()}
  def get_command_at(emulator, index) do
    case HistoryBuffer.get_command_at(emulator.history_buffer, index) do
      {:ok, command} -> {:ok, command}
      {:error, reason} -> {:error, "Failed to get command at index #{index}: #{inspect(reason)}"}
    end
  end

  @doc """
  Gets the current history position.
  Returns the current position.
  """
  @spec get_position(Emulator.t()) :: integer()
  def get_position(emulator) do
    HistoryBuffer.get_position(emulator.history_buffer)
  end

  @doc """
  Sets the history position.
  Returns the updated emulator.
  """
  @spec set_position(Emulator.t(), integer()) :: Emulator.t()
  def set_position(emulator, position) do
    buffer = HistoryBuffer.set_position(emulator.history_buffer, position)
    update_buffer(emulator, buffer)
  end

  @doc """
  Moves to the next command in history.
  Returns {:ok, updated_emulator, command} or {:error, reason}.
  """
  @spec next_command(Emulator.t()) :: {:ok, Emulator.t(), String.t()} | {:error, String.t()}
  def next_command(emulator) do
    case HistoryBuffer.next_command(emulator.history_buffer) do
      {:ok, new_buffer, command} ->
        {:ok, update_buffer(emulator, new_buffer), command}

      {:error, reason} ->
        {:error, "Failed to get next command: #{inspect(reason)}"}
    end
  end

  @doc """
  Moves to the previous command in history.
  Returns {:ok, updated_emulator, command} or {:error, reason}.
  """
  @spec previous_command(Emulator.t()) :: {:ok, Emulator.t(), String.t()} | {:error, String.t()}
  def previous_command(emulator) do
    case HistoryBuffer.previous_command(emulator.history_buffer) do
      {:ok, new_buffer, command} ->
        {:ok, update_buffer(emulator, new_buffer), command}

      {:error, reason} ->
        {:error, "Failed to get previous command: #{inspect(reason)}"}
    end
  end

  @doc """
  Clears the command history.
  Returns the updated emulator.
  """
  @spec clear_history(Emulator.t()) :: Emulator.t()
  def clear_history(emulator) do
    buffer = HistoryBuffer.clear(emulator.history_buffer)
    update_buffer(emulator, buffer)
  end

  @doc """
  Gets the history size.
  Returns the number of commands in history.
  """
  @spec get_size(Emulator.t()) :: non_neg_integer()
  def get_size(emulator) do
    HistoryBuffer.get_size(emulator.history_buffer)
  end

  @doc """
  Gets the maximum history size.
  Returns the maximum number of commands that can be stored.
  """
  @spec get_max_size(Emulator.t()) :: non_neg_integer()
  def get_max_size(emulator) do
    HistoryBuffer.get_max_size(emulator.history_buffer)
  end

  @doc """
  Sets the maximum history size.
  Returns the updated emulator.
  """
  @spec set_max_size(Emulator.t(), non_neg_integer()) :: Emulator.t()
  def set_max_size(emulator, size) do
    buffer = HistoryBuffer.set_max_size(emulator.history_buffer, size)
    update_buffer(emulator, buffer)
  end

  @doc """
  Gets all commands in history.
  Returns the list of commands.
  """
  @spec get_all_commands(Emulator.t()) :: list(String.t())
  def get_all_commands(emulator) do
    HistoryBuffer.get_all_commands(emulator.history_buffer)
  end

  @doc """
  Saves the history to a file.
  Returns :ok or {:error, reason}.
  """
  @spec save_to_file(Emulator.t(), String.t()) :: :ok | {:error, String.t()}
  def save_to_file(emulator, file_path) do
    case HistoryBuffer.save_to_file(emulator.history_buffer, file_path) do
      :ok -> :ok
      {:error, reason} -> {:error, "Failed to save history to file: #{inspect(reason)}"}
    end
  end

  @doc """
  Loads history from a file.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec load_from_file(Emulator.t(), String.t()) :: {:ok, Emulator.t()} | {:error, String.t()}
  def load_from_file(emulator, file_path) do
    case HistoryBuffer.load_from_file(emulator.history_buffer, file_path) do
      {:ok, new_buffer} ->
        {:ok, update_buffer(emulator, new_buffer)}

      {:error, reason} ->
        {:error, "Failed to load history from file: #{inspect(reason)}"}
    end
  end
end
