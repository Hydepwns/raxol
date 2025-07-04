defmodule Raxol.Core.Runtime.Plugins.Registry do
  @moduledoc """
  Plugin registry using GenServer for state management.
  Manages information about loaded plugins and their metadata.
  """

  use GenServer
  require Raxol.Core.Runtime.Log
  import Raxol.Guards

  # Public API

  @doc """
  Starts the plugin registry GenServer.
  """
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Registers a plugin with its metadata.
  """
  @spec register_plugin(atom(), map()) :: :ok
  def register_plugin(plugin_id, metadata)
      when atom?(plugin_id) and map?(metadata) do
    GenServer.call(__MODULE__, {:register_plugin, plugin_id, metadata})
  end

  @doc """
  Unregisters a plugin by its ID.
  """
  @spec unregister_plugin(atom()) :: :ok
  def unregister_plugin(plugin_id) when atom?(plugin_id) do
    GenServer.call(__MODULE__, {:unregister_plugin, plugin_id})
  end

  @doc """
  Lists all registered plugins as {plugin_id, metadata} tuples.
  """
  @spec list_plugins() :: list({atom(), map()})
  def list_plugins do
    GenServer.call(__MODULE__, :list_plugins)
  end

  # Backward compatibility for list_plugins/1 (deprecated)
  @doc false
  def list_plugins(_registry_state) do
    Raxol.Core.Runtime.Log.debug(
      "[#{__MODULE__}] list_plugins/1 called (deprecated, using GenServer state)."
    )

    list_plugins()
  end

  # GenServer Callbacks

  @impl GenServer
  def init(state) do
    Raxol.Core.Runtime.Log.debug("[#{__MODULE__}] Registry GenServer started.")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:register_plugin, plugin_id, metadata}, _from, state) do
    Raxol.Core.Runtime.Log.info(
      "[#{__MODULE__}] Registering plugin: #{inspect(plugin_id)}"
    )

    {:reply, :ok, Map.put(state, plugin_id, metadata)}
  end

  @impl GenServer
  def handle_call({:unregister_plugin, plugin_id}, _from, state) do
    Raxol.Core.Runtime.Log.info(
      "[#{__MODULE__}] Unregistering plugin: #{inspect(plugin_id)}"
    )

    {:reply, :ok, Map.delete(state, plugin_id)}
  end

  @impl GenServer
  def handle_call(:list_plugins, _from, state) do
    plugins = Enum.map(state, fn {id, meta} -> {id, meta} end)
    {:reply, plugins, state}
  end
end
