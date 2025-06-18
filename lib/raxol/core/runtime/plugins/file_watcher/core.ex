defmodule Raxol.Core.Runtime.Plugins.FileWatcher.Core do
  @moduledoc '''
  Core functionality for file watching in plugins.
  Handles basic setup and state management.
  '''

  require Raxol.Core.Runtime.Log

  @doc '''
  Sets up file watching for plugin source files.
  Returns the updated state with the file watcher PID.
  '''
  def setup_file_watching(state) do
    if Code.ensure_loaded?(FileSystem) do
      case FileSystem.start_link(dirs: state.plugin_dirs) do
        {:ok, pid} ->
          Raxol.Core.Runtime.Log.info(
            "[#{__MODULE__}] File system watcher started for plugin reloading (PID: #{inspect(pid)})."
          )

          FileSystem.subscribe(pid)
          {pid, true}

        {:error, reason} ->
          Raxol.Core.Runtime.Log.error(
            "[#{__MODULE__}] Failed to start file system watcher: #{inspect(reason)}"
          )

          {nil, false}
      end
    else
      Raxol.Core.Runtime.Log.warning_with_context(
        "[#{__MODULE__}] FileSystem dependency not found. Cannot enable plugin reloading.",
        %{}
      )

      {nil, false}
    end
  end

  @doc '''
  Updates the reverse path mapping for file watching.
  '''
  def update_file_watcher(state) do
    if state.file_watching_enabled? do
      # Calculate new reverse map {path => plugin_id} with normalized paths
      new_reverse_paths =
        Enum.into(state.plugin_paths, %{}, fn {plugin_id, path} ->
          normalized_path = Path.expand(path)
          {normalized_path, plugin_id}
        end)

      # Return state with updated reverse map
      %{state | reverse_plugin_paths: new_reverse_paths}
    else
      # File watching not enabled
      state
    end
  end
end
