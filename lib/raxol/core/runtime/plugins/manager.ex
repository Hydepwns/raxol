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

  # Core runtime dependencies
  alias Raxol.Core.Runtime.Events.Event
  alias Raxol.Core.Runtime.Plugins.CommandHandler
  alias Raxol.Core.Runtime.Plugins.FileWatcher
  alias Raxol.Core.Runtime.Plugins.Discovery
  alias Raxol.Core.Runtime.Plugins.StateManager
  alias Raxol.Core.Runtime.Plugins.PluginReloader
  alias Raxol.Core.Runtime.Plugins.TimerManager

  # Added for file watching
  if Code.ensure_loaded?(FileSystem) do
    alias FileSystem
  end

  @type plugin_id :: String.t()
  @type plugin_metadata :: map()
  @type plugin_state :: map()

  use GenServer
  @behaviour Raxol.Core.Runtime.Plugins.Manager.Behaviour

  require Raxol.Core.Runtime.Log
  require Logger

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
  @impl true
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

  @doc """
  Loads a plugin by ID with config and state maps (for test/mocking).
  """
  def load_plugin(plugin_id, config, state) do
    state.lifecycle_helper_module.load_plugin(
      plugin_id,
      config,
      state.plugins,
      state.metadata,
      state.plugin_states,
      state.load_order,
      state.command_registry_table,
      state.plugin_config
    )
  end

  @doc """
  Catch-all for load_plugin/4 to prevent UndefinedFunctionError. Raises a clear error if called.
  """
  def load_plugin(_a, _b, _c, _d) do
    raise "Raxol.Core.Runtime.Plugins.Manager.load_plugin/4 is not implemented. Use load_plugin/2 or load_plugin/3."
  end

  # --- Event Filtering Hook ---

  @doc "Placeholder for allowing plugins to filter events."
  @spec filter_event(any(), Event.t()) :: {:ok, Event.t()} | :halt | any()
  def filter_event(_plugin_manager_state, event) do
    # Placeholder for event filtering
    event
  end

  # --- GenServer Callbacks ---

  # Grouped handle_cast/2
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
  def handle_cast({:reload_plugin_by_id, plugin_id_string}, state) do
    case PluginReloader.reload_plugin_by_id(plugin_id_string, state) do
      {:ok, updated_state} -> {:noreply, updated_state}
      {:error, _reason, current_state} -> {:noreply, current_state}
    end
  end

  # Grouped handle_info/2
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
    case FileWatcher.Events.handle_debounced_events(
           state.plugin_id,
           state.plugin_path,
           state
         ) do
      {:ok, updated_state} -> {:noreply, updated_state}
      {:error, _reason, updated_state} -> {:noreply, updated_state}
    end
  end

  @impl true
  def handle_info({:lifecycle_event, :shutdown}, state) do
    # Gracefully unload all plugins in reverse order using LifecycleHelper
    Enum.reduce(Enum.reverse(state.load_order), state, fn plugin_id,
                                                          acc_state ->
      case acc_state.lifecycle_helper_module.cleanup_plugin(
             plugin_id,
             acc_state.metadata
           ) do
        {:ok, updated_metadata} ->
          %{acc_state | metadata: updated_metadata}

        {:error, reason} ->
          Raxol.Core.Runtime.Log.error_with_stacktrace(
            "[#{__MODULE__}] Failed to cleanup plugin during shutdown.",
            reason,
            nil,
            %{module: __MODULE__, plugin_id: plugin_id}
          )

          acc_state
      end
    end)

    {:noreply, %{state | initialized: false}}
  end

  @impl true
  def handle_info(:__internal_initialize__, state) do
    Raxol.Core.Runtime.Log.info(
      "[#{__MODULE__}] Starting internal plugin discovery and initialization."
    )

    case state.lifecycle_helper_module.initialize_plugins(
           state.plugins,
           state.metadata,
           state.plugin_config,
           state.plugin_states,
           state.load_order,
           state.command_registry_table,
           %{}
         ) do
      {:ok, {updated_metadata, updated_states, updated_table}} ->
        final_state = %{
          state
          | metadata: updated_metadata,
            plugin_states: updated_states,
            command_registry_table: updated_table,
            initialized: true
        }

        if final_state.runtime_pid do
          send(final_state.runtime_pid, {:plugin_manager_ready, self()})

          Raxol.Core.Runtime.Log.info(
            "[#{__MODULE__}] PluginManager fully initialized and ready. Notified runtime PID: #{inspect(final_state.runtime_pid)}"
          )
        else
          Raxol.Core.Runtime.Log.warning_with_context(
            "[#{__MODULE__}] PluginManager initialized, but no runtime_pid found in state to notify.",
            %{module: __MODULE__}
          )
        end

        {:noreply, final_state}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "[#{__MODULE__}] Failed during internal initialization (Discovery.initialize)",
          reason,
          nil,
          %{module: __MODULE__, reason: reason}
        )

        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:reload_plugin_file_debounced, plugin_id, path}, state) do
    Raxol.Core.Runtime.Log.info(
      "[#{__MODULE__}] Debounced file change: Reloading plugin #{plugin_id} from path #{path}"
    )

    new_state = TimerManager.cancel_existing_timer(state)

    case PluginReloader.reload_plugin(plugin_id, new_state) do
      {:ok, updated_state} ->
        {:noreply, updated_state}

      {:error, reason, updated_state} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "[#{__MODULE__}] Failed to reload plugin #{plugin_id}",
          reason,
          nil,
          %{module: __MODULE__, plugin_id: plugin_id, path: path}
        )

        {:noreply, updated_state}
    end
  end

  @impl true
  def handle_info(
        {:fs_error, _pid, {path, reason}},
        %{file_watching_enabled?: true} = state
      ) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "[#{__MODULE__}] File system watcher error for path #{path}: #{inspect(reason)}",
      %{module: __MODULE__, path: path, reason: reason}
    )

    {:noreply, state}
  end

  @impl true
  def handle_info({:fs, _, _}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({watcher_pid, true}, state) when is_pid(watcher_pid) do
    Raxol.Core.Runtime.Log.info(
      "[#{__MODULE__}] Received status :true from PID: #{inspect(watcher_pid)} (likely FileWatcher)."
    )

    {:noreply, state}
  end

  @impl true
  def handle_info({:file_event, path}, state) do
    case state.lifecycle_helper_module.reload_plugin_from_disk(
           state.plugin_id,
           path,
           state.plugins,
           state.metadata,
           state.plugin_states,
           state.load_order,
           state.command_registry_table,
           state.plugin_config
         ) do
      {:ok, {updated_metadata, updated_states, updated_table}} ->
        updated_state = %{
          state
          | metadata: updated_metadata,
            plugin_states: updated_states,
            command_registry_table: updated_table
        }

        {:noreply, updated_state}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Failed to reload plugin from disk #{state.plugin_id}",
          nil,
          nil,
          %{
            module: __MODULE__,
            plugin_id: state.plugin_id,
            path: path,
            reason: reason
          }
        )

        {:noreply, state}
    end
  end

  @impl true
  def handle_call(:initialize, _from, state) do
    # This public API might still be used for re-initialization or explicit trigger.
    # However, primary initialization is now async via :__internal_initialize__.
    # If called when already initialized, it could re-run discovery, or return current status.
    if state.initialized do
      Raxol.Core.Runtime.Log.info(
        "[#{__MODULE__}] :initialize called, but already initialized. Re-running discovery."
      )
    else
      Raxol.Core.Runtime.Log.info(
        "[#{__MODULE__}] :initialize called. Triggering internal initialization if not already started by init/1."
      )

      # This ensures that if :__internal_initialize__ hasn't run yet (e.g. race condition or direct call),
      # it gets a chance. Or, if it already ran, this might re-run it.
      # The logic in handle_info(:__internal_initialize__) is idempotent regarding sending the ready message
      # if structured to only send it once, or Lifecycle needs to handle multiple ready messages.
      # For simplicity, let's make this call also trigger the internal init,
      # and rely on Lifecycle to handle one :plugin_manager_ready message.
      send(self(), :__internal_initialize__)
    end

    # The actual result of initialization will be signaled asynchronously.
    # This call can reply :ok to indicate the command was received.
    # Or, it could be made to wait for the :__internal_initialize__ if a synchronous response is needed here.
    # For now, reply :ok immediately.
    {:reply, :ok, state}
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
    case Raxol.Core.Runtime.Plugins.LifecycleManager.enable_plugin(
           plugin_id,
           state
         ) do
      {:ok, updated_state} -> {:reply, :ok, updated_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:disable_plugin, plugin_id}, _from, state) do
    case Raxol.Core.Runtime.Plugins.LifecycleManager.disable_plugin(
           plugin_id,
           state
         ) do
      {:ok, updated_state} -> {:reply, :ok, updated_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:reload_plugin, plugin_id}, _from, state) do
    # Send plugin reload attempted event
    send(state.runtime_pid, {:plugin_reload_attempted, plugin_id})

    case state.lifecycle_helper_module.reload_plugin(
           plugin_id,
           state.plugins,
           state.metadata,
           state.plugin_states,
           state.load_order,
           state.command_registry_table,
           state.plugin_config
         ) do
      {:ok, {updated_metadata, updated_states, updated_table}} ->
        updated_state = %{
          state
          | metadata: updated_metadata,
            plugin_states: updated_states,
            command_registry_table: updated_table
        }

        {:reply, :ok, updated_state}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Failed to reload plugin #{plugin_id}",
          nil,
          nil,
          %{module: __MODULE__, plugin_id: plugin_id, reason: reason}
        )

        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:load_plugin, plugin_id, config}, _from, state) do
    # Send plugin load attempted event
    send(state.runtime_pid, {:plugin_load_attempted, plugin_id})

    case state.lifecycle_helper_module.load_plugin(
           plugin_id,
           config,
           state.plugins,
           state.metadata,
           state.plugin_states,
           state.load_order,
           state.command_registry_table,
           state.plugin_config
         ) do
      {:ok, {updated_metadata, updated_states, updated_table}} ->
        updated_state = %{
          state
          | metadata: updated_metadata,
            plugin_states: updated_states,
            command_registry_table: updated_table
        }

        {:reply, :ok, updated_state}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Failed to load plugin #{plugin_id}",
          nil,
          nil,
          %{module: __MODULE__, plugin_id: plugin_id, reason: reason}
        )

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
    updated_state =
      Raxol.Core.Runtime.Plugins.StateManager.set_plugin_state(
        plugin_id,
        new_state,
        state
      )

    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call({:update_plugin_state, plugin_id, update_fun}, _from, state) do
    updated_state =
      Raxol.Core.Runtime.Plugins.StateManager.update_plugin_state(
        plugin_id,
        update_fun,
        state
      )

    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call({:process_command, command}, _from, state) do
    case Raxol.Core.Runtime.Plugins.CommandHandler.process_command(
           command,
           state
         ) do
      {:ok, result} -> {:reply, {:ok, result}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
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

  @impl true
  def handle_call({:load_plugin_by_module, module, config}, _from, state) do
    # Send plugin load attempted event
    send(state.runtime_pid, {:plugin_load_attempted, module})

    case state.lifecycle_helper_module.load_plugin_by_module(
           module,
           config,
           state.plugins,
           state.metadata,
           state.plugin_states,
           state.load_order,
           state.command_registry_table,
           state.plugin_config
         ) do
      {:ok, {updated_metadata, updated_states, updated_table}} ->
        updated_state = %{
          state
          | metadata: updated_metadata,
            plugin_states: updated_states,
            command_registry_table: updated_table
        }

        {:reply, :ok, updated_state}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Failed to load plugin module #{inspect(module)}",
          nil,
          nil,
          %{module: __MODULE__, plugin_module: module, reason: reason}
        )

        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:unload_plugin, plugin_id}, _from, state) do
    # Send plugin unload attempted event
    send(state.runtime_pid, {:plugin_unload_attempted, plugin_id})

    case state.lifecycle_helper_module.unload_plugin(
           plugin_id,
           state.plugins,
           state.metadata,
           state.plugin_states,
           state.command_registry_table,
           state.plugin_config
         ) do
      {:ok, {updated_metadata, updated_states, updated_table}} ->
        updated_state = %{
          state
          | metadata: updated_metadata,
            plugin_states: updated_states,
            command_registry_table: updated_table
        }

        {:reply, :ok, updated_state}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Failed to unload plugin #{plugin_id}",
          nil,
          nil,
          %{module: __MODULE__, plugin_id: plugin_id, reason: reason}
        )

        {:reply, {:error, reason}, state}
    end
  end

  def process_output(_manager, _output) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "[Plugins.Manager] process_output/2 not implemented.",
      %{}
    )

    {:error, :not_implemented}
  end

  def process_mouse(_manager, _event, _emulator_state) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "[Plugins.Manager] process_mouse/3 not implemented.",
      %{}
    )

    {:error, :not_implemented}
  end

  def process_placeholder(_manager, _arg1, _arg2, _arg3) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "[Plugins.Manager] process_placeholder/4 not implemented.",
      %{}
    )

    {:error, :not_implemented}
  end

  def process_input(_manager, _input) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "[Plugins.Manager] process_input/2 not implemented.",
      %{}
    )

    {:error, :not_implemented}
  end

  def execute_command(_manager, _command, _arg1, _arg2) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "[Plugins.Manager] execute_command/4 not implemented.",
      %{}
    )

    {:error, :not_implemented}
  end

  @impl true
  def terminate(reason, state) do
    Raxol.Core.Runtime.Log.info(
      "[#{__MODULE__}] Terminating (Reason: #{inspect(reason)}).",
      %{module: __MODULE__, reason: reason}
    )

    # Clean up file watching resources
    FileWatcher.cleanup_file_watching(state)

    # Cancel any pending debounce timer
    TimerManager.cancel_existing_timer(state)

    :ok
  end

  def stop(pid \\ __MODULE__) do
    GenServer.stop(pid)
  end

  @doc """
  Initializes the GenServer with the provided argument.
  """
  @impl true
  def init(arg) do
    {:ok, arg}
  end

  @doc """
  Loads a plugin by sending a call to the GenServer.
  """
  @impl true
  def load_plugin(plugin_id) do
    GenServer.call(__MODULE__, {:load_plugin, plugin_id})
  end

  @doc """
  Unloads a plugin by sending a call to the GenServer.
  """
  @impl true
  def unload_plugin(plugin_id) do
    GenServer.call(__MODULE__, {:unload_plugin, plugin_id})
  end
end
