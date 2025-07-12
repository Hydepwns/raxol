defmodule Raxol.UI.Rendering.Layouter do
  @moduledoc """
  Handles layout of UI components.
  """

  import Raxol.Guards
  require Raxol.Core.Runtime.Log

  @spec layout_tree(diff_result :: any(), new_tree_for_reference :: map() | nil) ::
          map() | any()
  def layout_tree(diff_result, new_tree_for_reference) do
    case diff_result do
      {:replace, tree_to_layout} ->
        Raxol.Core.Runtime.Log.debug(
          "Layout Stage: Full layout due to :replace"
        )

        do_layout_node_and_children(tree_to_layout, {:replace, tree_to_layout})

      :no_change ->
        Raxol.Core.Runtime.Log.debug(
          "Layout Stage: Layout for :no_change (processing new_tree_for_reference)"
        )

        do_layout_node_and_children(new_tree_for_reference, :no_change)

      {:update, path, child_changes_list} ->
        Raxol.Core.Runtime.Log.debug(
          "Layout Stage: Partial layout for node at path #{inspect(path)} due to child changes: #{inspect(child_changes_list)}"
        )

        handle_update_diff(path, child_changes_list, new_tree_for_reference)

      _otherwise ->
        handle_otherwise_diff(diff_result)
    end
  end

  defp handle_update_diff([], child_changes_list, new_tree_for_reference) do
    do_layout_node_and_children(
      new_tree_for_reference,
      {:update_children, child_changes_list}
    )
  end

  defp handle_update_diff(path, child_changes_list, new_tree_for_reference) do
    access_path = path_to_access_path(path)

    update_in(
      new_tree_for_reference,
      access_path,
      &update_node_at_path(&1, access_path, child_changes_list)
    )
  end

  defp update_node_at_path(nil, access_path, _child_changes_list) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Layout Stage: Node not found at access path #{inspect(access_path)} during :update. Skipping.",
      %{}
    )

    nil
  end

  defp update_node_at_path(node_at_path, _access_path, child_changes_list) do
    do_layout_node_and_children(
      node_at_path,
      {:update_children, child_changes_list}
    )
  end

  defp handle_otherwise_diff(diff_result) do
    if map?(diff_result) do
      Raxol.Core.Runtime.Log.debug(
        "Layout Stage: Input is a map, treating as full layout: #{inspect(diff_result)}"
      )

      do_layout_node_and_children(diff_result, {:replace, diff_result})
    else
      Raxol.Core.Runtime.Log.warning_with_context(
        "Layout Stage: Unhandled diff_result type or non-map input: #{inspect(diff_result)}",
        %{}
      )

      diff_result
    end
  end

  defp do_layout_node_and_children(nil, _diff), do: nil

  defp do_layout_node_and_children(node_content, _diff_for_this_node)
       when not map?(node_content) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Layout Engine: Encountered non-map node content: #{inspect(node_content)}. Passing through.",
      %{}
    )

    node_content
  end

  defp do_layout_node_and_children(node_content, diff_for_this_node)
       when map?(node_content) do
    current_node_actual_content =
      get_current_node_content(node_content, diff_for_this_node)

    node_with_own_layout = add_layout_attrs(current_node_actual_content)

    processed_children =
      process_children(node_with_own_layout, diff_for_this_node)

    update_node_children(node_with_own_layout, processed_children)
  end

  defp get_current_node_content(node_content, diff_for_this_node) do
    case diff_for_this_node do
      {:replace, new_content_for_this_node}
      when map?(new_content_for_this_node) ->
        new_content_for_this_node

      {:replace, _} ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Layout Engine: Node replaced with non-map content: #{inspect(diff_for_this_node)}. Using original node_content for safety.",
          %{}
        )

        node_content

      _ ->
        node_content
    end
  end

  defp add_layout_attrs(node_content) do
    Map.put(node_content, :layout_attrs, dummy_layout_for_node(node_content))
  end

  defp process_children(node_with_own_layout, diff_for_this_node) do
    children = get_children(node_with_own_layout)

    case diff_for_this_node do
      {:replace, _} ->
        Enum.map(children, &do_layout_node_and_children(&1, {:replace, &1}))

      :no_change ->
        Enum.map(children, &do_layout_node_and_children(&1, :no_change))

      {:update_children, child_changes_list} ->
        map_child_changes_to_new_children_list(children, child_changes_list)

      _unknown_diff ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Layout Engine: Unhandled diff for node, doing full child relayout: #{inspect(diff_for_this_node)} on node #{inspect(get_node_type(node_with_own_layout))}",
          %{}
        )

        Enum.map(children, &do_layout_node_and_children(&1, {:replace, &1}))
    end
  end

  defp get_children(node) do
    if map?(node), do: Map.get(node, :children, []), else: []
  end

  defp get_node_type(node) do
    if map?(node), do: Map.get(node, :type, :unknown), else: :unknown
  end

  defp update_node_children(node, processed_children) do
    if Map.has_key?(node, :children) do
      %{node | children: processed_children}
    else
      node
    end
  end

  defp map_child_changes_to_new_children_list(
         children_in_current_node,
         child_diff_details_map
       ) do
    case child_diff_details_map do
      %{type: :indexed_children, diffs: indexed_child_diffs_list} ->
        # Process indexed child diffs
        Enum.reduce(
          indexed_child_diffs_list,
          children_in_current_node,
          &process_indexed_child_diff/2
        )

      %{type: :keyed_children, ops: keyed_child_ops} ->
        # Process keyed child operations
        Enum.reduce(
          keyed_child_ops,
          children_in_current_node,
          &process_keyed_child_op/2
        )

      _ ->
        # Unknown diff type, return original children
        children_in_current_node
    end
  end

  defp process_indexed_child_diff({index, child_diff}, acc) do
    case child_diff do
      {:replace, new_child} ->
        # Replace child at index
        List.replace_at(
          acc,
          index,
          do_layout_node_and_children(new_child, {:replace, new_child})
        )

      {:update, _child_path, child_changes} ->
        # Update child at index with partial changes
        current_child = Enum.at(acc, index)

        if current_child do
          updated_child =
            do_layout_node_and_children(
              current_child,
              {:update_children, child_changes}
            )

          List.replace_at(acc, index, updated_child)
        else
          acc
        end

      _ ->
        # Unknown diff type, keep original
        acc
    end
  end

  defp process_keyed_child_op({:key_add, _key, new_child}, acc) do
    # Add new child at the end (will be reordered by key_reorder op)
    acc ++ [do_layout_node_and_children(new_child, {:replace, new_child})]
  end

  defp process_keyed_child_op({:key_update, key, child_diff}, acc) do
    # Find and update existing child by key
    Enum.map(acc, fn child ->
      if map?(child) && Map.get(child, :key) == key do
        do_layout_node_and_children(child, child_diff)
      else
        child
      end
    end)
  end

  defp process_keyed_child_op({:key_remove, key}, acc) do
    # Remove child with matching key
    Enum.reject(acc, fn child ->
      map?(child) && Map.get(child, :key) == key
    end)
  end

  defp process_keyed_child_op({:key_reorder, new_keys_ordered}, acc) do
    # Reorder children according to new key order
    children_by_key =
      Map.new(acc, fn child ->
        if map?(child), do: {Map.get(child, :key), child}, else: {nil, child}
      end)

    Enum.map(new_keys_ordered, fn key ->
      Map.get(children_by_key, key)
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp process_keyed_child_op(_unknown_op, acc), do: acc

  defp path_to_access_path([]), do: []

  defp path_to_access_path(path_indices) when list?(path_indices) do
    Enum.reduce(path_indices, [], fn idx, acc ->
      acc ++ [:children, idx]
    end)
  end

  defp dummy_layout_for_node(node_content) do
    %{
      x: 0,
      y: 0,
      width: 10,
      height: 1,
      node_type:
        if(map?(node_content),
          do: Map.get(node_content, :type, :unknown),
          else: :unknown
        ),
      processed_with_diff: :full,
      timestamp: System.monotonic_time()
    }
  end
end
