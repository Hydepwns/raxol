defmodule Raxol.Core.Runtime.Plugins.Registry do
  @moduledoc """
  Plugin registry using GenServer for state management.

  @deprecated "Use Raxol.Core.GlobalRegistry with :plugins type instead"

  This module has been consolidated into the global registry system.
  For new code, use:

      # Instead of Registry.register_plugin(id, metadata)
      Raxol.Core.GlobalRegistry.register(:plugins, id, metadata)

      # Instead of Registry.list_plugins()
      Raxol.Core.GlobalRegistry.list(:plugins)
  """

  use Raxol.Core.Behaviours.BaseManager

  require Raxol.Core.Runtime.Log


  # Public API

  @doc """
  Registers a plugin with its metadata.
  """
  @deprecated "Use Raxol.Core.GlobalRegistry.register(:plugins, plugin_id, metadata) instead"
  @spec register_plugin(atom(), map()) :: :ok
  def register_plugin(plugin_id, metadata)
      when is_atom(plugin_id) and is_map(metadata) do
    Raxol.Core.GlobalRegistry.register(:plugins, plugin_id, metadata)
  end

  @doc """
  Unregisters a plugin by its ID.
  """
  @deprecated "Use Raxol.Core.GlobalRegistry.unregister(:plugins, plugin_id) instead"
  @spec unregister_plugin(atom()) :: :ok
  def unregister_plugin(plugin_id) when is_atom(plugin_id) do
    Raxol.Core.GlobalRegistry.unregister(:plugins, plugin_id)
  end

  @doc """
  Lists all registered plugins as {plugin_id, metadata} tuples.
  """
  @deprecated "Use Raxol.Core.GlobalRegistry.list(:plugins) instead"
  @spec list_plugins() :: list({atom(), map()})
  def list_plugins do
    case Raxol.Core.GlobalRegistry.list(:plugins) do
      plugins when is_list(plugins) ->
        Enum.map(plugins, fn plugin_data ->
          {plugin_data.id, plugin_data}
        end)

      _ ->
        []
    end
  end

  # GenServer Callbacks

  @impl true
  def init_manager(state) do
    Raxol.Core.Runtime.Log.debug("[#{__MODULE__}] Registry GenServer started.")
    {:ok, state}
  end

  @impl true
  def handle_manager_call({:register_plugin, plugin_id, metadata}, _from, state) do
    Raxol.Core.Runtime.Log.info(
      "[#{__MODULE__}] Registering plugin: #{inspect(plugin_id)}"
    )

    {:reply, :ok, Map.put(state, plugin_id, metadata)}
  end

  @impl true
  def handle_manager_call({:unregister_plugin, plugin_id}, _from, state) do
    Raxol.Core.Runtime.Log.info(
      "[#{__MODULE__}] Unregistering plugin: #{inspect(plugin_id)}"
    )

    {:reply, :ok, Map.delete(state, plugin_id)}
  end

  @impl true
  def handle_manager_call(:list_plugins, _from, state) do
    plugins = Enum.map(state, fn {id, meta} -> {id, meta} end)
    {:reply, plugins, state}
  end
end
