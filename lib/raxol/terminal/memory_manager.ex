defmodule Raxol.Terminal.MemoryManager do
  @moduledoc """
  Manages memory usage and cleanup for the terminal system.
  """

  alias Raxol.Terminal.{
    Buffer.UnifiedManager,
    Integration.State
  }

  require Raxol.Core.Runtime.Log

  @doc """
  Checks if memory usage is within limits and performs cleanup if necessary.
  """
  def check_and_cleanup(%State{} = state) do
    current_usage = UnifiedManager.get_memory_usage(state.buffer_manager)
    memory_limit = state.config.memory_limit || 50 * 1024 * 1024

    if current_usage > memory_limit do
      Raxol.Core.Runtime.Log.warning(
        "Memory usage (#{current_usage} bytes) exceeds limit (#{memory_limit} bytes). Performing cleanup."
      )

      # Perform cleanup
      state = cleanup(state)
      state
    else
      state
    end
  end

  # Handle general map types that contain terminal field
  def check_and_cleanup(%{terminal: terminal} = state) do
    case check_and_cleanup(terminal) do
      {:ok, updated_terminal} -> %{state | terminal: updated_terminal}
      _ -> state
    end
  end

  @doc """
  Estimates memory usage for a given state.
  """
  def estimate_memory_usage(state) when is_map(state) do
    case Map.fetch(state, :buffer_manager) do
      {:ok, bm} -> UnifiedManager.get_memory_usage(bm)
      :error -> 0
    end
  end

  # Private Functions

  defp cleanup(%State{} = state) do
    # Clear scrollback buffer
    scroll_buffer = Raxol.Terminal.Buffer.Scroll.clear(state.scroll_buffer)

    # Clear command history
    command_history = Raxol.Terminal.Commands.History.clear(state.command_history)

    # Update state
    %{state |
      scroll_buffer: scroll_buffer,
      command_history: command_history,
      last_cleanup: System.system_time(:millisecond)
    }
  end
end
