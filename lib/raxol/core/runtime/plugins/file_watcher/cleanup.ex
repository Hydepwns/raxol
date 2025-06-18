defmodule Raxol.Core.Runtime.Plugins.FileWatcher.Cleanup do
  @moduledoc """
  Handles cleanup of file watching resources.
  """

  require Raxol.Core.Runtime.Log

  @doc """
  Cleans up file watching resources.
  Returns the updated state.
  """
  def cleanup_file_watching(state) do
    # Stop the file watcher process if it exists
    if state.file_watcher_pid do
      Raxol.Core.Runtime.Log.debug(
        "[#{__MODULE__}] Stopping file watcher (PID: #{inspect(state.file_watcher_pid)})."
      )

      if is_pid(state.file_watcher_pid) and
           Process.alive?(state.file_watcher_pid) do
        if :erlang.function_exported(:sys, :get_state, 1) do
          result =
            try do
              {:ok, :sys.get_state(state.file_watcher_pid)}
            catch
              :exit, _ -> :not_genserver
              :error, _ -> :not_genserver
            end

          case result do
            {:ok, _} ->
              GenServer.stop(state.file_watcher_pid, :normal, :infinity)

            _ ->
              Process.exit(state.file_watcher_pid, :normal)
          end
        else
          Process.exit(state.file_watcher_pid, :normal)
        end
      end
    end

    # Cancel any pending debounce timer
    if state.file_event_timer do
      Process.cancel_timer(state.file_event_timer)
    end

    # Return state with cleared watcher references
    %{
      state
      | file_watcher_pid: nil,
        file_event_timer: nil,
        file_watching_enabled?: false
    }
  end
end
