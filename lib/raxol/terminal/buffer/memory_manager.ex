defmodule Raxol.Terminal.Buffer.MemoryManager do
  alias Raxol.Terminal.ScreenBuffer

  @moduledoc """
  Handles calculation and checking of terminal buffer memory usage.
  """

  @doc """
  Calculates the approximate memory usage of a single screen buffer.

  This is a rough estimation based on buffer dimensions and an estimated cell size.
  """
  @spec calculate_buffer_usage(ScreenBuffer.t()) :: non_neg_integer()
  def calculate_buffer_usage(buffer) do
    case buffer do
      %ScreenBuffer{} = buffer ->
        buffer_size = buffer.width * buffer.height
        cell_size = 100
        usage = buffer_size * cell_size
        usage

      _ ->
        0
    end
  end

  @doc """
  Calculates the total approximate memory usage for two buffers (active and back).
  """
  @spec get_total_usage(ScreenBuffer.t(), ScreenBuffer.t()) :: non_neg_integer()
  def get_total_usage(active_buffer, back_buffer) do
    active_usage = calculate_buffer_usage(active_buffer)
    back_usage = calculate_buffer_usage(back_buffer)
    total = active_usage + back_usage
    total
  end

  @doc """
  Checks if the given memory usage is within the specified limit.
  """
  @spec is_within_limit?(non_neg_integer(), non_neg_integer()) :: boolean()
  def is_within_limit?(current_usage, memory_limit) do
    current_usage <= memory_limit
  end

  @doc """
  Estimates the approximate memory usage for a given set of dimensions.
  """
  @spec estimate_usage(pos_integer(), pos_integer(), pos_integer()) ::
          non_neg_integer()
  def estimate_usage(width, height, scrollback_height) do
    # Approximate size of a cell in memory (bytes)
    cell_size = 100
    main_buffer_usage = width * height * cell_size
    # Assuming scrollback has same width
    scrollback_usage = width * scrollback_height * cell_size
    main_buffer_usage + scrollback_usage
  end
end
