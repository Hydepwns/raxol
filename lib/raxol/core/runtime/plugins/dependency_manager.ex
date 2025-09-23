defmodule Raxol.Core.Runtime.Plugins.DependencyManager do
  @moduledoc """
  Manages plugin dependencies, ensuring that plugins are loaded in the correct
  order and that their dependencies are met.

  This module is the primary interface for dependency management, and it is
  composed of several smaller modules, each with a specific responsibility:

  - `DependencyManager.Core`: Core dependency checking and load order resolution
  - `DependencyManager.Version`: Version parsing and constraint checking
  - `DependencyManager.Graph`: Dependency graph building and analysis
  - `DependencyManager.Resolver`: Load order resolution using Tarjan's algorithm

  For more detailed documentation about the module's architecture and internals,
  see `docs/dependency_manager.md`.
  """

  alias Raxol.Core.Runtime.Plugins.DependencyManager.Core
  alias Raxol.Core.Runtime.Plugins.DependencyManager.Graph
  alias Raxol.Core.Runtime.Plugins.DependencyManager.Resolver
  alias Raxol.Core.Runtime.Plugins.DependencyManager.Version, as: DepVersion

  @type version_constraint :: String.t()
  @type dependency :: {String.t(), version_constraint()} | String.t()
  @type dependency_chain :: [String.t()]
  @type dependency_error ::
          {:error, :missing_dependencies, [String.t()], dependency_chain()}
          | {:error, :version_mismatch,
             [{String.t(), String.t(), version_constraint()}],
             dependency_chain()}
          | {:error, :circular_dependency, [String.t()], dependency_chain()}

  @doc """
  Checks if a plugin's dependencies are met by the currently loaded plugins.

  ## Parameters

  * `plugin_id` - The ID of the plugin to check
  * `plugin_metadata` - The plugin's metadata containing its dependencies
  * `loaded_plugins` - Map of currently loaded plugins
  * `dependency_chain` - List of plugin IDs in the current dependency chain (for error reporting)

  ## Returns

  * `:ok` - If all dependencies are satisfied
  * `{:error, :missing_dependencies, missing, chain}` - If any dependencies are missing
  * `{:error, :version_mismatch, mismatches, chain}` - If any dependencies have incompatible versions
  * `{:error, :circular_dependency, cycle, chain}` - If a circular dependency is detected

  ## Examples

      iex> DependencyManager.check_dependencies("my_plugin", %{dependencies: [{"other_plugin", ">= 1.0.0"}]}, %{"other_plugin" => %{version: "1.1.0"}}, [])
      :ok

      iex> DependencyManager.check_dependencies("my_plugin", %{dependencies: [{"missing_plugin", ">= 1.0.0"}]}, %{}, [])
      {:error, :missing_dependencies, ["missing_plugin"], ["my_plugin"]}

      iex> DependencyManager.check_dependencies("my_plugin", %{dependencies: [{"other_plugin", ">= 2.0.0"}]}, %{"other_plugin" => %{version: "1.0.0"}}, [])
      {:error, :version_mismatch, [{"other_plugin", "1.0.0", ">= 2.0.0"}], ["my_plugin"]}
  """
  def check_dependencies(
        plugin_id,
        plugin_metadata,
        loaded_plugins,
        dependency_chain \\ []
      ) do
    dependencies = Map.get(plugin_metadata, :dependencies, [])
    Core.check_dependencies(
      plugin_id,
      dependencies,
      loaded_plugins,
      dependency_chain
    )
  end

  @doc """
  Resolves the load order for a list of plugins.
  """
  def resolve_load_order(plugins) do
    plugins
    |> Graph.build_dependency_graph()
    |> Resolver.tarjan_sort()
  end

  @doc """
  Checks if a version meets a version requirement.
  """
  def satisfies_version?(installed_version, version_req) do
    case DepVersion.check_version(installed_version, version_req) do
      :ok -> true
      _ -> false
    end
  end
end
