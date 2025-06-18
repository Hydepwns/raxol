defmodule Raxol.Terminal.Input.Buffer do
  @moduledoc """
  Manages input buffering for the terminal emulator.
  """

  @doc """
  Creates a new input buffer with the given size.
  """
  def new(max_size) when is_integer(max_size) and max_size > 0 do
    %{
      buffer: [],
      max_size: max_size,
      current_size: 0
    }
  end

  @doc """
  Adds an event to the input buffer.
  """
  def add(buffer, event) do
    if buffer.current_size >= buffer.max_size do
      {:error, :buffer_full}
    else
      new_buffer = %{
        buffer
        | buffer: buffer.buffer ++ [event],
          current_size: buffer.current_size + 1
      }

      {:ok, new_buffer}
    end
  end

  @doc """
  Gets the current buffer contents.
  """
  def get_contents(buffer) do
    buffer.buffer
  end

  @doc """
  Clears the input buffer.
  """
  def clear(buffer) do
    %{buffer | buffer: [], current_size: 0}
  end
end
