defmodule Raxol.Terminal.ScreenBuffer.Core.Utils do
  @moduledoc """
  Utility functions for the screen buffer.
  """

  @doc """
  Gets buffer dimensions.
  """
  def get_dimensions(buffer) do
    {buffer.width, buffer.height}
  end

  @doc """
  Gets buffer width.
  """
  def get_width(buffer) do
    buffer.width
  end

  @doc """
  Gets buffer height.
  """
  def get_height(buffer) do
    buffer.height
  end

  @doc """
  Placeholder for unimplemented functionality.
  """
  def unimplemented(_args), do: :ok
end
