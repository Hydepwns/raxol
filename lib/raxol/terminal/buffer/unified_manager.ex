defmodule Raxol.Terminal.Buffer.UnifiedManager do
  @moduledoc """
  Unified buffer manager for terminal operations.

  This module provides a unified interface for buffer management,
  consolidating buffer operations for the terminal renderer.
  """

  alias Raxol.Terminal.Buffer.BufferServer

  # Delegate to BufferServer for actual implementation
  def start_link(opts), do: BufferServer.start_link(opts)
  defdelegate set_cell(pid, x, y, cell), to: BufferServer
  defdelegate get_cell(pid, x, y), to: BufferServer
  defdelegate flush(pid), to: BufferServer
  defdelegate batch_operations(pid, operations), to: BufferServer
  defdelegate resize(pid, width, height), to: BufferServer
  defdelegate get_dimensions(pid), to: BufferServer
  defdelegate get_content(pid), to: BufferServer

  # Alias for compatibility
  def get_size(pid), do: get_dimensions(pid)

  # These functions need to be implemented as BufferServer doesn't have them
  def clear(pid) do
    # Clear by resizing to current dimensions
    {width, height} = get_dimensions(pid)
    resize(pid, width, height)
  end

  def update_cursor_position(_pid, _x, _y) do
    # BufferServer doesn't manage cursor, just return ok
    :ok
  end

  def get_cursor_position(_pid) do
    # Default cursor position
    {0, 0}
  end

  @doc """
  Writes text to the buffer at the current cursor position.

  This is a simplified interface that writes text character by character
  starting at the current cursor position.
  """
  @spec write(pid(), String.t()) :: {:ok, pid()}
  def write(pid, text) when is_binary(text) do
    # Convert string to characters and write each one
    text
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.each(fn {char, index} ->
      # Get current cursor position
      {x, y} = get_cursor_position(pid)

      # Create a basic cell with the character
      cell = %{
        char: char,
        fg: :default,
        bg: :default,
        attrs: []
      }

      # Write the cell at the position
      set_cell(pid, x + index, y, cell)
    end)

    # Update cursor position to end of text
    {cursor_x, cursor_y} = get_cursor_position(pid)
    new_x = cursor_x + String.length(text)
    update_cursor_position(pid, new_x, cursor_y)

    {:ok, pid}
  end

  @doc """
  Writes text to the buffer at a specific position.
  """
  @spec write_at(pid(), non_neg_integer(), non_neg_integer(), String.t()) :: {:ok, pid()}
  def write_at(pid, x, y, text) when is_binary(text) do
    # Set cursor position first
    update_cursor_position(pid, x, y)

    # Then write the text
    write(pid, text)
  end
end