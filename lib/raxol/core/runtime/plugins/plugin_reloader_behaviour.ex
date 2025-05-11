defmodule Raxol.Core.Runtime.Plugins.PluginReloader.Behaviour do
  @moduledoc """
  Defines the behaviour for plugin reloading functionality.

  This behaviour is responsible for:
  - Reloading plugins from disk
  - Managing plugin reload state
  - Handling plugin reload errors
  - Coordinating plugin reload lifecycle
  """

  @doc """
  Reloads a plugin from disk.
  """
  @callback reload_plugin_from_disk(
    plugin_id :: String.t(),
    plugin_module :: module(),
    plugin_state :: map(),
    plugins :: map(),
    metadata :: map(),
    plugin_states :: map(),
    load_order :: list(),
    command_table :: atom()
  ) :: {:ok, map()} | {:error, any()}

  @doc """
  Checks if a plugin can be reloaded.
  """
  @callback can_reload?(
    plugin_id :: String.t(),
    plugins :: map(),
    metadata :: map()
  ) :: boolean()

  @doc """
  Gets the reload state of a plugin.
  """
  @callback get_reload_state(
    plugin_id :: String.t(),
    plugins :: map(),
    metadata :: map()
  ) :: {:ok, map()} | {:error, any()}

  @doc """
  Handles plugin reload errors.
  """
  @callback handle_reload_error(
    plugin_id :: String.t(),
    error :: any(),
    plugins :: map(),
    metadata :: map(),
    plugin_states :: map()
  ) :: {:ok, map()} | {:error, any()}

  @doc """
  Coordinates the plugin reload lifecycle.
  """
  @callback coordinate_reload(
    plugin_id :: String.t(),
    plugins :: map(),
    metadata :: map(),
    plugin_states :: map(),
    load_order :: list(),
    command_table :: atom()
  ) :: {:ok, map()} | {:error, any()}
end
