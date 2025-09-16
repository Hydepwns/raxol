defmodule Raxol.Terminal.Buffer do
  @moduledoc """
  Main entry point for buffer operations.
  Provides convenience functions for creating and managing terminal buffers.
  """

  alias Raxol.Terminal.ScreenBuffer

  @doc """
  Creates a new buffer with the specified dimensions.
  Returns {:ok, buffer} on success.
  """
  @spec create(pos_integer(), pos_integer()) :: {:ok, ScreenBuffer.t()}
  def create(width, height) when width > 0 and height > 0 do
    {:ok, ScreenBuffer.new(width, height)}
  end

  @doc """
  Creates a new buffer with the specified dimensions.
  Returns {:ok, buffer} on success.
  Alias for create/2 for compatibility.
  """
  @spec new(pos_integer(), pos_integer()) :: {:ok, ScreenBuffer.t()}
  def new(width, height) when width > 0 and height > 0 do
    create(width, height)
  end

  @doc """
  Creates a new buffer with default dimensions.
  """
  @spec new() :: ScreenBuffer.t()
  def new() do
    ScreenBuffer.new()
  end

  @doc """
  Creates a new buffer with a single dimension parameter.
  Creates a square buffer.
  """
  @spec new(pos_integer()) :: ScreenBuffer.t()
  def new(size) when is_integer(size) and size > 0 do
    ScreenBuffer.new(size, size)
  end
end
