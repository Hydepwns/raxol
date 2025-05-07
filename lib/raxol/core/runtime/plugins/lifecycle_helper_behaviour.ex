defmodule Raxol.Core.Runtime.Plugins.LifecycleHelperBehaviour do
  @moduledoc """
  Defines the behaviour for the Plugin Lifecycle Helper module.

  This allows for easier mocking in tests.
  """

  # Callbacks based on usage observed in manager_test.exs

  @doc "Initializes and starts plugins based on discovery and dependencies."
  @callback initialize_plugins(
              plugin_specs :: list(map()),
              manager_pid :: pid(),
              plugin_registry :: pid() | atom(),
              command_registry_table :: atom(),
              api_version :: String.t(),
              app_config :: map(),
              env :: atom()
            ) :: {:ok, {list(map()), list(map())}} | {:error, any()}

  @doc "Reloads a specific plugin from disk."
  @callback reload_plugin_from_disk(
              plugin_id :: atom(),
              current_state :: map() | nil,
              plugin_spec :: map(),
              manager_pid :: pid(),
              plugin_registry :: pid() | atom(),
              command_registry_table :: atom(),
              api_version :: String.t(),
              loaded_plugins_paths :: list(String.t())
            ) :: {:ok, map()} | {:error, any()}

  # Add other callbacks here if the Manager interacts with more LifecycleHelper functions
end
