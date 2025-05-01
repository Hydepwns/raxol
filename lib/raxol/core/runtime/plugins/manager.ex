defmodule Raxol.Core.Runtime.Plugins.Manager do
  @moduledoc """
  Manages the loading, initialization, and lifecycle of plugins in the Raxol runtime.

  This module is responsible for:
  - Discovering available plugins
  - Loading and initializing plugins
  - Managing plugin lifecycle events
  - Providing access to loaded plugins
  - Handling plugin dependencies and conflicts
  - Optionally watching plugin source files for changes and reloading them (dev only).
  """

  alias Raxol.Core.Runtime.Events.Event
  alias Raxol.Core.Runtime.Plugins.LifecycleHelper
  alias Raxol.Core.Runtime.Plugins.CommandHelper

  # Added for file watching
  if Code.ensure_loaded?(FileSystem) do
    alias FileSystem
  end

  @type plugin_id :: String.t()
  @type plugin_metadata :: map()
  @type plugin_state :: map()

  # State stored in the process
  defmodule State do
    @moduledoc false
    defstruct [
      # Map of plugin_id to plugin instance
      plugins: %{},
      # Map of plugin_id to plugin metadata
      metadata: %{},
      # Map of plugin_id to plugin state
      plugin_states: %{},
      # Map of plugin_id to source file path
      plugin_paths: %{},
      # Map of source file path back to plugin_id (for file watcher)
      reverse_plugin_paths: %{},
      # List of plugin_ids in the order they were loaded
      load_order: [],
      # Whether the plugin system has been initialized
      initialized: false,
      # ETS table name for the command registry
      command_registry_table: nil,
      # Configuration for plugins, keyed by plugin_id
      plugin_config: %{},
      # Directory to discover plugins from
      plugins_dir: "priv/plugins", # Default value
      # FileSystem watcher PID
      file_watcher_pid: nil,
      # Whether file watching is enabled
      file_watching_enabled?: false,
      # Debounce timer reference for file events
      file_event_timer: nil
    ]
  end

  use GenServer

  require Logger

  # Debounce interval for file system events (milliseconds)
  @file_event_debounce_ms 500

  @doc """
  Starts the plugin manager process.

  Options:
  - `:plugin_config`: Initial configuration map for plugins.
  - `:plugins_dir`: Directory to discover plugins from.
  - `:enable_plugin_reloading`: Boolean flag to enable automatic reloading via file watching (dev only). Defaults to `false`.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Initialize the plugin system and load all available plugins.
  """
  def initialize do
    GenServer.call(__MODULE__, :initialize)
  end

  @doc """
  Get a list of all loaded plugins with their metadata.
  """
  def list_plugins do
    GenServer.call(__MODULE__, :list_plugins)
  end

  @doc """
  Get a specific plugin by its ID.
  """
  def get_plugin(plugin_id) do
    GenServer.call(__MODULE__, {:get_plugin, plugin_id})
  end

  @doc """
  Enable a plugin that was previously disabled.
  """
  def enable_plugin(plugin_id) do
    GenServer.call(__MODULE__, {:enable_plugin, plugin_id})
  end

  @doc """
  Disable a plugin temporarily without unloading it.
  """
  def disable_plugin(plugin_id) do
    GenServer.call(__MODULE__, {:disable_plugin, plugin_id})
  end

  @doc """
  Reload a plugin by unloading and then loading it again.
  """
  def reload_plugin(plugin_id) do
    GenServer.call(__MODULE__, {:reload_plugin, plugin_id})
  end

  @doc """
  Load a plugin with a given configuration.
  """
  def load_plugin(plugin_id, config) do
    GenServer.call(__MODULE__, {:load_plugin, plugin_id, config})
  end

  # --- Event Filtering Hook ---

  @doc "Placeholder for allowing plugins to filter events."
  @spec filter_event(any(), Event.t()) :: {:ok, Event.t()} | :halt | any()
  def filter_event(_plugin_manager_state, event) do
    Logger.debug(
      "[#{__MODULE__}] filter_event called for: #{inspect(event.type)}"
    )

    # TODO: Implement logic to iterate through plugins and apply filters
    # Default: pass event through unchanged
    event
  end

  # --- GenServer Callbacks ---

  @impl true
  def handle_cast({:handle_command, command_name, data}, state) do
    Logger.info(
      "[#{__MODULE__}] Delegating command: #{inspect(command_name)} with data: #{inspect(data)}"
    )
    # Delegate command handling to CommandHelper
    case CommandHelper.handle_command(
           command_name,
           data,
           state.command_registry_table,
           state.plugins,
           state.plugin_states
         ) do
      {:ok, updated_plugin_states} ->
        # Update state if helper indicates success
        {:noreply, %{state | plugin_states: updated_plugin_states}}

      :not_found ->
        # Command wasn't found, state unchanged
        {:noreply, state}

      {:error, _reason} ->
        # Error occurred during handling, state unchanged (error already logged by helper)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:send_clipboard_result, pid, content}, state) do
    send(pid, {:command_result, {:clipboard_content, content}})
    {:noreply, state}
  end

  @impl true
  def handle_info({:fs, _pid, {path, _events}}, %{file_watching_enabled?: true} = state) do
    # Check if the changed path corresponds to a known plugin source file
    case Map.get(state.reverse_plugin_paths, path) do
      nil ->
        # Not a known plugin file, ignore
        {:noreply, state}

      plugin_id ->
        Logger.debug("[#{__MODULE__}] Detected change in plugin source file: #{path} (Plugin: #{plugin_id})")
        # Debounce the reload request
        new_state = cancel_existing_timer(state)
        timer = Process.send_after(self(), {:trigger_reload, plugin_id}, @file_event_debounce_ms)
        {:noreply, %{new_state | file_event_timer: timer}}
    end
  end

  # Catch-all for other file system messages if not enabled or relevant
  def handle_info({:fs, _, _}, state) do
    {:noreply, state}
  end

  # Triggered after debounce timer
  def handle_info({:trigger_reload, plugin_id}, state) do
    Logger.debug("[#{__MODULE__}] Debounce finished, triggering reload for: #{plugin_id}")
    # Trigger reload via cast to avoid blocking handle_info
    GenServer.cast(self(), {:reload_plugin_by_id, plugin_id})
    {:noreply, %{state | file_event_timer: nil}} # Clear the timer ref
  end

  @impl true
  def handle_info({:lifecycle_event, :shutdown}, state) do
    # Gracefully unload all plugins in reverse order using LifecycleHelper
    Enum.reduce(Enum.reverse(state.load_order), state, fn plugin_id, acc_state ->
      case LifecycleHelper.unload_plugin(
        plugin_id,
        acc_state.plugins,
        acc_state.metadata,
        acc_state.plugin_states,
        acc_state.load_order,
        acc_state.command_registry_table
      ) do
        {:ok, updated_maps} ->
          %{
            acc_state
            | plugins: updated_maps.plugins,
              metadata: updated_maps.metadata,
              plugin_states: updated_maps.plugin_states,
              load_order: updated_maps.load_order
          }
        {:error, _reason} ->
          # Log error? Keep state as is.
          Logger.error("[#{__MODULE__}] Failed to unload plugin #{plugin_id} during shutdown.")
          acc_state
      end
    end)

    {:noreply, %{state | initialized: false}} # Keep manager initialized state update
  end

  @impl true
  def init(opts) do
    # CommandRegistry.new() is likely just creating the ETS table name atom, keep it here
    cmd_reg_table = Raxol.Core.Runtime.Plugins.CommandRegistry.new()
    # Get config options
    initial_plugin_config = Keyword.get(opts, :plugin_config, %{})
    plugins_dir = Keyword.get(opts, :plugins_dir, "priv/plugins")
    enable_reloading = Keyword.get(opts, :enable_plugin_reloading, false) && Mix.env() == :dev

    # Start file watcher if enabled (only in dev)
    {file_watcher_pid, file_watching_enabled?} =
      if enable_reloading and Code.ensure_loaded?(FileSystem) do
        case FileSystem.start_link(dirs: [plugins_dir]) do # Start watching the base dir initially
          {:ok, pid} ->
            Logger.info("[#{__MODULE__}] File system watcher started for plugin reloading (PID: #{inspect(pid)}).")
            FileSystem.subscribe(pid)
            {pid, true}
          {:error, reason} ->
            Logger.error("[#{__MODULE__}] Failed to start file system watcher: #{inspect(reason)}")
            {nil, false}
        end
      else
        if enable_reloading and Mix.env() != :dev do
          Logger.warning("[#{__MODULE__}] Plugin reloading via file watching only enabled in :dev environment.")
        end
        if enable_reloading and !Code.ensure_loaded?(FileSystem) do
          Logger.warning("[#{__MODULE__}] FileSystem dependency not found. Cannot enable plugin reloading.")
        end
        {nil, false}
      end

    # Subscribe to system shutdown event (TODO remains)
    # ...

    {:ok, %State{
      command_registry_table: cmd_reg_table,
      plugin_config: initial_plugin_config,
      plugins_dir: plugins_dir,
      plugin_paths: %{}, # Initialize plugin_paths
      reverse_plugin_paths: %{}, # Initialize reverse paths
      file_watcher_pid: file_watcher_pid,
      file_watching_enabled?: file_watching_enabled?
    }}
  end

  @impl true
  def handle_call(:initialize, _from, %{initialized: true} = state) do
    {:reply, :already_initialized, state}
  end

  @impl true
  def handle_call(:initialize, _from, state) do
    Logger.info("[#{__MODULE__}] Initializing...")

    # Use new/0 instead of create_table/0
    command_table = Raxol.Core.Runtime.Plugins.CommandRegistry.new()

    # Delegate discovery, sorting, and loading loop to LifecycleHelper
    case LifecycleHelper.initialize_plugins(
           state.plugins, # Pass initial empty maps
           state.metadata,
           state.plugin_states,
           state.load_order,
           command_table, # Pass the newly created table
           state.plugin_config, # Pass config loaded in init
           state.plugins_dir    # Pass plugins_dir for discovery
         ) do
      {:ok, final_state_maps} ->
        # Update manager state with results from helper
        new_state = %{
          state
          | initialized: true,
            command_registry_table: command_table,
            plugins: final_state_maps.plugins,
            metadata: final_state_maps.metadata,
            plugin_states: final_state_maps.plugin_states,
            load_order: final_state_maps.load_order,
            plugin_config: final_state_maps.plugin_config,
            plugin_paths: final_state_maps.plugin_paths # Store the returned paths
        }

        # Build reverse path map and watch files if enabled
        final_state = update_file_watcher(new_state)

        {:reply, :ok, final_state}

      {:error, reason} ->
        # Error already logged by helper
        {:reply, {:error, reason}, state} # Return original state on error
    end
  end

  @impl true
  def handle_call(:list_plugins, _from, state) do
    # Return metadata for loaded plugins
    {:reply, Map.values(state.metadata), state}
  end

  @impl true
  def handle_call({:get_plugin, plugin_id}, _from, state) do
    plugin = Map.get(state.plugins, plugin_id)
    {:reply, plugin, state}
  end

  # --- Loading / Unloading / Reloading ---

  # Public API call: load_plugin/2 translates to load_plugin/3 via handle_call
  @impl true
  def handle_call({:load_plugin, plugin_id_or_module, config}, _from, state) do
    case LifecycleHelper.load_plugin(
           plugin_id_or_module, # Can be ID or module now
           config,
           state.plugins,
           state.metadata,
           state.plugin_states,
           state.load_order,
           state.command_registry_table,
           state.plugin_config,
           state.plugin_paths # Pass paths for potential updates during load_by_id
         ) do
      {:ok, updated_maps} ->
        # Merge updated maps back into the state
        new_state = %{
          state
          | plugins: updated_maps.plugins,
            metadata: updated_maps.metadata,
            plugin_states: updated_maps.plugin_states,
            load_order: updated_maps.load_order,
            plugin_config: updated_maps.plugin_config,
            plugin_paths: updated_maps.plugin_paths # Update paths map
        }
        # Update watcher for the newly loaded plugin
        final_state = update_file_watcher(new_state)
        {:reply, :ok, final_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  # Public API call: reload_plugin/1 via handle_call
  @impl true
  def handle_call({:reload_plugin, plugin_id}, _from, state) do
    case handle_reload_plugin(plugin_id, state) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason, new_state} -> {:reply, {:error, reason}, new_state}
    end
  end

  # --- Termination ---
  @impl true
  def terminate(reason, state) do
    Logger.info("[#{__MODULE__}] Terminating (Reason: #{inspect(reason)}).")

    # Stop file watcher if it was started
    if state.file_watcher_pid do
      Logger.debug("[#{__MODULE__}] Stopping file watcher (PID: #{inspect(state.file_watcher_pid)}).")
      FileSystem.stop(state.file_watcher_pid)
    end

    # Cancel any pending debounce timer
    cancel_existing_timer(state)

    # Existing shutdown logic (unload plugins) will be triggered by supervisor/shutdown signals
    # via handle_info({:lifecycle_event, :shutdown}, ...) or implicit GenServer shutdown.

    :ok
  end

  # --- Private Helpers ---

  # Encapsulates the core reload logic used by both handle_call and handle_cast
  defp handle_reload_plugin(plugin_id, state) do
    if !state.initialized do
      {:error, :not_initialized, state}
    else
      Logger.info("[#{__MODULE__}] Reloading plugin: #{plugin_id}")
      # Cancel any pending reload timer for this specific plugin_id if triggered manually
      new_state = cancel_existing_timer(state)

      case LifecycleHelper.reload_plugin_from_disk(
             plugin_id,
             new_state.plugins,
             new_state.metadata,
             new_state.plugin_states,
             new_state.load_order,
             new_state.command_registry_table,
             new_state.plugin_config,
             new_state.plugin_paths # Pass the paths map
           ) do
        {:ok, updated_maps} ->
          # Update the full state from the returned maps
          reloaded_state = %{
            new_state
            | plugins: updated_maps.plugins,
              metadata: updated_maps.metadata,
              plugin_states: updated_maps.plugin_states,
              load_order: updated_maps.load_order,
              plugin_config: updated_maps.plugin_config,
              plugin_paths: updated_maps.plugin_paths
          }
           # Ensure watcher is up-to-date after reload (path might change theoretically)
           final_state = update_file_watcher(reloaded_state)
          {:ok, final_state}

        {:error, reason} ->
          # Reload failed, log and return error, state remains unchanged from before the call
          Logger.error("Failed to reload plugin #{plugin_id}: #{inspect(reason)}")
          {:error, reason, new_state} # Return state before failed reload attempt
      end
    end
  end

  # Updates the reverse path map and tells FileSystem to watch/unwatch files
  defp update_file_watcher(state) do
    if state.file_watching_enabled? and state.file_watcher_pid do
       # Calculate new reverse map {path => plugin_id}
      new_reverse_paths =
        Enum.into(state.plugin_paths, %{}, fn {plugin_id, path} -> {path, plugin_id} end)

      # Files currently watched (keys of old reverse map)
      old_watched_files = Map.keys(state.reverse_plugin_paths)
      # Files that should be watched (keys of new reverse map)
      new_watched_files = Map.keys(new_reverse_paths)

      # Watch new files
      files_to_watch = new_watched_files -- old_watched_files
      Enum.each(files_to_watch, fn path ->
        Logger.debug("[#{__MODULE__}] Watching plugin file: #{path}")
        FileSystem.watch(state.file_watcher_pid, path)
      end)

      # Unwatch removed files
      files_to_unwatch = old_watched_files -- new_watched_files
      Enum.each(files_to_unwatch, fn path ->
         Logger.debug("[#{__MODULE__}] Unwatching plugin file: #{path}")
        # Use FileSystem.unwatch! or handle potential errors if needed
         try do
           FileSystem.unwatch!(state.file_watcher_pid, path)
         rescue
           # Log error if unwatch fails (e.g., file already unwatched)
           e in FileSystem.Error -> Logger.warning("[#{__MODULE__}] Error unwatching #{path}: #{inspect(e)}")
         end
      end)

       # Return state with updated reverse map
       %{state | reverse_plugin_paths: new_reverse_paths}
    else
      # File watching not enabled or watcher not started
      state
    end
  end

  # Cancels existing debounce timer if active
  defp cancel_existing_timer(state) do
    if state.file_event_timer do
      Process.cancel_timer(state.file_event_timer)
      %{state | file_event_timer: nil}
    else
      state
    end
  end

  # New cast for internally triggered reloads from file watcher
  @impl true
  def handle_cast({:reload_plugin_by_id, plugin_id}, state) do
     # Reuse existing reload logic, but handle reply within the cast
    case handle_reload_plugin(plugin_id, state) do
      {:ok, new_state} ->
         Logger.debug("[#{__MODULE__}] Auto-reloaded plugin '#{plugin_id}' due to file change.")
         {:noreply, new_state}
      {:error, reason, new_state} ->
         Logger.error("[#{__MODULE__}] Failed to auto-reload plugin '#{plugin_id}': #{inspect(reason)}")
         {:noreply, new_state} # Keep state even on error
    end
  end
end
