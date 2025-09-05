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
    execute_file_watcher_stop(should_stop_file_watcher?(state), state)
    state
  end

  defp should_stop_file_watcher?(state) do
    state.file_watcher_pid && is_pid(state.file_watcher_pid) &&
      Process.alive?(state.file_watcher_pid)
  end

  defp stop_watcher_process(pid) do
    handle_watcher_process_stop(
      :erlang.function_exported(:sys, :get_state, 1),
      pid
    )
  end

  defp stop_genserver_or_process(pid) do
    result = try_get_genserver_state(pid)

    case result do
      {:ok, _} -> GenServer.stop(pid, :normal, :infinity)
      _ -> Process.exit(pid, :normal)
    end
  end

  defp try_get_genserver_state(pid) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           {:ok, :sys.get_state(pid)}
         end) do
      {:ok, result} -> result
      {:error, {:exit, _}} -> :not_genserver
      {:error, {:error, _}} -> :not_genserver
      {:error, _} -> :not_genserver
    end
  end

  defp cancel_file_event_timer(state) do
    cancel_timer_if_present(state.file_event_timer)
    state
  end

  # Helper functions for if-statement elimination
  defp execute_file_watcher_stop(false, _state), do: :ok

  defp execute_file_watcher_stop(true, state) do
    Raxol.Core.Runtime.Log.debug(
      "[#{__MODULE__}] Stopping file watcher (PID: #{inspect(state.file_watcher_pid)})."
    )

    stop_watcher_process(state.file_watcher_pid)
  end

  defp handle_watcher_process_stop(true, pid),
    do: stop_genserver_or_process(pid)

  defp handle_watcher_process_stop(false, pid), do: Process.exit(pid, :normal)

  defp cancel_timer_if_present(nil), do: :ok
  defp cancel_timer_if_present(timer), do: Process.cancel_timer(timer)
end
