defmodule Raxol.Terminal.Buffer.Manager.Memory do
  @moduledoc """
  Handles memory management for the terminal buffer.
  Provides functionality for tracking memory usage and enforcing limits.
  """

  alias Raxol.Terminal.Buffer.Manager.State
  # MemoryManager module doesn't exist, implementing functions locally

  @doc """
  Updates memory usage tracking.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = Memory.update_usage(state)
      iex> state.memory_usage > 0
      true
  """
  def update_usage(%State{} = state) do
    total_usage = get_total_usage(state.active_buffer, state.back_buffer)

    updated = %{state | memory_usage: total_usage}
    updated
  end

  @doc """
  Checks if memory usage is within limits.

  ## Examples

      iex> state = State.new(80, 24)
      iex> Memory.within_limits?(state)
      true
  """
  def within_limits?(%State{} = state) do
    within_limit?(state.memory_usage, state.memory_limit)
  end

  @doc """
  Gets the current memory usage.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = Memory.update_usage(state)
      iex> Memory.get_usage(state) > 0
      true
  """
  def get_usage(%State{} = state) do
    state.memory_usage
  end

  @doc """
  Gets the memory limit.

  ## Examples

      iex> state = State.new(80, 24)
      iex> Memory.get_limit(state)
      10_000_000
  """
  def get_limit(%State{} = state) do
    state.memory_limit
  end

  @doc """
  Sets a new memory limit.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = Memory.set_limit(state, 5_000_000)
      iex> Memory.get_limit(state)
      5_000_000
  """
  def set_limit(%State{} = state, new_limit)
      when is_integer(new_limit) and new_limit > 0 do
    %{state | memory_limit: new_limit}
  end

  @doc """
  Calculates memory usage for a specific buffer.

  ## Examples

      iex> state = State.new(80, 24)
      iex> Memory.calculate_buffer_usage(state.active_buffer) > 0
      true
  """
  def calculate_buffer_usage(buffer) do
    usage = calculate_buffer_usage_impl(buffer)
    usage
  end

  @doc """
  Estimates memory usage for a given buffer size.

  ## Examples

      iex> Memory.estimate_usage(80, 24, 1000) > 0
      true
  """
  def estimate_usage(width, height, scrollback_height) do
    estimate_usage_impl(width, height, scrollback_height)
  end

  @doc """
  Checks if a given buffer size would exceed memory limits.

  ## Examples

      iex> state = State.new(80, 24)
      iex> Memory.would_exceed_limit?(state, 100, 50, 2000)
      false
  """
  def would_exceed_limit?(%State{} = state, width, height, scrollback_height) do
    estimated_usage = estimate_usage(width, height, scrollback_height)
    estimated_usage > state.memory_limit
  end

  # Private helper functions

  defp get_total_usage(active_buffer, back_buffer) do
    active_size = calculate_buffer_size(active_buffer)
    back_size = calculate_buffer_size(back_buffer)
    active_size + back_size
  end

  defp within_limit?(usage, limit) do
    usage <= limit
  end

  defp calculate_buffer_usage_impl(buffer) do
    calculate_buffer_size(buffer)
  end

  defp estimate_usage_impl(width, height, scrollback_height) do
    # Estimate: each cell takes ~64 bytes (char + attributes)
    cells = width * (height + scrollback_height)
    cells * 64
  end

  defp calculate_buffer_size(nil), do: 0

  defp calculate_buffer_size(buffer) when is_map(buffer) do
    # Simple estimation based on buffer dimensions
    width = Map.get(buffer, :width, 0)
    height = Map.get(buffer, :height, 0)
    # 64 bytes per cell estimate
    width * height * 64
  end
end
