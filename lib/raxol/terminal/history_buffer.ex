defmodule Raxol.Terminal.HistoryBuffer do
  @moduledoc """
  Manages terminal command history buffer operations.
  This module handles the storage and retrieval of command history.
  """

  alias Raxol.Core.ErrorHandling

  
  @type t :: %__MODULE__{
          commands: list(String.t()),
          position: integer(),
          max_size: non_neg_integer()
        }

  defstruct commands: [], position: 0, max_size: 1000

  @doc """
  Creates a new history buffer with the specified maximum size.
  """
  @spec new(non_neg_integer()) :: t()
  def new(max_size \\ 1000) do
    %__MODULE__{max_size: max_size}
  end

  @doc """
  Adds a command to the history buffer.
  """
  @spec add_command(t(), String.t()) :: t()
  def add_command(buffer, command) when is_binary(command) and command != "" do
    commands = [command | buffer.commands]
    commands = Enum.take(commands, buffer.max_size)
    %{buffer | commands: commands, position: 0}
  end

  def add_command(buffer, _command), do: buffer

  @doc """
  Gets the command at the specified index.
  """
  @spec get_command_at(t(), integer()) ::
          {:ok, String.t()} | {:error, String.t()}
  def get_command_at(buffer, index)
      when index >= 0 and index < length(buffer.commands) do
    case Enum.at(buffer.commands, index) do
      nil -> {:error, "Index out of bounds"}
      command -> {:ok, command}
    end
  end

  def get_command_at(_buffer, _index), do: {:error, "Invalid index"}

  @doc """
  Gets the current history position.
  """
  @spec get_position(t()) :: integer()
  def get_position(buffer), do: buffer.position

  @doc """
  Sets the history position.
  """
  @spec set_position(t(), integer()) :: t()
  def set_position(buffer, position)
      when position >= 0 and position <= length(buffer.commands) do
    %{buffer | position: position}
  end

  def set_position(buffer, _position), do: buffer

  @doc """
  Moves to the next command in history.
  """
  @spec next_command(t()) :: {:ok, t(), String.t()} | {:error, String.t()}
  def next_command(buffer) do
    case buffer.position > 0 do
      true ->
        new_position = buffer.position - 1

        case get_command_at(buffer, new_position) do
          {:ok, command} -> {:ok, set_position(buffer, new_position), command}
          {:error, reason} -> {:error, reason}
        end

      false ->
        {:error, "Already at the most recent command"}
    end
  end

  @doc """
  Moves to the previous command in history.
  """
  @spec previous_command(t()) :: {:ok, t(), String.t()} | {:error, String.t()}
  def previous_command(buffer) do
    case buffer.position < length(buffer.commands) do
      true ->
        new_position = buffer.position + 1

        case get_command_at(buffer, new_position - 1) do
          {:ok, command} -> {:ok, set_position(buffer, new_position), command}
          {:error, reason} -> {:error, reason}
        end

      false ->
        {:error, "Already at the oldest command"}
    end
  end

  @doc """
  Clears the command history.
  """
  @spec clear(t()) :: t()
  def clear(buffer) do
    %{buffer | commands: [], position: 0}
  end

  @doc """
  Gets the history size.
  """
  @spec get_size(t()) :: non_neg_integer()
  def get_size(buffer), do: length(buffer.commands)

  @doc """
  Gets the maximum history size.
  """
  @spec get_max_size(t()) :: non_neg_integer()
  def get_max_size(buffer), do: buffer.max_size

  @doc """
  Sets the maximum history size.
  """
  @spec set_max_size(t(), non_neg_integer()) :: t()
  def set_max_size(buffer, max_size) when max_size > 0 do
    commands = Enum.take(buffer.commands, max_size)
    %{buffer | commands: commands, max_size: max_size}
  end

  def set_max_size(buffer, _max_size), do: buffer

  @doc """
  Gets all commands in history.
  """
  @spec get_all_commands(t()) :: list(String.t())
  def get_all_commands(buffer), do: buffer.commands

  @doc """
  Saves the history to a file.
  """
  @spec save_to_file(t(), String.t()) :: :ok | {:error, String.t()}
  def save_to_file(buffer, file_path) do
    case ErrorHandling.safe_call(fn ->
      File.write(file_path, Enum.join(buffer.commands, "\n"))
    end) do
      {:ok, result} -> result
      {:error, reason} -> {:error, "Failed to save history: #{inspect(reason)}"}
    end
  end

  @doc """
  Loads history from a file.
  """
  @spec load_from_file(t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def load_from_file(buffer, file_path) do
    case ErrorHandling.safe_call(fn ->
      case File.read(file_path) do
        {:ok, content} ->
          commands = String.split(content, "\n", trim: true)
          commands = Enum.take(commands, buffer.max_size)
          {:ok, %{buffer | commands: commands, position: 0}}

        {:error, reason} ->
          {:error, "Failed to read file: #{inspect(reason)}"}
      end
    end) do
      {:ok, result} -> result
      {:error, reason} -> {:error, "Failed to load history: #{inspect(reason)}"}
    end
  end
end
