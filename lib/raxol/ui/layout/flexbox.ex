defmodule Raxol.UI.Layout.Flexbox do
  @moduledoc """
  Modern Flexbox layout system for Raxol UI components.

  This module provides CSS Flexbox-compatible layout calculations with support for:
  - Flex direction (row, column, row-reverse, column-reverse)
  - Justify content (flex-start, flex-end, center, space-between, space-around, space-evenly)
  - Align items (flex-start, flex-end, center, stretch, baseline)
  - Align content (flex-start, flex-end, center, stretch, space-between, space-around)
  - Flex wrapping (nowrap, wrap, wrap-reverse)
  - Flex grow, shrink, and basis
  - Gap properties
  - Order property for reordering items

  ## Example Usage

      # Flexbox container
      %{
        type: :flex,
        attrs: %{
          flex_direction: :row,
          justify_content: :space_between,
          align_items: :center,
          gap: 10,
          padding: %{top: 5, right: 10, bottom: 5, left: 10}
        },
        children: [
          %{type: :text, attrs: %{content: "Item 1", flex: %{grow: 1}}},
          %{type: :text, attrs: %{content: "Item 2", flex: %{shrink: 0, basis: 100}}},
          %{type: :text, attrs: %{content: "Item 3", order: -1}}
        ]
      }
  """

  import Raxol.Guards
  alias Raxol.UI.Layout.Engine

  @doc """
  Processes a flex container, calculating layout for it and its children.
  """
  def process_flex(%{type: :flex, children: children} = flex, space, acc)
      when list?(children) do
    attrs = Map.get(flex, :attrs, %{})

    # Parse flex properties
    flex_props = parse_flex_properties(attrs)

    # Apply padding to available space
    content_space = apply_padding(space, flex_props.padding)

    # Sort children by order property
    sorted_children = sort_children_by_order(children)

    # Calculate flex layout
    positioned_children =
      calculate_flex_layout(sorted_children, content_space, flex_props)

    # Process each positioned child
    elements =
      Enum.flat_map(positioned_children, fn {child, child_space} ->
        Engine.process_element(child, child_space, [])
      end)

    elements ++ acc
  end

  def process_flex(_, _space, acc), do: acc

  @doc """
  Measures the space needed by a flex container.
  """
  def measure_flex(%{type: :flex, children: children} = flex, available_space)
      when list?(children) do
    attrs = Map.get(flex, :attrs, %{})
    flex_props = parse_flex_properties(attrs)

    # Apply padding to available space for measurement
    content_space = apply_padding(available_space, flex_props.padding)

    # Measure children
    child_dimensions =
      Enum.map(children, fn child ->
        measure_flex_child(child, content_space, flex_props)
      end)

    # Calculate container size based on flex direction and wrapping
    container_size =
      calculate_container_size(child_dimensions, flex_props, content_space)

    # Add padding back to container size
    %{
      width:
        container_size.width + flex_props.padding.left +
          flex_props.padding.right,
      height:
        container_size.height + flex_props.padding.top +
          flex_props.padding.bottom
    }
  end

  def measure_flex(_, _available_space), do: %{width: 0, height: 0}

  # Private helper functions

  defp parse_flex_properties(attrs) do
    %{
      flex_direction: Map.get(attrs, :flex_direction, :row),
      justify_content: Map.get(attrs, :justify_content, :flex_start),
      align_items: Map.get(attrs, :align_items, :stretch),
      align_content: Map.get(attrs, :align_content, :stretch),
      flex_wrap: Map.get(attrs, :flex_wrap, :nowrap),
      gap: parse_gap(Map.get(attrs, :gap, 0)),
      padding: parse_padding(Map.get(attrs, :padding, 0))
    }
  end

  defp parse_gap(gap) when is_integer(gap) do
    %{row: gap, column: gap}
  end

  defp parse_gap(%{row: row, column: column}) do
    %{row: row, column: column}
  end

  defp parse_gap(_), do: %{row: 0, column: 0}

  defp parse_padding(padding) when is_integer(padding) do
    %{top: padding, right: padding, bottom: padding, left: padding}
  end

  defp parse_padding(%{top: t, right: r, bottom: b, left: l}) do
    %{top: t, right: r, bottom: b, left: l}
  end

  defp parse_padding(%{vertical: v, horizontal: h}) do
    %{top: v, right: h, bottom: v, left: h}
  end

  defp parse_padding(_), do: %{top: 0, right: 0, bottom: 0, left: 0}

  defp apply_padding(space, padding) do
    %{
      x: space.x + padding.left,
      y: space.y + padding.top,
      width: max(0, space.width - padding.left - padding.right),
      height: max(0, space.height - padding.top - padding.bottom)
    }
  end

  defp sort_children_by_order(children) do
    Enum.sort_by(children, fn child ->
      child_attrs = Map.get(child, :attrs, %{})
      Map.get(child_attrs, :order, 0)
    end)
  end

  defp calculate_flex_layout(children, space, flex_props) do
    # Measure all children first
    children_with_dims =
      Enum.map(children, fn child ->
        dims = measure_flex_child(child, space, flex_props)
        flex_attrs = get_flex_attributes(child)
        {child, dims, flex_attrs}
      end)

    # Determine main and cross axis based on flex direction
    {main_axis, cross_axis} = get_axes(flex_props.flex_direction)

    # Calculate layout based on wrapping
    if flex_props.flex_wrap == :nowrap do
      calculate_single_line_layout(
        children_with_dims,
        space,
        flex_props,
        main_axis,
        cross_axis
      )
    else
      calculate_multi_line_layout(
        children_with_dims,
        space,
        flex_props,
        main_axis,
        cross_axis
      )
    end
  end

  defp measure_flex_child(child, available_space, flex_props) do
    # Get child's flex properties
    child_attrs = Map.get(child, :attrs, %{})
    flex_attrs = Map.get(child_attrs, :flex, %{})

    # Calculate available space for child based on flex-basis
    flex_basis = Map.get(flex_attrs, :basis, :auto)

    child_space =
      if flex_basis == :auto do
        available_space
      else
        case get_main_axis(flex_props.flex_direction) do
          :horizontal ->
            %{available_space | width: flex_basis}

          :vertical ->
            %{available_space | height: flex_basis}
        end
      end

    Engine.measure_element(child, child_space)
  end

  defp get_flex_attributes(child) do
    child_attrs = Map.get(child, :attrs, %{})
    flex = Map.get(child_attrs, :flex, %{})

    %{
      grow: Map.get(flex, :grow, 0),
      shrink: Map.get(flex, :shrink, 1),
      basis: Map.get(flex, :basis, :auto),
      align_self: Map.get(child_attrs, :align_self, nil)
    }
  end

  defp get_axes(:row), do: {:horizontal, :vertical}
  defp get_axes(:row_reverse), do: {:horizontal, :vertical}
  defp get_axes(:column), do: {:vertical, :horizontal}
  defp get_axes(:column_reverse), do: {:vertical, :horizontal}

  defp get_main_axis(direction) when direction in [:row, :row_reverse],
    do: :horizontal

  defp get_main_axis(direction) when direction in [:column, :column_reverse],
    do: :vertical

  defp calculate_single_line_layout(
         children_with_dims,
         space,
         flex_props,
         main_axis,
         cross_axis
       ) do
    # Calculate total main axis size needed by all children
    total_main_size =
      Enum.reduce(children_with_dims, 0, fn {_child, dims, _flex}, acc ->
        acc + get_dimension(dims, main_axis)
      end)

    # Calculate total gap size
    gap_size =
      get_gap_size(flex_props.gap, main_axis) *
        max(0, length(children_with_dims) - 1)

    # Available space for flex growth/shrinkage
    available_main_space =
      get_dimension(space, main_axis) - total_main_size - gap_size

    # Distribute extra space or shrink items
    sized_children =
      if available_main_space > 0 do
        distribute_extra_space(
          children_with_dims,
          available_main_space,
          main_axis
        )
      else
        shrink_items(children_with_dims, -available_main_space, main_axis)
      end

    # Position items along main axis
    positioned_children =
      position_main_axis(sized_children, space, flex_props, main_axis)

    # Position items along cross axis
    position_cross_axis(positioned_children, space, flex_props, cross_axis)
  end

  defp calculate_multi_line_layout(
         children_with_dims,
         space,
         flex_props,
         main_axis,
         cross_axis
       ) do
    # Break children into lines
    lines = break_into_lines(children_with_dims, space, flex_props, main_axis)

    # Calculate layout for each line
    lines_with_layout =
      Enum.map(lines, fn line_children ->
        line_space = %{
          space
          | height: calculate_line_height(line_children, cross_axis)
        }

        calculate_single_line_layout(
          line_children,
          line_space,
          flex_props,
          main_axis,
          cross_axis
        )
      end)

    # Position lines along cross axis
    position_lines_cross_axis(lines_with_layout, space, flex_props, cross_axis)
  end

  defp get_dimension(dims, :horizontal), do: dims.width
  defp get_dimension(dims, :vertical), do: dims.height

  defp get_gap_size(gap, :horizontal), do: gap.column
  defp get_gap_size(gap, :vertical), do: gap.row

  defp distribute_extra_space(children_with_dims, extra_space, main_axis) do
    # Calculate total flex grow
    total_grow =
      Enum.reduce(children_with_dims, 0, fn {_child, _dims, flex}, acc ->
        acc + flex.grow
      end)

    if total_grow == 0 do
      children_with_dims
    else
      # Distribute extra space proportionally
      Enum.map(children_with_dims, fn {child, dims, flex} ->
        if flex.grow > 0 do
          extra = div(extra_space * flex.grow, total_grow)

          new_dims =
            case main_axis do
              :horizontal -> %{dims | width: dims.width + extra}
              :vertical -> %{dims | height: dims.height + extra}
            end

          {child, new_dims, flex}
        else
          {child, dims, flex}
        end
      end)
    end
  end

  defp shrink_items(children_with_dims, shortage, main_axis) do
    # Calculate total flex shrink weighted by size
    total_shrink_weight =
      Enum.reduce(children_with_dims, 0, fn {_child, dims, flex}, acc ->
        size = get_dimension(dims, main_axis)
        acc + flex.shrink * size
      end)

    if total_shrink_weight == 0 do
      children_with_dims
    else
      # Shrink items proportionally
      Enum.map(children_with_dims, fn {child, dims, flex} ->
        if flex.shrink > 0 do
          size = get_dimension(dims, main_axis)
          shrink_weight = flex.shrink * size

          shrink_amount =
            min(size, div(shortage * shrink_weight, total_shrink_weight))

          new_dims =
            case main_axis do
              :horizontal -> %{dims | width: max(0, dims.width - shrink_amount)}
              :vertical -> %{dims | height: max(0, dims.height - shrink_amount)}
            end

          {child, new_dims, flex}
        else
          {child, dims, flex}
        end
      end)
    end
  end

  defp position_main_axis(sized_children, space, flex_props, main_axis) do
    total_size =
      Enum.reduce(sized_children, 0, fn {_child, dims, _flex}, acc ->
        acc + get_dimension(dims, main_axis)
      end)

    gap_size = get_gap_size(flex_props.gap, main_axis)
    total_gaps = gap_size * max(0, length(sized_children) - 1)
    available_space = get_dimension(space, main_axis) - total_size - total_gaps

    {start_pos, item_gap} =
      calculate_justify_positioning(
        flex_props.justify_content,
        available_space,
        length(sized_children),
        gap_size
      )

    start_coord =
      case main_axis do
        :horizontal -> space.x + start_pos
        :vertical -> space.y + start_pos
      end

    {_, positioned} =
      Enum.reduce(sized_children, {start_coord, []}, fn {child, dims, flex},
                                                        {current_pos, acc} ->
        child_space =
          case main_axis do
            :horizontal ->
              %{
                x: current_pos,
                y: space.y,
                width: dims.width,
                height: dims.height
              }

            :vertical ->
              %{
                x: space.x,
                y: current_pos,
                width: dims.width,
                height: dims.height
              }
          end

        next_pos = current_pos + get_dimension(dims, main_axis) + item_gap
        {next_pos, [{child, child_space, flex} | acc]}
      end)

    Enum.reverse(positioned)
  end

  defp position_cross_axis(positioned_children, space, flex_props, cross_axis) do
    _max_cross_size = get_dimension(space, cross_axis)

    Enum.map(positioned_children, fn {child, child_space, flex} ->
      # Determine alignment for this item
      alignment = flex.align_self || flex_props.align_items

      # Calculate cross axis position
      new_child_space =
        case {cross_axis, alignment} do
          {:horizontal, :flex_start} ->
            %{child_space | x: space.x}

          {:horizontal, :flex_end} ->
            %{child_space | x: space.x + space.width - child_space.width}

          {:horizontal, :center} ->
            %{
              child_space
              | x: space.x + div(space.width - child_space.width, 2)
            }

          {:horizontal, :stretch} ->
            %{child_space | x: space.x, width: space.width}

          {:vertical, :flex_start} ->
            %{child_space | y: space.y}

          {:vertical, :flex_end} ->
            %{child_space | y: space.y + space.height - child_space.height}

          {:vertical, :center} ->
            %{
              child_space
              | y: space.y + div(space.height - child_space.height, 2)
            }

          {:vertical, :stretch} ->
            %{child_space | y: space.y, height: space.height}

          _ ->
            child_space
        end

      {child, new_child_space}
    end)
  end

  defp calculate_justify_positioning(
         :flex_start,
         _available_space,
         _item_count,
         gap
       ) do
    {0, gap}
  end

  defp calculate_justify_positioning(
         :flex_end,
         available_space,
         _item_count,
         gap
       ) do
    {available_space, gap}
  end

  defp calculate_justify_positioning(:center, available_space, _item_count, gap) do
    {div(available_space, 2), gap}
  end

  defp calculate_justify_positioning(
         :space_between,
         available_space,
         item_count,
         _gap
       )
       when item_count > 1 do
    {0, div(available_space, item_count - 1)}
  end

  defp calculate_justify_positioning(
         :space_around,
         available_space,
         item_count,
         _gap
       ) do
    space_per_item = div(available_space, item_count)
    {div(space_per_item, 2), space_per_item}
  end

  defp calculate_justify_positioning(
         :space_evenly,
         available_space,
         item_count,
         _gap
       ) do
    space_per_gap = div(available_space, item_count + 1)
    {space_per_gap, space_per_gap}
  end

  defp calculate_justify_positioning(_, _available_space, _item_count, gap) do
    {0, gap}
  end

  defp break_into_lines(children_with_dims, space, flex_props, main_axis) do
    available_main_size = get_dimension(space, main_axis)
    gap_size = get_gap_size(flex_props.gap, main_axis)

    {lines, current_line, _current_size} =
      Enum.reduce(children_with_dims, {[], [], 0}, fn item =
                                                        {_child, dims, _flex},
                                                      {lines, current_line,
                                                       current_size} ->
        item_size = get_dimension(dims, main_axis)

        needed_size =
          if current_line == [] do
            item_size
          else
            current_size + gap_size + item_size
          end

        if needed_size <= available_main_size or current_line == [] do
          # Item fits in current line
          {lines, [item | current_line], needed_size}
        else
          # Start new line
          {[Enum.reverse(current_line) | lines], [item], item_size}
        end
      end)

    # Add the last line
    final_lines =
      if current_line == [] do
        lines
      else
        [Enum.reverse(current_line) | lines]
      end

    Enum.reverse(final_lines)
  end

  defp calculate_line_height(line_children, cross_axis) do
    Enum.reduce(line_children, 0, fn {_child, dims, _flex}, acc ->
      max(acc, get_dimension(dims, cross_axis))
    end)
  end

  defp position_lines_cross_axis(
         lines_with_layout,
         space,
         flex_props,
         cross_axis
       ) do
    line_heights =
      Enum.map(lines_with_layout, fn line ->
        Enum.reduce(line, 0, fn {_child, child_space, _flex}, acc ->
          max(acc, get_dimension(child_space, cross_axis))
        end)
      end)

    total_line_height = Enum.sum(line_heights)
    available_space = get_dimension(space, cross_axis) - total_line_height
    gap_size = get_gap_size(flex_props.gap, cross_axis)
    total_gaps = gap_size * max(0, length(lines_with_layout) - 1)

    {start_pos, line_gap} =
      calculate_align_content_positioning(
        flex_props.align_content,
        available_space - total_gaps,
        length(lines_with_layout),
        gap_size
      )

    start_coord =
      case cross_axis do
        :horizontal -> space.x + start_pos
        :vertical -> space.y + start_pos
      end

    {_, positioned_lines} =
      Enum.zip(lines_with_layout, line_heights)
      |> Enum.reduce({start_coord, []}, fn {line, line_height},
                                           {current_pos, acc} ->
        # Position each item in the line
        positioned_line =
          Enum.map(line, fn {child, child_space} ->
            new_child_space =
              case cross_axis do
                :horizontal ->
                  %{child_space | x: current_pos}

                :vertical ->
                  %{child_space | y: current_pos}
              end

            {child, new_child_space}
          end)

        next_pos = current_pos + line_height + line_gap
        {next_pos, positioned_line ++ acc}
      end)

    positioned_lines
  end

  defp calculate_align_content_positioning(
         :flex_start,
         _available_space,
         _line_count,
         gap
       ) do
    {0, gap}
  end

  defp calculate_align_content_positioning(
         :flex_end,
         available_space,
         _line_count,
         gap
       ) do
    {available_space, gap}
  end

  defp calculate_align_content_positioning(
         :center,
         available_space,
         _line_count,
         gap
       ) do
    {div(available_space, 2), gap}
  end

  defp calculate_align_content_positioning(
         :space_between,
         available_space,
         line_count,
         _gap
       )
       when line_count > 1 do
    {0, div(available_space, line_count - 1)}
  end

  defp calculate_align_content_positioning(
         :space_around,
         available_space,
         line_count,
         _gap
       ) do
    space_per_line = div(available_space, line_count)
    {div(space_per_line, 2), space_per_line}
  end

  defp calculate_align_content_positioning(
         _,
         _available_space,
         _line_count,
         gap
       ) do
    {0, gap}
  end

  defp calculate_container_size(child_dimensions, flex_props, _content_space) do
    if length(child_dimensions) == 0 do
      %{width: 0, height: 0}
    else
      {main_axis, cross_axis} = get_axes(flex_props.flex_direction)

      if flex_props.flex_wrap == :nowrap do
        # Single line: main axis is sum, cross axis is max
        main_size =
          Enum.reduce(child_dimensions, 0, fn dims, acc ->
            acc + get_dimension(dims, main_axis)
          end)

        cross_size =
          Enum.reduce(child_dimensions, 0, fn dims, acc ->
            max(acc, get_dimension(dims, cross_axis))
          end)

        case main_axis do
          :horizontal -> %{width: main_size, height: cross_size}
          :vertical -> %{width: cross_size, height: main_size}
        end
      else
        # Multi-line: more complex calculation needed
        # For now, return sum of all dimensions (conservative estimate)
        total_width =
          Enum.reduce(child_dimensions, 0, fn dims, acc ->
            max(acc, dims.width)
          end)

        total_height =
          Enum.reduce(child_dimensions, 0, fn dims, acc ->
            acc + dims.height
          end)

        %{width: total_width, height: total_height}
      end
    end
  end
end
