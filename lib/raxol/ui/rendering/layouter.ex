defmodule Raxol.UI.Rendering.Layouter do
  require Logger

  @doc """
  Computes the layout for the given UI tree.
  Currently a stub; in the future, this will calculate positions and sizes for all UI elements,
  potentially processing diffs for partial updates.
  """
  @spec layout_tree(diff_result :: any(), new_tree_for_reference :: map() | nil) ::
          map() | any()
  def layout_tree(diff_result, new_tree_for_reference) do
    case diff_result do
      {:replace, tree_to_layout} ->
        Logger.debug("Layout Stage: Full layout due to :replace")

        # Pass the tree_to_layout as the content, and indicate it's a full replace for context
        do_layout_node_and_children(tree_to_layout, {:replace, tree_to_layout})

      :no_change ->
        Logger.debug(
          "Layout Stage: Layout for :no_change (processing new_tree_for_reference)"
        )

        do_layout_node_and_children(new_tree_for_reference, :no_change)

      {:update, path, child_changes_list} ->
        Logger.debug(
          "Layout Stage: Partial layout for node at path #{inspect(path)} due to child changes: #{inspect(child_changes_list)}"
        )

        access_path = path_to_access_path(path)

        # Update is for the root node itself, affecting its children
        if path == [] do
          do_layout_node_and_children(
            new_tree_for_reference,
            {:update_children, child_changes_list}
          )
        else
          update_in(new_tree_for_reference, access_path, fn node_at_path ->
            if node_at_path do
              do_layout_node_and_children(
                node_at_path,
                {:update_children, child_changes_list}
              )
            else
              Logger.warning(
                "Layout Stage: Node not found at access path #{inspect(access_path)} during :update. Skipping.",
                []
              )

              # Or handle as error
              nil
            end
          end)
        end

      # This might be a direct tree passed if API evolves, or unhandled diff
      _otherwise ->
        if is_map(diff_result) do
          Logger.debug(
            "Layout Stage: Input is a map, treating as full layout: #{inspect(diff_result)}"
          )

          do_layout_node_and_children(diff_result, {:replace, diff_result})
        else
          Logger.warning(
            "Layout Stage: Unhandled diff_result type or non-map input: #{inspect(diff_result)}",
            []
          )

          # Pass through non-map or unknown diffs
          diff_result
        end
    end
  end

  # Recursive worker: takes a node (from new tree) and its specific diff, returns node with layout.
  defp do_layout_node_and_children(nil, _diff), do: nil

  defp do_layout_node_and_children(node_content, diff_for_this_node)
       when not is_map(node_content) do
    Logger.warning(
      "Layout Engine: Encountered non-map node content: #{inspect(node_content)}. Passing through.",
      []
    )

    # Pass through non-map content (e.g. if a child is a string or number)
    node_content
  end

  defp do_layout_node_and_children(node_content, diff_for_this_node)
       when is_map(node_content) do
    # 1. Determine actual content of this node based on diff_for_this_node
    current_node_actual_content =
      case diff_for_this_node do
        {:replace, new_content_for_this_node}
        when is_map(new_content_for_this_node) ->
          new_content_for_this_node

        # Replaced with non-map, should be caught by guard or logged
        {:replace, _} ->
          Logger.warning(
            "Layout Engine: Node replaced with non-map content: #{inspect(diff_for_this_node)}. Using original node_content for safety.",
            []
          )

          # Fallback to original if replacement is invalid
          node_content

        # For :no_change, :update_children, use the passed `node_content`
        _ ->
          node_content
      end

    # 2. Calculate layout for current_node_actual_content (dummy)
    node_with_own_layout =
      Map.put(
        current_node_actual_content,
        :layout_attrs,
        dummy_layout_for_node(current_node_actual_content, diff_for_this_node)
      )

    # 3. Process children
    processed_children =
      case diff_for_this_node do
        # Full replace, so all children of new content are processed as new
        {:replace, _} ->
          (node_with_own_layout[:children] || [])
          |> Enum.map(&do_layout_node_and_children(&1, {:replace, &1}))

        # This node's content/props didn't change. Children also :no_change individually.
        :no_change ->
          (node_with_own_layout[:children] || [])
          |> Enum.map(&do_layout_node_and_children(&1, :no_change))

        # Parent node itself didn't change type/props, but children did.
        {:update_children, child_changes_list} ->
          children_from_current_content = node_with_own_layout[:children] || []

          map_child_changes_to_new_children_list(
            children_from_current_content,
            child_changes_list
          )

        # Should not happen if diff_for_this_node is one of the above types
        _unknown_diff ->
          Logger.warning(
            "Layout Engine: Unhandled diff for node, doing full child relayout: #{inspect(diff_for_this_node)} on node #{inspect(node_with_own_layout[:type])}"
          )

          (node_with_own_layout[:children] || [])
          # Safest fallback: treat children as new
          |> Enum.map(&do_layout_node_and_children(&1, {:replace, &1}))
      end

    %{node_with_own_layout | children: processed_children}
  end

  # Helper for processing children when parent has {:update_children, child_changes_list}
  defp map_child_changes_to_new_children_list(
         children_in_current_node,
         child_diff_details_map
       ) do
    # children_in_current_node is the NEW list of children from the parent node being laid out.
    # child_diff_details_map is %{type: :indexed_children | :keyed_children, ...}

    case child_diff_details_map do
      %{type: :indexed_children, diffs: indexed_child_diffs_list} ->
        # indexed_child_diffs_list is [{idx, diff_for_child_at_that_idx_in_old_list}]
        # We are iterating `children_in_current_node` (the new list).
        # We need to find the diff for the child at the current new_idx.
        # This requires knowing the mapping from old_idx to new_idx if children were reordered
        # without keyed diffing, which indexed diffing doesn't handle well.
        # The `indexed_child_diffs_list`'s indices refer to the *original zipped list*.

        # Let's assume `children_in_current_node` is the new list.
        # The `indexed_child_diffs_list` gives diffs based on original positions.
        # This part is tricky if non-keyed children are reordered.
        # For simplicity, assume `layout_tree` gets the `new_tree_for_reference`.
        # If `diff_trees` said child at old index 0 was `{:replace, new_child_content}`,
        # and `children_in_current_node[0]` is that `new_child_content`, then it's simple.

        # The `diffs` in `indexed_children` is `[{original_idx, diff_result_for_child_at_original_idx}]`
        # `diff_result_for_child_at_original_idx` could be `{:replace, new_content}` or
        # `{:update, path_to_that_child, further_changes}`.
        # `map_child_changes_to_new_children_list` receives the new list of children.
        # It needs to pass the correct diff for each of these new children.

        # diffs_by_old_idx = Map.new(indexed_child_diffs_list) # This line seems unused, consider removing if confirmed.

        # This isn't quite right for indexed diffs if reordering happened.
        # The current `layout_tree` iterates `new_tree_for_reference`.
        # Let's reconsider. `diff_for_this_child` should be the diff that *resulted* in `child_node_content`.
        # If `child_node_content` is a new child (e.g. length increased), diff is {:replace, child_node_content}.
        # If `child_node_content` corresponds to an old child that changed, we need that diff.

        # The `diffs` in `indexed_children` from `perform_non_keyed_children_diff` are:
        # [{idx, diff_for_child_at_idx}] where `idx` is from `zip_longest`.
        # `diff_for_child_at_idx` is the result of `do_diff_trees(old_child_at_idx, new_child_at_idx, path_to_child_at_idx)`.
        # This `diff_for_child_at_idx` is exactly what we need for `do_layout_node_and_children`.

        # So, we iterate the NEW children. For each new child at `new_idx`,
        # we find its corresponding diff from `indexed_child_diffs_list`.
        # This assumes a correlation between `new_idx` and the `idx` from `zip_longest`.
        # This is true if there are no pure insertions/deletions that shift indices misaligningly.
        # `zip_longest` handles this: `{{old, new}, idx}`. `idx` is the common sequence index.

        Enum.with_index(children_in_current_node)
        |> Enum.map(fn {child_node_content, idx} ->
          # Find the diff that corresponds to this child at this new index `idx`.
          # The `diffs` are `[{original_zip_idx, diff_content}]`.
          # `original_zip_idx` aligns with `idx` here.
          associated_diff_tuple =
            Enum.find(indexed_child_diffs_list, fn {original_idx, _} ->
              original_idx == idx
            end)

          diff_for_this_child_node =
            if associated_diff_tuple do
              # The actual diff object
              elem(associated_diff_tuple, 1)
            else
              # No diff reported for this index, means it must be :no_change,
              # or it's a new child beyond the length of old_children (zip_longest gives {nil, new_child}).
              # If it was {nil, new_child}, diff would be {:replace, new_child}.
              # This 'else' implies it was {old_child, new_child} and diff was :no_change.
              # Or, if new list is shorter, this idx won't be hit.
              # If new list is longer, and old was shorter, {nil, new_child} -> diff is {:replace, new_child}
              # This case should be covered by `associated_diff_tuple` containing `{:replace, child_node_content}`
              # So, if not found, it implies :no_change was elided from `indexed_child_diffs_list`.
              :no_change
            end

          do_layout_node_and_children(
            child_node_content,
            diff_for_this_child_node
          )
        end)

      %{type: :keyed_children, ops: key_ops_list} ->
        # `children_in_current_node` is the NEW list of children, already in the correct order.
        # `key_ops_list` contains:
        #   {:key_update, key, child_diff}
        #   {:key_add, key, new_node_content_from_diff}
        #   {:key_remove, key} (irrelevant for laying out new children)
        #   {:key_reorder, new_keys_ordered} (implicitly handled by iterating children_in_current_node)

        # Create a map of diffs per key for quick lookup
        diff_map_for_keys =
          Enum.reduce(key_ops_list, %{}, fn op, acc ->
            case op do
              {:key_update, key, specific_child_diff} ->
                Map.put(acc, key, specific_child_diff)

              # For adds, the diff is effectively a "replace with self" from nil
              {:key_add, key, added_node_content} ->
                Map.put(acc, key, {:replace, added_node_content})

              # Ignore :key_remove, :key_reorder for this map
              _ ->
                acc
            end
          end)

        Enum.map(children_in_current_node, fn child_node_content ->
          # All children in `children_in_current_node` (which are new children) MUST have a key if this path is taken.
          # This is ensured by `are_children_consistently_keyed?` on the new children list.
          key = child_node_content[:key]

          diff_to_pass_to_layout = Map.get(diff_map_for_keys, key, :no_change)
          # If key is not in diff_map_for_keys:
          # - It wasn't added (no :key_add op).
          # - It wasn't updated (no :key_update op).
          # This means it's an existing child whose content didn't change (it might have moved, but content is same).
          # So, :no_change is the correct diff to pass for layout.

          do_layout_node_and_children(
            child_node_content,
            diff_to_pass_to_layout
          )
        end)

      # Fallback for unexpected child_diff_details_map structure
      other_diff_details ->
        Logger.warning(
          "Layout Engine: Encountered unknown child_diff_details_map type in map_child_changes_to_new_children_list: #{inspect(other_diff_details)}. Performing full layout for children."
        )

        Enum.map(children_in_current_node, fn child_node ->
          # Treat as new
          do_layout_node_and_children(child_node, {:replace, child_node})
        end)
    end
  end

  # Converts a diff path (list of child indices) to an Elixir Access path
  # Refers to the root node itself
  defp path_to_access_path([]), do: []

  defp path_to_access_path(path_indices) when is_list(path_indices) do
    # e.g., path_indices = [0, 1] means tree.children[0].children[1]
    # Access path should be [:children, 0, :children, 1]
    Enum.reduce(path_indices, [], fn idx, acc ->
      acc ++ [:children, idx]
    end)
  end

  defp dummy_layout_for_node(node_content, diff_type \\ :full) do
    %{
      # Placeholder values
      x: 0,
      y: 0,
      width: 10,
      height: 1,
      node_type: node_content[:type] || :unknown,
      processed_with_diff: diff_type,
      timestamp: System.monotonic_time()
    }
  end
end
