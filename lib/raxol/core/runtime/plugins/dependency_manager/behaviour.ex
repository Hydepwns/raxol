defmodule Raxol.Core.Runtime.Plugins.DependencyManager.Behaviour do
  @moduledoc """
  Behaviour for plugin dependency management.

  Defines the callbacks that dependency manager implementations must provide
  for checking, validating, and resolving plugin dependencies.
  """

  @type version_constraint :: String.t()
  @type dependency :: {String.t(), version_constraint()} | String.t()
  @type dependency_chain :: [String.t()]
  @type plugin_metadata :: map()
  @type loaded_plugins :: map()

  @type dependency_error ::
          {:error, :missing_dependencies, [String.t()], dependency_chain()}
          | {:error, :version_mismatch,
             [{String.t(), String.t(), version_constraint()}],
             dependency_chain()}
          | {:error, :circular_dependency, [String.t()], dependency_chain()}

  @doc """
  Checks if a plugin's dependencies are satisfied.

  ## Parameters
  - plugin_id: The ID of the plugin to check
  - dependencies: List of dependencies to check
  - loaded_plugins: Currently loaded plugins
  - dependency_chain: Chain of dependencies (for circular dependency detection)

  ## Returns
  - :ok if dependencies are satisfied
  - {:error, reason, details, chain} if dependencies are not satisfied
  """
  @callback check_dependencies(
              plugin_id :: String.t(),
              dependencies :: [dependency()],
              loaded_plugins :: loaded_plugins(),
              dependency_chain :: dependency_chain()
            ) :: :ok | dependency_error()

  @doc """
  Resolves the load order for plugins based on dependencies.

  ## Parameters
  - plugin_metadata: Metadata for all plugins including their dependencies
  - loaded_plugins: Currently loaded plugins

  ## Returns
  - {:ok, load_order} where load_order is a list of plugin IDs in dependency order
  - {:error, reason} if dependencies cannot be resolved
  """
  @callback resolve_dependencies(
              plugin_metadata :: plugin_metadata(),
              loaded_plugins :: loaded_plugins()
            ) :: {:ok, [String.t()]} | {:error, term()}

  @doc """
  Validates a list of dependencies for format and constraints.

  ## Parameters
  - dependencies: List of dependencies to validate

  ## Returns
  - :ok if all dependencies are valid
  - {:error, invalid_dependencies} if any dependencies are invalid
  """
  @callback validate_dependencies(dependencies :: [dependency()]) ::
              :ok | {:error, [String.t()]}

  @doc """
  Checks for circular dependencies in a plugin's dependency chain.

  ## Parameters
  - plugin_id: The ID of the plugin to check
  - dependencies: List of dependencies for the plugin
  - loaded_plugins: Currently loaded plugins (used for dependency resolution)

  ## Returns
  - :ok if no circular dependencies detected
  - {:error, :circular_dependency, cycle, chain} if circular dependency found
  """
  @callback check_circular_dependencies(
              plugin_id :: String.t(),
              dependencies :: [dependency()],
              loaded_plugins :: loaded_plugins()
            ) ::
              :ok
              | {:error, :circular_dependency, [String.t()], dependency_chain()}
end
