defmodule Raxol.Core.Runtime.Plugins.DependencyManager.Graph do
  @moduledoc """
  Handles dependency graph building and cycle detection for plugin dependencies.
  Provides functionality for building dependency graphs and analyzing dependency chains.
  """

  @doc """
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
  """
  def build_dependency_graph(plugins) do
    Enum.reduce(plugins, %{}, fn {id, metadata}, acc ->
      # Handle both Plugin structs and plain metadata maps
      deps =
        case metadata do
          %Raxol.Plugins.Plugin{} -> Map.get(metadata, :dependencies, [])
          _ -> Map.get(metadata, :dependencies, [])
        end

      dep_info =
        Enum.map(deps, fn
          {dep_id, version_req, opts} ->
            {to_atom(dep_id), version_req, opts}

          {dep_id, version_req} ->
            {to_atom(dep_id), version_req, %{optional: false}}

          dep_id ->
            {to_atom(dep_id), nil, %{optional: false}}
        end)

      Map.put(acc, to_atom(id), dep_info)
    end)
  end

  defp to_atom(id) when is_atom(id), do: id
  defp to_atom(id) when is_binary(id), do: String.to_atom(id)

  @doc """
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
  """
  def build_dependency_chain(cycle, _graph) do
    # Add the first element at the end to complete the cycle
    case cycle do
      [] -> []
      [first | _] -> cycle ++ [first]
    end
  end

  @doc """
  Gets all dependencies for a plugin, including transitive dependencies.

  ## Parameters

  * `plugin_id` - The ID of the plugin
  * `graph` - The dependency graph
  * `visited` - Set of already visited plugin IDs (for cycle detection)

  ## Returns

  * `{:ok, deps}` - List of all dependencies
  * `{:error, :circular_dependency, cycle}` - If a circular dependency is detected
  """
  def get_all_dependencies(plugin_id, graph, visited \\ MapSet.new()) do
    # Normalize plugin_id to atom
    normalized_plugin_id = to_atom(plugin_id)

    case MapSet.member?(visited, normalized_plugin_id) do
      true ->
        {:error, :circular_dependency, [normalized_plugin_id]}
      false ->
        visited = MapSet.put(visited, normalized_plugin_id)
        deps = Map.get(graph, normalized_plugin_id, [])

        Enum.reduce_while(
          deps,
          {:ok, []},
          &process_dependency(&1, &2, graph, visited)
        )
        |> case do
        {:ok, deps} -> {:ok, Enum.uniq(deps)}
        error -> error
      end
    end
  end

  defp process_dependency({dep_id, _, _}, {:ok, acc}, graph, visited) do
    # Ensure dep_id is an atom
    normalized_dep_id = to_atom(dep_id)

    case get_all_dependencies(normalized_dep_id, graph, visited) do
      {:ok, dep_deps} ->
        {:cont, {:ok, [normalized_dep_id | acc] ++ dep_deps}}

      {:error, :circular_dependency, cycle} ->
        {:halt, {:error, :circular_dependency, [normalized_dep_id | cycle]}}
    end
  end
end
