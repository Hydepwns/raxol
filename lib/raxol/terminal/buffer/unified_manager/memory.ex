defmodule Raxol.Terminal.Buffer.UnifiedManager.Memory do
  @moduledoc """
  Handles memory management for the unified buffer manager.

  This module provides functions for calculating memory usage,
  updating memory metrics, and managing memory limits.
  """

  alias Raxol.Terminal.Buffer.Scroll

  @doc """
  Updates the memory usage in the state.
  """
  @spec update_memory_usage(map()) :: map()
  def update_memory_usage(state) do
    # Calculate memory usage based on buffer dimensions and content
    active_memory = calculate_buffer_memory(state.active_buffer)
    back_memory = calculate_buffer_memory(state.back_buffer)
    scrollback_memory = calculate_scrollback_memory(state.scrollback_buffer)

    memory = active_memory + back_memory + scrollback_memory

    # Record memory usage metric
    # Raxol.Core.Metrics.UnifiedCollector.record_resource(
    #   :buffer_memory_usage,
    #   memory,
    #   tags: [:buffer, :memory]
    # )

    # Update state with memory usage
    %{state | memory_usage: memory}
  end

  @doc """
  Calculates memory usage for a ScreenBuffer.
  """
  @spec calculate_buffer_memory(map()) :: non_neg_integer()
  def calculate_buffer_memory(buffer) do
    # Estimate memory usage based on dimensions and content
    # Each cell is roughly 64 bytes (including overhead)
    # Plus some overhead for the struct itself
    cell_count = buffer.width * buffer.height
    cell_memory = cell_count * 64

    # Add overhead for the struct and other fields
    struct_overhead = 1024

    cell_memory + struct_overhead
  end

  @doc """
  Calculates memory usage for a Scroll buffer.
  """
  @spec calculate_scrollback_memory(Scroll.t()) :: non_neg_integer()
  def calculate_scrollback_memory(scrollback) do
    # Estimate memory usage based on scrollback content
    # Each line is roughly 80 * 64 bytes (assuming 80 columns)
    # Plus some overhead for the struct itself
    line_count = length(scrollback.buffer)
    line_memory = line_count * 80 * 64

    # Add overhead for the struct and other fields
    struct_overhead = 512

    line_memory + struct_overhead
  end

  @doc """
  Gets the memory usage of the buffer.
  """
  @spec get_memory_usage(map()) :: {:ok, non_neg_integer()}
  def get_memory_usage(state) do
    memory =
      calculate_buffer_memory(state.active_buffer) +
        calculate_buffer_memory(state.back_buffer) +
        calculate_scrollback_memory(state.scrollback_buffer)

    {:ok, memory}
  end
end
