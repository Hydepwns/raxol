defmodule Raxol.Core.Runtime.Plugins.FileWatcher.Behaviour do
  @moduledoc """
  Defines the behaviour for file watching functionality in the plugin system.

  This behaviour is responsible for:
  - Setting up file system watchers
  - Handling file change events
  - Managing file paths and reverse mappings
  - Debouncing file events
  - Triggering plugin reloads
  """

  @doc """
  Sets up file watching for plugin source files.
  Returns the updated state with the file watcher PID.
  """
  @callback setup_file_watching(state :: map()) :: {pid() | nil, boolean()}

  @doc """
  Handles file system events.
  Returns updated state with debounced reload timer if needed.
  """
  @callback handle_file_event(path :: String.t(), state :: map()) :: {:ok, map()} | {:error, any()}

  @doc """
  Handles debounced file events.
  Returns updated state after processing events.
  """
  @callback handle_debounced_events(state :: map()) :: {:ok, map()} | {:error, any()}

  @doc """
  Updates the reverse path mapping for file watching.
  """
  @callback update_file_watcher(state :: map()) :: map()

  @doc """
  Cleans up file watching resources.
  """
  @callback cleanup_file_watching(state :: map()) :: map()
end
