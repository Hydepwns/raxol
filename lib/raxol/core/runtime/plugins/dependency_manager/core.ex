defmodule Raxol.Core.Runtime.Plugins.DependencyManager.Core do
  @moduledoc """
  Core module for managing plugin dependencies and dependency resolution.
  Provides the main public API for dependency checking and load order resolution.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Core.Runtime.Plugins.DependencyManager.{
    Version,
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

    # --- Conflicting requirements check (moved from resolve_load_order) ---
    reqs =
      Enum.group_by(dependencies, fn
        {dep_id, _ver_req} -> dep_id
        {dep_id, _ver_req, _opts} -> dep_id
        dep_id when is_binary(dep_id) -> dep_id
      end)

    conflict =
      Enum.find(reqs, fn {_dep_id, dep_list} ->
        length(dep_list) > 1 and not compatible_requirements?(dep_list)
      end)

    if conflict do
      {dep_id, dep_list} = conflict

      requirements =
        Enum.map(dep_list, fn
          {_, req} -> req
          {_, req, _} -> req
          _ -> nil
        end)

      return_conflicts = [{dep_id, requirements}]
      # Return in the shape expected by the test
      {:error, :conflicting_requirements, return_conflicts, current_chain}
    else
      {missing, missing_version, invalid_version_format,
       invalid_version_requirement, version_mismatches,
       optional_missing} =
        Enum.reduce(dependencies, {[], [], [], [], [], []}, fn
          # Handle tuple format {dep_id, version_req, opts}
          {dep_id, version_req, %{optional: true}},
          {missing_acc, miss_ver_acc, inv_ver_fmt_acc, inv_req_acc,
           mismatch_acc, opt_missing_acc} ->
            case Map.get(loaded_plugins, dep_id) do
              nil ->
                {missing_acc, miss_ver_acc, inv_ver_fmt_acc, inv_req_acc,
                 mismatch_acc, opt_missing_acc}

              %{version: nil} ->
                {missing_acc, miss_ver_acc ++ [dep_id], inv_ver_fmt_acc,
                 inv_req_acc, mismatch_acc, opt_missing_acc}

              %{version: version} ->
                case Raxol.Core.Runtime.Plugins.DependencyManager.Version.check_version(
                       version,
                       version_req
                     ) do
                  :ok ->
                    {missing_acc, miss_ver_acc, inv_ver_fmt_acc, inv_req_acc,
                     mismatch_acc, opt_missing_acc}

                  {:error, :invalid_version_format} ->
                    {missing_acc, miss_ver_acc, inv_ver_fmt_acc ++ [dep_id],
                     inv_req_acc, mismatch_acc, opt_missing_acc}

                  {:error, :invalid_requirement_format} ->
                    {missing_acc, miss_ver_acc, inv_ver_fmt_acc,
                     inv_req_acc ++ [dep_id], mismatch_acc, opt_missing_acc}

                  {:error, :invalid_version_requirement} ->
                    {missing_acc, miss_ver_acc, inv_ver_fmt_acc,
                     inv_req_acc ++ [dep_id], mismatch_acc, opt_missing_acc}

                  # Ignore version mismatch for optional
                  {:error, _reason} ->
                    {missing_acc, miss_ver_acc, inv_ver_fmt_acc, inv_req_acc,
                     mismatch_acc, opt_missing_acc}
                end

              _ ->
                {missing_acc, miss_ver_acc, inv_ver_fmt_acc, inv_req_acc,
                 mismatch_acc, opt_missing_acc}
            end

          # Handle tuple format {dep_id, version_req}
          {dep_id, version_req},
          {missing_acc, miss_ver_acc, inv_ver_fmt_acc, inv_req_acc,
           mismatch_acc, opt_missing_acc} ->
            case Map.get(loaded_plugins, dep_id) do
              nil ->
                {missing_acc ++ [dep_id], miss_ver_acc, inv_ver_fmt_acc,
                 inv_req_acc, mismatch_acc, opt_missing_acc}

              plugin when is_map(plugin) ->
                case plugin do
                  %{version: nil} ->
                    {missing_acc, miss_ver_acc ++ [dep_id], inv_ver_fmt_acc,
                     inv_req_acc, mismatch_acc, opt_missing_acc}

                  %{version: version} ->
                    case Raxol.Core.Runtime.Plugins.DependencyManager.Version.check_version(
                           version,
                           version_req
                         ) do
                      :ok ->
                        {missing_acc, miss_ver_acc, inv_ver_fmt_acc,
                         inv_req_acc, mismatch_acc, opt_missing_acc}

                      {:error, :invalid_version_format} ->
                        {missing_acc, miss_ver_acc, inv_ver_fmt_acc ++ [dep_id],
                         inv_req_acc, mismatch_acc, opt_missing_acc}

                      {:error, :invalid_requirement_format} ->
                        {missing_acc, miss_ver_acc, inv_ver_fmt_acc,
                         inv_req_acc ++ [dep_id], mismatch_acc, opt_missing_acc}

                      {:error, :invalid_version_requirement} ->
                        {missing_acc, miss_ver_acc, inv_ver_fmt_acc,
                         inv_req_acc ++ [dep_id], mismatch_acc, opt_missing_acc}

                      {:error, _reason} ->
                        {missing_acc, miss_ver_acc, inv_ver_fmt_acc,
                         inv_req_acc,
                         mismatch_acc ++ [{dep_id, version, version_req}],
                         opt_missing_acc}
                    end

                  _ ->
                    {missing_acc, miss_ver_acc ++ [dep_id], inv_ver_fmt_acc,
                     inv_req_acc, mismatch_acc, opt_missing_acc}
                end

              _ ->
                {missing_acc ++ [dep_id], miss_ver_acc, inv_ver_fmt_acc,
                 inv_req_acc, mismatch_acc, opt_missing_acc}
            end

          # Handle simple plugin_id
          dep_id,
          {missing_acc, miss_ver_acc, inv_ver_fmt_acc, inv_req_acc,
           mismatch_acc, opt_missing_acc}
          when is_binary(dep_id) ->
            if Map.has_key?(loaded_plugins, dep_id) do
              {missing_acc, miss_ver_acc, inv_ver_fmt_acc, inv_req_acc,
               mismatch_acc, opt_missing_acc}
            else
              {missing_acc ++ [dep_id], miss_ver_acc, inv_ver_fmt_acc,
               inv_req_acc, mismatch_acc, opt_missing_acc}
            end
        end)

      if Enum.any?(optional_missing) do
        Raxol.Core.Runtime.Log.info(
          "Optional dependencies not found for plugin #{plugin_id}: #{inspect(optional_missing)}"
        )
      end

      cond do
        Enum.any?(missing_version) ->
          {:error, :missing_version, Enum.reverse(missing_version),
           current_chain}

        Enum.any?(missing) ->
          {:error, :missing_dependencies, Enum.reverse(missing), current_chain}

        Enum.any?(invalid_version_format) ->
          {:error, :invalid_version_format,
           Enum.reverse(invalid_version_format), current_chain}

        Enum.any?(invalid_version_requirement) ->
          # If the test expects just {:error, :invalid_version_requirement, _}, return that
          {:error, :invalid_version_requirement,
           Enum.reverse(invalid_version_requirement), current_chain}

        Enum.any?(version_mismatches) ->
          {:error, :version_mismatch, Enum.reverse(version_mismatches),
           current_chain}

        true ->
          :ok
      end
    end
  end

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

    # 1. Self-dependency check
    case find_self_dependency(graph) do
      {:error, plugin_id, chain} ->
        {:error, :self_dependency, [plugin_id], chain}

      :ok ->
        :ok
    end

    # 2. Conflicting requirements check
    case find_conflicting_requirements(graph) do
      {:error, conflicts, chain} ->
        {:error, :conflicting_requirements, conflicts, chain}

      :ok ->
        :ok
    end

    # 3. Version mismatch check (simulate loaded_plugins as plugins with their own version)
    case find_version_mismatches(graph, plugins) do
      {:error, mismatches, chain} ->
        {:error, :version_mismatch, mismatches, chain}

      :ok ->
        :ok
    end

    # 4. Cycle detection (Tarjan's algorithm)
    case Resolver.tarjan_sort(graph) do
      {:ok, order} ->
        {:ok, order}

      {:error, cycle} ->
        {:error, :circular_dependency, cycle,
         Graph.build_dependency_chain(cycle, graph)}
    end
  end

  # --- Helper functions for error detection ---

  # Self-dependency: plugin depends on itself
  defp find_self_dependency(graph) do
    Enum.find_value(graph, :ok, fn {plugin_id, deps} ->
      if Enum.any?(deps, fn {dep_id, _, _} -> dep_id == plugin_id end) do
        {:error, plugin_id, [plugin_id]}
      else
        nil
      end
    end)
  end

  # Conflicting requirements: multiple dependencies on the same plugin with incompatible version requirements
  defp find_conflicting_requirements(graph) do
    Enum.find_value(graph, :ok, fn {plugin_id, deps} ->
      reqs = Enum.group_by(deps, fn {dep_id, _, _} -> dep_id end)

      conflict =
        Enum.find(reqs, fn {_dep_id, dep_list} ->
          length(dep_list) > 1 and not compatible_requirements?(dep_list)
        end)

      if conflict do
        {dep_id, dep_list} = conflict
        requirements = Enum.map(dep_list, fn {_, req, _} -> req end)
        {:error, [{dep_id, requirements}], [plugin_id, dep_id]}
      else
        nil
      end
    end)
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

  # Version mismatch: plugin depends on another with incompatible version
  defp find_version_mismatches(graph, plugins) do
    Enum.find_value(graph, :ok, fn {plugin_id, deps} ->
      mismatches =
        deps
        |> Enum.filter(fn {dep_id, req, _} ->
          dep = plugins[dep_id]
          version = dep && Map.get(dep, :version)

          if version && req do
            case Raxol.Core.Runtime.Plugins.DependencyManager.Version.check_version(
                   version,
                   req
                 ) do
              :ok -> false
              {:error, _} -> true
            end
          else
            false
          end
        end)
        |> Enum.map(fn {dep_id, req, _} -> {dep_id, plugins[dep_id][:version], req} end)

      if mismatches != [] do
        {:error, mismatches,
         [plugin_id | Enum.map(mismatches, fn {dep_id, _, _} -> dep_id end)]}
      else
        nil
      end
    end)
  end
end
