defmodule Raxol.Core.Runtime.Plugins.DependencyResolver do
  @moduledoc """
  Install-time and load-time dependency resolution for plugins.

  Uses Kahn's algorithm for topological sort with cycle detection,
  conflict checking, and capability matching.
  """

  alias Raxol.Core.Runtime.Plugins.Manifest

  @type resolution :: {:ok, load_order :: [atom()]} | {:error, reason()}
  @type reason ::
          {:cycle, [atom()]}
          | {:missing, plugin :: atom(), dependency :: atom()}
          | {:conflict, atom(), atom()}
          | {:unmet_capability, plugin :: atom(), capability :: atom()}

  @doc """
  Resolves load order for a set of manifests using topological sort.

  Returns `{:ok, [plugin_id]}` in dependency order (dependencies first),
  or `{:error, reason}` on failure.
  """
  @spec resolve([Manifest.t()]) :: resolution()
  def resolve(manifests) when is_list(manifests) do
    with :ok <- check_conflicts(manifests),
         :ok <- satisfy_capabilities(manifests),
         :ok <- check_missing_deps(manifests) do
      topo_sort(manifests)
    end
  end

  @doc """
  Resolves load order for new manifests given already-loaded plugin ids.

  Treats `already_loaded` as satisfied dependencies that don't need ordering.
  """
  @spec resolve_incremental([Manifest.t()], already_loaded :: [atom()]) ::
          resolution()
  def resolve_incremental(manifests, already_loaded) when is_list(manifests) do
    loaded_set = MapSet.new(already_loaded)
    all_ids = MapSet.union(loaded_set, MapSet.new(Enum.map(manifests, & &1.id)))

    missing =
      for m <- manifests,
          {dep_id, _} <- m.depends_on,
          dep_id not in all_ids,
          do: {m.id, dep_id}

    case missing do
      [] ->
        # Strip deps that are already loaded so topo_sort only sees new plugins
        stripped =
          Enum.map(manifests, fn m ->
            filtered_deps =
              Enum.reject(m.depends_on, fn {dep_id, _} ->
                dep_id in loaded_set
              end)

            %{m | depends_on: filtered_deps}
          end)

        topo_sort(stripped)

      [{plugin, dep} | _] ->
        {:error, {:missing, plugin, dep}}
    end
  end

  @doc """
  Checks for conflicts between manifests.
  """
  @spec check_conflicts([Manifest.t()]) ::
          :ok | {:error, {:conflict, atom(), atom()}}
  def check_conflicts(manifests) do
    id_set = MapSet.new(Enum.map(manifests, & &1.id))

    conflict =
      Enum.find_value(manifests, fn m ->
        Enum.find_value(m.conflicts_with, fn cid ->
          if cid in id_set, do: {m.id, cid}
        end)
      end)

    case conflict do
      nil -> :ok
      {a, b} -> {:error, {:conflict, a, b}}
    end
  end

  @doc """
  Checks that all `requires` capabilities are satisfied by some plugin's `provides`.
  """
  @spec satisfy_capabilities([Manifest.t()]) ::
          :ok | {:error, {:unmet_capability, atom(), atom()}}
  def satisfy_capabilities(manifests) do
    provided =
      manifests
      |> Enum.flat_map(& &1.provides)
      |> MapSet.new()

    unmet =
      Enum.find_value(manifests, fn m ->
        Enum.find_value(m.requires, fn cap ->
          if cap not in provided, do: {m.id, cap}
        end)
      end)

    case unmet do
      nil -> :ok
      {plugin, cap} -> {:error, {:unmet_capability, plugin, cap}}
    end
  end

  # -- Private: Kahn's algorithm --------------------------------------------

  defp check_missing_deps(manifests) do
    id_set = MapSet.new(Enum.map(manifests, & &1.id))

    missing =
      Enum.find_value(manifests, fn m ->
        Enum.find_value(m.depends_on, fn {dep_id, _} ->
          if dep_id not in id_set, do: {m.id, dep_id}
        end)
      end)

    case missing do
      nil -> :ok
      {plugin, dep} -> {:error, {:missing, plugin, dep}}
    end
  end

  defp topo_sort(manifests) do
    graph = build_graph(manifests)
    in_degrees = compute_in_degrees(manifests, graph)
    all_ids = Enum.map(manifests, & &1.id)

    queue =
      all_ids
      |> Enum.filter(fn id -> Map.get(in_degrees, id, 0) == 0 end)
      |> :queue.from_list()

    kahn_loop(queue, graph, in_degrees, [], length(all_ids))
  end

  defp build_graph(manifests) do
    for m <- manifests,
        {dep_id, _} <- m.depends_on,
        reduce: %{} do
      acc -> Map.update(acc, dep_id, [m.id], &[m.id | &1])
    end
  end

  defp compute_in_degrees(manifests, _graph) do
    for m <- manifests,
        {dep_id, _} <- m.depends_on,
        dep_id != m.id,
        reduce: Map.new(manifests, fn m -> {m.id, 0} end) do
      acc -> Map.update(acc, m.id, 1, &(&1 + 1))
    end
  end

  defp kahn_loop(queue, graph, in_degrees, sorted, total) do
    case :queue.out(queue) do
      {:empty, _} ->
        if length(sorted) == total do
          {:ok, Enum.reverse(sorted)}
        else
          cycle_ids =
            in_degrees
            |> Enum.filter(fn {_id, deg} -> deg > 0 end)
            |> Enum.map(fn {id, _} -> id end)

          {:error, {:cycle, cycle_ids}}
        end

      {{:value, id}, rest} ->
        neighbors = Map.get(graph, id, [])

        {new_queue, new_degrees} =
          Enum.reduce(neighbors, {rest, in_degrees}, fn neighbor, {q, degs} ->
            new_deg = Map.get(degs, neighbor, 0) - 1
            degs = Map.put(degs, neighbor, new_deg)

            if new_deg == 0 do
              {:queue.in(neighbor, q), degs}
            else
              {q, degs}
            end
          end)

        kahn_loop(new_queue, graph, new_degrees, [id | sorted], total)
    end
  end
end
