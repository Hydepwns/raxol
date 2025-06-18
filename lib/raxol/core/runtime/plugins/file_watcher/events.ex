defmodule Raxol.Core.Runtime.Plugins.FileWatcher.Events do
  @moduledoc '''
  Handles file system events and debouncing for plugin reloading.
  '''

  require Raxol.Core.Runtime.Log

  @file_event_debounce_ms 1000

  @doc '''
  Handles file system events.
  Returns updated state with debounced reload timer if needed.
  '''
  def handle_file_event(path, state, file_mod \\ File) do
    # Normalize the path
    normalized_path = Path.expand(path)

    # Check if the changed path corresponds to a known plugin source file
    case Map.get(state.reverse_plugin_paths, normalized_path) do
      nil ->
        # Not a plugin file, ignore
        Raxol.Core.Runtime.Log.debug(
          "[#{__MODULE__}] Ignoring file event for unknown path: #{normalized_path}"
        )

        {:ok, state}

      plugin_id ->
        # Cancel existing timer if any
        if state.file_event_timer do
          Process.cancel_timer(state.file_event_timer)

          Raxol.Core.Runtime.Log.debug(
            "[#{__MODULE__}] Cancelled existing timer for plugin #{plugin_id}"
          )
        end

        # Verify the file still exists and is readable
        case file_mod.stat(normalized_path) do
          {:ok, %{type: :regular, access: :read}} ->
            # Schedule a debounced reload
            timer_ref =
              Process.send_after(
                self(),
                {:reload_plugin_file_debounced, plugin_id, normalized_path},
                @file_event_debounce_ms
              )

            Raxol.Core.Runtime.Log.debug(
              "[#{__MODULE__}] Scheduled reload for plugin #{plugin_id} in #{@file_event_debounce_ms}ms"
            )

            {:ok, %{state | file_event_timer: timer_ref}}

          {:ok, _} ->
            # Not a regular file or not readable
            Raxol.Core.Runtime.Log.warning_with_context(
              "File #{normalized_path} is not a regular file or not readable",
              %{}
            )

            {:ok, state}

          {:error, reason} ->
            # File doesn't exist or can't be accessed
            Raxol.Core.Runtime.Log.error(
              "[#{__MODULE__}] Cannot access file #{normalized_path}: #{inspect(reason)}"
            )

            {:error, {:file_access_error, reason}}
        end
    end
  end

  @doc '''
  Handles debounced file events.
  Returns updated state after processing events.
  '''
  def handle_debounced_events(plugin_id, path, state) do
    # Clear the timer reference
    new_state = %{state | file_event_timer: nil}

    # Reload the affected plugin
    case Raxol.Core.Runtime.Plugins.FileWatcher.Reload.reload_plugin(
           plugin_id,
           path
         ) do
      :ok ->
        Raxol.Core.Runtime.Log.info(
          "[#{__MODULE__}] Successfully reloaded plugin #{plugin_id} after file change"
        )

        {:ok, new_state}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error(
          "[#{__MODULE__}] Failed to reload plugin #{plugin_id}: #{inspect(reason)}"
        )

        {:error, reason, new_state}
    end
  end
end
