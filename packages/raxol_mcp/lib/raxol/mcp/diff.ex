defmodule Raxol.MCP.Diff do
  @moduledoc """
  Simple map diff utility for detecting resource/model changes.

  Compares two maps and returns which keys were added, removed, or changed.
  Used by the ToolSynchronizer to compute model projection diffs for
  streaming notifications.
  """

  @type diff_result :: %{
          added: %{term() => term()},
          removed: [term()],
          changed: %{term() => {old :: term(), new :: term()}}
        }

  @doc """
  Compute the diff between two maps.

  Returns a map with `:added`, `:removed`, and `:changed` keys.
  """
  @spec diff(map(), map()) :: diff_result()
  def diff(old, new) when is_map(old) and is_map(new) do
    old_keys = Map.keys(old) |> MapSet.new()
    new_keys = Map.keys(new) |> MapSet.new()

    added_keys = MapSet.difference(new_keys, old_keys)
    removed_keys = MapSet.difference(old_keys, new_keys)
    common_keys = MapSet.intersection(old_keys, new_keys)

    added = Map.take(new, MapSet.to_list(added_keys))
    removed = MapSet.to_list(removed_keys)

    changed =
      common_keys
      |> Enum.reduce(%{}, fn key, acc ->
        old_val = Map.get(old, key)
        new_val = Map.get(new, key)

        if old_val == new_val do
          acc
        else
          Map.put(acc, key, {old_val, new_val})
        end
      end)

    %{added: added, removed: removed, changed: changed}
  end

  @doc "Returns true if the diff contains any changes."
  @spec changed?(diff_result()) :: boolean()
  def changed?(%{added: added, removed: removed, changed: changed}) do
    map_size(added) > 0 or removed != [] or map_size(changed) > 0
  end
end
