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
  alias Raxol.Core.Runtime.Plugins.CommandHandler
  alias Raxol.Core.Runtime.Plugins.FileWatcher
  alias Raxol.Core.Runtime.Plugins.LifecycleManager
  alias Raxol.Core.Runtime.Plugins.Discovery
  alias Raxol.Core.Runtime.Plugins.StateManager
  alias Raxol.Core.Runtime.Plugins.EventFilter
  alias Raxol.Core.Runtime.Plugins.PluginReloader
  alias Raxol.Core.Runtime.Plugins.TimerManager
  # Explicitly alias core plugins
  alias Raxol.Core.Plugins.Core.ClipboardPlugin
  # Assume this exists
  alias Raxol.Core.Plugins.Core.NotificationPlugin

  # Added alias for State
  alias Raxol.Core.Runtime.Plugins.Manager.State

  # Added for file watching
  if Code.ensure_loaded?(FileSystem) do
    alias FileSystem
  end

  @type plugin_id :: String.t()
  @type plugin_metadata :: map()
  @type plugin_state :: map()

  # Use the literal default value
  @default_plugins_dir "priv/plugins"

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
      runtime_pid: nil,
      # Get plugin directories, ensure it's a list
      plugin_dirs: [],
      # Configurable modules for testing
      loader_module: Raxol.Core.Runtime.Plugins.Loader,
      lifecycle_helper_module: Raxol.Core.Runtime.Plugins.LifecycleHelper
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
  def filter_event(plugin_manager_state, event) do
    EventFilter.filter_event(plugin_manager_state, event)
  end

  # --- GenServer Callbacks ---

  @impl true
  def handle_cast(
        {:handle_command, command_atom, namespace, data, dispatcher_pid},
        state
      ) do
    case CommandHandler.handle_command(
           command_atom,
           namespace,
           data,
           dispatcher_pid,
           state
         ) do
      {:ok, updated_plugin_states} ->
        {:noreply, %{state | plugin_states: updated_plugin_states}}

      {:error, _reason} ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:send_clipboard_result, pid, content}, state) do
    CommandHandler.handle_clipboard_result(pid, content)
    {:noreply, state}
  end

  @impl true
  def handle_info(
        {:fs, _pid, {path, _events}},
        %{file_watching_enabled?: true} = state
      ) do
    case FileWatcher.handle_file_event(path, state) do
      {:ok, updated_state} -> {:noreply, updated_state}
      {:error, _reason} -> {:noreply, state}
    end
  end

  @impl true
  def handle_info(:debounce_file_events, state) do
    case FileWatcher.handle_debounced_events(state) do
      {:ok, updated_state} -> {:noreply, updated_state}
      {:error, _reason} -> {:noreply, state}
    end
  end

  @impl true
  def handle_info({:lifecycle_event, :shutdown}, state) do
    # Gracefully unload all plugins in reverse order using LifecycleHelper
    Enum.reduce(Enum.reverse(state.load_order), state, fn plugin_id,
                                                          acc_state ->
      case state.lifecycle_helper_module.unload_plugin(
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
    IO.inspect(opts, label: "Manager init opts")

    # CommandRegistry.new() is likely just creating the ETS table name atom, keep it here
    cmd_reg_table =
      Keyword.get(opts, :command_registry_table) ||
        Raxol.Core.Runtime.Plugins.CommandRegistry.new()

    # Extract runtime_pid from opts (passed by supervisor)
    runtime_pid = Keyword.get(opts, :runtime_pid)

    unless is_pid(runtime_pid) do
      Logger.error(
        "[#{__MODULE__}] :runtime_pid is missing or invalid in init opts: #{inspect(opts)}"
      )
    end

    # Get config options
    app_env_plugin_config =
      Application.get_env(:raxol, :plugin_manager_config, %{})

    opts_plugin_config = Keyword.get(opts, :plugin_config, %{})
    initial_plugin_config = Map.merge(app_env_plugin_config, opts_plugin_config)

    # Get plugin directories, ensure it's a list
    plugin_dirs =
      case Keyword.get(opts, :plugin_dirs, [@default_plugins_dir]) do
        dirs when is_list(dirs) -> dirs
        dir when is_binary(dir) -> [dir]
        _ -> [@default_plugins_dir]
      end

    IO.inspect(plugin_dirs, label: "Manager init plugin_dirs")

    enable_reloading =
      Keyword.get(opts, :enable_plugin_reloading, false) && Mix.env() == :dev

    # Configurable modules
    loader_mod =
      Keyword.get(opts, :loader_module, Raxol.Core.Runtime.Plugins.Loader)

    lifecycle_helper_mod =
      Keyword.get(
        opts,
        :lifecycle_helper_module,
        Raxol.Core.Runtime.Plugins.LifecycleHelper
      )

    # Start file watcher if enabled (only in dev)
    {file_watcher_pid, file_watching_enabled?} =
      if enable_reloading and Code.ensure_loaded?(FileSystem) do
        FileWatcher.setup_file_watching(%{
          plugin_dirs: plugin_dirs,
          file_watching_enabled?: false
        })
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

    {:ok,
     %State{
       command_registry_table: cmd_reg_table,
       plugin_config: initial_plugin_config,
       plugin_dirs: plugin_dirs,
       plugin_paths: %{},
       reverse_plugin_paths: %{},
       file_watcher_pid: file_watcher_pid,
       file_watching_enabled?: file_watching_enabled?,
       runtime_pid: runtime_pid,
       loader_module: loader_mod,
       lifecycle_helper_module: lifecycle_helper_mod
     }}
  end

  @impl true
  def handle_call(:initialize, _from, state) do
    case Discovery.initialize(state) do
      {:ok, updated_state} -> {:reply, :ok, updated_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:list_plugins, _from, state) do
    plugins = Discovery.list_plugins(state)
    {:reply, plugins, state}
  end

  @impl true
  def handle_call({:get_plugin, plugin_id}, _from, state) do
    case Discovery.get_plugin(plugin_id, state) do
      {:ok, plugin} -> {:reply, {:ok, plugin}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:enable_plugin, plugin_id}, _from, state) do
    case LifecycleManager.enable_plugin(plugin_id, state) do
      {:ok, updated_state} -> {:reply, :ok, updated_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:disable_plugin, plugin_id}, _from, state) do
    case LifecycleManager.disable_plugin(plugin_id, state) do
      {:ok, updated_state} -> {:reply, :ok, updated_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:reload_plugin, plugin_id}, _from, state) do
    case LifecycleManager.reload_plugin(plugin_id, state) do
      {:ok, updated_state} -> {:reply, :ok, updated_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:load_plugin, plugin_id, config}, _from, state) do
    # Send plugin load attempted event
    send(state.runtime_pid, {:plugin_load_attempted, plugin_id})

    case LifecycleManager.load_plugin(plugin_id, config, state) do
      {:ok, updated_state} ->
        {:reply, :ok, updated_state}

      {:error, reason} ->
        Logger.error("Failed to load plugin #{plugin_id}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:get_plugin_state, {_from, plugin_id}, state) do
    case StateManager.get_plugin_state(plugin_id, state) do
      {:ok, plugin_state} -> {:reply, {:ok, plugin_state}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:set_plugin_state, plugin_id, new_state}, _from, state) do
    case StateManager.set_plugin_state(plugin_id, new_state, state) do
      {:ok, updated_state} -> {:reply, :ok, updated_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:update_plugin_state, plugin_id, update_fun}, _from, state) do
    case StateManager.update_plugin_state(plugin_id, update_fun, state) do
      {:ok, updated_state} -> {:reply, :ok, updated_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_cast({:reload_plugin_by_id, plugin_id_string}, state) do
    case PluginReloader.reload_plugin_by_id(plugin_id_string, state) do
      {:ok, updated_state} -> {:noreply, updated_state}
      {:error, _reason, current_state} -> {:noreply, current_state}
    end
  end

  @impl true
  def handle_info({:reload_plugin_file_debounced, plugin_id, path}, state) do
    Logger.info(
      "[#{__MODULE__}] Debounced file change: Reloading plugin #{plugin_id} from path #{path}"
    )

    # Clear the timer ref
    new_state = TimerManager.cancel_existing_timer(state)

    case PluginReloader.reload_plugin(plugin_id, new_state) do
      {:ok, updated_state} -> {:noreply, updated_state}
      {:error, _reason, current_state} -> {:noreply, current_state}
    end
  end

  @impl true
  def handle_info(
        {:fs_error, _pid, {path, reason}},
        %{file_watching_enabled?: true} = state
      ) do
    Logger.error(
      "[#{__MODULE__}] File system watcher error for path #{path}: #{inspect(reason)}"
    )

    {:noreply, state}
  end

  # Fallback for other fs messages
  @impl true
  def handle_info({:fs, _, _}, state) do
    # Ignore if file watching not enabled or unexpected message
    {:noreply, state}
  end

  @impl true
  def handle_call({:process_command, command}, _from, state) do
    case CommandHandler.process_command(command, state) do
      {:ok, result, updated_state} ->
        # Send command processed event
        send(state.runtime_pid, {:command_processed, command, result})
        {:reply, {:ok, result}, updated_state}

      {:error, reason} ->
        Logger.error("Failed to process command: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  # --- Stubs for missing Plugin Manager functions ---
  @doc "Stub: process_output/2 not yet implemented."
  def process_output(_manager, _output) do
    Logger.warning("[Plugins.Manager] process_output/2 not implemented.")
    {:error, :not_implemented}
  end

  @doc "Stub: process_mouse/3 not yet implemented."
  def process_mouse(_manager, _event, _emulator_state) do
    Logger.warning("[Plugins.Manager] process_mouse/3 not implemented.")
    {:error, :not_implemented}
  end

  @doc "Stub: process_placeholder/4 not yet implemented."
  def process_placeholder(_manager, _arg1, _arg2, _arg3) do
    Logger.warning("[Plugins.Manager] process_placeholder/4 not implemented.")
    {:error, :not_implemented}
  end

  @doc "Stub: process_input/2 not yet implemented."
  def process_input(_manager, _input) do
    Logger.warning("[Plugins.Manager] process_input/2 not implemented.")
    {:error, :not_implemented}
  end

  @doc "Stub: execute_command/4 not yet implemented."
  def execute_command(_manager, _command, _arg1, _arg2) do
    Logger.warning("[Plugins.Manager] execute_command/4 not implemented.")
    {:error, :not_implemented}
  end

  # --- Termination ---
  @impl true
  def terminate(reason, state) do
    Logger.info("[#{__MODULE__}] Terminating (Reason: #{inspect(reason)}).")

    # Clean up file watching resources
    FileWatcher.cleanup_file_watching(state)

    # Cancel any pending debounce timer
    TimerManager.cancel_existing_timer(state)

    :ok
  end
end
