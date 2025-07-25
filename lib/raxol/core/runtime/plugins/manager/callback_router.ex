defmodule Raxol.Core.Runtime.Plugins.Manager.CallbackRouter do
  @moduledoc """
  Routes GenServer callbacks to appropriate operation modules.
  Centralizes callback handling and delegates to specialized modules.
  """

  alias Raxol.Core.Runtime.Plugins.Manager.{
    LifecycleOperations,
    StateOperations,
    ConfigOperations,
    CommandOperations
  }

  @type state :: map()

  @doc """
  Routes handle_call callbacks to appropriate operation modules.
  """
  @spec route_call(tuple(), pid(), state()) :: {:reply, any(), state()}
  
  # Lifecycle operations
  def route_call({:load_plugin, plugin_id, config}, _from, state) do
    LifecycleOperations.handle_load_plugin(plugin_id, config, state)
  end

  def route_call({:load_plugin, plugin_id}, _from, state) do
    LifecycleOperations.handle_load_plugin(plugin_id, state)
  end

  def route_call({:unload_plugin, plugin_id}, _from, state) do
    LifecycleOperations.handle_unload_plugin(plugin_id, state)
  end

  def route_call({:enable_plugin, plugin_id}, _from, state) do
    LifecycleOperations.handle_enable_plugin(plugin_id, state)
  end

  def route_call({:disable_plugin, plugin_id}, _from, state) do
    LifecycleOperations.handle_disable_plugin(plugin_id, state)
  end

  def route_call({:reload_plugin, plugin_id}, _from, state) do
    LifecycleOperations.handle_reload_plugin(plugin_id, state)
  end

  def route_call({:load_plugin_by_module, module, config}, _from, state) do
    LifecycleOperations.handle_load_plugin_by_module(module, config, state)
  end

  # State operations
  def route_call(:get_loaded_plugins, _from, state) do
    StateOperations.handle_get_loaded_plugins(state)
  end

  def route_call({:get_plugin_state, plugin_id}, _from, state) do
    StateOperations.handle_get_plugin_state(plugin_id, state)
  end

  def route_call({:set_plugin_state, plugin_id, new_state}, _from, state) do
    StateOperations.handle_set_plugin_state(plugin_id, new_state, state)
  end

  def route_call({:update_plugin_state, plugin_id, update_fun}, _from, state) do
    StateOperations.handle_update_plugin_state(plugin_id, update_fun, state)
  end

  def route_call(:get_plugins, _from, state) do
    StateOperations.handle_get_plugins(state)
  end

  def route_call(:get_plugin_states, _from, state) do
    StateOperations.handle_get_plugin_states(state)
  end

  def route_call(:list_plugins, _from, state) do
    StateOperations.handle_list_plugins(state)
  end

  def route_call({:get_plugin, plugin_id}, _from, state) do
    StateOperations.handle_get_plugin(plugin_id, state)
  end

  def route_call({:plugin_loaded?, plugin_id}, _from, state) do
    StateOperations.handle_plugin_loaded?(plugin_id, state)
  end

  def route_call(:get_full_state, _from, state) do
    StateOperations.handle_get_full_state(state)
  end

  # Configuration operations
  def route_call({:get_plugin_config, plugin_id}, _from, state) do
    ConfigOperations.handle_get_plugin_config(plugin_id, state)
  end

  def route_call({:update_plugin_config, plugin_id, config}, _from, state) do
    ConfigOperations.handle_update_plugin_config(plugin_id, config, state)
  end

  def route_call({:initialize_plugin, plugin_id, config}, _from, state) do
    ConfigOperations.handle_initialize_plugin(plugin_id, config, state)
  end

  def route_call({:init, config}, _from, state) do
    ConfigOperations.handle_init_with_config(config, state)
  end

  def route_call(:initialize, _from, state) do
    ConfigOperations.handle_initialize(state)
  end

  # Command operations
  def route_call({:execute_command, command, arg1, arg2}, _from, state) do
    CommandOperations.handle_execute_command(command, arg1, arg2, state)
  end

  def route_call({:process_command, command}, _from, state) do
    CommandOperations.handle_process_command(command, state)
  end

  def route_call({:call_hook, plugin_id, hook_name, args}, _from, state) do
    CommandOperations.handle_call_hook(plugin_id, hook_name, args, state)
  end

  # Fallback for unhandled messages
  def route_call(unhandled_message, _from, state) do
    require Logger
    Logger.warning("Unhandled message in PluginManager: #{inspect(unhandled_message)}")
    {:reply, {:error, {:unhandled_message, unhandled_message}}, state}
  end
end