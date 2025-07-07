defmodule Raxol.Core.Runtime.Plugins.Manager do
  import Raxol.Guards

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

  @type plugin_id :: String.t()
  @type plugin_metadata :: map()
  @type plugin_state :: map()

  use GenServer
  @behaviour Raxol.Core.Runtime.Plugins.Manager.Behaviour

  require Raxol.Core.Runtime.Log

  # Add missing aliases for modules being called without full names
  alias Raxol.Core.Runtime.Plugins.CommandHandler
  alias Raxol.Core.Runtime.Plugins.Discovery
  alias Raxol.Core.Runtime.Plugins.FileWatcher
  alias Raxol.Core.Runtime.Plugins.PluginReloader
  alias Raxol.Core.Runtime.Plugins.TimerManager

  @impl Raxol.Core.Runtime.Plugins.Manager.Behaviour
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def start_link(_app, opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(arg) do
    # Convert list of options to a proper state map
    state = case arg do
      opts when is_list(opts) ->
        # Convert keyword list to map
        opts_map = Enum.into(opts, %{})

        # Initialize with default values
        %{
          plugins: %{},
          metadata: %{},
          plugin_states: %{},
          plugin_config: Map.get(opts_map, :plugin_config, %{}),
          load_order: [],
          command_registry_table: Map.get(opts_map, :command_registry_table, :command_registry),
          runtime_pid: Map.get(opts_map, :runtime_pid),
          file_watching_enabled?: Map.get(opts_map, :enable_plugin_reloading, false),
          initialized: false,
          lifecycle_helper_module: Raxol.Core.Runtime.Plugins.LifecycleManager
        }

      state when is_map(state) ->
        # Already a map, just ensure it has required fields
        Map.merge(%{
          plugins: %{},
          metadata: %{},
          plugin_states: %{},
          plugin_config: %{},
          load_order: [],
          command_registry_table: :command_registry,
          runtime_pid: nil,
          file_watching_enabled?: false,
          initialized: false,
          lifecycle_helper_module: Raxol.Core.Runtime.Plugins.LifecycleManager
        }, state)

      _ ->
        # Fallback to default state
        %{
          plugins: %{},
          metadata: %{},
          plugin_states: %{},
          plugin_config: %{},
          load_order: [],
          command_registry_table: :command_registry,
          runtime_pid: nil,
          file_watching_enabled?: false,
          initialized: false,
          lifecycle_helper_module: Raxol.Core.Runtime.Plugins.LifecycleManager
        }
    end

    # Start internal initialization
    send(self(), :__internal_initialize__)

    {:ok, state}
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
  @impl Raxol.Core.Runtime.Plugins.Manager.Behaviour
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

  @impl GenServer
  def handle_call({:load_plugin, plugin_id, config}, _from, state) do
    # Send plugin load attempted event
    send(state.runtime_pid, {:plugin_load_attempted, plugin_id})

    operation =
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

    handle_plugin_operation(operation, plugin_id, state, "load")
  end

  @impl Raxol.Core.Runtime.Plugins.Manager.Behaviour
  def load_plugin(plugin_id) do
    GenServer.call(__MODULE__, {:load_plugin, plugin_id})
  end

  @impl GenServer
  def handle_call({:load_plugin, plugin_id}, _from, state) do
    case state.lifecycle_helper_module.load_plugin(plugin_id) do
      {:ok, plugin_state} ->
        new_state = Map.put(state, plugin_id, plugin_state)
        {:reply, {:ok, plugin_state}, new_state}

      error ->
        {:reply, error, state}
    end
  end

  @impl Raxol.Core.Runtime.Plugins.Manager.Behaviour
  def unload_plugin(plugin_id) do
    GenServer.call(__MODULE__, {:unload_plugin, plugin_id})
  end

  @impl GenServer
  def handle_call({:unload_plugin, plugin_id}, _from, state) do
    case Map.get(state, plugin_id) do
      nil ->
        {:reply, {:error, :plugin_not_found}, state}

      _plugin_state ->
        case state.lifecycle_helper_module.unload_plugin(
               plugin_id,
               state.plugins,
               state.metadata,
               state.plugin_states,
               state.command_registry_table,
               state.plugin_config
             ) do
          :ok ->
            new_state = Map.delete(state, plugin_id)
            {:reply, :ok, new_state}

          {:error, _reason} ->
            {:reply, {:error, :unknown_reason}, state}
        end
    end
  end

  @impl GenServer
  def handle_call(:get_loaded_plugins, _from, state) do
    plugins = Map.keys(state)
    {:reply, plugins, state}
  end

  @impl GenServer
  def handle_call({:execute_command, command, arg1, arg2}, _from, state) do
    case execute_command(command, arg1, arg2) do
      {:ok, result} ->
        {:reply, {:ok, result}, state}

      error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:get_plugin_state, plugin_id}, _from, state) do
    case Map.get(state.plugin_states, plugin_id) do
      nil -> {:reply, {:error, :plugin_not_found}, state}
      plugin_state -> {:reply, {:ok, plugin_state}, state}
    end
  end

  @impl GenServer
  def handle_call({:initialize_plugin, plugin_name, config}, _from, state) do
    case state.lifecycle_helper_module.initialize_plugin(
           plugin_name,
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

        {:reply, {:ok, updated_state}, updated_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:plugin_loaded?, plugin_name}, _from, state) do
    is_loaded = Map.has_key?(state.plugin_states, plugin_name)
    {:reply, is_loaded, state}
  end

  @impl GenServer
  def handle_call({:call_hook, plugin_name, hook_name, args}, _from, state) do
    case Map.get(state.plugin_states, plugin_name) do
      nil ->
        {:reply, {:error, :plugin_not_found}, state}

      plugin_state ->
        case call_plugin_hook(plugin_name, hook_name, args, plugin_state) do
          {:ok, result, updated_plugin_state} ->
            updated_state = %{
              state
              | plugin_states:
                  Map.put(
                    state.plugin_states,
                    plugin_name,
                    updated_plugin_state
                  )
            }

            {:reply, {:ok, updated_state, result}, updated_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl GenServer
  def handle_call({:get_plugin_config, plugin_name}, _from, state) do
    case Map.get(state.plugin_config, plugin_name) do
      nil -> {:reply, {:error, :plugin_not_found}, state}
      config -> {:reply, {:ok, config}, state}
    end
  end

  @impl GenServer
  def handle_call({:update_plugin_config, plugin_name, config}, _from, state) do
    case validate_plugin_config_static(plugin_name, config) do
      :ok ->
        updated_state = %{
          state
          | plugin_config: Map.put(state.plugin_config, plugin_name, config)
        }

        {:reply, {:ok, updated_state}, updated_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:set_plugin_state, plugin_id, new_state}, _from, state) do
    updated_state =
      Raxol.Core.Runtime.Plugins.StateManager.set_plugin_state(
        plugin_id,
        new_state,
        state
      )

    {:reply, :ok, updated_state}
  end

  @impl GenServer
  def handle_call({:update_plugin_state, plugin_id, update_fun}, _from, state) do
    updated_state =
      Raxol.Core.Runtime.Plugins.StateManager.update_plugin_state(
        plugin_id,
        update_fun,
        state
      )

    {:reply, :ok, updated_state}
  end

  @impl GenServer
  def handle_call({:process_command, command}, _from, state) do
    case Raxol.Core.Runtime.Plugins.CommandHandler.process_command(
           command,
           state
         ) do
      {:ok, result} -> {:reply, {:ok, result}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call(:get_plugins, _from, state) do
    {:reply, state.plugins, state}
  end

  @impl GenServer
  def handle_call(:get_plugin_states, _from, state) do
    {:reply, state.plugin_states, state}
  end

  @impl GenServer
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

  @impl GenServer
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

  @impl GenServer
  def handle_call(:list_plugins, _from, state) do
    plugins = Discovery.list_plugins(state)
    {:reply, plugins, state}
  end

  @impl GenServer
  def handle_call({:get_plugin, plugin_id}, _from, state) do
    case Discovery.get_plugin(plugin_id, state) do
      {:ok, plugin} -> {:reply, {:ok, plugin}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:enable_plugin, plugin_id}, _from, state) do
    case Raxol.Core.Runtime.Plugins.LifecycleManager.enable_plugin(
           plugin_id,
           state
         ) do
      {:ok, updated_state} -> {:reply, :ok, updated_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:disable_plugin, plugin_id}, _from, state) do
    case Raxol.Core.Runtime.Plugins.LifecycleManager.disable_plugin(
           plugin_id,
           state
         ) do
      {:ok, updated_state} -> {:reply, :ok, updated_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:reload_plugin, plugin_id}, _from, state) do
    # Send plugin reload attempted event
    send(state.runtime_pid, {:plugin_reload_attempted, plugin_id})

    operation =
      state.lifecycle_helper_module.reload_plugin(
        plugin_id,
        state.plugins,
        state.metadata,
        state.plugin_states,
        state.load_order,
        state.command_registry_table,
        state.plugin_config
      )

    handle_plugin_operation(operation, plugin_id, state, "reload")
  end

  @impl GenServer
  def handle_call(:get_full_state, _from, state) do
    {:reply, state, state}
  end

  @impl GenServer
  def handle_call(unhandled_message, _from, state) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "[#{__MODULE__}] Unhandled call message: #{inspect(unhandled_message)}",
      %{}
    )

    {:reply, {:error, :unknown_call}, state}
  end

  @impl GenServer
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

  @impl GenServer
  def handle_cast({:reload_plugin_by_id, plugin_id_string}, state) do
    case PluginReloader.reload_plugin_by_id(plugin_id_string, state) do
      {:ok, updated_state} -> {:noreply, updated_state}
      {:error, _reason, current_state} -> {:noreply, current_state}
    end
  end

  @impl GenServer
  def handle_cast(:shutdown, state) do
    Raxol.Core.Runtime.Log.info_with_context(
      "[#{__MODULE__}] Received :shutdown cast for #{inspect(state.app_name)}. Stopping dependent processes..."
    )

    if state.dispatcher_pid do
      Raxol.Core.Runtime.Log.info_with_context(
        "[#{__MODULE__}] Stopping Dispatcher PID: #{inspect(state.dispatcher_pid)}"
      )

      GenServer.stop(state.dispatcher_pid, :shutdown, :infinity)
    end

    if state.plugin_manager do
      Raxol.Core.Runtime.Log.info_with_context(
        "[#{__MODULE__}] Stopping PluginManager PID: #{inspect(state.plugin_manager)}"
      )

      GenServer.stop(state.plugin_manager, :shutdown, :infinity)
    end

    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_cast({:plugin_error, _plugin_id, _reason}, state) do
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:plugin_error, _plugin_id, _reason, current_state}, _state) do
    {:noreply, current_state}
  end

  @impl GenServer
  def handle_cast(unhandled_message, state) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "[#{__MODULE__}] Unhandled cast message: #{inspect(unhandled_message)}",
      %{}
    )

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:send_clipboard_result, pid, content}, state) do
    CommandHandler.handle_clipboard_result(pid, content)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(
        {:fs, _pid, {path, _events}},
        %{file_watching_enabled?: true} = state
      ) do
    case FileWatcher.handle_file_event(path, state) do
      {:ok, updated_state} -> {:noreply, updated_state}
      {:error, _reason} -> {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info(:debounce_file_events, state) do
    case FileWatcher.handle_debounced_events(
           state.plugin_id,
           state.plugin_path,
           state
         ) do
      {:ok, updated_state} -> {:noreply, updated_state}
      {:error, _reason, updated_state} -> {:noreply, updated_state}
    end
  end

  @impl GenServer
  def handle_info({:lifecycle_event, :shutdown}, state) do
    # Gracefully unload all plugins in reverse order using LifecycleHelper
    final_state =
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

    {:noreply, %{final_state | initialized: false}}
  end

  @impl GenServer
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

  @impl GenServer
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

  @impl GenServer
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

  @impl GenServer
  def handle_info({:fs, _, _}, state) do
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({watcher_pid, true}, state) when pid?(watcher_pid) do
    Raxol.Core.Runtime.Log.info(
      "[#{__MODULE__}] Received status :true from PID: #{inspect(watcher_pid)} (likely FileWatcher)."
    )

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:file_event, path}, state) do
    operation =
      state.lifecycle_helper_module.reload_plugin_from_disk(
        state.plugin_id,
        path,
        state.plugins,
        state.metadata,
        state.plugin_states,
        state.load_order,
        state.command_registry_table,
        state.plugin_config
      )

    case operation do
      {:ok, {updated_metadata, updated_states, updated_table}} ->
        updated_state =
          update_plugin_state(
            state,
            updated_metadata,
            updated_states,
            updated_table
          )

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

  @impl GenServer
  def handle_info(:tick, state) do
    # Handle periodic updates
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:plugin_error, _plugin_id, _reason}, state) do
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:plugin_error, _plugin_id, _reason, updated_state}, _state) do
    {:noreply, updated_state}
  end

  @impl GenServer
  def terminate(reason, state) do
    Raxol.Core.Runtime.Log.info(
      "[#{__MODULE__}] Terminating (Reason: #{inspect(reason)}).",
      %{module: __MODULE__, reason: reason}
    )

    state = TimerManager.cancel_periodic_tick(state)
    {:ok, state}
  end

  def stop(pid \\ __MODULE__) do
    GenServer.stop(pid)
  end

  @doc """
  Updates a plugin's state using a function.
  """
  def update_plugin(plugin_id, update_fun) when function?(update_fun, 1) do
    GenServer.call(__MODULE__, {:update_plugin_state, plugin_id, update_fun})
  end

  @doc """
  Sets a plugin's state directly.
  """
  def set_plugin_state(plugin_id, new_state) do
    GenServer.call(__MODULE__, {:set_plugin_state, plugin_id, new_state})
  end

  @doc """
  Gets a plugin's current state.
  """
  def get_plugin_state(plugin_id) do
    GenServer.call(__MODULE__, {:get_plugin_state, plugin_id})
  end

  @doc """
  Initializes a plugin with the given configuration.
  """
  def initialize_plugin(manager_pid, plugin_name, config) do
    GenServer.call(manager_pid, {:initialize_plugin, plugin_name, config})
  end

  @doc """
  Checks if a plugin is loaded.
  """
  def plugin_loaded?(manager_pid, plugin_name) do
    GenServer.call(manager_pid, {:plugin_loaded?, plugin_name})
  end

  @doc """
  Gets the list of loaded plugins.
  """
  def get_loaded_plugins(manager_pid) do
    GenServer.call(manager_pid, :get_loaded_plugins)
  end

  @doc """
  Unloads a plugin.
  """
  def unload_plugin(manager_pid, plugin_name) do
    GenServer.call(manager_pid, {:unload_plugin, plugin_name})
  end

  @doc """
  Calls a plugin hook with the given arguments.
  """
  def call_hook(manager_pid, plugin_name, hook_name, args) do
    GenServer.call(manager_pid, {:call_hook, plugin_name, hook_name, args})
  end

  @doc """
  Gets a plugin's configuration.
  """
  def get_plugin_config(manager_pid, plugin_name) do
    GenServer.call(manager_pid, {:get_plugin_config, plugin_name})
  end

  @doc """
  Updates a plugin's configuration.
  """
  def update_plugin_config(manager_pid, plugin_name, config) do
    GenServer.call(manager_pid, {:update_plugin_config, plugin_name, config})
  end

  @doc """
  Validates a plugin's configuration.
  """
  def validate_plugin_config(plugin_name, config) do
    # This is a static validation that doesn't require the manager state
    case validate_plugin_config_static(plugin_name, config) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # Helper functions
  defp execute_command(command, arg1, arg2) do
    case command do
      :load_plugin ->
        load_plugin(arg1)

      :unload_plugin ->
        unload_plugin(arg1)

      :get_plugin ->
        get_plugin(arg1)

      :update_plugin ->
        update_plugin(arg1, arg2)

      :list_plugins ->
        list_plugins()

      :get_plugin_state ->
        get_plugin_state(arg1)

      :set_plugin_state ->
        set_plugin_state(arg1, arg2)

      _ ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "[Plugins.Manager] Unknown command: #{inspect(command)}",
          %{command: command, arg1: arg1, arg2: arg2}
        )

        {:error, :unknown_command}
    end
  end

  defp handle_plugin_operation(operation, plugin_id, state, success_message) do
    case operation do
      {:ok, {updated_metadata, updated_states, updated_table}} ->
        updated_state =
          update_plugin_state(
            state,
            updated_metadata,
            updated_states,
            updated_table
          )

        {:reply, :ok, updated_state}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Failed to #{success_message} plugin #{plugin_id}",
          nil,
          nil,
          %{module: __MODULE__, plugin_id: plugin_id, reason: reason}
        )

        {:reply, {:error, reason}, state}
    end
  end

  def handle_error(error, _context) do
    # Log the error with context
    Raxol.Core.Runtime.Log.error_with_stacktrace(
      "Application error occurred",
      error,
      nil,
      %{module: __MODULE__}
    )

    # Attempt to recover based on error type
    case error do
      %{type: :runtime_error} ->
        # For runtime errors, try to restart the affected components
        {:ok, :restart_components}

      %{type: :resource_error} ->
        # For resource errors, try to reinitialize resources
        {:ok, :reinitialize_resources}

      _ ->
        # For unknown errors, just log and continue
        {:ok, :continue}
    end
  end

  def handle_cleanup(context) do
    # Log cleanup operation
    Raxol.Core.Runtime.Log.info(
      "Performing application cleanup",
      %{module: __MODULE__, context: context}
    )

    # Clean up resources
    with :ok <- cleanup_resources(context),
         :ok <- cleanup_plugins(context),
         :ok <- cleanup_state(context) do
      {:ok, :cleanup_complete}
    else
      error ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Failed during cleanup",
          error,
          nil,
          %{module: __MODULE__, context: context}
        )

        {:error, :cleanup_failed}
    end
  end

  defp cleanup_resources(_context), do: :ok
  defp cleanup_plugins(_context), do: :ok
  defp cleanup_state(_context), do: :ok

  # Helper function to call a plugin hook
  defp call_plugin_hook(plugin_name, hook_name, args, plugin_state) do
    # This is a placeholder implementation
    # In a real implementation, this would call the actual plugin hook
    case hook_name do
      "init" ->
        {:ok, :initialized, plugin_state}

      "start" ->
        {:ok, :started, plugin_state}

      "stop" ->
        {:ok, :stopped, plugin_state}

      _ ->
        {:ok, {:hook_called, hook_name, args}, plugin_state}
    end
  end

  # Helper function to validate plugin configuration
  defp validate_plugin_config_static(plugin_name, config) when is_map(config) do
    # Basic validation - ensure config is a map and has required fields
    case config do
      %{enabled: enabled} when is_boolean(enabled) ->
        :ok

      %{} ->
        # Config is valid if it's a map, even without required fields
        :ok

      _ ->
        {:error, :invalid_config_format}
    end
  end

  defp validate_plugin_config_static(_plugin_name, _config) do
    {:error, :invalid_config_format}
  end

  # Helper functions for state updates
  defp update_plugin_state(
         state,
         updated_metadata,
         updated_states,
         updated_table
       ) do
    %{
      state
      | metadata: updated_metadata,
        plugin_states: updated_states,
        command_registry_table: updated_table
    }
  end

  @doc """
  Loads a plugin with the given name and configuration.
  """
  @spec load_plugin(String.t(), map()) :: {:ok, map()} | {:error, String.t()}
  def load_plugin(name, config) do
    # Implement plugin loading logic here
    {:ok, %{name: name, config: config}}
  end

  @doc """
  Gets all available commands from loaded plugins.
  """
  @spec get_commands(map()) :: list(map())
  def get_commands(_state) do
    # Return empty list for now - implement based on actual command registry
    []
  end

  @doc """
  Gets metadata for all loaded plugins.
  """
  @spec get_metadata(map()) :: map()
  def get_metadata(_state) do
    # Return empty map for now - implement based on actual metadata
    %{}
  end

  @doc """
  Handles a command from a plugin.
  """
  @spec handle_command(map(), atom(), any()) :: {:ok, any()} | {:error, any()}
  def handle_command(_state, _command, _args) do
    # Implement command handling logic here
    {:ok, :command_handled}
  end

  @doc """
  Handles an event from a plugin.
  """
  @spec handle_event(map(), any()) :: {:ok, map()} | {:error, any()}
  def handle_event(state, event) do
    # Delegate event handling to the lifecycle helper module
    case state.lifecycle_helper_module.handle_event(
           event,
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

        {:ok, updated_state}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Failed to handle event in plugin manager",
          nil,
          nil,
          %{module: __MODULE__, event: event, reason: reason}
        )

        {:error, reason}
    end
  end
end
