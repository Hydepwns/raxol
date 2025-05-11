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
    case Enum.reduce_while(Map.keys(graph), {:ok, indices, lowlinks, components, stack, index}, fn node, {:ok, idx, low, comp, stk, i} ->
      if Map.has_key?(idx, node) do
        {:cont, {:ok, idx, low, comp, stk, i}}
      else
        case strongconnect(node, graph, idx, low, comp, stk, i, on_stack) do
          {:ok, new_idx, new_low, new_comp, new_stk, new_i} ->
            {:cont, {:ok, new_idx, new_low, new_comp, new_stk, new_i}}
          {:error, cycle} ->
            {:halt, {:error, cycle}}
        end
      end
    end) do
      {:ok, _, _, components, _, _} ->
        # Reverse components to get topological order
        {:ok, Enum.reverse(Enum.flat_map(components, & &1))}
      {:error, cycle} ->
        {:error, cycle}
    end
  end

  @doc false
  defp strongconnect(node, graph, indices, lowlinks, components, stack, index, on_stack) do
    # Initialize node's index and lowlink
    new_indices = Map.put(indices, node, index)
    new_lowlinks = Map.put(lowlinks, node, index)
    new_index = index + 1
    new_stack = [node | stack]
    new_on_stack = MapSet.put(on_stack, node)

    # Process all neighbors
    result = Enum.reduce_while(graph[node], {new_indices, new_lowlinks, components, new_stack, new_on_stack, new_index}, fn {neighbor, _, _}, {idx, low, comp, stk, on_stk, i} ->
      if not Map.has_key?(idx, neighbor) do
        # Neighbor has not been visited yet
        case strongconnect(neighbor, graph, idx, low, comp, stk, i, on_stk) do
          {:ok, new_idx, new_low, new_comp, new_stk, new_on_stk, new_i} ->
            new_low = Map.put(new_low, node, min(Map.get(new_low, node), Map.get(new_low, neighbor)))
            {:cont, {new_idx, new_low, new_comp, new_stk, new_on_stk, new_i}}
          {:error, cycle} ->
            {:halt, {:error, cycle}}
        end
      else
        if MapSet.member?(on_stk, neighbor) do
          # Neighbor is on stack, update lowlink
          new_low = Map.put(low, node, min(Map.get(low, node), Map.get(idx, neighbor)))
          {:cont, {idx, new_low, comp, stk, on_stk, i}}
        else
          {:cont, {idx, low, comp, stk, on_stk, i}}
        end
      end
    end)

    case result do
      {:error, cycle} ->
        {:error, cycle}
      {idx, low, comp, stk, on_stk, i} ->
        if Map.get(low, node) == Map.get(idx, node) do
          # Node is root of strongly connected component
          {component, new_stack} = extract_component(node, stk)
          # Assert types for safety
          unless is_list(component) and Enum.all?(component, &is_binary/1), do: raise "Component must be a list of strings"
          unless is_struct(on_stk, MapSet), do: raise "on_stk must be a MapSet"
          new_components = [component | comp]
          new_on_stack = Enum.reduce(component, on_stk, fn elem, acc ->
            unless is_struct(acc, MapSet), do: raise "Accumulator must be a MapSet"
            MapSet.delete(acc, elem)
          end)
          {:ok, idx, low, new_components, new_stack, new_on_stack, i}
        else
          {:ok, idx, low, comp, stk, on_stk, i}
        end
    end
  end

  @doc false
  defp extract_component(node, stack) do
    {component, rest} = Enum.split_while(stack, &(&1 != node))
    {[node | component], rest}
  end
end
