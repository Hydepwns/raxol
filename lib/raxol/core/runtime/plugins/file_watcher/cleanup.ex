defmodule Raxol.Core.Runtime.Plugins.FileWatcher.Cleanup do
  @moduledoc """
  Handles cleanup of file watching resources.
  """

  require Raxol.Core.Runtime.Log
  import Raxol.Guards

  @doc """
  Cleans up file watching resources.
  Returns the updated state.
  """
  def cleanup_file_watching(state) do
    state = stop_file_watcher(state)
    state = cancel_file_event_timer(state)

    # Return state with cleared watcher references
    %{
      state
      | file_watcher_pid: nil,
        file_event_timer: nil,
        file_watching_enabled?: false
    }
  end

  defp stop_file_watcher(state) do
    if should_stop_file_watcher?(state) do
      Raxol.Core.Runtime.Log.debug(
        "[#{__MODULE__}] Stopping file watcher (PID: #{inspect(state.file_watcher_pid)})."
      )

      stop_watcher_process(state.file_watcher_pid)
    end

    state
  end

  defp should_stop_file_watcher?(state) do
    state.file_watcher_pid && pid?(state.file_watcher_pid) &&
      Process.alive?(state.file_watcher_pid)
  end

  defp stop_watcher_process(pid) do
    if :erlang.function_exported(:sys, :get_state, 1) do
      stop_genserver_or_process(pid)
    else
      Process.exit(pid, :normal)
    end
  end

  defp stop_genserver_or_process(pid) do
    result = try_get_genserver_state(pid)

    case result do
      {:ok, _} -> GenServer.stop(pid, :normal, :infinity)
      _ -> Process.exit(pid, :normal)
    end
  end

  defp try_get_genserver_state(pid) do
    try do
      {:ok, :sys.get_state(pid)}
    catch
      :exit, _ -> :not_genserver
      :error, _ -> :not_genserver
    end
  end

  defp cancel_file_event_timer(state) do
    if state.file_event_timer do
      Process.cancel_timer(state.file_event_timer)
    end

    state
  end
end
