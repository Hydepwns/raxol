defmodule Raxol.Terminal.History.Manager do
  @moduledoc """
  Manages command history operations for the terminal emulator.
  This module handles command history storage, retrieval, and manipulation.
  """

  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct

  @doc """
  Gets the command history.

  ## Parameters

  * `emulator` - The emulator instance

  ## Returns

  List of command history entries
  """
  @spec get_command_history(EmulatorStruct.t()) :: list()
  def get_command_history(%EmulatorStruct{} = emulator) do
    emulator.command_history
  end

  @doc """
  Adds a command to the history.

  ## Parameters

  * `emulator` - The emulator instance
  * `command` - The command to add

  ## Returns

  Updated emulator with new command in history
  """
  @spec add_to_history(EmulatorStruct.t(), String.t()) :: EmulatorStruct.t()
  def add_to_history(%EmulatorStruct{} = emulator, command) when is_binary(command) do
    new_history = [command | emulator.command_history]
    # Trim history if it exceeds the limit
    trimmed_history = Enum.take(new_history, emulator.max_command_history)
    %{emulator | command_history: trimmed_history}
  end

  @doc """
  Clears the command history.

  ## Parameters

  * `emulator` - The emulator instance

  ## Returns

  Updated emulator with empty command history
  """
  @spec clear_history(EmulatorStruct.t()) :: EmulatorStruct.t()
  def clear_history(%EmulatorStruct{} = emulator) do
    %{emulator | command_history: []}
  end

  @doc """
  Gets a command from history by index.

  ## Parameters

  * `emulator` - The emulator instance
  * `index` - The index of the command to retrieve (0-based)

  ## Returns

  The command at the specified index or nil if not found
  """
  @spec get_history_command(EmulatorStruct.t(), non_neg_integer()) :: String.t() | nil
  def get_history_command(%EmulatorStruct{} = emulator, index) when is_integer(index) and index >= 0 do
    Enum.at(emulator.command_history, index)
  end

  @doc """
  Searches the command history for commands matching a prefix.

  ## Parameters

  * `emulator` - The emulator instance
  * `prefix` - The prefix to search for

  ## Returns

  List of matching commands
  """
  @spec search_history(EmulatorStruct.t(), String.t()) :: list()
  def search_history(%EmulatorStruct{} = emulator, prefix) when is_binary(prefix) do
    emulator.command_history
    |> Enum.filter(&String.starts_with?(&1, prefix))
  end

  @doc """
  Gets the current command buffer.

  ## Parameters

  * `emulator` - The emulator instance

  ## Returns

  The current command buffer
  """
  @spec get_command_buffer(EmulatorStruct.t()) :: String.t()
  def get_command_buffer(%EmulatorStruct{} = emulator) do
    emulator.current_command_buffer
  end

  @doc """
  Updates the current command buffer.

  ## Parameters

  * `emulator` - The emulator instance
  * `buffer` - The new command buffer content

  ## Returns

  Updated emulator with new command buffer
  """
  @spec update_command_buffer(EmulatorStruct.t(), String.t()) :: EmulatorStruct.t()
  def update_command_buffer(%EmulatorStruct{} = emulator, buffer) when is_binary(buffer) do
    %{emulator | current_command_buffer: buffer}
  end

  @doc """
  Gets the maximum command history size.

  ## Parameters

  * `emulator` - The emulator instance

  ## Returns

  The maximum number of commands to store in history
  """
  @spec get_max_history_size(EmulatorStruct.t()) :: non_neg_integer()
  def get_max_history_size(%EmulatorStruct{} = emulator) do
    emulator.max_command_history
  end

  @doc """
  Updates the maximum command history size.

  ## Parameters

  * `emulator` - The emulator instance
  * `size` - The new maximum history size

  ## Returns

  Updated emulator with new maximum history size
  """
  @spec set_max_history_size(EmulatorStruct.t(), non_neg_integer()) :: EmulatorStruct.t()
  def set_max_history_size(%EmulatorStruct{} = emulator, size)
      when is_integer(size) and size > 0 do
    %{emulator | max_command_history: size}
  end

  @doc """
  Gets the last key event.

  ## Parameters

  * `emulator` - The emulator instance

  ## Returns

  The last key event map or nil
  """
  @spec get_last_key_event(EmulatorStruct.t()) :: map() | nil
  def get_last_key_event(%EmulatorStruct{} = emulator) do
    emulator.last_key_event
  end

  @doc """
  Updates the last key event.

  ## Parameters

  * `emulator` - The emulator instance
  * `event` - The new key event map

  ## Returns

  Updated emulator with new last key event
  """
  @spec update_last_key_event(EmulatorStruct.t(), map() | nil) :: EmulatorStruct.t()
  def update_last_key_event(%EmulatorStruct{} = emulator, event) when is_map(event) or is_nil(event) do
    %{emulator | last_key_event: event}
  end
end
