defmodule Raxol.UI.Rendering.Painter do
  require Logger

  @doc """
  Paints the render tree into draw commands or buffer updates.
  Currently a stub; in the future, this will convert the render tree into draw commands,
  potentially processing diffs or composition-specific changes.
  """
  @spec paint(
          compose_stage_output :: any(),
          new_tree_for_reference :: map() | nil,
          previous_composed_tree :: any(),
          previous_painted_output :: list(map()) | nil
        ) :: list(map())
  def paint(
        composed_data,
        _new_tree_for_reference,
        previous_composed_tree,
        previous_painted_output
      ) do
    # If the composed_data is identical to the previous composed tree, reuse the previous painted output
    if composed_data === previous_composed_tree &&
         previous_painted_output != nil do
      Logger.debug(
        "Paint Stage: Reusing previous_painted_output as composed_data is identical to previous_composed_tree."
      )

      previous_painted_output
    else
      if composed_data === previous_composed_tree do
        Logger.debug(
          "Paint Stage: composed_data is identical, but no previous_painted_output to reuse. Repainting."
        )
      else
        Logger.debug(
          "Paint Stage: composed_data differs from previous_composed_tree or no previous. Repainting. Details: composed_data: #{inspect(composed_data)}, prev_composed_tree: #{inspect(previous_composed_tree)}"
        )
      end

      Logger.debug(
        "Paint Stage: Starting with composed_stage_output: #{inspect(composed_data)}"
      )

      # Initial parent offsets are 0,0
      do_paint_node(composed_data, 0, 0)
    end
  end

  defp do_paint_node(nil, _parent_x, _parent_y), do: []

  defp do_paint_node(composed_node, parent_x_offset, parent_y_offset)
       when not is_map(composed_node) do
    Logger.warn(
      "Paint Stage: Encountered non-map node, expected composed map structure: #{inspect(composed_node)}"
    )

    []
  end

  defp do_paint_node(composed_node, parent_x_offset, parent_y_offset) do
    paint_ops_for_current_node =
      case composed_node[:composed_type] do
        :composed_element ->
          # Fallback for safety
          attrs =
            composed_node[:attributes] || %{x: 0, y: 0, width: 0, height: 0}

          original_type = composed_node[:original_type]
          properties = composed_node[:properties] || %{}

          # For dummy layout, attributes.x and .y are absolute. If they were relative, we'd add parent_x_offset.
          # current_node_x = attrs.x + parent_x_offset
          # current_node_y = attrs.y + parent_y_offset
          current_node_x = attrs.x
          current_node_y = attrs.y

          paint_op = %{
            op: :draw_element,
            element_type: original_type,
            x: current_node_x,
            y: current_node_y,
            width: attrs.width,
            height: attrs.height,
            properties: properties,
            # Example: if properties contain text, make it explicit for renderer
            text_content:
              properties[:text] || properties[:label] || properties[:value]
          }

          Logger.debug(
            "Paint Stage: Generated draw_element op for #{original_type}: #{inspect(paint_op)}"
          )

          [paint_op]

        :primitive ->
          value = composed_node[:value]

          paint_op = %{
            op: :draw_primitive,
            value: value,
            # Primitives are typically positioned by their parent container at the parent's current drawing cursor/offset
            x: parent_x_offset,
            y: parent_y_offset,
            primitive_type:
              if(is_binary(value),
                do: :text,
                else: if(is_number(value), do: :number, else: :unknown)
              )
          }

          Logger.debug(
            "Paint Stage: Generated draw_primitive op: #{inspect(paint_op)}"
          )

          [paint_op]

        :unprocessed_map_wrapper ->
          Logger.warn(
            "Paint Stage: Encountered :unprocessed_map_wrapper for node: #{inspect(composed_node[:original_node][:type])}. Painting children only."
          )

          # Don't paint the wrapper itself, only its children (handled below)
          []

        unknown_type ->
          Logger.warn(
            "Paint Stage: Unknown composed_type: #{inspect(unknown_type)} for node: #{inspect(composed_node)}"
          )

          []
      end

    children_paint_ops =
      (composed_node[:children] || [])
      |> Enum.flat_map(fn child_node ->
        # If current node was :composed_element, children are positioned relative to ITS x,y
        # For now, assuming dummy layout gives absolute x,y for all elements, so child_parent_offset is just parent's.
        # A more sophisticated layout would require passing the current element's absolute x,y as parent offset for children.
        # With current absolute dummy layout from `layout_tree`, children will use their own absolute attrs.x/y.
        # So, the parent_x_offset/parent_y_offset passed to children effectively becomes the container's origin for them IF their layout was relative.
        # Since layout is absolute in the dummy version, we can pass 0,0 or the current parent_x_offset, it won't change the child's absolute position.
        # Let's stick to passing parent_x_offset, parent_y_offset for consistency if layout became relative.
        child_parent_x =
          if composed_node[:composed_type] == :composed_element,
            do: (composed_node[:attributes] || %{})[:x] || 0,
            else: parent_x_offset

        child_parent_y =
          if composed_node[:composed_type] == :composed_element,
            do: (composed_node[:attributes] || %{})[:y] || 0,
            else: parent_y_offset

        do_paint_node(child_node, child_parent_x, child_parent_y)
      end)

    paint_ops_for_current_node ++ children_paint_ops
  end
end
