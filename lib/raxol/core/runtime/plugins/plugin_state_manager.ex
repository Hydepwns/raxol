defmodule Raxol.Core.Runtime.Plugins.PluginStateManager do
  @moduledoc """
  Handles plugin state management: updating, initializing, and cleaning up state.
  """

  alias Raxol.Core.Runtime.Plugins.StateManager

  @doc """
  Updates the state for a plugin.
  """
  def update_plugin_state(
        plugin_id,
        initial_state,
        plugins,
        metadata,
        plugin_states,
        load_order,
        plugin_config
      ) do
    StateManager.update_plugin_state(plugin_id, initial_state, %{
      plugins: plugins,
      metadata: metadata,
      plugin_states: plugin_states,
      load_order: load_order,
      plugin_config: plugin_config
    })
  end

  @doc """
  Initializes plugin state by calling the plugin's init/1.
  """
  def initialize_plugin_state(plugin_module, config) do
    plugin_module.init(config)
  end
end
