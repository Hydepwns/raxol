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
  alias Raxol.Core.Runtime.Plugins.Loader
  # Explicitly alias core plugins
  alias Raxol.Core.Plugins.Core.ClipboardPlugin
  # Assume this exists
  alias Raxol.Core.Plugins.Core.NotificationPlugin

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
      # Default value
      plugins_dir: "priv/plugins",
      # FileSystem watcher PID
      file_watcher_pid: nil,
      # Whether file watching is enabled
      file_watching_enabled?: false,
      # Debounce timer reference for file events
      file_event_timer: nil,
      # Runtime PID
      runtime_pid: nil
    ]
  end

  use GenServer
  @behaviour Raxol.Core.Runtime.Plugins.Manager.Behaviour

  require Logger

  # Debounce interval for file system events (milliseconds)
  @file_event_debounce_ms 500

  @doc """
  Starts the Plugin Manager GenServer.
  """
  @impl true
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

    # TODO: (Future Agent) Implement logic to iterate through plugins and apply filters.
    # This will involve defining how plugins register filters and how their responses
    # (e.g., modified event, :halt) are handled by the manager.
    # Default: pass event through unchanged
    event
  end

  # --- GenServer Callbacks ---

  @impl true
  def handle_cast(
        {:handle_command, command_atom, namespace, data, dispatcher_pid},
        state
      ) do
    command_name_str = Atom.to_string(command_atom)

    Logger.info(
      "[#{__MODULE__}] Delegating command: #{inspect(command_atom)} in namespace: #{inspect(namespace)} with data: #{inspect(data)}, result_to: #{inspect(dispatcher_pid)}"
    )

    # Delegate command handling to CommandHelper
    case CommandHelper.handle_command(
           state.command_registry_table,
           command_name_str,
           namespace,
           data,
           state
         ) do
      # Expected success format from CommandHelper: {:ok, new_plugin_state, result_tuple, plugin_id}
      {:ok, new_plugin_state, result_tuple, plugin_id} ->
        Logger.debug(
          "[#{__MODULE__}] Command #{inspect(command_atom)} executed by plugin #{inspect(plugin_id)}. Result: #{inspect(result_tuple)}"
        )

        updated_plugin_states =
          Map.put(state.plugin_states, plugin_id, new_plugin_state)

        # Format result message for Dispatcher/Application
        result_msg = {:command_result, {command_atom, result_tuple}}

        Logger.debug(
          "[#{__MODULE__}] Sending result to #{inspect(dispatcher_pid)}: #{inspect(result_msg)}"
        )

        send(dispatcher_pid, result_msg)

        {:noreply, %{state | plugin_states: updated_plugin_states}}

      :not_found ->
        Logger.warning(
          "[#{__MODULE__}] Command not found by CommandHelper: #{inspect(command_atom)} in namespace: #{inspect(namespace)}"
        )

        # Send an error back
        error_result_tuple = {:error, :command_not_found}

        send(
          dispatcher_pid,
          {:command_result, {command_atom, error_result_tuple}}
        )

        {:noreply, state}

      # Expected error format from CommandHelper: {:error, reason_tuple, plugin_id (can be nil)}
      {:error, reason_tuple, plugin_id} ->
        Logger.error(
          "[#{__MODULE__}] Error executing command #{inspect(command_atom)} in plugin #{inspect(plugin_id || "unknown")}: #{inspect(reason_tuple)}"
        )

        # Send error back to Dispatcher/Application
        send(
          dispatcher_pid,
          {:command_result, {command_atom, {:error, reason_tuple}}}
        )

        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:send_clipboard_result, pid, content}, state) do
    send(pid, {:command_result, {:clipboard_content, content}})
    {:noreply, state}
  end

  @impl true
  def handle_info(
        {:fs, _pid, {path, _events}},
        %{file_watching_enabled?: true} = state
      ) do
    # Check if the changed path corresponds to a known plugin source file
    case Map.get(state.reverse_plugin_paths, path) do
      nil ->
        # Not a known plugin file, ignore
        {:noreply, state}

      plugin_id ->
        Logger.debug(
          "[#{__MODULE__}] Detected change in plugin source file: #{path} (Plugin: #{plugin_id})"
        )

        # Debounce the reload request
        new_state = cancel_existing_timer(state)

        timer =
          Process.send_after(
            self(),
            {:trigger_reload, plugin_id},
            @file_event_debounce_ms
          )

        {:noreply, %{new_state | file_event_timer: timer}}
    end
  end

  # Catch-all for other file system messages if not enabled or relevant
  def handle_info({:fs, _, _}, state) do
    {:noreply, state}
  end

  # Triggered after debounce timer
  def handle_info({:trigger_reload, plugin_id}, state) do
    Logger.debug(
      "[#{__MODULE__}] Debounce finished, triggering reload for: #{plugin_id}"
    )

    # Trigger reload via cast to avoid blocking handle_info
    GenServer.cast(self(), {:reload_plugin_by_id, plugin_id})
    # Clear the timer ref
    {:noreply, %{state | file_event_timer: nil}}
  end

  @impl true
  def handle_info({:lifecycle_event, :shutdown}, state) do
    # Gracefully unload all plugins in reverse order using LifecycleHelper
    Enum.reduce(Enum.reverse(state.load_order), state, fn plugin_id,
                                                          acc_state ->
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
          Logger.error(
            "[#{__MODULE__}] Failed to unload plugin #{plugin_id} during shutdown."
          )

          acc_state
      end
    end)

    # Keep manager initialized state update
    {:noreply, %{state | initialized: false}}
  end

  @impl true
  def init(opts) do
    # CommandRegistry.new() is likely just creating the ETS table name atom, keep it here
    cmd_reg_table = Raxol.Core.Runtime.Plugins.CommandRegistry.new()

    # Extract runtime_pid from opts (passed by supervisor)
    # Get runtime_pid
    runtime_pid = Keyword.get(opts, :runtime_pid)

    unless is_pid(runtime_pid) do
      Logger.error(
        "[#{__MODULE__}] :runtime_pid is missing or invalid in init opts: #{inspect(opts)}"
      )

      # Decide how to handle this - raise error, return {:stop, ...}?
      # For now, let it proceed with nil, but it will likely cause issues later.
    end

    # Get config options
    # Fetch from Application environment
    app_env_plugin_config =
      Application.get_env(:raxol, :plugin_manager_config, %{})

    # Fetch from opts (as before)
    opts_plugin_config = Keyword.get(opts, :plugin_config, %{})
    # Merge them - opts can override app_env for specific plugins if keys clash
    initial_plugin_config = Map.merge(app_env_plugin_config, opts_plugin_config)

    plugins_dir = Keyword.get(opts, :plugins_dir, "priv/plugins")

    enable_reloading =
      Keyword.get(opts, :enable_plugin_reloading, false) && Mix.env() == :dev

    # Start file watcher if enabled (only in dev)
    {file_watcher_pid, file_watching_enabled?} =
      if enable_reloading and Code.ensure_loaded?(FileSystem) do
        # Start watching the base dir initially
        case FileSystem.start_link(dirs: [plugins_dir]) do
          {:ok, pid} ->
            Logger.info(
              "[#{__MODULE__}] File system watcher started for plugin reloading (PID: #{inspect(pid)})."
            )

            FileSystem.subscribe(pid)
            {pid, true}

          {:error, reason} ->
            Logger.error(
              "[#{__MODULE__}] Failed to start file system watcher: #{inspect(reason)}"
            )

            {nil, false}
        end
      else
        if enable_reloading and Mix.env() != :dev do
          Logger.warning(
            "[#{__MODULE__}] Plugin reloading via file watching only enabled in :dev environment."
          )
        end

        if enable_reloading and !Code.ensure_loaded?(FileSystem) do
          Logger.warning(
            "[#{__MODULE__}] FileSystem dependency not found. Cannot enable plugin reloading."
          )
        end

        {nil, false}
      end

    # Subscribe to system shutdown event (TODO remains)
    # ...

    {:ok,
     %State{
       command_registry_table: cmd_reg_table,
       plugin_config: initial_plugin_config,
       plugins_dir: plugins_dir,
       # Initialize plugin_paths
       plugin_paths: %{},
       # Initialize reverse paths
       reverse_plugin_paths: %{},
       file_watcher_pid: file_watcher_pid,
       file_watching_enabled?: file_watching_enabled?,
       # Store runtime_pid
       runtime_pid: runtime_pid
     }}
  end

  @impl true
  def handle_call(:initialize, _from, %{initialized: true} = state) do
    {:reply, :already_initialized, state}
  end

  @impl true
  def handle_call(:initialize, _from, state) do
    Logger.info("[#{__MODULE__}] Initializing Plugins...")

    # Define Core Plugins
    core_plugin_modules = [
      ClipboardPlugin,
      NotificationPlugin
    ]

    # Discover external plugins
    discovered_external_specs = Loader.discover_plugins(state.plugins_dir)

    Logger.debug(
      "[#{__MODULE__}] Discovered external plugin specs: #{inspect(discovered_external_specs)}"
    )

    # Combine core modules and discovered specs (need to get file_path for core if needed)
    # For now, assume core plugins don't need a file_path for loading via load_plugin_by_module
    # Let's create specs for core plugins {module, nil} to fit the reduce structure
    core_plugin_specs = Enum.map(core_plugin_modules, &{&1, nil})
    all_specs = core_plugin_specs ++ discovered_external_specs

    Logger.debug(
      "[#{__MODULE__}] Combined specs for loading: #{inspect(all_specs)}"
    )

    # Ensure ETS table exists
    command_table = Raxol.Core.Runtime.Plugins.CommandRegistry.new()

    # Initial state for reduction
    initial_acc = %{
      plugins: state.plugins,
      metadata: state.metadata,
      plugin_states: state.plugin_states,
      load_order: state.load_order,
      plugin_config: state.plugin_config,
      plugin_paths: state.plugin_paths,
      command_table: command_table,
      errors: []
    }

    # Iterate through ALL specs (core + external) and try to load each plugin
    final_acc =
      Enum.reduce(all_specs, initial_acc, fn {module_atom, file_path}, acc ->
        plugin_id_guess = Loader.module_to_default_id(module_atom)

        # Use specific config for core plugins if provided in state.plugin_config
        config =
          Map.get(
            acc.plugin_config,
            module_atom,
            Map.get(acc.plugin_config, plugin_id_guess, %{})
          )

        case LifecycleHelper.load_plugin_by_module(
               module_atom,
               config,
               acc.plugins,
               acc.metadata,
               acc.plugin_states,
               acc.load_order,
               acc.command_table,
               acc.plugin_config
             ) do
          {:ok, updated_maps} ->
            # Get consistent ID
            current_plugin_id = Loader.module_to_default_id(module_atom)

            new_plugin_paths =
              if file_path do
                Map.put(acc.plugin_paths, current_plugin_id, file_path)
              else
                # Don't add path for core plugins
                acc.plugin_paths
              end

            %{
              acc
              | plugins: updated_maps.plugins,
                metadata: updated_maps.metadata,
                plugin_states: updated_maps.plugin_states,
                load_order: updated_maps.load_order,
                plugin_config: updated_maps.plugin_config,
                plugin_paths: new_plugin_paths
            }

          {:error, reason} ->
            Logger.error(
              "[#{__MODULE__}] Failed to load plugin #{inspect(module_atom)}: #{inspect(reason)}"
            )

            %{acc | errors: [{module_atom, reason} | acc.errors]}
        end
      end)

    # Check if any errors occurred during loading
    if Enum.empty?(final_acc.errors) do
      Logger.info("[#{__MODULE__}] Plugin initialization successful.")
      # Update manager state with results from accumulator
      new_state = %{
        state
        | initialized: true,
          command_registry_table: final_acc.command_table,
          plugins: final_acc.plugins,
          metadata: final_acc.metadata,
          plugin_states: final_acc.plugin_states,
          load_order: final_acc.load_order,
          plugin_config: final_acc.plugin_config,
          plugin_paths: final_acc.plugin_paths
      }

      # Build reverse path map and watch files if enabled
      final_state_with_watcher = update_file_watcher(new_state)
      {:reply, :ok, final_state_with_watcher}
    else
      Logger.error(
        "[#{__MODULE__}] Plugin initialization failed with errors: #{inspect(final_acc.errors)}"
      )

      # Return error, state remains uninitialized
      {:reply, {:error, {:initialization_failed, final_acc.errors}}, state}
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

  @impl true
  def handle_call({:load_plugin, plugin_id_or_module, config}, _from, state) do
    case LifecycleHelper.load_plugin(
           # Can be ID or module now
           plugin_id_or_module,
           config,
           state.plugins,
           state.metadata,
           state.plugin_states,
           state.load_order,
           state.command_registry_table,
           # Removed plugin_paths for arity 8
           state.plugin_config
         ) do
      {:ok, updated_maps} ->
        # Merge updated maps back into the state
        new_state = %{
          state
          | plugins: updated_maps.plugins,
            metadata: updated_maps.metadata,
            plugin_states: updated_maps.plugin_states,
            load_order: updated_maps.load_order,
            plugin_config: updated_maps.plugin_config
        }

        # Update watcher for the newly loaded plugin
        final_state = update_file_watcher(new_state)
        {:reply, :ok, final_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:reload_plugin, plugin_id}, _from, state) do
    case handle_reload_plugin(plugin_id, state) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason, new_state} -> {:reply, {:error, reason}, new_state}
    end
  end

  @impl true
  def handle_call(:get_plugins, _from, state) do
    {:reply, state.plugins, state}
  end

  @impl true
  def handle_call(:get_plugin_states, _from, state) do
    {:reply, state.plugin_states, state}
  end

  # --- Termination ---
  @impl true
  def terminate(reason, state) do
    Logger.info("[#{__MODULE__}] Terminating (Reason: #{inspect(reason)}).")

    # Stop file watcher if it was started
    if state.file_watcher_pid do
      Logger.debug(
        "[#{__MODULE__}] Stopping file watcher (PID: #{inspect(state.file_watcher_pid)})."
      )

      # Use GenServer.stop for clean shutdown
      GenServer.stop(state.file_watcher_pid, :normal, :infinity)
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
             # Pass the paths map
             new_state.plugin_paths
           ) do
        {:ok, updated_maps} ->
          # Update the full state from the returned maps
          reloaded_state = %{
            new_state
            | plugins: updated_maps.plugins,
              metadata: updated_maps.metadata,
              plugin_states: updated_maps.plugin_states,
              load_order: updated_maps.load_order,
              plugin_config: updated_maps.plugin_config
          }

          # Ensure watcher is up-to-date after reload (path might change theoretically)
          final_state = update_file_watcher(reloaded_state)
          {:ok, final_state}

        {:error, reason} ->
          # Reload failed, log and return error, state remains unchanged from before the call
          Logger.error(
            "Failed to reload plugin #{plugin_id}: #{inspect(reason)}"
          )

          # Return state before failed reload attempt
          {:error, reason, new_state}
      end
    end
  end

  # Updates the reverse path map. FileSystem process watches the directory specified in init.
  defp update_file_watcher(state) do
    if state.file_watching_enabled? do
      # Calculate new reverse map {path => plugin_id}
      new_reverse_paths =
        Enum.into(state.plugin_paths, %{}, fn {plugin_id, path} ->
          {path, plugin_id}
        end)

      # Return state with updated reverse map
      %{state | reverse_plugin_paths: new_reverse_paths}
    else
      # File watching not enabled
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
        Logger.debug(
          "[#{__MODULE__}] Auto-reloaded plugin '#{plugin_id}' due to file change."
        )

        {:noreply, new_state}

      {:error, reason, new_state} ->
        Logger.error(
          "[#{__MODULE__}] Failed to auto-reload plugin '#{plugin_id}': #{inspect(reason)}"
        )

        # Keep state even on error
        {:noreply, new_state}
    end
  end
end
