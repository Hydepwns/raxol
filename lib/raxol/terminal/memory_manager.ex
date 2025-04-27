defmodule Raxol.Terminal.MemoryManager do
  @moduledoc """
  Monitors and manages memory usage for terminal processes.

  Can trigger actions like trimming scrollback when limits are exceeded.
  """
  use GenServer
  require Logger

  alias Raxol.Terminal.Buffer.Manager, as: BufferManager
  alias Raxol.Terminal.Integration

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
  @spec check_and_cleanup(Integration.t()) :: Integration.t()
  def check_and_cleanup(%Integration{} = integration) do
    now = System.system_time(:millisecond)
    time_since_last_cleanup = now - integration.last_cleanup

    if time_since_last_cleanup >= integration.config.cleanup_interval do
      Logger.debug(
        "Performing terminal memory check. Interval: #{integration.config.cleanup_interval}ms"
      )
      perform_cleanup(%{integration | last_cleanup: now})
    else
      integration
    end
  end

  @doc """
  Performs memory cleanup operations on relevant terminal components.

  Currently focuses on trimming the buffer manager.
  """
  @spec perform_cleanup(Integration.t()) :: Integration.t()
  def perform_cleanup(%Integration{} = integration) do
    # Update usage and get the value
    updated_buffer_manager = BufferManager.update_memory_usage(integration.buffer_manager)
    current_usage = updated_buffer_manager.memory_usage
    memory_limit = integration.config.memory_limit_bytes

    # Update integration with the potentially updated buffer manager (with new usage)
    integration_with_updated_manager = %{integration | buffer_manager: updated_buffer_manager}

    if current_usage > memory_limit do
      bytes_over_limit = current_usage - memory_limit
      Logger.debug("Memory usage (#{current_usage} bytes) exceeds limit (#{memory_limit} bytes). Over by #{bytes_over_limit} bytes.")

      # Remove the attempt to trim scrollback manually, as it trims on add_lines
      # The main buffer update itself might free memory implicitly.
      updated_integration = integration_with_updated_manager

      # Recalculate usage (in case buffer update changed it, though update_memory_usage already did)
      final_buffer_manager = BufferManager.update_memory_usage(updated_integration.buffer_manager)
      new_usage = final_buffer_manager.memory_usage

      if new_usage > memory_limit do
        Logger.warning("Memory usage still high after check. Current: #{new_usage}, Limit: #{memory_limit}. Need more aggressive cleanup.")
        # TODO: Implement more aggressive cleanup (e.g., clear parts of main buffer?)
      else
        Logger.debug("Memory usage within limits after check. Current usage: #{new_usage} bytes.")
      end

      %{updated_integration | buffer_manager: final_buffer_manager, last_cleanup: System.monotonic_time(:millisecond)}
    else
      Logger.debug("Memory usage (#{current_usage} bytes) within limit (#{memory_limit} bytes). No cleanup needed.")
      # No cleanup needed, just update timestamp and potentially the manager if usage was recalculated
      # No cleanup needed, just update timestamp
      %{integration | last_cleanup: System.monotonic_time(:millisecond)}
    end
  end

  # TODO: Implement actual memory usage estimation logic if needed.
  # def estimate_memory_usage(integration) do ... end
end
