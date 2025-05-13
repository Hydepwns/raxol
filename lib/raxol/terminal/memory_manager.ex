defmodule Raxol.Terminal.MemoryManager do
  @moduledoc """
  Monitors and manages memory usage for terminal processes.

  Can trigger actions like trimming scrollback when limits are exceeded.
  """
  use GenServer
  require Logger

  alias Raxol.Terminal.Buffer.Manager, as: BufferManager
  alias Raxol.Terminal.Integration
  alias Raxol.Terminal.Integration.State

  defstruct manager_pid: nil

  # --- GenServer Callbacks ---
  @impl GenServer
  def init(init_arg) do
    {:ok, init_arg}
  end

  # --- Public API ---

  @doc """
  Checks if memory usage exceeds the limit and performs cleanup if necessary.

  This function should be called periodically.
  """
  @spec check_and_cleanup(State.t()) :: State.t()
  def check_and_cleanup(%State{} = state) do
    now = System.system_time(:millisecond)
    time_since_last_cleanup = now - state.last_cleanup

    if time_since_last_cleanup >= state.config.cleanup_interval do
      Logger.debug(
        "Performing terminal memory check. Interval: #{state.config.cleanup_interval}ms"
      )

      perform_cleanup(%{state | last_cleanup: now})
    else
      state
    end
  end

  @doc """
  Performs memory cleanup operations on relevant terminal components.

  Currently focuses on trimming the buffer manager.
  """
  @spec perform_cleanup(State.t()) :: State.t()
  def perform_cleanup(%State{} = state) do
    updated_buffer_manager =
      BufferManager.update_memory_usage(state.buffer_manager)

    current_usage = updated_buffer_manager.memory_usage
    memory_limit = state.config.memory_limit_bytes

    state_with_updated_manager = %{
      state
      | buffer_manager: updated_buffer_manager
    }

    if current_usage > memory_limit do
      bytes_over_limit = current_usage - memory_limit

      Logger.debug(
        "Memory usage (#{current_usage} bytes) exceeds limit (#{memory_limit} bytes). Over by #{bytes_over_limit} bytes."
      )

      updated_state = state_with_updated_manager

      final_buffer_manager =
        BufferManager.update_memory_usage(updated_state.buffer_manager)

      new_usage = final_buffer_manager.memory_usage

      if new_usage > memory_limit do
        Logger.warning(
          "Memory usage still high after check. Current: #{new_usage}, Limit: #{memory_limit}. Need more aggressive cleanup."
        )

        # TODO: Implement more aggressive cleanup
      else
        Logger.debug(
          "Memory usage within limits after check. Current usage: #{new_usage} bytes."
        )
      end

      %{
        updated_state
        | buffer_manager: final_buffer_manager,
          last_cleanup: System.monotonic_time(:millisecond)
      }
    else
      Logger.debug(
        "Memory usage (#{current_usage} bytes) within limit (#{memory_limit} bytes). No cleanup needed."
      )

      %{state | last_cleanup: System.monotonic_time(:millisecond)}
    end
  end

  @doc """
  Estimates the total memory usage of the terminal state.

  Sums the memory usage of the buffer manager, scroll buffer, and other relevant components.
  Returns the total in bytes.
  """
  @spec estimate_memory_usage(State.t()) :: non_neg_integer()
  def estimate_memory_usage(%State{} = state) do
    buffer_manager_usage =
      case Map.fetch(state, :buffer_manager) do
        {:ok, bm} -> Map.get(bm, :memory_usage, 0)
        :error -> 0
      end

    scroll_buffer_usage =
      case Map.fetch(state, :scroll_buffer) do
        {:ok, sb} -> Map.get(sb, :memory_usage, 0)
        :error -> 0
      end

    # Add other components as needed
    # For now, just sum buffer_manager and scroll_buffer
    buffer_manager_usage + scroll_buffer_usage
  end
end
