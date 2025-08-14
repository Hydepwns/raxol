defmodule Raxol.Core.Runtime.Plugins.DependencyManager.Resolver do
  
  @moduledoc """
  Handles load order resolution for plugin dependencies using Tarjan's algorithm.
  Provides efficient cycle detection and topological sorting of dependencies.
  """

  @doc """
  Performs a topological sort of the dependency graph using Tarjan's algorithm.
  This algorithm efficiently detects cycles and produces a valid load order.

  ## Parameters

  * `graph` - The dependency graph

  ## Returns

  * `{:ok, order}` - List of plugin IDs in the correct load order
  * `{:error, cycle}` - If a circular dependency is detected

  ## Example

      iex> Resolver.tarjan_sort(%{
        "plugin_a" => [{"plugin_b", ">= 1.0.0", %{optional: false}}],
        "plugin_b" => []
      })
      {:ok, ["plugin_b", "plugin_a"]}
  """
  def tarjan_sort(graph) do
    # Initialize data structures
    index = 0
    indices = %{}
    lowlinks = %{}
    on_stack = MapSet.new()
    components = []
    stack = []

    # Visit each node
    case Enum.reduce_while(
           Map.keys(graph),
           {:ok, indices, lowlinks, components, stack, on_stack, index},
           &process_node(&1, &2, graph)
         ) do
      {:ok, _, _, components, _, _, _} ->
        # Reverse components to get topological order
        {:ok, Enum.reverse(Enum.flat_map(components, & &1))}

      {:error, cycle} ->
        {:error, cycle}
    end
  end

  defp process_node(node, {:ok, idx, low, comp, stk, on_stk, i}, graph) do
    if Map.has_key?(idx, node) do
      {:cont, {:ok, idx, low, comp, stk, on_stk, i}}
    else
      handle_strongconnect_result(
        strongconnect(node, graph, idx, low, comp, stk, i, on_stk)
      )
    end
  end

  defp handle_strongconnect_result(
         {:ok, new_idx, new_low, new_comp, new_stk, new_on_stk, new_i}
       ) do
    {:cont, {:ok, new_idx, new_low, new_comp, new_stk, new_on_stk, new_i}}
  end

  defp handle_strongconnect_result({:error, cycle}) do
    {:halt, {:error, cycle}}
  end

  @doc false
  defp strongconnect(
         node,
         graph,
         indices,
         lowlinks,
         components,
         stack,
         index,
         on_stack
       ) do
    # Initialize node's index and lowlink
    new_indices = Map.put(indices, node, index)
    new_lowlinks = Map.put(lowlinks, node, index)
    new_index = index + 1
    new_stack = [node | stack]
    new_on_stack = MapSet.put(on_stack, node)

    # Process all neighbors
    result =
      Enum.reduce_while(
        Map.get(graph, node, []),
        {new_indices, new_lowlinks, components, new_stack, new_on_stack,
         new_index},
        &process_neighbor(&1, &2, graph, node)
      )

    case result do
      {:error, cycle} ->
        {:error, cycle}

      {idx, low, comp, stk, on_stk, i} ->
        process_component_root(node, idx, low, comp, stk, on_stk, i, graph)
    end
  end

  defp process_neighbor(
         {neighbor, _, _},
         {idx, low, comp, stk, on_stk, i},
         graph,
         node
       ) do
    neighbor_state = %{
      graph: graph,
      idx: idx,
      low: low,
      comp: comp,
      stk: stk,
      on_stk: on_stk,
      i: i,
      node: node
    }

    case get_neighbor_type(neighbor, graph, idx, on_stk) do
      :missing ->
        {:cont, {idx, low, comp, stk, on_stk, i}}

      :unvisited ->
        process_unvisited_neighbor(neighbor, neighbor_state)

      :on_stack ->
        update_lowlink_and_continue(
          node,
          neighbor,
          idx,
          low,
          comp,
          stk,
          on_stk,
          i
        )

      :visited ->
        {:cont, {idx, low, comp, stk, on_stk, i}}
    end
  end

  defp get_neighbor_type(neighbor, graph, _idx, _on_stk) when not is_map_key(graph, neighbor) do
    :missing
  end

  defp get_neighbor_type(neighbor, _graph, idx, _on_stk) when not is_map_key(idx, neighbor) do
    :unvisited
  end

  defp get_neighbor_type(neighbor, _graph, _idx, on_stk) do
    if MapSet.member?(on_stk, neighbor), do: :on_stack, else: :visited
  end

  defp process_unvisited_neighbor(neighbor, %{
         graph: graph,
         idx: idx,
         low: low,
         comp: comp,
         stk: stk,
         on_stk: on_stk,
         i: i,
         node: node
       }) do
    case strongconnect(neighbor, graph, idx, low, comp, stk, i, on_stk) do
      {:ok, new_idx, new_low, new_comp, new_stk, new_on_stk, new_i} ->
        new_low =
          Map.put(
            new_low,
            node,
            min(Map.get(new_low, node), Map.get(new_low, neighbor))
          )

        {:cont, {new_idx, new_low, new_comp, new_stk, new_on_stk, new_i}}

      {:error, cycle} ->
        {:halt, {:error, cycle}}
    end
  end

  defp process_component_root(node, idx, low, comp, stk, on_stk, i, graph) do
    if Map.get(low, node) == Map.get(idx, node) do
      {component, new_stack} = extract_component(node, stk)
      validate_component(component, on_stk)
      handle_component(component, idx, low, comp, new_stack, on_stk, i, graph)
    else
      {:ok, idx, low, comp, stk, on_stk, i}
    end
  end

  defp validate_component(component, on_stk) do
    if !(is_list(component) and Enum.all?(component, &is_atom/1)),
      do: raise("Component must be a list of atoms")

    if not is_struct(on_stk, MapSet), do: raise("on_stk must be a MapSet")
  end

  defp handle_component(component, idx, low, comp, new_stack, on_stk, i, graph) do
    if length(component) > 1 do
      handle_multi_node_component(
        component,
        idx,
        low,
        comp,
        new_stack,
        on_stk,
        i,
        graph
      )
    else
      handle_single_node_component(
        component,
        idx,
        low,
        comp,
        new_stack,
        on_stk,
        i,
        graph
      )
    end
  end

  defp handle_multi_node_component(
         component,
         idx,
         low,
         comp,
         new_stack,
         on_stk,
         i,
         graph
       ) do
    if has_internal_edge?(component, graph) do
      {:error, component}
    else
      new_components = [component | comp]
      new_on_stack = remove_from_stack(component, on_stk)
      {:ok, idx, low, new_components, new_stack, new_on_stack, i}
    end
  end

  defp handle_single_node_component(
         component,
         idx,
         low,
         comp,
         new_stack,
         on_stk,
         i,
         graph
       ) do
    node = hd(component)
    deps = Map.get(graph, node, [])

    if Enum.any?(deps, fn {neighbor, _, _} -> neighbor == node end) do
      {:error, component}
    else
      new_components = [component | comp]
      new_on_stack = MapSet.delete(on_stk, node)
      {:ok, idx, low, new_components, new_stack, new_on_stack, i}
    end
  end

  defp has_internal_edge?(component, graph) do
    Enum.any?(component, fn n ->
      deps = Map.get(graph, n, [])
      Enum.any?(deps, fn {neighbor, _, _} -> neighbor in component end)
    end)
  end

  defp update_lowlink_and_continue(
         node,
         neighbor,
         idx,
         low,
         comp,
         stk,
         on_stk,
         i
       ) do
    new_low =
      Map.put(low, node, min(Map.get(low, node), Map.get(idx, neighbor)))

    {:cont, {idx, new_low, comp, stk, on_stk, i}}
  end

  defp remove_from_stack(component, on_stk) do
    Enum.reduce(component, on_stk, fn elem, acc ->
      if not is_struct(acc, MapSet), do: raise("Accumulator must be a MapSet")
      MapSet.delete(acc, elem)
    end)
  end

  @doc false
  defp extract_component(node, [top | rest]) do
    do_extract_component(node, [top | rest], [])
  end

  defp do_extract_component(node, [top | rest], acc) do
    acc = [top | acc]

    if top == node do
      {acc, rest}
    else
      do_extract_component(node, rest, acc)
    end
  end

  @doc """
  Finds cycles in the dependency graph.
  """
  def find_cycles(graph) do
    case tarjan_sort(graph) do
      {:ok, _order} -> {:ok, []}
      {:error, cycle} -> {:ok, [cycle]}
    end
  end
end
