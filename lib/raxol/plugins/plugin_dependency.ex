defmodule Raxol.Plugins.PluginDependency do
  @moduledoc """
  Handles plugin dependency resolution and version compatibility checks.
  """

  @doc """
  Resolves plugin dependencies and returns a sorted list of plugins to load.
  The list is sorted so that dependencies are loaded before the plugins that depend on them.
  """
  def resolve_dependencies(plugins) when is_list(plugins) do
    # Create a dependency graph
    graph = build_dependency_graph(plugins)

    # Check for circular dependencies
    case detect_cycles(graph) do
      {:ok, _} ->
        # Sort plugins by dependencies (topological sort)
        case topological_sort(graph) do
          {:ok, sorted_plugins} ->
            {:ok, sorted_plugins}

          {:error, reason} ->
            {:error, "Failed to sort plugins: #{reason}"}
        end

      {:error, cycle} ->
        {:error, "Circular dependency detected: #{Enum.join(cycle, " -> ")}"}
    end
  end

  @doc """
  Checks if a plugin's dependencies are satisfied by the currently loaded plugins.
  """
  def check_dependencies(plugin, loaded_plugins)
      when is_map(plugin) and is_list(loaded_plugins) do
    dependencies = plugin.dependencies || []

    Enum.reduce_while(dependencies, {:ok, []}, fn dependency, {:ok, missing} ->
      plugin_name = dependency["name"]
      version_constraint = dependency["version"] || ">= 0.0.0"
      optional = dependency["optional"] || false

      case find_plugin(loaded_plugins, plugin_name) do
        nil ->
          if optional do
            {:cont, {:ok, missing}}
          else
            {:halt, {:error, "Required dependency '#{plugin_name}' not found"}}
          end

        loaded_plugin ->
          case check_version_compatibility(
                 loaded_plugin.version,
                 version_constraint
               ) do
            :ok ->
              {:cont, {:ok, missing}}

            {:error, reason} ->
              if optional do
                {:cont, {:ok, missing}}
              else
                {:halt,
                 {:error, "Version mismatch for '#{plugin_name}': #{reason}"}}
              end
          end
      end
    end)
  end

  @doc """
  Checks if a plugin's API version is compatible with the plugin manager.
  """
  def check_api_compatibility(plugin_api_version, manager_api_version) do
    # For now, we just check if the major version matches
    plugin_major =
      String.split(plugin_api_version, ".")
      |> List.first()
      |> String.to_integer()

    manager_major =
      String.split(manager_api_version, ".")
      |> List.first()
      |> String.to_integer()

    if plugin_major == manager_major do
      :ok
    else
      {:error,
       "API version mismatch: plugin requires API version #{plugin_api_version}, but manager provides #{manager_api_version}"}
    end
  end

  # Private functions

  defp build_dependency_graph(plugins) do
    Enum.reduce(plugins, %{}, fn plugin, graph ->
      dependencies = plugin.dependencies || []
      plugin_name = plugin.name

      # Add plugin to graph if not already present
      graph = Map.put_new(graph, plugin_name, [])

      # Add dependencies to graph
      Enum.reduce(dependencies, graph, fn dependency, acc_graph ->
        dep_name = dependency["name"]
        acc_graph = Map.put_new(acc_graph, dep_name, [])
        Map.update!(acc_graph, dep_name, &[plugin_name | &1])
      end)
    end)
  end

  defp detect_cycles(graph) do
    # Use depth-first search to detect cycles
    visited = MapSet.new()
    recursion_stack = MapSet.new()

    case Enum.find(Map.keys(graph), fn node ->
           not MapSet.member?(visited, node) and
             has_cycle?(graph, node, visited, recursion_stack)
         end) do
      nil ->
        {:ok, graph}

      cycle_start ->
        {:error, find_cycle_path(graph, cycle_start, cycle_start, [])}
    end
  end

  defp has_cycle?(graph, node, visited, recursion_stack) do
    if MapSet.member?(recursion_stack, node) do
      true
    else
      if MapSet.member?(visited, node) do
        false
      else
        visited = MapSet.put(visited, node)
        recursion_stack = MapSet.put(recursion_stack, node)

        neighbors = Map.get(graph, node, [])

        Enum.any?(neighbors, fn neighbor ->
          has_cycle?(graph, neighbor, visited, recursion_stack)
        end)
      end
    end
  end

  defp find_cycle_path(graph, start, current, path) do
    if current == start and length(path) > 0 do
      Enum.reverse([current | path])
    else
      neighbors = Map.get(graph, current, [])

      Enum.find_value(neighbors, fn neighbor ->
        if neighbor == start or not Enum.member?(path, neighbor) do
          find_cycle_path(graph, start, neighbor, [current | path])
        end
      end)
    end
  end

  defp topological_sort(graph) do
    # Kahn's algorithm for topological sorting
    in_degree = calculate_in_degree(graph)

    queue =
      Enum.filter(Map.keys(graph), fn node ->
        Map.get(in_degree, node, 0) == 0
      end)

    result = []

    case topological_sort_helper(graph, in_degree, queue, result) do
      {:ok, sorted} -> {:ok, sorted}
      {:error, _} = error -> error
    end
  end

  defp topological_sort_helper(graph, in_degree, queue, result) do
    if queue == [] do
      if map_size(in_degree) == length(result) do
        {:ok, Enum.reverse(result)}
      else
        {:error, "Graph contains cycles"}
      end
    else
      [node | rest_queue] = queue
      new_in_degree = decrease_in_degree(graph, node, in_degree)
      new_queue = update_queue(graph, node, new_in_degree, rest_queue)

      topological_sort_helper(graph, new_in_degree, new_queue, [node | result])
    end
  end

  defp calculate_in_degree(graph) do
    Enum.reduce(graph, %{}, fn {node, neighbors}, in_degree ->
      in_degree = Map.put(in_degree, node, 0)

      Enum.reduce(neighbors, in_degree, fn neighbor, acc ->
        Map.update(acc, neighbor, 1, &(&1 + 1))
      end)
    end)
  end

  defp decrease_in_degree(graph, node, in_degree) do
    neighbors = Map.get(graph, node, [])

    Enum.reduce(neighbors, in_degree, fn neighbor, acc ->
      Map.update(acc, neighbor, 0, &max(0, &1 - 1))
    end)
  end

  defp update_queue(graph, node, in_degree, queue) do
    neighbors = Map.get(graph, node, [])

    Enum.reduce(neighbors, queue, fn neighbor, acc ->
      if Map.get(in_degree, neighbor, 0) == 0 do
        [neighbor | acc]
      else
        acc
      end
    end)
  end

  defp find_plugin(plugins, name) do
    Enum.find(plugins, fn plugin -> plugin.name == name end)
  end

  defp check_version_compatibility(version, constraint) do
    # Simple version compatibility check
    # In a real implementation, this would use a proper version comparison library
    case Regex.run(~r/^([<>=]+)\s*([0-9.]+)$/, constraint) do
      [_, op, version_str] ->
        case compare_versions(version, version_str) do
          :lt when op in [">", ">="] ->
            :ok

          :eq when op in [">=", "<=", "="] ->
            :ok

          :gt when op in ["<", "<="] ->
            :ok

          _ ->
            {:error,
             "Version #{version} does not satisfy constraint #{constraint}"}
        end

      _ ->
        {:error, "Invalid version constraint: #{constraint}"}
    end
  end

  defp compare_versions(v1, v2) do
    v1_parts = String.split(v1, ".") |> Enum.map(&String.to_integer/1)
    v2_parts = String.split(v2, ".") |> Enum.map(&String.to_integer/1)

    compare_version_parts(v1_parts, v2_parts)
  end

  defp compare_version_parts([a | _rest_a], [b | _rest_b]) when a > b, do: :gt
  defp compare_version_parts([a | _rest_a], [b | _rest_b]) when a < b, do: :lt

  defp compare_version_parts([a | rest_a], [a | rest_b]),
    do: compare_version_parts(rest_a, rest_b)

  defp compare_version_parts([], []), do: :eq
  defp compare_version_parts([], _), do: :lt
  defp compare_version_parts(_, []), do: :gt
end
