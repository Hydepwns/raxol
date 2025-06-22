defmodule Raxol.Terminal.Buffer.Manager.Memory do
  @moduledoc """
  Handles memory management for the terminal buffer.
  Provides functionality for tracking memory usage and enforcing limits.
  """

  alias Raxol.Terminal.Buffer.Manager.State
  alias Raxol.Terminal.Buffer.MemoryManager

  @doc """
  Updates memory usage tracking.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = Memory.update_usage(state)
      iex> state.memory_usage > 0
      true
  """
  def update_usage(%State{} = state) do
    total_usage =
      Raxol.Terminal.Buffer.MemoryManager.get_total_usage(
        state.active_buffer,
        state.back_buffer
      )

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
    MemoryManager.within_limit?(state.memory_usage, state.memory_limit)
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
    usage = MemoryManager.calculate_buffer_usage(buffer)
    usage
  end

  @doc """
  Estimates memory usage for a given buffer size.

  ## Examples

      iex> Memory.estimate_usage(80, 24, 1000) > 0
      true
  """
  def estimate_usage(width, height, scrollback_height) do
    MemoryManager.estimate_usage(width, height, scrollback_height)
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
end
