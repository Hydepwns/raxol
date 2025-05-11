defmodule Raxol.Core.Runtime.Plugins.DependencyManager do
  @moduledoc """
  Manages plugin dependencies and dependency resolution.
  Provides sophisticated version constraint handling, efficient cycle detection,
  and detailed dependency chain reporting.

  This module serves as the main entry point for dependency management functionality,
  delegating to specialized submodules for different aspects of the functionality:

  - `DependencyManager.Core`: Core dependency checking and load order resolution
  - `DependencyManager.Version`: Version parsing and constraint checking
  - `DependencyManager.Graph`: Dependency graph building and analysis
  - `DependencyManager.Resolver`: Load order resolution using Tarjan's algorithm

  For more detailed documentation about the module's architecture and internals,
  see `docs/dependency_manager.md`.
  """

  alias Raxol.Core.Runtime.Plugins.DependencyManager.Core

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

  ## Examples

      iex> DependencyManager.check_dependencies("my_plugin", %{dependencies: [{"other_plugin", ">= 1.0.0"}]}, %{"other_plugin" => %{version: "1.1.0"}}, [])
      :ok

      iex> DependencyManager.check_dependencies("my_plugin", %{dependencies: [{"missing_plugin", ">= 1.0.0"}]}, %{}, [])
      {:error, :missing_dependencies, ["missing_plugin"], ["my_plugin"]}

      iex> DependencyManager.check_dependencies("my_plugin", %{dependencies: [{"other_plugin", ">= 2.0.0"}]}, %{"other_plugin" => %{version: "1.0.0"}}, [])
      {:error, :version_mismatch, [{"other_plugin", "1.0.0", ">= 2.0.0"}], ["my_plugin"]}
  """
  def check_dependencies(plugin_id, plugin_metadata, loaded_plugins, dependency_chain \\ []) do
    Core.check_dependencies(plugin_id, plugin_metadata, loaded_plugins, dependency_chain)
  end

  @doc """
  Resolves the load order for a set of plugins based on their dependencies.
  Uses Tarjan's algorithm for efficient cycle detection and component identification.

  ## Parameters

  * `plugins` - Map of plugin metadata, keyed by plugin ID

  ## Returns

  * `{:ok, load_order}` - List of plugin IDs in the correct load order
  * `{:error, :circular_dependency, cycle, chain}` - If a circular dependency is detected

  ## Examples

      iex> DependencyManager.resolve_load_order(%{
        "plugin_a" => %{dependencies: [{"plugin_b", ">= 1.0.0"}]},
        "plugin_b" => %{dependencies: []}
      })
      {:ok, ["plugin_b", "plugin_a"]}
  """
  def resolve_load_order(plugins) do
    Core.resolve_load_order(plugins)
  end

  # --- Private Functions ---

  # Enhanced version constraint parsing and checking
  defp parse_and_check_version(version, requirement) do
    with {:ok, parsed_version} <- Version.parse(version),
         {:ok, parsed_requirement} <- parse_version_requirement(requirement) do
      case parsed_requirement do
        {:or, requirements} ->
          if Enum.any?(requirements, &Version.match?(parsed_version, &1)) do
            :ok
          else
            {:error, :version_mismatch}
          end
        requirement ->
          if Version.match?(parsed_version, requirement) do
            :ok
          else
            {:error, :version_mismatch}
          end
      end
    else
      {:error, :invalid_version} -> {:error, :invalid_version_format}
      {:error, :invalid_requirement} -> {:error, :invalid_requirement_format}
    end
  end

  # Enhanced version requirement parsing with support for complex constraints
  defp parse_version_requirement(requirement) when is_binary(requirement) do
    # Handle complex version requirements
    case String.split(requirement, "||") do
      [single_req] ->
        parse_single_requirement(single_req)
      multiple_reqs ->
        # Handle OR conditions
        parsed_reqs = Enum.map(multiple_reqs, &parse_single_requirement/1)
        if Enum.all?(parsed_reqs, fn {:ok, _} -> true; _ -> false end) do
          {:ok, {:or, Enum.map(parsed_reqs, fn {:ok, req} -> req end)}}
        else
          {:error, :invalid_requirement}
        end
    end
  end

  defp parse_single_requirement(req) do
    req = String.trim(req)
    case Version.parse_requirement(req) do
      {:ok, parsed} -> {:ok, parsed}
      _ -> {:error, :invalid_requirement}
    end
  end

  # Build dependency graph with version information
  defp build_dependency_graph(plugins) do
    Enum.reduce(plugins, %{}, fn {id, metadata}, acc ->
      deps = Map.get(metadata, :dependencies, [])
      dep_info = Enum.map(deps, fn
        {dep_id, version_req, opts} -> {dep_id, version_req, opts}
        {dep_id, version_req} -> {dep_id, version_req, %{optional: false}}
        dep_id -> {dep_id, nil, %{optional: false}}
      end)
      Map.put(acc, id, dep_info)
    end)
  end

  # Tarjan's algorithm for cycle detection and topological sort
  defp tarjan_sort(graph) do
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

  # Strongly connected component detection (Tarjan's algorithm)
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
        case strongconnect(neighbor, graph, idx, low, comp, stk, i, on_stk) do
          {:ok, idx2, low2, comp2, stk2, i2} ->
            # Update lowlink
            low2 = Map.put(low2, node, min(Map.get(low2, node), Map.get(low2, neighbor)))
            {:cont, {idx2, low2, comp2, stk2, on_stk, i2}}
          {:error, cycle} ->
            {:halt, {:error, cycle}}
        end
      else
        if MapSet.member?(on_stk, neighbor) do
          # Neighbor is in stack and hence in the current SCC
          low = Map.put(low, node, min(Map.get(low, node), Map.get(idx, neighbor)))
          {:cont, {idx, low, comp, stk, on_stk, i}}
        else
          {:cont, {idx, low, comp, stk, on_stk, i}}
        end
      end
    end)

    case result do
      {:error, cycle} ->
        {:error, cycle}
      {final_indices, final_lowlinks, final_components, final_stack, final_on_stack, final_index} ->
        # If node is a root node, pop the stack and generate an SCC
        if Map.get(final_lowlinks, node) == Map.get(final_indices, node) do
          {component, new_stack2, new_on_stack2} = pop_component(node, final_stack, final_on_stack)
          new_components = [component | final_components]
          {:ok, final_indices, final_lowlinks, new_components, new_stack2, final_index}
        else
          {:ok, final_indices, final_lowlinks, final_components, final_stack, final_index}
        end
    end
  end

  # Helper to pop a strongly connected component from the stack
  defp pop_component(node, stack, on_stack) do
    {component, new_stack} = Enum.split_while(stack, &(&1 != node))
    new_on_stack = Enum.reduce(component, on_stack, &MapSet.delete(&2, &1))
    {[node | component], tl(new_stack), new_on_stack}
  end

  # Build dependency chain for error reporting
  defp build_dependency_chain(cycle, graph) do
    build_chain(cycle, graph, MapSet.new(), [])
  end

  defp build_chain([], _graph, _visited, acc), do: acc
  defp build_chain([node | rest], graph, visited, acc) do
    if MapSet.member?(visited, node) do
      build_chain(rest, graph, visited, acc)
    else
      new_visited = MapSet.put(visited, node)
      new_acc = [node | acc]
      deps = Enum.map(graph[node], fn {dep, _, _} -> dep end)
      build_chain(deps ++ rest, graph, new_visited, new_acc)
    end
  end

  @doc """
  Checks if a version meets a version requirement.
  """
  def satisfies_version?(installed_version, version_req) do
    case {Version.parse(installed_version), parse_version_requirement(version_req)} do
      {{:ok, parsed_version}, {:ok, parsed_requirement}} ->
        case parsed_requirement do
          {:or, requirements} ->
            Enum.any?(requirements, &Version.match?(parsed_version, &1))
          requirement ->
            Version.match?(parsed_version, requirement)
        end
      _ -> false
    end
  end
end
