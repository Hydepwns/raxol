defmodule Raxol.Core.Runtime.Plugins.Manager do
  @moduledoc """
  Manages the loading, initialization, and lifecycle of plugins in the Raxol runtime.

  This module is responsible for:
  - Discovering available plugins
  - Loading and initializing plugins
  - Managing plugin lifecycle events
  - Providing access to loaded plugins
  - Handling plugin dependencies and conflicts
  """

  alias Raxol.Core.Runtime.Events.Dispatcher
  alias Raxol.Core.Runtime.Lifecycle

  @type plugin_id :: String.t()
  @type plugin_metadata :: map()
  @type plugin_state :: map()

  @plugins_directory "plugins"

  # State stored in the process
  defmodule State do
    @moduledoc false
    defstruct [
      plugins: %{}, # Map of plugin_id to plugin instance
      metadata: %{}, # Map of plugin_id to plugin metadata
      plugin_states: %{}, # Map of plugin_id to plugin state
      load_order: [], # List of plugin_ids in the order they were loaded
      initialized: false # Whether the plugin system has been initialized
    ]
  end

  use GenServer

  @doc """
  Starts the plugin manager process.
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

  # GenServer callbacks

  @impl true
  def init(_opts) do
    # Subscribe to lifecycle events
    Lifecycle.subscribe(:shutdown, __MODULE__)

    {:ok, %State{}}
  end

  @impl true
  def handle_call(:initialize, _from, %State{initialized: true} = state) do
    {:reply, {:error, :already_initialized}, state}
  end

  @impl true
  def handle_call(:initialize, _from, state) do
    # 1. Discover plugins
    plugins_with_metadata = discover_plugins()

    # 2. Sort plugins by dependencies
    sorted_plugins = sort_plugins_by_dependencies(plugins_with_metadata)

    # 3. Load plugins in order
    {loaded_plugins, plugin_states} = load_plugins(sorted_plugins)

    # 4. Store plugin information
    new_state = %State{
      state |
      plugins: loaded_plugins,
      metadata: Map.new(plugins_with_metadata, fn {id, metadata, _module} -> {id, metadata} end),
      plugin_states: plugin_states,
      load_order: Enum.map(sorted_plugins, fn {id, _, _} -> id end),
      initialized: true
    }

    # 5. Broadcast plugin system initialized event
    Dispatcher.broadcast(:plugin_system_initialized, %{plugins: Map.keys(loaded_plugins)})

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:list_plugins, _from, state) do
    result = Enum.map(state.load_order, fn plugin_id ->
      %{
        id: plugin_id,
        metadata: Map.get(state.metadata, plugin_id, %{}),
        enabled: plugin_enabled?(plugin_id, state)
      }
    end)

    {:reply, result, state}
  end

  @impl true
  def handle_call({:get_plugin, plugin_id}, _from, state) do
    case Map.fetch(state.plugins, plugin_id) do
      {:ok, plugin} ->
        plugin_data = %{
          plugin: plugin,
          metadata: Map.get(state.metadata, plugin_id, %{}),
          state: Map.get(state.plugin_states, plugin_id, %{}),
          enabled: plugin_enabled?(plugin_id, state)
        }
        {:reply, {:ok, plugin_data}, state}
      :error ->
        {:reply, {:error, :plugin_not_found}, state}
    end
  end

  @impl true
  def handle_call({:enable_plugin, plugin_id}, _from, state) do
    with {:ok, plugin} <- Map.fetch(state.plugins, plugin_id),
         plugin_state <- Map.get(state.plugin_states, plugin_id, %{}),
         {:ok, new_plugin_state} <- apply(plugin, :enable, [plugin_state]) do

      # Update plugin state and broadcast event
      new_states = Map.put(state.plugin_states, plugin_id, new_plugin_state)
      Dispatcher.broadcast(:plugin_enabled, %{plugin_id: plugin_id})

      {:reply, :ok, %{state | plugin_states: new_states}}
    else
      :error -> {:reply, {:error, :plugin_not_found}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:disable_plugin, plugin_id}, _from, state) do
    with {:ok, plugin} <- Map.fetch(state.plugins, plugin_id),
         plugin_state <- Map.get(state.plugin_states, plugin_id, %{}),
         {:ok, new_plugin_state} <- apply(plugin, :disable, [plugin_state]) do

      # Update plugin state and broadcast event
      new_states = Map.put(state.plugin_states, plugin_id, new_plugin_state)
      Dispatcher.broadcast(:plugin_disabled, %{plugin_id: plugin_id})

      {:reply, :ok, %{state | plugin_states: new_states}}
    else
      :error -> {:reply, {:error, :plugin_not_found}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:reload_plugin, plugin_id}, _from, state) do
    # First unload
    state = case unload_plugin(plugin_id, state) do
      {:ok, new_state} -> new_state
      {:error, _} -> state
    end

    # Then reload from disk
    case reload_plugin_from_disk(plugin_id, state) do
      {:ok, plugin, metadata, plugin_state} ->
        new_state = %{state |
          plugins: Map.put(state.plugins, plugin_id, plugin),
          metadata: Map.put(state.metadata, plugin_id, metadata),
          plugin_states: Map.put(state.plugin_states, plugin_id, plugin_state)
        }
        Dispatcher.broadcast(:plugin_reloaded, %{plugin_id: plugin_id})
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info({:lifecycle_event, :shutdown}, state) do
    # Gracefully unload all plugins in reverse order
    Enum.reduce(Enum.reverse(state.load_order), state, fn plugin_id, acc_state ->
      case unload_plugin(plugin_id, acc_state) do
        {:ok, new_state} -> new_state
        {:error, _} -> acc_state
      end
    end)

    {:noreply, %{state | initialized: false}}
  end

  # Private functions

  defp discover_plugins do
    # In a real implementation, this would scan the plugins directory
    # and load plugin metadata from manifest files

    # For now, return an empty list as a placeholder
    []
  end

  defp sort_plugins_by_dependencies(plugins) do
    # In a real implementation, this would perform a topological sort
    # based on plugin dependencies
    plugins
  end

  defp load_plugins(sorted_plugins) do
    # In a real implementation, this would load each plugin module
    # and initialize its state
    {%{}, %{}}
  end

  defp unload_plugin(plugin_id, state) do
    with {:ok, plugin} <- Map.fetch(state.plugins, plugin_id),
         plugin_state <- Map.get(state.plugin_states, plugin_id, %{}) do

      # Call plugin's unload callback
      _ = apply(plugin, :unload, [plugin_state])

      # Remove plugin from state
      new_state = %{state |
        plugins: Map.delete(state.plugins, plugin_id),
        metadata: Map.delete(state.metadata, plugin_id),
        plugin_states: Map.delete(state.plugin_states, plugin_id)
      }

      Dispatcher.broadcast(:plugin_unloaded, %{plugin_id: plugin_id})
      {:ok, new_state}
    else
      :error -> {:error, :plugin_not_found}
    end
  end

  defp reload_plugin_from_disk(plugin_id, _state) do
    # In a real implementation, this would read the plugin from disk
    # and load it again
    {:error, :not_implemented}
  end

  defp plugin_enabled?(plugin_id, state) do
    case Map.fetch(state.plugin_states, plugin_id) do
      {:ok, %{enabled: enabled}} -> enabled
      _ -> false
    end
  end
end
