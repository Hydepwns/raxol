defmodule Raxol.Core.Runtime.Plugins.Registry do
  @moduledoc """
  Plugin registry using GenServer for state management.

  @deprecated "Use Raxol.Core.UnifiedRegistry with :plugins type instead"

  This module has been consolidated into the unified registry system.
  For new code, use:

      # Instead of Registry.register_plugin(id, metadata)
      UnifiedRegistry.register(:plugins, id, metadata)
      
      # Instead of Registry.list_plugins()
      UnifiedRegistry.list(:plugins)
  """

  use GenServer
  require Raxol.Core.Runtime.Log

  alias Raxol.Core.UnifiedRegistry

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
  @deprecated "Use UnifiedRegistry.register(:plugins, plugin_id, metadata) instead"
  @spec register_plugin(atom(), map()) :: :ok
  def register_plugin(plugin_id, metadata)
      when is_atom(plugin_id) and is_map(metadata) do
    UnifiedRegistry.register(:plugins, plugin_id, metadata)
  end

  @doc """
  Unregisters a plugin by its ID.
  """
  @deprecated "Use UnifiedRegistry.unregister(:plugins, plugin_id) instead"
  @spec unregister_plugin(atom()) :: :ok
  def unregister_plugin(plugin_id) when is_atom(plugin_id) do
    UnifiedRegistry.unregister(:plugins, plugin_id)
  end

  @doc """
  Lists all registered plugins as {plugin_id, metadata} tuples.
  """
  @deprecated "Use UnifiedRegistry.list(:plugins) instead"
  @spec list_plugins() :: list({atom(), map()})
  def list_plugins do
    case UnifiedRegistry.list(:plugins) do
      plugins when is_list(plugins) ->
        Enum.map(plugins, fn plugin_data ->
          {plugin_data.id, plugin_data}
        end)

      _ ->
        []
    end
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
