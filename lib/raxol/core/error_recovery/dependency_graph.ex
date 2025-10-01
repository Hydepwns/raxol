defmodule Raxol.Core.ErrorRecovery.DependencyGraph do
  @moduledoc """
  Manages dependency relationships between components for intelligent recovery.

  This module builds and maintains a dependency graph that helps determine
  the optimal order for restarting components and implementing cascading
  failure prevention strategies.

  ## Features

  - Dependency relationship mapping
  - Restart order optimization
  - Circular dependency detection
  - Fallback strategy configuration
  - Critical path analysis

  ## Usage

      # Build dependency graph from child specs
      graph = DependencyGraph.build([
        {DatabaseWorker, []},
        {CacheWorker, [depends_on: [:database_worker]]},
        {APIWorker, [depends_on: [:cache_worker, :database_worker]]}
      ])

      # Get restart order for a component
      restart_order = DependencyGraph.get_restart_order(graph, :api_worker)
  """

  alias Raxol.Core.Runtime.Log

  defstruct [
    :nodes,
    :edges,
    :fallback_strategies,
    :critical_paths,
    :restart_strategies
  ]

  @type node_id :: atom() | term()
  @type dependency_graph :: %__MODULE__{}

  @type node_info :: %{
          id: node_id(),
          module: module(),
          priority: integer(),
          critical: boolean(),
          fallback_strategy: fallback_strategy()
        }

  @type fallback_strategy ::
          :disable
          | {:fallback_module, module()}
          | {:notification, String.t()}
          | :graceful_degradation

  @type restart_strategy ::
          :wait_for_dependencies
          | :restart_with_dependencies
          | :independent
          | :graceful_degradation

  # Public API

  @doc """
  Build a dependency graph from child specifications.
  """
  def build(children_specs) do
    {nodes, edges} = parse_children_specs(children_specs)

    graph = %__MODULE__{
      nodes: nodes,
      edges: edges,
      fallback_strategies: extract_fallback_strategies(children_specs),
      critical_paths: [],
      restart_strategies: extract_restart_strategies(children_specs)
    }

    # Validate and enhance the graph
    graph
    |> validate_graph()
    |> calculate_critical_paths()
    |> optimize_restart_order()
  end

  @doc """
  Get the dependencies for a given node.
  """
  def get_dependencies(graph, node_id) do
    Map.get(graph.edges, node_id, [])
  end

  @doc """
  Get the dependents (nodes that depend on this one) for a given node.
  """
  def get_dependents(graph, node_id) do
    graph.edges
    |> Enum.filter(fn {_dependent, dependencies} ->
      node_id in dependencies
    end)
    |> Enum.map(fn {dependent, _} -> dependent end)
  end

  @doc """
  Get the optimal restart order for a given node and its dependencies.
  """
  def get_restart_order(graph, node_id) do
    calculate_restart_order(graph, node_id, [])
  end

  @doc """
  Get the fallback strategy for a node.
  """
  def get_fallback_strategy(graph, node_id) do
    Map.get(graph.fallback_strategies, node_id, :disable)
  end

  @doc """
  Get the restart strategy for a node.
  """
  def get_restart_strategy(graph, node_id) do
    Map.get(graph.restart_strategies, node_id, :independent)
  end

  @doc """
  Check if a node is on a critical path.
  """
  def is_critical?(graph, node_id) do
    node_id in graph.critical_paths
  end

  @doc """
  Get all nodes that would be affected by the failure of a given node.
  """
  def get_affected_nodes(graph, failed_node_id) do
    get_affected_nodes_recursive(graph, failed_node_id, MapSet.new())
    |> MapSet.to_list()
  end

  @doc """
  Determine if restarting a node would cause cascading restarts.
  """
  def would_cascade?(graph, node_id) do
    dependents = get_dependents(graph, node_id)
    length(dependents) > 0
  end

  @doc """
  Get performance impact estimate for restarting a node.
  """
  def get_restart_impact(graph, node_id) do
    affected_nodes = get_affected_nodes(graph, node_id)
    node_info = Map.get(graph.nodes, node_id, %{})

    %{
      affected_count: length(affected_nodes),
      critical_path_affected: is_critical?(graph, node_id),
      estimated_downtime: estimate_downtime(node_info, affected_nodes),
      cascade_risk: would_cascade?(graph, node_id)
    }
  end

  # Private implementation

  defp parse_children_specs(children_specs) do
    nodes = extract_nodes(children_specs)
    edges = extract_dependencies(children_specs)

    {nodes, edges}
  end

  defp extract_nodes(children_specs) do
    children_specs
    |> Enum.map(&extract_node_info/1)
    |> Enum.map(fn node -> {node.id, node} end)
    |> Map.new()
  end

  defp extract_node_info({module, args}) do
    node_id = extract_node_id(module, args)

    %{
      id: node_id,
      module: module,
      priority: Keyword.get(args, :priority, 5),
      critical: Keyword.get(args, :critical, false),
      fallback_strategy: Keyword.get(args, :fallback_strategy, :disable)
    }
  end

  defp extract_node_info(%{id: id, start: {module, _fun, _args}} = spec) do
    %{
      id: id,
      module: module,
      priority: Map.get(spec, :priority, 5),
      critical: Map.get(spec, :critical, false),
      fallback_strategy: Map.get(spec, :fallback_strategy, :disable)
    }
  end

  defp extract_node_info(spec) do
    # Default node info for unknown spec format
    %{
      id: extract_node_id(spec, []),
      module: spec,
      priority: 5,
      critical: false,
      fallback_strategy: :disable
    }
  end

  defp extract_node_id(module, args) when is_atom(module) do
    Keyword.get(args, :id, module_to_atom(module))
  end

  defp extract_node_id(spec, _args) do
    spec
  end

  defp module_to_atom(module) when is_atom(module) do
    module
    |> Atom.to_string()
    |> String.split(".")
    |> List.last()
    |> String.downcase()
    |> String.to_atom()
  end

  defp extract_dependencies(children_specs) do
    children_specs
    |> Enum.map(fn
      {module, args} ->
        node_id = extract_node_id(module, args)
        dependencies = Keyword.get(args, :depends_on, [])
        {node_id, dependencies}

      %{id: id} = spec ->
        dependencies = Map.get(spec, :depends_on, [])
        {id, dependencies}

      spec ->
        node_id = extract_node_id(spec, [])
        {node_id, []}
    end)
    |> Enum.reject(fn {_node, deps} -> deps == [] end)
    |> Map.new()
  end

  defp extract_fallback_strategies(children_specs) do
    children_specs
    |> Enum.map(fn
      {module, args} ->
        node_id = extract_node_id(module, args)
        strategy = Keyword.get(args, :fallback_strategy, :disable)
        {node_id, strategy}

      %{id: id} = spec ->
        strategy = Map.get(spec, :fallback_strategy, :disable)
        {id, strategy}

      spec ->
        node_id = extract_node_id(spec, [])
        {node_id, :disable}
    end)
    |> Map.new()
  end

  defp extract_restart_strategies(children_specs) do
    children_specs
    |> Enum.map(fn
      {module, args} ->
        node_id = extract_node_id(module, args)
        strategy = Keyword.get(args, :restart_strategy, :independent)
        {node_id, strategy}

      %{id: id} = spec ->
        strategy = Map.get(spec, :restart_strategy, :independent)
        {id, strategy}

      spec ->
        node_id = extract_node_id(spec, [])
        {node_id, :independent}
    end)
    |> Map.new()
  end

  defp validate_graph(graph) do
    # Check for circular dependencies
    case detect_circular_dependencies(graph) do
      [] ->
        graph

      cycles ->
        Log.module_warning("Circular dependencies detected: #{inspect(cycles)}")
        # Could potentially break cycles or warn user
        graph
    end
  end

  defp detect_circular_dependencies(graph) do
    # Simple cycle detection using DFS
    graph.edges
    |> Map.keys()
    |> Enum.flat_map(fn node ->
      case find_cycle(graph, node, [node], MapSet.new([node])) do
        nil -> []
        cycle -> [cycle]
      end
    end)
    |> Enum.uniq()
  end

  defp find_cycle(graph, current_node, path, visited) do
    dependencies = Map.get(graph.edges, current_node, [])

    Enum.find_value(dependencies, fn dep ->
      cond do
        dep in visited ->
          # Found a cycle
          cycle_start_index = Enum.find_index(path, &(&1 == dep))
          Enum.drop(path, cycle_start_index) ++ [dep]

        true ->
          # Continue searching
          new_visited = MapSet.put(visited, dep)
          new_path = path ++ [dep]
          find_cycle(graph, dep, new_path, new_visited)
      end
    end)
  end

  defp calculate_critical_paths(graph) do
    # Identify critical paths - nodes whose failure would affect many others
    critical_nodes =
      graph.nodes
      |> Map.keys()
      |> Enum.filter(fn node_id ->
        affected_count = length(get_affected_nodes(graph, node_id))

        affected_count >= 2 ||
          Map.get(graph.nodes, node_id, %{}) |> Map.get(:critical, false)
      end)

    %{graph | critical_paths: critical_nodes}
  end

  defp optimize_restart_order(graph) do
    # Could implement more sophisticated restart order optimization here
    # For now, just return the graph as-is
    graph
  end

  defp calculate_restart_order(graph, node_id, visited) do
    if node_id in visited do
      # Circular dependency - return empty list to avoid infinite recursion
      []
    else
      dependencies = Map.get(graph.edges, node_id, [])
      new_visited = [node_id | visited]

      # Get restart order for all dependencies first
      dependency_orders =
        dependencies
        |> Enum.flat_map(fn dep ->
          calculate_restart_order(graph, dep, new_visited)
        end)
        |> Enum.uniq()

      # Add current node after its dependencies
      dependency_orders ++ [node_id]
    end
  end

  defp get_affected_nodes_recursive(graph, node_id, visited) do
    if MapSet.member?(visited, node_id) do
      visited
    else
      new_visited = MapSet.put(visited, node_id)
      dependents = get_dependents(graph, node_id)

      Enum.reduce(dependents, new_visited, fn dependent, acc ->
        get_affected_nodes_recursive(graph, dependent, acc)
      end)
    end
  end

  defp estimate_downtime(node_info, affected_nodes) do
    base_restart_time =
      case Map.get(node_info, :priority, 5) do
        # High priority - fast restart
        p when p <= 2 -> 500
        # Medium priority
        p when p <= 5 -> 1000
        # Low priority
        _ -> 2000
      end

    # Add time for affected nodes
    cascade_time = length(affected_nodes) * 200

    base_restart_time + cascade_time
  end
end
