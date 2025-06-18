defmodule Raxol.Core.Runtime.Plugins.StateManager do
  @moduledoc """
  Manages plugin state and state transitions.
  """

  @behaviour Raxol.Core.Runtime.Plugins.StateManager.Behaviour

  require Raxol.Core.Runtime.Log
  alias Raxol.Core.Runtime.Plugins.State

  @impl true
  def update_state_maps(
        plugin_id,
        plugin_module,
        plugin_metadata,
        plugin_state,
        config,
        state_maps
      ) do
    %{
      plugins: Map.put(state_maps.plugins, plugin_id, plugin_module),
      metadata: Map.put(state_maps.metadata, plugin_id, plugin_metadata),
      plugin_states: Map.put(state_maps.plugin_states, plugin_id, plugin_state),
      load_order: state_maps.load_order ++ [plugin_id],
      plugin_config: Map.put(state_maps.plugin_config, plugin_id, config)
    }
  end

  @impl true
  def remove_plugin(plugin_id, state_maps) do
    %{
      plugins: Map.delete(state_maps.plugins, plugin_id),
      metadata: Map.delete(state_maps.metadata, plugin_id),
      plugin_states: Map.delete(state_maps.plugin_states, plugin_id),
      load_order: Enum.reject(state_maps.load_order, &(&1 == plugin_id)),
      plugin_config: Map.delete(state_maps.plugin_config, plugin_id)
    }
  end

  @impl true
  def update_plugin_state(plugin_id, new_state, state_maps) do
    %{
      state_maps
      | plugin_states: Map.put(state_maps.plugin_states, plugin_id, new_state)
    }
  end

  @impl true
  def get_plugin_state(plugin_id, state_maps) do
    Map.get(state_maps.plugin_states, plugin_id)
  end

  @impl true
  def get_plugin_module(plugin_id, state_maps) do
    Map.get(state_maps.plugins, plugin_id)
  end

  @impl true
  def get_plugin_metadata(plugin_id, state_maps) do
    Map.get(state_maps.metadata, plugin_id)
  end

  @impl true
  def get_plugin_config(plugin_id, state_maps) do
    Map.get(state_maps.plugin_config, plugin_id)
  end

  @doc """
  Returns a new default plugin manager state struct.
  """
  def new do
    %State{
      plugins: %{},
      metadata: %{},
      plugin_states: %{},
      load_order: [],
      command_registry_table: %{},
      plugin_config: %{},
      initialized: false,
      plugins_dir: "priv/plugins"
    }
  end

  @doc """
  Sets the state for a given plugin.
  Alias for update_plugin_state/3.
  """
  def set_plugin_state(plugin_id, new_state, state_maps) do
    update_plugin_state(plugin_id, new_state, state_maps)
  end

  @doc """
  Initializes the plugin state. Returns {:ok, state}.
  """
  def initialize(state), do: {:ok, state}
end
