defmodule Raxol.Terminal.Scrollback.Manager do
  @moduledoc """
  Manages scrollback operations for the terminal emulator.
  This module handles scrollback buffer management, including adding lines,
  retrieving history, and managing scrollback limits.
  """

  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct

  @doc """
  Gets the scrollback buffer.

  ## Parameters

  * `emulator` - The emulator instance

  ## Returns

  List of scrollback lines
  """
  @spec get_scrollback_buffer(EmulatorStruct.t()) :: list()
  def get_scrollback_buffer(%EmulatorStruct{} = emulator) do
    emulator.scrollback_buffer
  end

  @doc """
  Adds a line to the scrollback buffer.

  ## Parameters

  * `emulator` - The emulator instance
  * `line` - The line to add

  ## Returns

  Updated emulator with new line in scrollback buffer
  """
  @spec add_to_scrollback(EmulatorStruct.t(), String.t()) :: EmulatorStruct.t()
  def add_to_scrollback(%EmulatorStruct{} = emulator, line) when is_binary(line) do
    new_buffer = [line | emulator.scrollback_buffer]
    # Trim buffer if it exceeds the limit
    trimmed_buffer = Enum.take(new_buffer, emulator.scrollback_limit)
    %{emulator | scrollback_buffer: trimmed_buffer}
  end

  @doc """
  Clears the scrollback buffer.

  ## Parameters

  * `emulator` - The emulator instance

  ## Returns

  Updated emulator with empty scrollback buffer
  """
  @spec clear_scrollback(EmulatorStruct.t()) :: EmulatorStruct.t()
  def clear_scrollback(%EmulatorStruct{} = emulator) do
    %{emulator | scrollback_buffer: []}
  end

  @doc """
  Gets the scrollback limit.

  ## Parameters

  * `emulator` - The emulator instance

  ## Returns

  The maximum number of lines to store in scrollback
  """
  @spec get_scrollback_limit(EmulatorStruct.t()) :: non_neg_integer()
  def get_scrollback_limit(%EmulatorStruct{} = emulator) do
    emulator.scrollback_limit
  end

  @doc """
  Updates the scrollback limit.

  ## Parameters

  * `emulator` - The emulator instance
  * `limit` - The new scrollback limit

  ## Returns

  Updated emulator with new scrollback limit
  """
  @spec set_scrollback_limit(EmulatorStruct.t(), non_neg_integer()) :: EmulatorStruct.t()
  def set_scrollback_limit(%EmulatorStruct{} = emulator, limit)
      when is_integer(limit) and limit >= 0 do
    # Trim buffer if new limit is smaller than current size
    new_buffer = Enum.take(emulator.scrollback_buffer, limit)
    %{emulator | scrollback_buffer: new_buffer, scrollback_limit: limit}
  end

  @doc """
  Gets a range of lines from the scrollback buffer.

  ## Parameters

  * `emulator` - The emulator instance
  * `start` - The starting index (0-based)
  * `count` - The number of lines to retrieve

  ## Returns

  List of lines from the scrollback buffer
  """
  @spec get_scrollback_range(EmulatorStruct.t(), non_neg_integer(), non_neg_integer()) :: list()
  def get_scrollback_range(%EmulatorStruct{} = emulator, start, count)
      when is_integer(start) and is_integer(count) and start >= 0 and count >= 0 do
    emulator.scrollback_buffer
    |> Enum.drop(start)
    |> Enum.take(count)
  end

  @doc """
  Gets the total number of lines in the scrollback buffer.

  ## Parameters

  * `emulator` - The emulator instance

  ## Returns

  The number of lines in the scrollback buffer
  """
  @spec get_scrollback_size(EmulatorStruct.t()) :: non_neg_integer()
  def get_scrollback_size(%EmulatorStruct{} = emulator) do
    length(emulator.scrollback_buffer)
  end

  @doc """
  Checks if the scrollback buffer is empty.

  ## Parameters

  * `emulator` - The emulator instance

  ## Returns

  true if the scrollback buffer is empty, false otherwise
  """
  @spec scrollback_empty?(EmulatorStruct.t()) :: boolean()
  def scrollback_empty?(%EmulatorStruct{} = emulator) do
    emulator.scrollback_buffer == []
  end
end
