defmodule Raxol.Core.Runtime.Plugins.FileWatcher.Cleanup do
  @moduledoc """
  Handles cleanup of file watching resources.
  """

  require Logger

  @doc """
  Cleans up file watching resources.
  Returns the updated state.
  """
  def cleanup_file_watching(state) do
    # Stop the file watcher process if it exists
    if state.file_watcher_pid do
      Logger.debug(
        "[#{__MODULE__}] Stopping file watcher (PID: #{inspect(state.file_watcher_pid)})."
      )

      # Use GenServer.stop for clean shutdown
      GenServer.stop(state.file_watcher_pid, :normal, :infinity)
    end

    # Cancel any pending debounce timer
    if state.file_event_timer do
      Process.cancel_timer(state.file_event_timer)
    end

    # Return state with cleared watcher references
    %{state |
      file_watcher_pid: nil,
      file_event_timer: nil,
      file_watching_enabled?: false
    }
  end
end
