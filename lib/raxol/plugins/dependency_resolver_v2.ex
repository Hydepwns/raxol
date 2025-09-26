defmodule Raxol.Plugins.DependencyResolverV2 do
  @moduledoc """
  Advanced dependency resolution system for Plugin System v2.0.

  Features:
  - Semantic version resolution (^1.2.0, ~> 2.1, >= 1.0.0)
  - Conflict detection and resolution strategies
  - Circular dependency detection
  - Dependency graph optimization
  - Version compatibility checking
  """

  require Logger

  @type plugin_id :: String.t()
  @type version :: String.t()
  @type version_requirement :: String.t()
  @type dependency_spec :: {plugin_id(), version_requirement()}
  @type resolution_result :: {:ok, [dependency_spec()]} | {:error, term()}

  defstruct available_plugins: %{},
            dependency_graph: %{},
            resolution_cache: %{},
            conflict_strategies: %{}

  @doc """
  Resolves dependencies for a plugin manifest.
  Returns ordered list of dependencies to install/load.
  """
  def resolve_dependencies(manifest, available_plugins \\ %{}) do
    resolver = %__MODULE__{
      available_plugins: available_plugins,
      dependency_graph: build_initial_graph(available_plugins),
      resolution_cache: %{},
      conflict_strategies: default_conflict_strategies()
    }

    case resolve_plugin_dependencies(manifest, resolver) do
      {:ok, dependencies} ->
        # Sort dependencies by load order (topological sort)
        case topological_sort(dependencies, resolver.dependency_graph) do
          {:ok, sorted_deps} -> {:ok, sorted_deps}
          {:error, :circular_dependency} = error -> error
        end

      error ->
        error
    end
  end

  @doc """
  Checks if a version satisfies a version requirement.
  Supports: ^1.2.0, ~> 2.1, >= 1.0.0, == 1.5.0, < 2.0.0
  """
  def version_satisfies?(version, requirement) do
    case parse_requirement(requirement) do
      {:ok, {operator, target_version}} ->
        case Version.parse(version) do
          {:ok, parsed_version} ->
            case Version.parse(target_version) do
              {:ok, parsed_target} ->
                check_version_constraint(
                  parsed_version,
                  operator,
                  parsed_target
                )

              :error ->
                false
            end

          :error ->
            false
        end

      :error ->
        false
    end
  end

  @doc """
  Detects circular dependencies in the dependency graph.
  """
  def detect_circular_dependencies(graph) do
    visited = MapSet.new()
    visiting = MapSet.new()

    Enum.reduce_while(graph, :ok, fn {node, _deps}, _acc ->
      case detect_cycle(node, graph, visited, visiting, []) do
        {:cycle, path} -> {:halt, {:error, {:circular_dependency, path}}}
        {:ok, _new_visited} -> {:cont, :ok}
      end
    end)
  end

  @doc """
  Resolves version conflicts using configured strategies.
  """
  def resolve_conflicts(conflicts, strategies \\ default_conflict_strategies()) do
    Enum.reduce(conflicts, {:ok, []}, fn conflict, {:ok, acc} ->
      case resolve_single_conflict(conflict, strategies) do
        {:ok, resolution} -> {:ok, [resolution | acc]}
        error -> error
      end
    end)
  end

  # Private Implementation

  defp resolve_plugin_dependencies(manifest, resolver) do
    plugin_id = manifest.name
    dependencies = manifest.dependencies || []

    Logger.debug("[DependencyResolver] Resolving dependencies for #{plugin_id}")

    case collect_all_dependencies(
           dependencies,
           resolver,
           MapSet.new([plugin_id])
         ) do
      {:ok, all_deps} ->
        case detect_conflicts(all_deps) do
          [] ->
            {:ok, all_deps}

          conflicts ->
            Logger.info(
              "[DependencyResolver] Detected conflicts: #{inspect(conflicts)}"
            )

            resolve_conflicts(conflicts, resolver.conflict_strategies)
        end

      error ->
        error
    end
  end

  defp collect_all_dependencies(dependencies, resolver, visited) do
    Enum.reduce_while(dependencies, {:ok, []}, fn {dep_id, requirement},
                                                  {:ok, acc} ->
      if MapSet.member?(visited, dep_id) do
        Logger.warning(
          "[DependencyResolver] Circular dependency detected: #{dep_id}"
        )

        {:halt, {:error, {:circular_dependency, dep_id}}}
      else
        case find_compatible_version(
               dep_id,
               requirement,
               resolver.available_plugins
             ) do
          {:ok, version} ->
            new_visited = MapSet.put(visited, dep_id)
            dep_spec = {dep_id, version}

            # Recursively resolve transitive dependencies
            case get_plugin_manifest(
                   dep_id,
                   version,
                   resolver.available_plugins
                 ) do
              {:ok, dep_manifest} ->
                case collect_all_dependencies(
                       dep_manifest.dependencies || [],
                       resolver,
                       new_visited
                     ) do
                  {:ok, transitive_deps} ->
                    {:cont, {:ok, [dep_spec | transitive_deps ++ acc]}}

                  error ->
                    {:halt, error}
                end

              {:error, :not_found} ->
                {:halt, {:error, {:dependency_not_found, dep_id, requirement}}}
            end

          {:error, :no_compatible_version} ->
            {:halt, {:error, {:no_compatible_version, dep_id, requirement}}}
        end
      end
    end)
  end

  defp find_compatible_version(plugin_id, requirement, available_plugins) do
    case Map.get(available_plugins, plugin_id) do
      nil ->
        {:error, :plugin_not_found}

      plugin_versions ->
        compatible_versions =
          Enum.filter(plugin_versions, fn version ->
            version_satisfies?(version, requirement)
          end)

        case compatible_versions do
          [] ->
            {:error, :no_compatible_version}

          versions ->
            # Select highest compatible version
            highest_version = Enum.max_by(versions, &Version.parse!/1, Version)
            {:ok, highest_version}
        end
    end
  end

  defp parse_requirement(requirement) do
    cond do
      String.starts_with?(requirement, "^") ->
        version = String.slice(requirement, 1..-1)
        {:ok, {:caret, version}}

      String.starts_with?(requirement, "~>") ->
        version = String.trim_leading(requirement, "~> ")
        {:ok, {:tilde, version}}

      String.starts_with?(requirement, ">=") ->
        version = String.trim_leading(requirement, ">= ")
        {:ok, {:gte, version}}

      String.starts_with?(requirement, "==") ->
        version = String.trim_leading(requirement, "== ")
        {:ok, {:eq, version}}

      String.starts_with?(requirement, "<") ->
        version = String.trim_leading(requirement, "< ")
        {:ok, {:lt, version}}

      true ->
        # Default to exact match
        {:ok, {:eq, requirement}}
    end
  end

  defp check_version_constraint(version, :caret, target) do
    # ^1.2.3 allows >=1.2.3 and <2.0.0
    version.major == target.major and Version.compare(version, target) != :lt
  end

  defp check_version_constraint(version, :tilde, target) do
    # ~>2.1.0 allows >=2.1.0 and <2.2.0
    version.major == target.major and
      version.minor == target.minor and
      Version.compare(version, target) != :lt
  end

  defp check_version_constraint(version, :gte, target) do
    Version.compare(version, target) != :lt
  end

  defp check_version_constraint(version, :eq, target) do
    Version.compare(version, target) == :eq
  end

  defp check_version_constraint(version, :lt, target) do
    Version.compare(version, target) == :lt
  end

  defp detect_conflicts(dependencies) do
    # Group by plugin ID and check for conflicting version requirements
    grouped =
      Enum.group_by(dependencies, fn {plugin_id, _version} -> plugin_id end)

    Enum.flat_map(grouped, fn {plugin_id, versions} ->
      if length(versions) > 1 do
        [{:conflict, plugin_id, versions}]
      else
        []
      end
    end)
  end

  defp resolve_single_conflict({:conflict, plugin_id, versions}, strategies) do
    strategy = Map.get(strategies, :version_conflict, :highest)

    case strategy do
      :highest ->
        highest_version =
          Enum.max_by(
            versions,
            fn {_id, version} -> Version.parse!(version) end,
            Version
          )

        {:ok, highest_version}

      :lowest ->
        lowest_version =
          Enum.min_by(
            versions,
            fn {_id, version} -> Version.parse!(version) end,
            Version
          )

        {:ok, lowest_version}

      :fail ->
        {:error, {:unresolvable_conflict, plugin_id, versions}}
    end
  end

  defp topological_sort(dependencies, graph) do
    # Implement Kahn's algorithm for topological sorting
    in_degree = calculate_in_degrees(dependencies, graph)

    queue =
      Enum.filter(dependencies, fn {plugin_id, _} ->
        Map.get(in_degree, plugin_id, 0) == 0
      end)

    topological_sort_impl(queue, in_degree, graph, dependencies, [])
  end

  defp topological_sort_impl([], in_degree, _graph, _dependencies, result) do
    if Enum.any?(in_degree, fn {_node, degree} -> degree > 0 end) do
      {:error, :circular_dependency}
    else
      {:ok, Enum.reverse(result)}
    end
  end

  defp topological_sort_impl(
         [{node, version} | queue],
         in_degree,
         graph,
         dependencies,
         result
       ) do
    new_result = [{node, version} | result]

    # Update in-degrees for dependent nodes
    dependents = Map.get(graph, node, [])

    {new_queue, new_in_degree} =
      Enum.reduce(dependents, {queue, in_degree}, fn dependent,
                                                     {acc_queue, acc_degrees} ->
        new_degree = Map.get(acc_degrees, dependent, 0) - 1
        updated_degrees = Map.put(acc_degrees, dependent, new_degree)

        if new_degree == 0 do
          # Find the version for this dependent
          case Enum.find(dependencies, fn {dep_id, _} -> dep_id == dependent end) do
            nil -> {acc_queue, updated_degrees}
            dep_spec -> {[dep_spec | acc_queue], updated_degrees}
          end
        else
          {acc_queue, updated_degrees}
        end
      end)

    topological_sort_impl(
      new_queue,
      new_in_degree,
      graph,
      dependencies,
      new_result
    )
  end

  defp calculate_in_degrees(dependencies, graph) do
    plugin_ids = Enum.map(dependencies, fn {plugin_id, _} -> plugin_id end)

    Enum.reduce(plugin_ids, %{}, fn plugin_id, acc ->
      in_degree = Enum.count(graph, fn {_node, deps} -> plugin_id in deps end)
      Map.put(acc, plugin_id, in_degree)
    end)
  end

  defp detect_cycle(node, graph, visited, visiting, path) do
    cond do
      MapSet.member?(visiting, node) ->
        cycle_path = Enum.drop_while(path, fn n -> n != node end)
        {:cycle, [node | cycle_path]}

      MapSet.member?(visited, node) ->
        {:ok, visited}

      true ->
        new_visiting = MapSet.put(visiting, node)
        new_path = [node | path]

        dependencies = Map.get(graph, node, [])

        Enum.reduce_while(dependencies, {:ok, visited}, fn dep,
                                                           {:ok, acc_visited} ->
          case detect_cycle(dep, graph, acc_visited, new_visiting, new_path) do
            {:cycle, cycle_path} -> {:halt, {:cycle, cycle_path}}
            {:ok, new_visited} -> {:cont, {:ok, new_visited}}
          end
        end)
        |> case do
          {:cycle, cycle_path} ->
            {:cycle, cycle_path}

          {:ok, final_visited} ->
            {:ok, MapSet.put(final_visited, node)}
        end
    end
  end

  defp build_initial_graph(_available_plugins) do
    # Build dependency graph from available plugins
    %{}
  end

  defp get_plugin_manifest(plugin_id, version, available_plugins) do
    # Mock implementation - would load actual manifest
    case Map.get(available_plugins, plugin_id) do
      nil ->
        {:error, :not_found}

      versions when is_list(versions) ->
        if version in versions do
          {:ok, %{name: plugin_id, version: version, dependencies: []}}
        else
          {:error, :not_found}
        end

      _ ->
        {:error, :not_found}
    end
  end

  defp default_conflict_strategies do
    %{
      version_conflict: :highest,
      api_conflict: :fail,
      capability_conflict: :merge
    }
  end
end
