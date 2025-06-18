defmodule Raxol.Core.Runtime.Plugins.DependencyManager.Graph do
  @moduledoc '''
  Handles dependency graph building and cycle detection for plugin dependencies.
  Provides functionality for building dependency graphs and analyzing dependency chains.
  '''

  @doc '''
  Builds a dependency graph from plugin metadata.

  ## Parameters

  * `plugins` - Map of plugin metadata, keyed by plugin ID

  ## Returns

  * A map representing the dependency graph, where each key is a plugin ID and the value
    is a list of tuples containing dependency information: `{dep_id, version_req, opts}`

  ## Example

      iex> Graph.build_dependency_graph(%{
        "plugin_a" => %{dependencies: [{"plugin_b", ">= 1.0.0"}]},
        "plugin_b" => %{dependencies: []}
      })
      %{
        "plugin_a" => [{"plugin_b", ">= 1.0.0", %{optional: false}}],
        "plugin_b" => []
      }
  '''
  def build_dependency_graph(plugins) do
    Enum.reduce(plugins, %{}, fn {id, metadata}, acc ->
      deps = Map.get(metadata, :dependencies, [])

      dep_info =
        Enum.map(deps, fn
          {dep_id, version_req, opts} -> {dep_id, version_req, opts}
          {dep_id, version_req} -> {dep_id, version_req, %{optional: false}}
          dep_id -> {dep_id, nil, %{optional: false}}
        end)

      Map.put(acc, id, dep_info)
    end)
  end

  @doc '''
  Builds a dependency chain for error reporting.

  ## Parameters

  * `cycle` - List of plugin IDs forming a cycle
  * `graph` - The dependency graph

  ## Returns

  * A list of plugin IDs representing the dependency chain

  ## Example

      iex> Graph.build_dependency_chain(["plugin_a", "plugin_b"], %{
        "plugin_a" => [{"plugin_b", ">= 1.0.0", %{optional: false}}],
        "plugin_b" => [{"plugin_a", ">= 1.0.0", %{optional: false}}]
      })
      ["plugin_a", "plugin_b", "plugin_a"]
  '''
  def build_dependency_chain(cycle, _graph) do
    # Add the first element again to complete the cycle
    cycle ++ [List.first(cycle)]
  end

  @doc '''
  Gets all dependencies for a plugin, including transitive dependencies.

  ## Parameters

  * `plugin_id` - The ID of the plugin
  * `graph` - The dependency graph
  * `visited` - Set of already visited plugin IDs (for cycle detection)

  ## Returns

  * `{:ok, deps}` - List of all dependencies
  * `{:error, :circular_dependency, cycle}` - If a circular dependency is detected
  '''
  def get_all_dependencies(plugin_id, graph, visited \\ MapSet.new()) do
    if MapSet.member?(visited, plugin_id) do
      {:error, :circular_dependency, [plugin_id]}
    else
      visited = MapSet.put(visited, plugin_id)
      deps = Map.get(graph, plugin_id, [])

      Enum.reduce_while(deps, {:ok, []}, fn {dep_id, _, _}, {:ok, acc} ->
        case get_all_dependencies(dep_id, graph, visited) do
          {:ok, dep_deps} ->
            {:cont, {:ok, [dep_id | acc] ++ dep_deps}}

          {:error, :circular_dependency, cycle} ->
            {:halt, {:error, :circular_dependency, [plugin_id | cycle]}}
        end
      end)
      |> case do
        {:ok, deps} -> {:ok, Enum.uniq(deps)}
        error -> error
      end
    end
  end
end
