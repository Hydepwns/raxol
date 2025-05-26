defmodule Raxol.Core.Runtime.Plugins.FileWatcher do
  @moduledoc """
  Handles file watching functionality for plugins.

  This module provides a public API for monitoring plugin source files and triggering
  reloads when changes are detected. It delegates to specialized submodules for
  different aspects of the functionality:

  - `FileWatcher.Core`: Core setup and state management
  - `FileWatcher.Events`: Event handling and debouncing
  - `FileWatcher.Reload`: Plugin reloading logic
  - `FileWatcher.Cleanup`: Resource cleanup

  ## State

  The module maintains state in the following structure:

  ```elixir
  %{
    plugin_dirs: [String.t()],           # List of directories to watch
    plugin_paths: %{String.t() => String.t()},  # Plugin ID to path mapping
    reverse_plugin_paths: %{String.t() => String.t()},  # Path to plugin ID mapping
    file_watcher_pid: pid() | nil,       # File system watcher process
    file_event_timer: reference() | nil,  # Debounce timer reference
    file_watching_enabled?: boolean()    # File watching status
  }
  ```

  ## Usage

  ```elixir
  # Initialize file watching
  state = %{
    plugin_dirs: ["plugins"],
    plugin_paths: %{"my_plugin" => "plugins/my_plugin.ex"},
    file_watching_enabled?: false
  }

  # Setup file watching
  {pid, enabled?} = FileWatcher.setup_file_watching(state)
  state = %{state | file_watcher_pid: pid, file_watching_enabled?: enabled?}

  # Update file watcher with new paths
  state = FileWatcher.update_file_watcher(state)

  # Cleanup on shutdown
  state = FileWatcher.cleanup_file_watching(state)
  ```

  For more detailed documentation about the module's architecture and internals,
  see `docs/file_watcher.md`.
  """

  alias Raxol.Core.Runtime.Plugins.FileWatcher.{
    Core,
    Events,
    Reload,
    Cleanup
  }

  require Raxol.Core.Runtime.Log

  @doc """
  Creates a new file watcher state.
  """
  def new do
    %{
      plugin_dirs: [],
      plugins_dir: "priv/plugins",
      initialized: false,
      command_registry_table: nil,
      loader_module: Raxol.Core.Runtime.Plugins.Loader,
      lifecycle_helper_module: Raxol.Core.Runtime.Plugins.FileWatcher,
      plugins: %{},
      metadata: %{},
      plugin_states: %{},
      plugin_paths: %{},
      reverse_plugin_paths: %{},
      load_order: [],
      file_watching_enabled?: false,
      file_watcher_pid: nil,
      file_event_timer: nil
    }
  end

  @doc """
  Sets up file watching for plugin source files.
  Returns the updated state with the file watcher PID.
  """
  def setup_file_watching(state) do
    Core.setup_file_watching(state)
  end

  @doc """
  Handles file system events.
  Returns updated state with debounced reload timer if needed.
  """
  def handle_file_event(path, state, file_mod \\ File) do
    Events.handle_file_event(path, state, file_mod)
  end

  @doc """
  Handles debounced file events.
  Returns updated state after processing events.
  """
  def handle_debounced_events(plugin_id, path, state) do
    Events.handle_debounced_events(plugin_id, path, state)
  end

  @doc """
  Updates the reverse path mapping for file watching.
  """
  def update_file_watcher(state) do
    Core.update_file_watcher(state)
  end

  @doc """
  Cleans up file watching resources.
  """
  def cleanup_file_watching(state) do
    Cleanup.cleanup_file_watching(state)
  end

  @doc """
  Reloads a plugin after file changes.
  Returns :ok on success or {:error, reason} on failure.
  """
  def reload_plugin(plugin_id, path) do
    Reload.reload_plugin(plugin_id, path)
  end
end
