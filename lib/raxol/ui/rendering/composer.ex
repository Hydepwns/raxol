defmodule Raxol.UI.Rendering.Composer do
  @moduledoc """
  Handles composition of UI rendering trees.
  """

  import Raxol.Guards
  require Raxol.Core.Runtime.Log

  @doc """
  Composes a render tree or command list from the layout tree.
  Currently a stub; in the future, this will build a render tree or command list,
  potentially processing diffs or layout-specific changes.
  """
  @spec compose_render_tree(
          layout_stage_output :: any(),
          new_tree_for_reference :: map() | nil,
          previous_composed_tree :: any()
        ) :: map() | any()
  def compose_render_tree(
        layout_data,
        _new_tree_for_reference,
        previous_composed_tree
      ) do
    Raxol.Core.Runtime.Log.debug(
      "Composition Stage: Starting with layout_data: #{inspect(layout_data)}, prev_composed_tree: #{inspect(previous_composed_tree)}"
    )

    do_compose_recursive(layout_data, previous_composed_tree)
  end

  # Renamed and modified do_compose_node to be recursive and diff-aware
  defp do_compose_recursive(current_layout_node, previous_composed_node)
       when map?(current_layout_node) do
    if can_reuse_previous_node?(current_layout_node, previous_composed_node) do
      log_reuse_previous_node(current_layout_node)
      previous_composed_node
    else
      log_recomposition_reason(current_layout_node, previous_composed_node)
      build_new_composed_node(current_layout_node, previous_composed_node)
    end
  end

  defp do_compose_recursive(current_layout_node, _previous_composed_node)
       when not map?(current_layout_node) do
    Raxol.Core.Runtime.Log.debug(
      "Composition Stage: Passing through non-map primitive node: #{inspect(current_layout_node)}"
    )

    %{composed_type: :primitive, value: current_layout_node}
  end

  defp do_compose_recursive(nil, _previous_composed_node) do
    Raxol.Core.Runtime.Log.debug(
      "Composition Stage: Encountered nil layout node."
    )

    nil
  end

  defp can_reuse_previous_node?(current_layout_node, previous_composed_node) do
    map?(current_layout_node[:layout_attrs]) &&
      current_layout_node[:layout_attrs][:processed_with_diff] == :no_change &&
      map?(previous_composed_node) &&
      current_layout_node_type(current_layout_node) ==
        previous_composed_node[:original_type]
  end

  defp log_reuse_previous_node(current_layout_node) do
    Raxol.Core.Runtime.Log.debug(
      "Composition Stage: Reusing previous composed node for type: #{current_layout_node_type(current_layout_node)}"
    )
  end

  defp build_new_composed_node(current_layout_node, previous_composed_node) do
    original_type = current_layout_node_type(current_layout_node)
    layout_attrs = current_layout_node[:layout_attrs]

    properties_to_carry_forward =
      Map.drop(current_layout_node, [:children, :layout_attrs, :type])

    composed_children =
      build_composed_children(current_layout_node, previous_composed_node)

    %{
      composed_type: :composed_element,
      original_type: original_type,
      attributes: layout_attrs,
      properties: properties_to_carry_forward,
      children: composed_children
    }
  end

  defp build_composed_children(current_layout_node, previous_composed_node) do
    (current_layout_node[:children] || [])
    |> Enum.with_index()
    |> Enum.map(fn {child_layout_node, idx} ->
      prev_child_composed_node = get_previous_child(previous_composed_node, idx)
      do_compose_recursive(child_layout_node, prev_child_composed_node)
    end)
  end

  defp current_layout_node_type(node) do
    if map?(node), do: Map.get(node, :type, nil), else: nil
  end

  defp get_previous_child(previous_composed_node, idx) do
    if map?(previous_composed_node) && previous_composed_node[:children] do
      Enum.at(previous_composed_node[:children], idx)
    else
      nil
    end
  end

  defp log_recomposition_reason(current_layout_node, previous_composed_node) do
    if map?(previous_composed_node) do
      cond do
        not map?(current_layout_node[:layout_attrs]) ->
          Raxol.Core.Runtime.Log.debug(
            "Composition Stage: Re-composing node #{current_layout_node_type(current_layout_node)} - missing layout_attrs."
          )

        current_layout_node[:layout_attrs][:processed_with_diff] != :no_change ->
          Raxol.Core.Runtime.Log.debug(
            "Composition Stage: Re-composing node #{current_layout_node_type(current_layout_node)} - diff type: #{current_layout_node[:layout_attrs][:processed_with_diff]}"
          )

        current_layout_node_type(current_layout_node) !=
            previous_composed_node[:original_type] ->
          Raxol.Core.Runtime.Log.debug(
            "Composition Stage: Re-composing node #{current_layout_node_type(current_layout_node)} vs prev #{previous_composed_node[:original_type]} - type mismatch."
          )

        true ->
          Raxol.Core.Runtime.Log.debug(
            "Composition Stage: Re-composing node #{current_layout_node_type(current_layout_node)} - other reason or first time."
          )
      end
    else
      Raxol.Core.Runtime.Log.debug(
        "Composition Stage: Composing new node (no valid previous) for type: #{current_layout_node_type(current_layout_node)}"
      )
    end
  end
end
