defmodule Raxol.UI.Layout.Containers do
  @moduledoc """
  Handles layout calculations for container elements like rows and columns.

  This module is responsible for:
  * Row layout calculations
  * Column layout calculations
  * Flexbox-like distribution of space
  * Gap and alignment handling
  """

  alias Raxol.UI.Layout.Engine

  @doc """
  Processes a row element, calculating layout for it and its children.

  ## Parameters

  * `row` - The row element to process
  * `space` - The available space for the row
  * `acc` - The accumulator for rendered elements

  ## Returns

  A list of positioned elements with absolute coordinates.
  """
  def process_row(%{type: :row, children: children} = row, space, acc)
      when is_list(children) do
    # Get attrs with default empty map if not present
    attrs = Map.get(row, :attrs, %{})

    # Calculate spacing between items
    gap = Map.get(attrs, :gap, 1)
    justify = Map.get(attrs, :justify, :start)
    align = Map.get(attrs, :align, :start)

    # Skip if no children
    process_row_with_children(children, gap, justify, align, space, acc)
  end

  # Catch-all clause for process_row
  def process_row(_, _space, acc), do: acc

  defp process_row_with_children([], _gap, _justify, _align, _space, acc),
    do: acc

  defp process_row_with_children(children, gap, justify, align, space, acc) do
    child_dimensions = measure_all_children(children, space)

    layout_info =
      calculate_row_layout(child_dimensions, gap, justify, children, space)

    children
    |> position_row_children(child_dimensions, layout_info, align, space)
    |> List.flatten()
    |> Kernel.++(acc)
  end

  defp calculate_row_layout(child_dimensions, gap, justify, children, space) do
    total_width = calculate_total_width(child_dimensions)
    gaps_width = gap * (length(children) - 1)
    total_content_width = total_width + gaps_width
    start_x = calculate_row_start_x(justify, space, total_content_width)

    effective_gap =
      calculate_row_gap(justify, children, gap, space.width, total_width)

    %{
      start_x: start_x,
      effective_gap: effective_gap
    }
  end

  defp calculate_total_width(child_dimensions) do
    Enum.reduce(child_dimensions, 0, fn dim, acc -> acc + dim.width end)
  end

  defp calculate_row_start_x(justify, space, total_content_width) do
    case justify do
      :start -> space.x
      :center -> space.x + div(space.width - total_content_width, 2)
      :end -> space.x + space.width - total_content_width
      :space_between -> space.x
    end
  end

  defp position_row_children(
         children,
         child_dimensions,
         layout_info,
         align,
         space
       ) do
    Enum.zip(children, child_dimensions)
    |> Enum.reduce({layout_info.start_x, []}, fn {child, dims},
                                                 {current_x, elements} ->
      child_y = calculate_child_y_position(align, space, dims)
      child_space = create_child_space(current_x, child_y, dims)
      child_elements = Engine.process_element(child, child_space, [])

      next_x = current_x + dims.width + layout_info.effective_gap
      {next_x, child_elements ++ elements}
    end)
    |> elem(1)
  end

  defp calculate_child_y_position(align, space, dims) do
    case align do
      :start -> space.y
      :center -> space.y + div(space.height - dims.height, 2)
      :end -> space.y + space.height - dims.height
    end
  end

  @doc """
  Processes a column element, calculating layout for it and its children.

  ## Parameters

  * `column` - The column element to process
  * `space` - The available space for the column
  * `acc` - The accumulator for rendered elements

  ## Returns

  A list of positioned elements with absolute coordinates.
  """
  def process_column(
        %{type: :column, children: children} = column,
        space,
        acc
      )
      when is_list(children) do
    # Get attrs with default empty map if not present
    attrs = Map.get(column, :attrs, %{})

    # Calculate spacing between items
    gap = Map.get(attrs, :gap, 1)
    justify = Map.get(attrs, :justify, :start)
    align = Map.get(attrs, :align, :start)

    # Skip if no children
    process_column_with_children(children, gap, justify, align, space, acc)
  end

  def process_column(_, _space, acc), do: acc

  defp process_column_with_children([], _gap, _justify, _align, _space, acc),
    do: acc

  defp process_column_with_children(children, gap, justify, align, space, acc) do
    child_dimensions = measure_all_children(children, space)

    layout_info =
      calculate_column_layout(child_dimensions, gap, justify, children, space)

    children
    |> position_column_children(child_dimensions, layout_info, align, space)
    |> List.flatten()
    |> Kernel.++(acc)
  end

  defp measure_all_children(children, space) do
    Enum.map(children, fn child -> Engine.measure_element(child, space) end)
  end

  defp calculate_column_layout(child_dimensions, gap, justify, children, space) do
    total_height = calculate_total_height(child_dimensions)
    gaps_height = gap * (length(children) - 1)
    total_content_height = total_height + gaps_height
    start_y = calculate_column_start_y(justify, space, total_content_height)

    effective_gap =
      calculate_column_gap(justify, children, gap, space.height, total_height)

    %{
      start_y: start_y,
      effective_gap: effective_gap
    }
  end

  defp calculate_total_height(child_dimensions) do
    Enum.reduce(child_dimensions, 0, fn dim, acc -> acc + dim.height end)
  end

  defp calculate_column_start_y(justify, space, total_content_height) do
    case justify do
      :start -> space.y
      :center -> space.y + div(space.height - total_content_height, 2)
      :end -> space.y + space.height - total_content_height
      :space_between -> space.y
    end
  end

  defp position_column_children(
         children,
         child_dimensions,
         layout_info,
         align,
         space
       ) do
    Enum.zip(children, child_dimensions)
    |> Enum.reduce({layout_info.start_y, []}, fn {child, dims},
                                                 {current_y, elements} ->
      child_x = calculate_child_x_position(align, space, dims)
      child_space = create_child_space(child_x, current_y, dims)
      child_elements = Engine.process_element(child, child_space, [])

      next_y = current_y + dims.height + layout_info.effective_gap
      {next_y, child_elements ++ elements}
    end)
    |> elem(1)
  end

  defp calculate_child_x_position(align, space, dims) do
    case align do
      :start -> space.x
      :center -> space.x + div(space.width - dims.width, 2)
      :end -> space.x + space.width - dims.width
    end
  end

  defp create_child_space(x, y, dims) do
    %{x: x, y: y, width: dims.width, height: dims.height}
  end

  @doc """
  Measures the space needed by a row element.

  ## Parameters

  * `row` - The row element to measure
  * `available_space` - The available space for the row

  ## Returns

  The dimensions of the row: %{width: w, height: h}
  """
  def measure_row(
        %{type: :row, attrs: _attrs, children: children},
        available_space
      )
      when is_list(children) do
    # Skip if no children
    measure_row_with_children(children, available_space)
  end

  def measure_row(_, _available_space), do: %{width: 0, height: 0}

  defp measure_row_with_children([], _available_space),
    do: %{width: 0, height: 0}

  defp measure_row_with_children(children, available_space) do
    # Calculate the space each child needs
    child_dimensions =
      Enum.map(children, fn child ->
        Engine.measure_element(child, available_space)
      end)

    # Row width is sum of children's width
    row_width =
      Enum.reduce(child_dimensions, 0, fn dim, acc ->
        acc + dim.width
      end)

    # Row height is the maximum child height
    row_height =
      Enum.reduce(child_dimensions, 0, fn dim, acc ->
        max(acc, dim.height)
      end)

    # Return dimensions constrained to available space
    %{
      width: min(row_width, available_space.width),
      height: min(row_height, available_space.height)
    }
  end

  @doc """
  Measures the space needed by a column element.

  ## Parameters

  * `column` - The column element to measure
  * `available_space` - The available space for the column

  ## Returns

  The dimensions of the column: %{width: w, height: h}
  """
  def measure_column(
        %{type: :column, attrs: _attrs, children: children},
        available_space
      )
      when is_list(children) do
    # Skip if no children
    measure_column_with_children(children, available_space)
  end

  def measure_column(_, _available_space), do: %{width: 0, height: 0}

  defp measure_column_with_children([], _available_space),
    do: %{width: 0, height: 0}

  defp measure_column_with_children(children, available_space) do
    # Calculate the space each child needs
    child_dimensions =
      Enum.map(children, fn child ->
        Engine.measure_element(child, available_space)
      end)

    # Column height is sum of children's height
    column_height =
      Enum.reduce(child_dimensions, 0, fn dim, acc ->
        acc + dim.height
      end)

    # Column width is the maximum child width
    column_width =
      Enum.reduce(child_dimensions, 0, fn dim, acc ->
        max(acc, dim.width)
      end)

    # Return dimensions constrained to available space
    %{
      width: min(column_width, available_space.width),
      height: min(column_height, available_space.height)
    }
  end

  ## Pattern matching helper functions for gap calculations

  defp calculate_row_gap(
         :space_between,
         children,
         _gap,
         available_width,
         total_width
       )
       when length(children) > 1 do
    remaining_space = available_width - total_width
    div(remaining_space, length(children) - 1)
  end

  defp calculate_row_gap(
         _justify,
         _children,
         gap,
         _available_width,
         _total_width
       ),
       do: gap

  defp calculate_column_gap(
         :space_between,
         children,
         _gap,
         available_height,
         total_height
       )
       when length(children) > 1 do
    remaining_space = available_height - total_height
    div(remaining_space, length(children) - 1)
  end

  defp calculate_column_gap(
         _justify,
         _children,
         gap,
         _available_height,
         _total_height
       ),
       do: gap
end
