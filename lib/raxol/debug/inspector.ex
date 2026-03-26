defmodule Raxol.Debug.Inspector do
  @moduledoc """
  Pure functions for rendering a map/struct as an expandable tree.

  Flattens a nested map into displayable lines with indentation and
  expand/collapse markers. Used by the Debugger UI's model inspector panel.
  """

  @type line :: %{
          depth: non_neg_integer(),
          path: [term()],
          key: term(),
          value_preview: String.t(),
          expandable: boolean(),
          expanded: boolean()
        }

  @doc """
  Flattens a model (map) into a list of displayable lines.

  Each line includes its depth, key path, a preview string, and whether
  it's expandable (has nested map children). The `expanded_paths` MapSet
  controls which nodes show their children.

  ## Parameters
    - `model` - The map/struct to inspect
    - `expanded_paths` - MapSet of key paths that are expanded

  ## Returns
    List of `line()` maps suitable for rendering.
  """
  @spec flatten(term(), MapSet.t()) :: [line()]
  def flatten(model, expanded_paths \\ MapSet.new()) do
    flatten_value(model, [], 0, expanded_paths)
  end

  @doc """
  Toggles a path in the expanded set. Returns the updated MapSet.
  """
  @spec toggle(MapSet.t(), [term()]) :: MapSet.t()
  def toggle(expanded_paths, path) do
    if MapSet.member?(expanded_paths, path) do
      MapSet.delete(expanded_paths, path)
    else
      MapSet.put(expanded_paths, path)
    end
  end

  @doc """
  Expands all paths in the model to the given depth.
  """
  @spec expand_all(term(), non_neg_integer()) :: MapSet.t()
  def expand_all(model, max_depth \\ 3) do
    collect_paths(model, [], 0, max_depth, MapSet.new())
  end

  # -- Private --

  defp flatten_value(model, path, depth, expanded_paths) when is_map(model) do
    keys = sorted_keys(model)

    Enum.flat_map(keys, fn key ->
      value = Map.get(model, key)
      child_path = path ++ [key]
      expandable = is_map(value) and map_size(value) > 0

      expanded =
        expandable and MapSet.member?(expanded_paths, child_path)

      line = %{
        depth: depth,
        path: child_path,
        key: key,
        value_preview: preview(value),
        expandable: expandable,
        expanded: expanded
      }

      if expanded do
        [line | flatten_value(value, child_path, depth + 1, expanded_paths)]
      else
        [line]
      end
    end)
  end

  defp flatten_value(_value, _path, _depth, _expanded_paths), do: []

  defp sorted_keys(%{__struct__: _} = s) do
    s |> Map.from_struct() |> Map.keys() |> Enum.sort()
  end

  defp sorted_keys(map) when is_map(map) do
    map |> Map.keys() |> Enum.sort()
  end

  defp preview(value) when is_map(value) do
    count = map_size(value)
    "{#{count} #{if count == 1, do: "key", else: "keys"}}"
  end

  defp preview(value) when is_list(value) do
    "[#{length(value)} items]"
  end

  defp preview(value) do
    str = inspect(value, limit: 5, printable_limit: 60)

    if String.length(str) > 60 do
      String.slice(str, 0, 57) <> "..."
    else
      str
    end
  end

  defp collect_paths(model, path, depth, max_depth, acc)
       when is_map(model) and depth < max_depth do
    keys = sorted_keys(model)

    Enum.reduce(keys, acc, fn key, paths ->
      value = Map.get(model, key)
      child_path = path ++ [key]

      if is_map(value) and map_size(value) > 0 do
        paths
        |> MapSet.put(child_path)
        |> then(&collect_paths(value, child_path, depth + 1, max_depth, &1))
      else
        paths
      end
    end)
  end

  defp collect_paths(_model, _path, _depth, _max_depth, acc), do: acc
end
