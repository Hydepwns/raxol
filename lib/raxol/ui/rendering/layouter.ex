defmodule Raxol.UI.Rendering.Layouter do
  require Raxol.Core.Runtime.Log

  @spec layout_tree(diff_result :: any(), new_tree_for_reference :: map() | nil) ::
          map() | any()
  def layout_tree(diff_result, new_tree_for_reference) do
    case diff_result do
      {:replace, tree_to_layout} ->
        Raxol.Core.Runtime.Log.debug("Layout Stage: Full layout due to :replace")
        do_layout_node_and_children(tree_to_layout, {:replace, tree_to_layout})
      :no_change ->
        Raxol.Core.Runtime.Log.debug("Layout Stage: Layout for :no_change (processing new_tree_for_reference)")
        do_layout_node_and_children(new_tree_for_reference, :no_change)
      {:update, path, child_changes_list} ->
        Raxol.Core.Runtime.Log.debug("Layout Stage: Partial layout for node at path #{inspect(path)} due to child changes: #{inspect(child_changes_list)}")
        access_path = path_to_access_path(path)
        if path == [] do
          do_layout_node_and_children(new_tree_for_reference, {:update_children, child_changes_list})
        else
          update_in(new_tree_for_reference, access_path, fn node_at_path ->
            if node_at_path do
              do_layout_node_and_children(node_at_path, {:update_children, child_changes_list})
            else
              Raxol.Core.Runtime.Log.warning_with_context("Layout Stage: Node not found at access path #{inspect(access_path)} during :update. Skipping.", %{})
              nil
            end
          end)
        end
      _otherwise ->
        if is_map(diff_result) do
          Raxol.Core.Runtime.Log.debug("Layout Stage: Input is a map, treating as full layout: #{inspect(diff_result)}")
          do_layout_node_and_children(diff_result, {:replace, diff_result})
        else
          Raxol.Core.Runtime.Log.warning_with_context("Layout Stage: Unhandled diff_result type or non-map input: #{inspect(diff_result)}", %{})
          diff_result
        end
    end
  end

  defp do_layout_node_and_children(nil, _diff), do: nil

  defp do_layout_node_and_children(node_content, diff_for_this_node)
       when not is_map(node_content) do
    Raxol.Core.Runtime.Log.warning_with_context("Layout Engine: Encountered non-map node content: #{inspect(node_content)}. Passing through.", %{})
    node_content
  end

  defp do_layout_node_and_children(node_content, diff_for_this_node)
       when is_map(node_content) do
    current_node_actual_content =
      case diff_for_this_node do
        {:replace, new_content_for_this_node} when is_map(new_content_for_this_node) ->
          new_content_for_this_node
        {:replace, _} ->
          Raxol.Core.Runtime.Log.warning_with_context("Layout Engine: Node replaced with non-map content: #{inspect(diff_for_this_node)}. Using original node_content for safety.", %{})
          node_content
        _ ->
          node_content
      end
    node_with_own_layout =
      Map.put(
        current_node_actual_content,
        :layout_attrs,
        dummy_layout_for_node(current_node_actual_content, diff_for_this_node)
      )
    processed_children =
      case diff_for_this_node do
        {:replace, _} ->
          Enum.map((if is_map(node_with_own_layout), do: Map.get(node_with_own_layout, :children, []), else: []), &do_layout_node_and_children(&1, {:replace, &1}))
        :no_change ->
          Enum.map((if is_map(node_with_own_layout), do: Map.get(node_with_own_layout, :children, []), else: []), &do_layout_node_and_children(&1, :no_change))
        {:update_children, child_changes_list} ->
          children = if is_map(node_with_own_layout), do: Map.get(node_with_own_layout, :children, []), else: []
          map_child_changes_to_new_children_list(children, child_changes_list)
        _unknown_diff ->
          Raxol.Core.Runtime.Log.warning_with_context("Layout Engine: Unhandled diff for node, doing full child relayout: #{inspect(diff_for_this_node)} on node #{inspect(if is_map(node_with_own_layout), do: Map.get(node_with_own_layout, :type, :unknown), else: :unknown)}", %{})
          Enum.map((if is_map(node_with_own_layout), do: Map.get(node_with_own_layout, :children, []), else: []), &do_layout_node_and_children(&1, {:replace, &1}))
      end
    %{node_with_own_layout | children: processed_children}
  end

  defp map_child_changes_to_new_children_list(children_in_current_node, child_diff_details_map) do
    case child_diff_details_map do
      %{type: :indexed_children, diffs: indexed_child_diffs_list} ->
        Raxol.Core.Runtime.Log.warning_with_context("Layout Engine: Unhandled indexed child diff type: #{inspect(indexed_child_diffs_list)}", [])
      %{type: :keyed_children, diffs: keyed_child_diffs_list} ->
        []
    end
  end

  defp path_to_access_path([]), do: []
  defp path_to_access_path(path_indices) when is_list(path_indices) do
    Enum.reduce(path_indices, [], fn idx, acc ->
      acc ++ [:children, idx]
    end)
  end

  defp dummy_layout_for_node(node_content, diff_type \\ :full) do
    %{
      x: 0,
      y: 0,
      width: 10,
      height: 1,
      node_type: (if is_map(node_content), do: Map.get(node_content, :type, :unknown), else: :unknown),
      processed_with_diff: diff_type,
      timestamp: System.monotonic_time()
    }
  end
end
