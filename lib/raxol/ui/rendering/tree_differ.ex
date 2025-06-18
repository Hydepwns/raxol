defmodule Raxol.UI.Rendering.TreeDiffer do
  @moduledoc """
  Provides functions to compute the difference (diff) between two UI trees.
  This module is responsible for identifying changes, additions, removals,
  and reordering of nodes, supporting both keyed and non-keyed children.
  """

  require Raxol.Core.Runtime.Log

  @doc """
  Computes the minimal set of changes (diff) between two UI trees.

  Returns:
    * :no_change if trees are identical
    * {:replace, new_tree} if the root node differs significantly
    * {:update, path, changes} for subtree updates. `path` is a list of indices
      to the parent node, and `changes` describes the modifications to its children
      (either as indexed diffs or keyed operations).

  The `path` in `{:update, path, changes}` always refers to the parent node whose
  children have changed. For keyed children, the recursive diffs for individual
  children (e.g., in `{:key_update, key, child_diff}`) will have their own paths
  relative to that child (i.e., starting with `[]` if the child itself is the root
  of that sub-diff).
  """
  @spec diff_trees(old_tree :: map() | nil, new_tree :: map() | nil) ::
          :no_change
          | {:replace, map()}
          | {:update, [integer()], any()}
  def diff_trees(old_tree, new_tree), do: do_diff_trees(old_tree, new_tree, [])

  defp do_diff_trees(nil, nil, _path), do: :no_change
  defp do_diff_trees(nil, new, _path), do: {:replace, new}
  defp do_diff_trees(old, nil, _path), do: {:replace, nil}
  # Path incorporated in update return
  defp do_diff_trees(old, new, _path) when old == new, do: :no_change

  defp do_diff_trees(%{type: t1} = _old, %{type: t2} = new, _path)
       when t1 != t2 do
    # Path is not used here because it's a full replacement from the root of this comparison.
    # If this diff_trees call was for a child, the caller (e.g., another do_diff_trees for parent)
    # would associate this {:replace, new} with the child's path/key.
    {:replace, new}
  end

  defp do_diff_trees(
         %{type: _type, children: old_children} = _old,
         %{type: _type, children: new_children} = _new,
         path
       ) do
    attempt_keyed_diff =
      are_children_consistently_keyed?(old_children) &&
        are_children_consistently_keyed?(new_children)

    if attempt_keyed_diff do
      perform_keyed_children_diff(old_children, new_children, path)
    else
      perform_non_keyed_children_diff(old_children, new_children, path)
    end
  end

  # Fallback for non-map nodes or nodes without :children that are not identical
  defp do_diff_trees(_old, new, _path), do: {:replace, new}

  # Helper to check if a list of children is consistently keyed
  defp are_children_consistently_keyed?(children) when is_list(children) do
    if Enum.empty?(children) do
      # An empty list is vacuously considered keyed
      true
    else
      Enum.all?(children, fn
        child when is_map(child) -> Map.has_key?(child, :key)
        _non_map_child -> false
      end)
    end
  end

  defp are_children_consistently_keyed?(_other), do: false

  defp validate_child_has_key!(nil, _list_name), do: :ok

  defp validate_child_has_key!(child, list_name) when not is_map(child) do
    Raxol.Core.Runtime.Log.warning(
      "Keyed diffing expected map child in #{list_name}, got: #{inspect(child)}. Problems may occur."
    )

    :ok
  end

  defp validate_child_has_key!(child, list_name) do
    if !Map.has_key?(child, :key) do
      Raxol.Core.Runtime.Log.error(
        "Child in #{list_name} is missing :key for keyed diffing: #{inspect(child)}"
      )

      # Consider raising: raise ArgumentError, "Child in #{list_name} missing :key: #{inspect(child)}"
    end

    :ok
  end

  defp perform_non_keyed_children_diff(old_children, new_children, path) do
    child_diffs =
      zip_longest(old_children, new_children)
      |> Enum.with_index()
      |> Enum.map(fn
        {{old_child, new_child}, idx} ->
          # The path for `do_diff_trees` here is the path *to the child node itself*.
          # So, it's `path ++ [idx]`.
          # The `path` argument of `perform_non_keyed_children_diff` is path_to_parent.
          # The diff from `do_diff_trees` will be relative to this child.
          case do_diff_trees(old_child, new_child, path ++ [idx]) do
            :no_change -> nil
            diff_for_child_at_idx -> {idx, diff_for_child_at_idx}
          end
      end)
      |> Enum.reject(&is_nil/1)

    if child_diffs == [] do
      :no_change
    else
      # `path` here is path_to_parent.
      # `diffs` contains tuples `{original_child_idx, diff_for_child_at_idx}`.
      # `diff_for_child_at_idx` could be {:replace, new_content_for_child} or
      # {:update, child_path_segment, grandchild_changes} if the child itself had children that changed.
      # The `child_path_segment` in such an internal update would be relative to the child,
      # so if child was at path `P` and its own child at index `C` changed, the path in that
      # internal diff would be `[C]`.
      # The path stored in the diff entry `{idx, diff}` should reflect the *full path to the changed node*
      # if the diff is an :update.
      # However, `do_diff_trees` already returns paths like `path ++ [idx]` if it's an update.
      # So `diff_for_child_at_idx` will contain the correct full path if it's an update.
      {:update, path, %{type: :indexed_children, diffs: child_diffs}}
    end
  end

  defp perform_keyed_children_diff(
         old_children_list,
         new_children_list,
         path_to_parent
       ) do
    old_children_map_by_key =
      Map.new(old_children_list || [], fn child ->
        validate_child_has_key!(child, "old_children_list for keyed diff")
        {child[:key], child}
      end)

    new_children_map_by_key =
      Map.new(new_children_list || [], fn child ->
        validate_child_has_key!(child, "new_children_list for keyed diff")
        {child[:key], child}
      end)

    old_keys_set = Map.keys(old_children_map_by_key) |> MapSet.new()
    new_keys_set = Map.keys(new_children_map_by_key) |> MapSet.new()
    new_keys_ordered = Enum.map(new_children_list || [], & &1[:key])
    _ops = []

    ops =
      Enum.reduce(
        Enum.with_index(new_children_list || []),
        [],
        fn {new_child_node, _new_idx}, acc ->
          key = new_child_node[:key]

          if MapSet.member?(old_keys_set, key) do
            old_child_node = old_children_map_by_key[key]
            # Diff children relative to themselves, so path is [].
            # Any paths *inside* child_diff will be relative to the child.
            child_diff = do_diff_trees(old_child_node, new_child_node, [])

            if child_diff != :no_change do
              [{:key_update, key, child_diff} | acc]
            else
              acc
            end
          else
            [{:key_add, key, new_child_node} | acc]
          end
        end
      )

    ops =
      Enum.reduce(MapSet.to_list(old_keys_set), ops, fn old_key, acc ->
        if !MapSet.member?(new_keys_set, old_key) do
          [{:key_remove, old_key} | acc]
        else
          acc
        end
      end)

    final_ops_reversed = ops
    has_structural_changes = Enum.any?(final_ops_reversed, fn _ -> true end)
    old_keys_ordered = Enum.map(old_children_list || [], & &1[:key])
    order_changed = old_keys_ordered != new_keys_ordered

    cond do
      !has_structural_changes && !order_changed ->
        :no_change

      !has_structural_changes && order_changed ->
        {:update, path_to_parent,
         %{type: :keyed_children, ops: [{:key_reorder, new_keys_ordered}]}}

      true ->
        current_ops_in_processing_order = Enum.reverse(final_ops_reversed)

        all_ops_for_payload =
          if order_changed do
            current_ops_in_processing_order ++
              [{:key_reorder, new_keys_ordered}]
          else
            if current_ops_in_processing_order != [] do
              # Even if order hasn't changed, include reorder op if other ops exist,
              # simplifies consumer logic that might expect it.
              current_ops_in_processing_order ++
                [{:key_reorder, new_keys_ordered}]
            else
              # Should be empty, leading to :no_change
              current_ops_in_processing_order
            end
          end

        if all_ops_for_payload == [] && !order_changed do
          :no_change
        else
          if all_ops_for_payload == [{:key_reorder, new_keys_ordered}] &&
               !has_structural_changes && !order_changed do
            :no_change
          else
            {:update, path_to_parent,
             %{type: :keyed_children, ops: all_ops_for_payload}}
          end
        end
    end
  end

  # Zips two lists, padding with nil if lengths differ
  defp zip_longest([], []), do: []
  defp zip_longest([h1 | t1], []), do: [{h1, nil} | zip_longest(t1, [])]
  defp zip_longest([], [h2 | t2]), do: [{nil, h2} | zip_longest([], t2)]
  defp zip_longest([h1 | t1], [h2 | t2]), do: [{h1, h2} | zip_longest(t1, t2)]
end
