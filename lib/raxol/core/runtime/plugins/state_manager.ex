defmodule Raxol.Core.Runtime.Plugins.StateManager do
  @moduledoc """
  Manages plugin state and state transitions.
  """

  require Raxol.Core.Runtime.Log
  alias Raxol.Core.Runtime.Plugins.State

  @doc """
  Updates the plugin state maps with a new plugin.

  ## Parameters

  * `plugin_id` - The ID of the plugin
  * `plugin_module` - The plugin's module
  * `plugin_metadata` - The plugin's metadata
  * `plugin_state` - The plugin's initial state
  * `config` - The plugin's configuration
  * `state_maps` - Map containing all state maps (plugins, metadata, states, load_order, config)

  ## Returns

  * Updated state maps

  ## Examples

      iex> StateManager.update_state_maps("my_plugin", MyPlugin, %{version: "1.0.0"}, %{initialized: true}, %{setting: "value"}, %{
        plugins: %{},
        metadata: %{},
        plugin_states: %{},
        load_order: [],
        plugin_config: %{}
      })
      %{
        plugins: %{"my_plugin" => MyPlugin},
        metadata: %{"my_plugin" => %{version: "1.0.0"}},
        plugin_states: %{"my_plugin" => %{initialized: true}},
        load_order: ["my_plugin"],
        plugin_config: %{"my_plugin" => %{setting: "value"}}
      }
  """
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

  @doc """
  Removes a plugin from the state maps.

  ## Parameters

  * `plugin_id` - The ID of the plugin to remove
  * `state_maps` - Map containing all state maps

  ## Returns

  * Updated state maps

  ## Examples

      iex> StateManager.remove_plugin("my_plugin", %{
        plugins: %{"my_plugin" => MyPlugin},
        metadata: %{"my_plugin" => %{version: "1.0.0"}},
        plugin_states: %{"my_plugin" => %{initialized: true}},
        load_order: ["my_plugin"],
        plugin_config: %{"my_plugin" => %{setting: "value"}}
      })
      %{
        plugins: %{},
        metadata: %{},
        plugin_states: %{},
        load_order: [],
        plugin_config: %{}
      }
  """
  def remove_plugin(plugin_id, state_maps) do
    %{
      plugins: Map.delete(state_maps.plugins, plugin_id),
      metadata: Map.delete(state_maps.metadata, plugin_id),
      plugin_states: Map.delete(state_maps.plugin_states, plugin_id),
      load_order: Enum.reject(state_maps.load_order, &(&1 == plugin_id)),
      plugin_config: Map.delete(state_maps.plugin_config, plugin_id)
    }
  end

  @doc """
  Updates a plugin's state.

  ## Parameters

  * `plugin_id` - The ID of the plugin
  * `new_state` - The new state to set
  * `state_maps` - Map containing all state maps

  ## Returns

  * Updated state maps

  ## Examples

      iex> StateManager.update_plugin_state("my_plugin", %{updated: true}, %{
        plugins: %{"my_plugin" => MyPlugin},
        metadata: %{"my_plugin" => %{version: "1.0.0"}},
        plugin_states: %{"my_plugin" => %{initialized: true}},
        load_order: ["my_plugin"],
        plugin_config: %{"my_plugin" => %{setting: "value"}}
      })
      %{
        plugins: %{"my_plugin" => MyPlugin},
        metadata: %{"my_plugin" => %{version: "1.0.0"}},
        plugin_states: %{"my_plugin" => %{updated: true}},
        load_order: ["my_plugin"],
        plugin_config: %{"my_plugin" => %{setting: "value"}}
      }
  """
  def update_plugin_state(plugin_id, new_state, state_maps) do
    %{
      state_maps
      | plugin_states: Map.put(state_maps.plugin_states, plugin_id, new_state)
    }
  end

  @doc """
  Gets a plugin's state.

  ## Parameters

  * `plugin_id` - The ID of the plugin
  * `state_maps` - Map containing all state maps

  ## Returns

  * The plugin's state, or nil if not found

  ## Examples

      iex> StateManager.get_plugin_state("my_plugin", %{
        plugin_states: %{"my_plugin" => %{initialized: true}}
      })
      %{initialized: true}
  """
  def get_plugin_state(plugin_id, state_maps) do
    Map.get(state_maps.plugin_states, plugin_id)
  end

  @doc """
  Gets a plugin's module.

  ## Parameters

  * `plugin_id` - The ID of the plugin
  * `state_maps` - Map containing all state maps

  ## Returns

  * The plugin's module, or nil if not found

  ## Examples

      iex> StateManager.get_plugin_module("my_plugin", %{
        plugins: %{"my_plugin" => MyPlugin}
      })
      MyPlugin
  """
  def get_plugin_module(plugin_id, state_maps) do
    Map.get(state_maps.plugins, plugin_id)
  end

  @doc """
  Gets a plugin's metadata.

  ## Parameters

  * `plugin_id` - The ID of the plugin
  * `state_maps` - Map containing all state maps

  ## Returns

  * The plugin's metadata, or nil if not found

  ## Examples

      iex> StateManager.get_plugin_metadata("my_plugin", %{
        metadata: %{"my_plugin" => %{version: "1.0.0"}}
      })
      %{version: "1.0.0"}
  """
  def get_plugin_metadata(plugin_id, state_maps) do
    Map.get(state_maps.metadata, plugin_id)
  end

  @doc """
  Gets a plugin's configuration.

  ## Parameters

  * `plugin_id` - The ID of the plugin
  * `state_maps` - Map containing all state maps

  ## Returns

  * The plugin's configuration, or nil if not found

  ## Examples

      iex> StateManager.get_plugin_config("my_plugin", %{
        plugin_config: %{"my_plugin" => %{setting: "value"}}
      })
      %{setting: "value"}
  """
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
      initialized: false
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
