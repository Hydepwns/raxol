defmodule Raxol.Plugins.Manager do
  @moduledoc """
  Plugin manager for Raxol.
  Handles plugin lifecycle, registration, and state management.
  """

  use Raxol.Core.Behaviours.BaseManager
  require Raxol.Core.Runtime.Log

  # Client API

  @doc """
  List all registered plugins.
  """
  def list_plugins do
    GenServer.call(__MODULE__, :list_plugins)
  end

  @doc """
  Get the state of a specific plugin.
  """
  def get_plugin_state(plugin_id) do
    GenServer.call(__MODULE__, {:get_plugin_state, plugin_id})
  end

  @doc """
  Register a new plugin.
  """
  def register_plugin(plugin) do
    GenServer.call(__MODULE__, {:register_plugin, plugin})
  end

  @doc """
  Unregister a plugin.
  """
  def unregister_plugin(plugin_id) do
    GenServer.call(__MODULE__, {:unregister_plugin, plugin_id})
  end

  # BaseManager Implementation

  @impl true
  def init_manager(_opts) do
    state = %{
      plugins: %{},
      enabled: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_manager_call(:list_plugins, _from, state) do
    plugins = Map.keys(state.plugins)
    {:reply, plugins, state}
  end

  def handle_manager_call({:get_plugin_state, plugin_id}, _from, state) do
    case Map.get(state.plugins, plugin_id) do
      nil -> {:reply, {:error, :not_found}, state}
      plugin -> {:reply, {:ok, plugin}, state}
    end
  end

  def handle_manager_call({:register_plugin, plugin}, _from, state) do
    plugin_id = Map.get(plugin, :id) || Map.get(plugin, "id")
    updated_plugins = Map.put(state.plugins, plugin_id, plugin)
    updated_state = %{state | plugins: updated_plugins}
    {:reply, :ok, updated_state}
  end

  def handle_manager_call({:unregister_plugin, plugin_id}, _from, state) do
    updated_plugins = Map.delete(state.plugins, plugin_id)
    updated_enabled = Map.delete(state.enabled, plugin_id)

    updated_state = %{
      state
      | plugins: updated_plugins,
        enabled: updated_enabled
    }

    {:reply, :ok, updated_state}
  end
end
