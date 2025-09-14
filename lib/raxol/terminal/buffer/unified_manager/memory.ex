defmodule Raxol.Terminal.Buffer.UnifiedManager.Memory do
  @moduledoc """
  Memory management utilities for the UnifiedManager.

  Provides functions for tracking and updating memory usage in the unified buffer manager.
  """

  @doc """
  Gets the current memory usage from the state.

  ## Parameters
  - state: The unified manager state

  ## Returns
  Memory usage information
  """
  @spec get_memory_usage(map()) :: non_neg_integer()
  def get_memory_usage(state) do
    Map.get(state, :memory_usage, 0)
  end

  @doc """
  Updates memory usage tracking in the state.

  ## Parameters
  - state: The unified manager state

  ## Returns
  Updated state with current memory usage
  """
  @spec update_memory_usage(map()) :: map()
  def update_memory_usage(state) do
    # Calculate approximate memory usage based on state size
    memory_usage = calculate_memory_usage(state)
    Map.put(state, :memory_usage, memory_usage)
  end

  # Private helper to calculate memory usage
  defp calculate_memory_usage(state) do
    # Simple approximation - in a real implementation this could be more sophisticated
    # Base overhead
    base_size = 1000
    buffer_size = calculate_buffer_memory(state)
    session_size = calculate_session_memory(state)

    base_size + buffer_size + session_size
  end

  defp calculate_buffer_memory(state) do
    # Estimate memory usage from buffers
    sessions = Map.get(state, :sessions, %{})

    Enum.reduce(sessions, 0, fn {_id, session}, acc ->
      acc + Map.get(session, :buffer_memory, 100)
    end)
  end

  defp calculate_session_memory(state) do
    # Estimate memory usage from session data
    sessions = Map.get(state, :sessions, %{})
    # Rough estimate per session
    map_size(sessions) * 500
  end
end
