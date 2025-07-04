defmodule Raxol.Core.Runtime.Plugins.DependencyManager.Core do
  import Raxol.Guards

  @moduledoc """
  Core module for managing plugin dependencies and dependency resolution.
  Provides the main public API for dependency checking and load order resolution.
  """

  @behaviour Raxol.Core.Runtime.Plugins.DependencyManager.Behaviour

  require Raxol.Core.Runtime.Log

  alias Raxol.Core.Runtime.Plugins.DependencyManager.{
    Graph,
    Resolver
  }

  @type version_constraint :: String.t()
  @type dependency :: {String.t(), version_constraint()} | String.t()
  @type dependency_chain :: [String.t()]
  @type dependency_error ::
          {:error, :missing_dependencies, [String.t()], dependency_chain()}
          | {:error, :version_mismatch,
             [{String.t(), String.t(), version_constraint()}],
             dependency_chain()}
          | {:error, :circular_dependency, [String.t()], dependency_chain()}

  @impl Raxol.Core.Runtime.Plugins.DependencyManager.Behaviour
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
  def check_dependencies(
        plugin_id,
        plugin_metadata,
        loaded_plugins,
        dependency_chain \\ []
      ) do
    dependencies = Map.get(plugin_metadata, :dependencies, [])
    current_chain = [plugin_id | dependency_chain]

    case check_conflicting_requirements(dependencies, current_chain) do
      {:error, _} = error -> error
      :ok -> process_dependencies(dependencies, loaded_plugins, current_chain)
    end
  end

  defp check_conflicting_requirements(dependencies, current_chain) do
    dependencies
    |> group_requirements()
    |> find_conflict()
    |> format_conflict_result(current_chain)
  end

  defp group_requirements(dependencies) do
    Enum.group_by(dependencies, fn
      {dep_id, _ver_req} -> dep_id
      {dep_id, _ver_req, _opts} -> dep_id
      dep_id when binary?(dep_id) -> dep_id
    end)
  end

  defp find_conflict(reqs) do
    Enum.find_value(reqs, :ok, fn {dep_id, dep_list} ->
      if length(dep_list) > 1 and not compatible_requirements?(dep_list) do
        {dep_id, dep_list}
      end
    end)
  end

  defp format_conflict_result(:ok, _current_chain), do: :ok

  defp format_conflict_result({dep_id, dep_list}, current_chain) do
    requirements = extract_requirements(dep_list)
    {:error, :conflicting_requirements, [{dep_id, requirements}], current_chain}
  end

  defp extract_requirements(dep_list) do
    Enum.map(dep_list, fn
      {_, req} -> req
      {_, req, _} -> req
      _ -> nil
    end)
  end

  defp process_dependencies(dependencies, loaded_plugins, current_chain) do
    {missing, missing_version, invalid_version_format,
     invalid_version_requirement, version_mismatches,
     optional_missing} =
      Enum.reduce(
        dependencies,
        {[], [], [], [], [], []},
        &process_dependency(&1, loaded_plugins, &2)
      )

    log_optional_missing(optional_missing, current_chain)

    check_dependency_errors(
      missing,
      missing_version,
      invalid_version_format,
      invalid_version_requirement,
      version_mismatches,
      current_chain
    )
  end

  defp log_optional_missing(optional_missing, current_chain) do
    if Enum.any?(optional_missing) do
      Raxol.Core.Runtime.Log.info(
        "Optional dependencies not found for plugin #{current_chain |> List.first()}: #{inspect(optional_missing)}"
      )
    end
  end

  defp check_dependency_errors(
         missing,
         missing_version,
         invalid_version_format,
         invalid_version_requirement,
         version_mismatches,
         current_chain
       ) do
    cond do
      Enum.any?(missing_version) ->
        {:error, :missing_version, Enum.reverse(missing_version), current_chain}

      Enum.any?(missing) ->
        {:error, :missing_dependencies, Enum.reverse(missing), current_chain}

      Enum.any?(invalid_version_format) ->
        {:error, :invalid_version_format, Enum.reverse(invalid_version_format),
         current_chain}

      Enum.any?(invalid_version_requirement) ->
        {:error, :invalid_version_requirement,
         Enum.reverse(invalid_version_requirement), current_chain}

      Enum.any?(version_mismatches) ->
        {:error, :version_mismatch, Enum.reverse(version_mismatches),
         current_chain}

      true ->
        :ok
    end
  end

  defp process_dependency(
         {dep_id, version_req, %{optional: true}},
         loaded_plugins,
         acc
       ) do
    handle_optional_dependency(dep_id, version_req, loaded_plugins, acc)
  end

  defp process_dependency({dep_id, version_req}, loaded_plugins, acc) do
    handle_plugin_dependency(dep_id, version_req, loaded_plugins, acc)
  end

  defp process_dependency(dep_id, loaded_plugins, acc) when binary?(dep_id) do
    if Map.has_key?(loaded_plugins, dep_id) do
      acc
    else
      {elem(acc, 0) ++ [dep_id], elem(acc, 1), elem(acc, 2), elem(acc, 3),
       elem(acc, 4), elem(acc, 5)}
    end
  end

  @impl Raxol.Core.Runtime.Plugins.DependencyManager.Behaviour
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
    graph = Graph.build_dependency_graph(plugins)

    case validate_dependencies(graph, plugins) do
      :ok ->
        case Resolver.tarjan_sort(graph) do
          {:ok, order} -> {:ok, order}
          {:error, cycle} -> {:error, :circular_dependency, cycle, cycle}
        end

      {:error, plugin_id, cycle} ->
        # Convert self-dependency error to circular dependency format
        {:error, :circular_dependency, cycle, cycle}

      error ->
        error
    end
  end

  defp validate_dependencies(graph, plugins) do
    case find_self_dependency(graph) do
      :ok ->
        case find_conflicting_requirements(graph) do
          :ok ->
            find_version_mismatches(graph, plugins)

          error ->
            error
        end

      error ->
        error
    end
  end

  # --- Helper functions for error detection ---

  # Self-dependency: plugin depends on itself
  defp find_self_dependency(graph) do
    Enum.find_value(graph, :ok, &check_self_dependency/1)
  end

  defp check_self_dependency({plugin_id, deps}) do
    if Enum.any?(deps, fn {dep_id, _, _} -> dep_id == plugin_id end) do
      {:error, plugin_id, [plugin_id]}
    end
  end

  # Conflicting requirements: multiple dependencies on the same plugin with incompatible version requirements
  defp find_conflicting_requirements(graph) do
    Enum.find_value(graph, :ok, &check_plugin_conflicts/1)
  end

  defp check_plugin_conflicts({plugin_id, deps}) do
    reqs = Enum.group_by(deps, fn {dep_id, _, _} -> dep_id end)

    case Enum.find(reqs, fn {_dep_id, dep_list} ->
           length(dep_list) > 1 and not compatible_requirements?(dep_list)
         end) do
      {dep_id, dep_list} ->
        requirements = Enum.map(dep_list, fn {_, req, _} -> req end)
        {:error, [{dep_id, requirements}], [plugin_id, dep_id]}

      nil ->
        nil
    end
  end

  defp compatible_requirements?(dep_list) do
    reqs =
      Enum.map(dep_list, fn
        {_, req} -> req
        {_, req, _} -> req
        _ -> nil
      end)
      |> Enum.uniq()

    length(reqs) == 1
  end

  defp has_version_mismatch?(dep_id, req, plugins) do
    dep = plugins[dep_id]
    version = dep && Map.get(dep, :version)

    version && req &&
      match?(
        {:error, _},
        Raxol.Core.Runtime.Plugins.DependencyManager.Version.check_version(
          version,
          req
        )
      )
  end

  defp find_version_mismatches(graph, plugins) do
    Enum.find_value(graph, :ok, fn {plugin_id, deps} ->
      mismatches =
        deps
        |> Enum.filter(fn {dep_id, req, _} ->
          has_version_mismatch?(dep_id, req, plugins)
        end)
        |> Enum.map(fn {dep_id, req, _} ->
          {dep_id, plugins[dep_id][:version], req}
        end)

      if mismatches != [] do
        {:error, mismatches,
         [plugin_id | Enum.map(mismatches, fn {dep_id, _, _} -> dep_id end)]}
      else
        nil
      end
    end)
  end

  defp handle_optional_dependency(dep_id, version_req, loaded_plugins, acc) do
    case Map.get(loaded_plugins, dep_id) do
      nil ->
        acc

      %{version: nil} ->
        {elem(acc, 0), elem(acc, 1) ++ [dep_id], elem(acc, 2), elem(acc, 3),
         elem(acc, 4), elem(acc, 5)}

      %{version: version} ->
        check_version_requirement(dep_id, version, version_req, acc)
    end
  end

  defp handle_plugin_version(plugin, dep_id, version_req, acc) do
    case plugin do
      %{version: nil} ->
        update_acc(acc, 1, dep_id)

      %{version: version} ->
        check_version_requirement(dep_id, version, version_req, acc)

      _ ->
        update_acc(acc, 1, dep_id)
    end
  end

  defp handle_plugin_dependency(dep_id, version_req, loaded_plugins, acc) do
    case Map.get(loaded_plugins, dep_id) do
      nil ->
        update_acc(acc, 0, dep_id)

      plugin when map?(plugin) ->
        handle_plugin_version(plugin, dep_id, version_req, acc)

      _ ->
        update_acc(acc, 0, dep_id)
    end
  end

  defp update_acc(acc, field_idx, value) do
    List.to_tuple(
      Enum.with_index(Tuple.to_list(acc))
      |> Enum.map(fn {v, i} -> if i == field_idx, do: v ++ [value], else: v end)
    )
  end

  defp check_version_requirement(dep_id, version, version_req, acc) do
    case Raxol.Core.Runtime.Plugins.DependencyManager.Version.check_version(
           version,
           version_req
         ) do
      :ok -> acc
      {:error, :invalid_version_format} -> update_acc(acc, 2, dep_id)
      {:error, :invalid_requirement_format} -> update_acc(acc, 3, dep_id)
      {:error, :invalid_version_requirement} -> update_acc(acc, 3, dep_id)
      {:error, _reason} -> update_acc(acc, 4, {dep_id, version, version_req})
    end
  end

  @impl Raxol.Core.Runtime.Plugins.DependencyManager.Behaviour
  @doc """
  Resolves dependencies between plugins.

  ## Parameters

  * `plugin_metadata` - The plugin's metadata containing its dependencies
  * `loaded_plugins` - Map of currently loaded plugins

  ## Returns

  * `{:ok, resolved_deps}` - List of resolved dependencies
  * `{:error, reason}` - If dependency resolution fails
  """
  def resolve_dependencies(plugin_metadata, _loaded_plugins) do
    dependencies = Map.get(plugin_metadata, :dependencies, [])

    case validate_dependencies(dependencies) do
      :ok ->
        resolved =
          Enum.map(dependencies, fn
            {dep_id, _ver_req} -> dep_id
            {dep_id, _ver_req, _opts} -> dep_id
            dep_id when binary?(dep_id) -> dep_id
          end)

        {:ok, resolved}

      error ->
        error
    end
  end

  @impl Raxol.Core.Runtime.Plugins.DependencyManager.Behaviour
  @doc """
  Validates a list of dependencies.

  ## Parameters

  * `dependencies` - List of dependencies to validate

  ## Returns

  * `:ok` - If all dependencies are valid
  * `{:error, reason}` - If any dependencies are invalid
  """
  def validate_dependencies(dependencies) do
    case Enum.find(dependencies, fn
           {dep_id, _ver_req} when binary?(dep_id) -> false
           {dep_id, _ver_req, _opts} when binary?(dep_id) -> false
           dep_id when binary?(dep_id) -> false
           _ -> true
         end) do
      nil -> :ok
      invalid -> {:error, :invalid_dependency_format, invalid}
    end
  end

  @impl Raxol.Core.Runtime.Plugins.DependencyManager.Behaviour
  @doc """
  Checks for circular dependencies in the plugin graph.

  ## Parameters

  * `plugin_id` - The ID of the plugin to check
  * `dependencies` - List of dependencies to check
  * `loaded_plugins` - Map of currently loaded plugins

  ## Returns

  * `:ok` - If no circular dependencies are found
  * `{:error, :circular_dependency, cycle, chain}` - If a circular dependency is detected
  """
  def check_circular_dependencies(plugin_id, dependencies, _loaded_plugins) do
    graph =
      Graph.build_dependency_graph(%{plugin_id => %{dependencies: dependencies}})

    case Resolver.find_cycles(graph) do
      {:ok, []} ->
        :ok

      {:ok, cycles} ->
        cycle = hd(cycles)
        chain = [plugin_id | cycle]
        {:error, :circular_dependency, cycle, chain}

      error ->
        error
    end
  end
end
