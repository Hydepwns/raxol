defmodule Raxol.Core.Runtime.Plugins.Manager do
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
  @behaviour Raxol.Core.Runtime.Plugins.Manager.Behaviour

  require Raxol.Core.Runtime.Log

  # Delegated operation modules
  alias Raxol.Core.Runtime.Plugins.Manager.{
    Lifecycle,
    EventHandlers,
    Utility
  }

  @impl true
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

  @impl true
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

  @impl true
  def load_plugin(plugin_id) do
    GenServer.call(__MODULE__, {:load_plugin, plugin_id})
  end

  @impl true
  def unload_plugin(plugin_id) do
    GenServer.cast(__MODULE__, {:unload_plugin, plugin_id})
  end

  @impl GenServer
  defdelegate handle_call(message, from, state), to: EventHandlers

  @impl GenServer
  defdelegate handle_cast(message, state), to: EventHandlers

  @impl GenServer
  defdelegate handle_info(message, state), to: EventHandlers

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

    case Map.get(state, :tick_timer) do
      nil -> :ok
      timer_ref -> Process.cancel_timer(timer_ref)
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

  def validate_plugin_config(plugin_name, config) do
    Lifecycle.validate_plugin_config(plugin_name, config)
  end

  # Legacy compatibility functions
  defdelegate handle_error(error, context), to: Utility
  defdelegate handle_cleanup(context), to: Utility
  defdelegate load_plugin(name, config), to: Utility
  defdelegate handle_event(state, event), to: Utility

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
