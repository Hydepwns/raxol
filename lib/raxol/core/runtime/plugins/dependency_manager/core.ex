defmodule Raxol.Core.Runtime.Plugins.DependencyManager.Core do
  @moduledoc """
  Core module for managing plugin dependencies and dependency resolution.
  Provides the main public API for dependency checking and load order resolution.
  """

  require Logger

  alias Raxol.Core.Runtime.Plugins.DependencyManager.{
    Version,
    Graph,
    Resolver
  }

  @type version_constraint :: String.t()
  @type dependency :: {String.t(), version_constraint()} | String.t()
  @type dependency_chain :: [String.t()]
  @type dependency_error ::
    {:error, :missing_dependencies, [String.t()], dependency_chain()} |
    {:error, :version_mismatch, [{String.t(), String.t(), version_constraint()}], dependency_chain()} |
    {:error, :circular_dependency, [String.t()], dependency_chain()}

  @doc """
  Checks if a plugin's dependencies are satisfied.

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
  """
  def check_dependencies(plugin_id, plugin_metadata, loaded_plugins, dependency_chain \\ []) do
    # Get dependencies from metadata, defaulting to empty list
    dependencies = Map.get(plugin_metadata, :dependencies, [])
    current_chain = [plugin_id | dependency_chain]

    # Check each dependency with improved error handling
    {missing, version_mismatches, optional_missing} =
      Enum.reduce(dependencies, {[], [], []}, fn
        # Handle tuple format {plugin_id, version_req, opts}
        {dep_id, version_req, %{optional: true}}, {missing_acc, mismatch_acc, opt_missing_acc} ->
          case Map.get(loaded_plugins, dep_id) do
            nil ->
              {missing_acc, mismatch_acc, [dep_id | opt_missing_acc]}

            %{version: version} ->
              case Version.check_version(version, version_req) do
                :ok -> {missing_acc, mismatch_acc, opt_missing_acc}
                {:error, reason} -> {missing_acc, [{dep_id, version, version_req, reason} | mismatch_acc], opt_missing_acc}
              end

            _ ->
              {missing_acc, mismatch_acc, [dep_id | opt_missing_acc]}
          end

        # Handle tuple format {plugin_id, version_req}
        {dep_id, version_req}, {missing_acc, mismatch_acc, opt_missing_acc} ->
          case Map.get(loaded_plugins, dep_id) do
            nil ->
              {[dep_id | missing_acc], mismatch_acc, opt_missing_acc}

            %{version: version} ->
              case Version.check_version(version, version_req) do
                :ok -> {missing_acc, mismatch_acc, opt_missing_acc}
                {:error, reason} -> {missing_acc, [{dep_id, version, version_req, reason} | mismatch_acc], opt_missing_acc}
              end

            _ ->
              {[dep_id | missing_acc], mismatch_acc, opt_missing_acc}
          end

        # Handle simple plugin_id
        dep_id, {missing_acc, mismatch_acc, opt_missing_acc} when is_binary(dep_id) ->
          if Map.has_key?(loaded_plugins, dep_id) do
            {missing_acc, mismatch_acc, opt_missing_acc}
          else
            {[dep_id | missing_acc], mismatch_acc, opt_missing_acc}
          end
      end)

    # Log optional missing dependencies
    if Enum.any?(optional_missing) do
      Logger.info("Optional dependencies not found for plugin #{plugin_id}: #{inspect(optional_missing)}")
    end

    cond do
      Enum.any?(missing) ->
        {:error, :missing_dependencies, missing, current_chain}

      Enum.any?(version_mismatches) ->
        {:error, :version_mismatch, Enum.map(version_mismatches, fn {id, v, req, _} -> {id, v, req} end), current_chain}

      true ->
        :ok
    end
  end

  @doc """
  Resolves the load order for a set of plugins based on their dependencies.
  Uses Tarjan's algorithm for efficient cycle detection and component identification.

  ## Parameters

  * `plugins` - Map of plugin metadata, keyed by plugin ID

  ## Returns

  * `{:ok, load_order}` - List of plugin IDs in the correct load order
  * `{:error, :circular_dependency, cycle, chain}` - If a circular dependency is detected
  """
  def resolve_load_order(plugins) do
    # Build dependency graph with version information
    graph = Graph.build_dependency_graph(plugins)

    # Use Tarjan's algorithm for cycle detection and topological sort
    case Resolver.tarjan_sort(graph) do
      {:ok, order} -> {:ok, order}
      {:error, cycle} -> {:error, :circular_dependency, cycle, Graph.build_dependency_chain(cycle, graph)}
    end
  end
end
