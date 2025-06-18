defmodule Raxol.Core.Runtime.Plugins.DependencyManager.Behaviour do
  @moduledoc '''
  Defines the behaviour for plugin dependency management.

  This behaviour is responsible for:
  - Checking plugin dependencies
  - Resolving dependency conflicts
  - Managing dependency versions
  - Handling circular dependencies
  '''

  @doc '''
  Checks if a plugin's dependencies are satisfied.
  '''
  @callback check_dependencies(
              plugin_id :: String.t(),
              plugin_metadata :: map(),
              loaded_plugins :: map()
            ) :: :ok | {:error, any()}

  @doc '''
  Resolves dependencies between plugins.
  '''
  @callback resolve_dependencies(
              plugin_metadata :: map(),
              loaded_plugins :: map()
            ) :: {:ok, list(String.t())} | {:error, any()}

  @doc '''
  Validates a plugin's dependency specifications.
  '''
  @callback validate_dependencies(dependencies :: list({atom(), String.t()})) ::
              :ok | {:error, any()}

  @doc '''
  Checks for circular dependencies in the plugin graph.
  '''
  @callback check_circular_dependencies(
              plugin_id :: String.t(),
              dependencies :: list({atom(), String.t()}),
              loaded_plugins :: map()
            ) :: :ok | {:error, any()}
end
