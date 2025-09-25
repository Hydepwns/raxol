defmodule Raxol.Core.Runtime.Plugins.PluginManager do
  @moduledoc """
  Manages the loading, initialization, and lifecycle of plugins in the Raxol runtime.

  This module has been refactored to delegate operations to specialized modules:
  - Lifecycle operations (load, enable, disable, reload)
  - State management (get/set plugin states and configs)
  - Event handling (GenServer callbacks)
  - Utility functions (error handling, cleanup)
  """

  @type t :: %{
          plugins: map(),
          state: term(),
          config: map()
        }
  @type plugin_id :: String.t()
  @type plugin_metadata :: map()
  @type plugin_state :: map()

  use GenServer

  # Note: PluginManager.Behaviour does not exist, removing the behaviour declaration

  require Raxol.Core.Runtime.Log

  # Removed unused aliases for non-existent modules
  # (Previously: Lifecycle, EventHandler, Utility)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def start_link(_app, opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(arg) do
    state =
      case arg do
        opts when is_list(opts) ->
          opts_map = Enum.into(opts, %{})

          %{
            plugins: %{},
            metadata: %{},
            plugin_states: %{},
            plugin_config: Map.get(opts_map, :plugin_config, %{}),
            load_order: [],
            command_registry_table:
              Map.get(opts_map, :command_registry_table, :command_registry),
            runtime_pid: Map.get(opts_map, :runtime_pid),
            file_watching_enabled?:
              Map.get(opts_map, :enable_plugin_reloading, false),
            initialized: false,
            tick_timer: nil,
            file_event_timer: nil,
            file_watcher_pid: nil,
            plugin_dirs: Map.get(opts_map, :plugin_dirs, []),
            plugins_dir: Map.get(opts_map, :plugins_dir, nil)
          }

        state when is_map(state) ->
          Map.merge(
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
              tick_timer: nil,
              file_event_timer: nil,
              file_watcher_pid: nil,
              plugin_dirs: [],
              plugins_dir: nil
            },
            state
          )

        _ ->
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
            tick_timer: nil,
            file_event_timer: nil,
            file_watcher_pid: nil,
            plugin_dirs: [],
            plugins_dir: nil
          }
      end

    Process.send_after(self(), :__internal_initialize__, 100)
    {:ok, state}
  end

  def initialize do
    GenServer.call(__MODULE__, :initialize)
  end

  def initialize_with_config(config) do
    GenServer.call(__MODULE__, {:initialize_with_config, config})
  end

  def list_plugins do
    GenServer.call(__MODULE__, :list_plugins)
  end

  def get_plugin(plugin_id) do
    GenServer.call(__MODULE__, {:get_plugin, plugin_id})
  end

  def enable_plugin(plugin_id) do
    GenServer.cast(__MODULE__, {:enable_plugin, plugin_id})
  end

  def disable_plugin(plugin_id) do
    GenServer.cast(__MODULE__, {:disable_plugin, plugin_id})
  end

  def reload_plugin(plugin_id) do
    GenServer.cast(__MODULE__, {:reload_plugin, plugin_id})
  end

  def load_plugin_by_module(module, config \\ %{}) do
    GenServer.call(__MODULE__, {:load_plugin_by_module, module, config})
  end

  def load_plugin(plugin_id) do
    GenServer.call(__MODULE__, {:load_plugin, plugin_id})
  end

  def unload_plugin(plugin_id) do
    GenServer.cast(__MODULE__, {:unload_plugin, plugin_id})
  end

  @impl GenServer
  def handle_call({:load_plugin, plugin_module}, _from, state) do
    case Raxol.Core.Runtime.Plugins.SafeLifecycleOperations.safe_load_plugin(plugin_module, %{}, state) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:unload_plugin, plugin_name}, _from, state) do
    case Raxol.Core.Runtime.Plugins.SafeLifecycleOperations.safe_unload_plugin(plugin_name, state) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:get_plugin, plugin_name}, _from, state) do
    plugin = Map.get(state.plugins, plugin_name)
    {:reply, plugin, state}
  end

  def handle_call(:initialize, _from, state) do
    new_state = Map.put(state, :initialized, true)
    {:reply, :ok, new_state}
  end

  def handle_call({:initialize_with_config, config}, _from, state) do
    new_state =
      state
      |> Map.put(:initialized, true)
      |> Map.put(:plugin_config, config)
    {:reply, :ok, new_state}
  end

  def handle_call(:list_plugins, _from, state) do
    plugins = Map.values(state.plugins)
    {:reply, plugins, state}
  end

  def handle_call({:load_plugin_by_module, module, config}, _from, state) do
    case Raxol.Core.Runtime.Plugins.SafeLifecycleOperations.safe_load_plugin(module, config, state) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:get_plugin_state, plugin_id}, _from, state) do
    plugin_state = Map.get(state.plugin_states, plugin_id)
    {:reply, plugin_state, state}
  end

  def handle_call({:update_plugin, plugin_id, update_fun}, _from, state) do
    case Map.get(state.plugins, plugin_id) do
      nil -> {:reply, {:error, :plugin_not_found}, state}
      plugin ->
        updated_plugin = update_fun.(plugin)
        new_plugins = Map.put(state.plugins, plugin_id, updated_plugin)
        new_state = Map.put(state, :plugins, new_plugins)
        {:reply, :ok, new_state}
    end
  end

  def handle_call({:initialize_plugin, plugin_name, config}, _from, state) do
    case Map.get(state.plugins, plugin_name) do
      nil -> {:reply, {:error, :plugin_not_found}, state}
      _plugin ->
        new_plugin_states = Map.put(state.plugin_states, plugin_name, :initialized)
        new_plugin_config = Map.put(state.plugin_config, plugin_name, config)
        new_state =
          state
          |> Map.put(:plugin_states, new_plugin_states)
          |> Map.put(:plugin_config, new_plugin_config)
        {:reply, :ok, new_state}
    end
  end

  def handle_call({:plugin_loaded?, plugin_name}, _from, state) do
    loaded = Map.has_key?(state.plugins, plugin_name)
    {:reply, loaded, state}
  end

  def handle_call({:get_loaded_plugins}, _from, state) do
    plugin_names = Map.keys(state.plugins)
    {:reply, plugin_names, state}
  end

  def handle_call({:call_hook, plugin_name, hook_name, args}, _from, state) do
    case Map.get(state.plugins, plugin_name) do
      nil -> {:reply, {:error, :plugin_not_found}, state}
      plugin ->
        # Basic hook call implementation - just return success for now
        {:reply, {:ok, args}, state}
    end
  end

  def handle_call({:get_plugin_config, plugin_name}, _from, state) do
    config = Map.get(state.plugin_config, plugin_name, %{})
    {:reply, config, state}
  end

  def handle_call(_message, _from, state) do
    {:reply, {:error, :unknown_command}, state}
  end

  @impl GenServer
  def handle_cast({:reload_plugin, plugin_name}, state) do
    case Raxol.Core.Runtime.Plugins.SafeLifecycleOperations.safe_reload_plugin(plugin_name, state) do
      {:ok, new_state} -> {:noreply, new_state}
      {:error, _reason} -> {:noreply, state}
    end
  end

  def handle_cast({:enable_plugin, plugin_id}, state) do
    case Map.get(state.plugins, plugin_id) do
      nil -> {:noreply, state}
      plugin ->
        updated_plugin = Map.put(plugin, :enabled, true)
        new_plugins = Map.put(state.plugins, plugin_id, updated_plugin)
        new_state = Map.put(state, :plugins, new_plugins)
        {:noreply, new_state}
    end
  end

  def handle_cast({:disable_plugin, plugin_id}, state) do
    case Map.get(state.plugins, plugin_id) do
      nil -> {:noreply, state}
      plugin ->
        updated_plugin = Map.put(plugin, :enabled, false)
        new_plugins = Map.put(state.plugins, plugin_id, updated_plugin)
        new_state = Map.put(state, :plugins, new_plugins)
        {:noreply, new_state}
    end
  end

  def handle_cast({:unload_plugin, plugin_name}, state) do
    case Raxol.Core.Runtime.Plugins.SafeLifecycleOperations.safe_unload_plugin(plugin_name, state) do
      {:ok, new_state} -> {:noreply, new_state}
      {:error, _reason} -> {:noreply, state}
    end
  end

  def handle_cast({:set_plugin_state, plugin_id, new_plugin_state}, state) do
    new_plugin_states = Map.put(state.plugin_states, plugin_id, new_plugin_state)
    new_state = Map.put(state, :plugin_states, new_plugin_states)
    {:noreply, new_state}
  end

  def handle_cast({:update_plugin_config, plugin_name, config}, state) do
    new_plugin_config = Map.put(state.plugin_config, plugin_name, config)
    new_state = Map.put(state, :plugin_config, new_plugin_config)
    {:noreply, new_state}
  end

  def handle_cast(_message, state) do
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:plugin_event, event}, state) do
    # Process plugin events
    new_state = process_plugin_event(event, state)
    {:noreply, new_state}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  defp process_plugin_event(_event, state), do: state

  @impl GenServer
  def terminate(reason, state) when is_map(state) do
    Raxol.Core.Runtime.Log.info(
      "Plugin manager terminating",
      %{module: __MODULE__, reason: reason}
    )

    case Map.get(state, :file_watcher_pid) do
      nil -> :ok
      pid when is_pid(pid) -> Process.exit(pid, :shutdown)
    end

    _ =
      case Map.get(state, :tick_timer) do
        nil -> :ok
        timer_ref -> _ = Process.cancel_timer(timer_ref)
      end

    :ok
  end

  def terminate(reason, state) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Plugin manager terminating with invalid state",
      %{module: __MODULE__, reason: reason, state: inspect(state)}
    )

    :ok
  end

  def stop(pid \\ __MODULE__) do
    GenServer.stop(pid)
  end

  def update_plugin(plugin_id, update_fun) when is_function(update_fun, 1) do
    GenServer.call(__MODULE__, {:update_plugin, plugin_id, update_fun})
  end

  def set_plugin_state(plugin_id, new_state) do
    GenServer.cast(__MODULE__, {:set_plugin_state, plugin_id, new_state})
  end

  def get_plugin_state(plugin_id) do
    GenServer.call(__MODULE__, {:get_plugin_state, plugin_id})
  end

  def initialize_plugin(manager_pid, plugin_name, config) do
    GenServer.call(manager_pid, {:initialize_plugin, plugin_name, config})
  end

  def plugin_loaded?(manager_pid, plugin_name) do
    GenServer.call(manager_pid, {:plugin_loaded?, plugin_name})
  end

  def get_loaded_plugins(manager_pid) do
    GenServer.call(manager_pid, {:get_loaded_plugins})
  end

  def unload_plugin(manager_pid, plugin_name) do
    GenServer.cast(manager_pid, {:unload_plugin, plugin_name})
  end

  def call_hook(manager_pid, plugin_name, hook_name, args) do
    GenServer.call(manager_pid, {:call_hook, plugin_name, hook_name, args})
  end

  def get_plugin_config(manager_pid, plugin_name) do
    GenServer.call(manager_pid, {:get_plugin_config, plugin_name})
  end

  def update_plugin_config(manager_pid, plugin_name, config) do
    GenServer.cast(manager_pid, {:update_plugin_config, plugin_name, config})
  end

  def validate_plugin_config(_plugin_name, config) do
    # Basic validation - ensure config is a map
    if is_map(config) do
      {:ok, config}
    else
      {:error, :invalid_config}
    end
  end

  # Legacy compatibility functions (stubs)
  def handle_error(error, context) do
    Raxol.Core.Runtime.Log.error("Plugin error", error: error, context: context)
    {:error, error}
  end

  def handle_cleanup(_context) do
    :ok
  end

  def load_plugin(name, _config) do
    load_plugin(name)
  end

  def handle_event(state, _event) do
    state
  end

  def get_commands(_state) do
    %{}
  end

  def get_metadata(_state) do
    %{}
  end

  def handle_command(_state, _command, _args) do
    {:error, :not_implemented}
  end
end
