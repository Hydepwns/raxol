defmodule Raxol.Core.Runtime.Plugins.LifecycleHelper.Behaviour do
  @moduledoc '''
  Defines the behaviour for plugin lifecycle management.

  This behaviour is responsible for:
  - Loading and unloading plugins
  - Managing plugin dependencies
  - Handling plugin state transitions
  - Coordinating plugin lifecycle events
  '''

  @doc '''
  Loads a plugin by its ID or module.
  '''
  @callback load_plugin(
              plugin_id_or_module :: String.t() | module(),
              config :: map(),
              plugins :: map(),
              metadata :: map(),
              plugin_states :: map(),
              load_order :: list(),
              command_table :: atom(),
              plugin_config :: map()
            ) :: {:ok, map()} | {:error, any()}

  @doc '''
  Unloads a plugin by its ID.
  '''
  @callback unload_plugin(
              plugin_id :: String.t(),
              plugins :: map(),
              metadata :: map(),
              plugin_states :: map(),
              load_order :: list(),
              command_table :: atom()
            ) :: {:ok, map()} | {:error, any()}

  @doc '''
  Reloads a plugin by its ID.
  '''
  @callback reload_plugin(
              plugin_id :: String.t(),
              plugins :: map(),
              metadata :: map(),
              plugin_states :: map(),
              load_order :: list(),
              command_table :: atom(),
              plugin_config :: map()
            ) :: {:ok, map()} | {:error, any()}

  @doc '''
  Initializes plugins based on discovery and dependencies.
  '''
  @callback initialize_plugins(
              plugin_specs :: list(map()),
              manager_pid :: pid(),
              plugin_registry :: pid() | atom(),
              command_registry_table :: atom(),
              api_version :: String.t(),
              app_config :: map(),
              env :: atom()
            ) :: {:ok, {list(map()), list(map())}} | {:error, any()}

  @doc '''
  Reloads a specific plugin from disk.
  '''
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

  @doc 'Loads a plugin by its module name when the module is already known.'
  @callback load_plugin_by_module(
              plugin_module :: atom(),
              config :: map(),
              plugins :: map(),
              metadata :: map(),
              plugin_states :: map(),
              load_order :: list(),
              command_table :: atom(),
              plugin_config :: map()
            ) :: {:ok, map()} | {:error, any()}

  @doc '''
  Initializes a plugin with the given module and options.
  '''
  @callback init_plugin(module :: module(), opts :: map()) ::
              {:ok, map()} | {:error, any()}

  @doc '''
  Terminates a plugin with the given plugin_id, state, and reason.
  '''
  @callback terminate_plugin(
              plugin_id :: any(),
              state :: map(),
              reason :: any()
            ) :: :ok | {:error, any()}

  @doc '''
  Cleans up a plugin with the given plugin_id and state.
  '''
  @callback cleanup_plugin(plugin_id :: any(), state :: map()) ::
              :ok | {:error, any()}

  @doc '''
  Handles a state transition for a plugin.
  '''
  @callback handle_state_transition(
              plugin_id :: any(),
              transition :: any(),
              state :: map()
            ) :: {:ok, map()} | {:error, any()}

  # Add other callbacks here if the Manager interacts with more LifecycleHelper functions
end
