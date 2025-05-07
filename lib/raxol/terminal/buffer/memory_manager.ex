defmodule Raxol.Terminal.Buffer.MemoryManager do
  @moduledoc """
  Handles calculation and checking of terminal buffer memory usage.
  """

  alias Raxol.Terminal.ScreenBuffer

  @doc """
  Calculates the approximate memory usage of a single screen buffer.

  This is a rough estimation based on buffer dimensions and an estimated cell size.
  """
  @spec calculate_buffer_usage(ScreenBuffer.t()) :: non_neg_integer()
  def calculate_buffer_usage(%ScreenBuffer{} = buffer) do
    # Rough estimation of memory usage based on buffer size and content
    buffer_size = buffer.width * buffer.height
    # Estimated bytes per cell (adjust as needed)
    cell_size = 100
    buffer_size * cell_size
  end

  @doc """
  Calculates the total approximate memory usage for two buffers (active and back).
  """
  @spec get_total_usage(ScreenBuffer.t(), ScreenBuffer.t()) :: non_neg_integer()
  def get_total_usage(active_buffer, back_buffer) do
    active_usage = calculate_buffer_usage(active_buffer)
    back_usage = calculate_buffer_usage(back_buffer)
    active_usage + back_usage
  end

  @doc """
  Checks if the given memory usage is within the specified limit.
  """
  @spec is_within_limit?(non_neg_integer(), non_neg_integer()) :: boolean()
  def is_within_limit?(current_usage, memory_limit) do
    current_usage <= memory_limit
  end
end
