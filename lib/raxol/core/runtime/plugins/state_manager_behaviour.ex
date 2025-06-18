defmodule Raxol.Core.Runtime.Plugins.StateManager.Behaviour do
  @moduledoc """
  Defines the behaviour for plugin state management.

  This behaviour is responsible for:
  - Managing plugin state transitions
  - Updating plugin state maps
  - Retrieving plugin state information
  - Handling plugin state lifecycle
  """

  @doc """
  Updates the plugin state maps with a new plugin.
  """
  @callback update_state_maps(
              plugin_id :: String.t(),
              plugin_module :: module(),
              plugin_metadata :: map(),
              plugin_state :: map(),
              config :: map(),
              state_maps :: map()
            ) :: map()

  @doc """
  Removes a plugin from the state maps.
  """
  @callback remove_plugin(
              plugin_id :: String.t(),
              state_maps :: map()
            ) :: map()

  @doc """
  Updates a plugin's state.
  """
  @callback update_plugin_state(
              plugin_id :: String.t(),
              new_state :: map(),
              state_maps :: map()
            ) :: map()

  @doc """
  Gets a plugin's state.
  """
  @callback get_plugin_state(
              plugin_id :: String.t(),
              state_maps :: map()
            ) :: map() | nil

  @doc """
  Gets a plugin's module.
  """
  @callback get_plugin_module(
              plugin_id :: String.t(),
              state_maps :: map()
            ) :: module() | nil

  @doc """
  Gets a plugin's metadata.
  """
  @callback get_plugin_metadata(
              plugin_id :: String.t(),
              state_maps :: map()
            ) :: map() | nil

  @doc """
  Gets a plugin's configuration.
  """
  @callback get_plugin_config(
              plugin_id :: String.t(),
              state_maps :: map()
            ) :: map() | nil
end
