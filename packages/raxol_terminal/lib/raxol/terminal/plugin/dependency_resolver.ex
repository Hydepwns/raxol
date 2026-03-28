defmodule Raxol.Terminal.Plugin.DependencyResolver do
  @moduledoc """
  Handles plugin dependency resolution for the terminal emulator.
  This module extracts the plugin dependency resolution logic from the main emulator.
  """

  @doc """
  Resolves plugin dependencies and returns the load order.
  """
  @spec resolve_plugin_dependencies(map()) :: [String.t()]
  def resolve_plugin_dependencies(plugin_manager) do
    # Extract plugin dependencies
    plugins = Map.get(plugin_manager, :plugins, [])
    dependencies = extract_plugin_dependencies(plugins)

    # Perform topological sort
    case topological_sort(dependencies) do
      {:ok, sorted_plugins} ->
        sorted_plugins

      {:error, _reason} ->
        # If there are circular dependencies, return plugins in original order
        Enum.map(plugins, & &1.name)
    end
  end

  @doc """
  Extracts dependencies from a list of plugins.
  """
  @spec extract_plugin_dependencies([map()]) :: map()
  def extract_plugin_dependencies(plugins) do
    Enum.map(plugins, fn plugin ->
      {plugin.name, Map.get(plugin, :dependencies, [])}
    end)
    |> Map.new()
  end

  @doc """
  Performs topological sorting on plugin dependencies.
  """
  @spec topological_sort(map()) :: {:ok, [String.t()]} | {:error, atom()}
  def topological_sort(dependencies) do
    # Kahn's algorithm for topological sorting
    nodes = Map.keys(dependencies)
    in_degree = calculate_in_degree(dependencies, nodes)

    # Find nodes with no incoming edges
    queue = Enum.filter(nodes, fn node -> Map.get(in_degree, node, 0) == 0 end)

    case topological_sort_helper(dependencies, in_degree, queue, []) do
      sorted when length(sorted) == length(nodes) -> {:ok, sorted}
      _ -> {:error, :circular_dependency}
    end
  end

  @doc """
  Calculates the in-degree for each node in the dependency graph.
  """
  @spec calculate_in_degree(map(), [String.t()]) :: map()
  def calculate_in_degree(dependencies, nodes) do
    Enum.reduce(nodes, %{}, fn node, acc ->
      in_degree =
        Enum.count(dependencies, fn {_name, deps} ->
          Enum.member?(deps, node)
        end)

      Map.put(acc, node, in_degree)
    end)
  end

  @doc """
  Helper function for topological sorting using Kahn's algorithm.
  """
  @spec topological_sort_helper(map(), map(), [String.t()], [String.t()]) :: [
          String.t()
        ]
  def topological_sort_helper(_dependencies, _in_degree, [], result) do
    result
  end

  def topological_sort_helper(dependencies, in_degree, [node | queue], result) do
    # Remove node and its outgoing edges
    new_in_degree =
      Enum.reduce(dependencies[node] || [], in_degree, fn dep, acc ->
        Map.update(acc, dep, 0, &(&1 - 1))
      end)

    # Add nodes with no incoming edges to queue
    new_queue =
      queue ++
        Enum.filter(dependencies[node] || [], fn dep ->
          Map.get(new_in_degree, dep, 0) == 0
        end)

    topological_sort_helper(dependencies, new_in_degree, new_queue, [
      node | result
    ])
  end
end
