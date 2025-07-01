defmodule Raxol.Core.Renderer.View.Layout.Flex do
  @moduledoc """
  Handles flex layout functionality for the Raxol view system.
  Provides row and column layouts with various alignment and justification options.
  """

  import Raxol.Guards

  @doc """
  Creates a row layout container that arranges its children horizontally.

  ## Options
    * `:children` - List of child views to arrange horizontally
    * `:align` - Alignment of children (:start, :center, :end)
    * `:justify` - Justification of children (:start, :center, :end, :space_between)
    * `:gap` - Space between children (integer)

  ## Examples

      Flex.row(children: [view1, view2])
      Flex.row(align: :center, justify: :space_between, children: [view1, view2])
  """
  def row(opts \\ []) do
    children = Keyword.get(opts, :children, [])
    align = Keyword.get(opts, :align, :start)
    justify = Keyword.get(opts, :justify, :start)
    gap = Keyword.get(opts, :gap, 0)
    style = Keyword.get(opts, :style, [])

    %{
      type: :flex,
      direction: :row,
      align: align,
      justify: justify,
      gap: gap,
      style: style,
      children: children
    }
  end

  @doc """
  Creates a flex container that arranges its children in the specified direction.

  ## Options
    * `:direction` - Direction of flex layout (:row or :column)
    * `:children` - List of child views
    * `:align` - Alignment of children (:start, :center, :end)
    * `:justify` - Justification of children (:start, :center, :end, :space_between)
    * `:gap` - Space between children (integer)
    * `:wrap` - Whether to wrap children (boolean)

  ## Examples

      Flex.container(direction: :row, children: [view1, view2])
      Flex.container(direction: :column, align: :center, children: [view1, view2])
  """
  def container(opts) do
    direction = Keyword.get(opts, :direction, :row)

    # Validate flex direction
    if direction not in [:row, :column] do
      raise ArgumentError, "Invalid flex direction: #{inspect(direction)}"
    end

    # Get raw children from opts
    raw_children = Keyword.get(opts, :children)

    processed_children =
      cond do
        list?(raw_children) -> raw_children
        # Default to empty list if nil
        nil?(raw_children) -> []
        # Wrap single child in a list
        true -> [raw_children]
      end

    align = Keyword.get(opts, :align, :start)
    justify = Keyword.get(opts, :justify, :start)
    gap = Keyword.get(opts, :gap, 0)
    wrap = Keyword.get(opts, :wrap, false)
    style = Keyword.get(opts, :style, [])

    %{
      type: :flex,
      direction: direction,
      align: align,
      justify: justify,
      gap: gap,
      wrap: wrap,
      style: style,
      # Use the processed list of children
      children: processed_children
    }
  end

  @doc """
  Creates a column layout container that arranges its children vertically.

  ## Options
    * `:children` - List of child views to arrange vertically
    * `:align` - Alignment of children (:start, :center, :end)
    * `:justify` - Justification of children (:start, :center, :end, :space_between)
    * `:gap` - Space between children (integer)

  ## Examples

      Flex.column(children: [view1, view2])
      Flex.column(align: :center, justify: :space_between, children: [view1, view2])
  """
  def column(opts \\ []) do
    children = Keyword.get(opts, :children, [])
    align = Keyword.get(opts, :align, :start)
    justify = Keyword.get(opts, :justify, :start)
    gap = Keyword.get(opts, :gap, 0)
    style = Keyword.get(opts, :style, [])

    %{
      type: :flex,
      direction: :column,
      align: align,
      justify: justify,
      gap: gap,
      style: style,
      children: children
    }
  end

  @doc """
  Calculates the layout of flex children based on container size and options.
  Supports wrapping if :wrap is true.
  """
  def calculate_layout(container, {width, height}) do
    measured_children = measure_children(container.children, {width, height})
    direction = container.direction
    wrap = Map.get(container, :wrap, false)
    gap = container.gap

    if wrap do
      wrap_flex_layout(measured_children, direction, {width, height}, gap)
    else
      # Existing non-wrapping logic
      {main_axis_size, cross_axis_size} = get_axis_sizes(direction, {width, height})
      total_content_size = calculate_total_content_size(measured_children, gap)
      justified_children = apply_justification(measured_children, container.justify, main_axis_size, total_content_size, gap)
      aligned_children = apply_alignment(justified_children, container.align, cross_axis_size, direction)
      apply_gap_spacing(aligned_children, gap, direction)
    end
  end

  # New: Implements wrapping for flex layout
  defp wrap_flex_layout(children, :row, {width, _height}, gap) do
    {lines, current_line, _} =
      Enum.reduce(children, {[], [], 0}, fn child, {lines, line, line_width} ->
        {child_w, _child_h} = Map.get(child, :measured_size)
        new_width = if line_width == 0, do: child_w, else: line_width + gap + child_w
        if new_width > width and line_width > 0 do
          # Start new line with current child
          {[line | lines], [child], child_w}
        else
          # Add to current line
          {lines, [child | line], new_width}
        end
      end)

    # Add the last line and filter out empty lines
    all_lines =
      [current_line | lines]
      |> Enum.reverse()
      |> Enum.map(&Enum.reverse/1)
      |> Enum.reject(&(&1 == []))

    # Position children in lines
    all_lines
    |> Enum.with_index()
    |> Enum.flat_map(fn {line, line_idx} ->
      # Skip empty lines
      if line == [] do
        []
      else
        Enum.reduce(line, {0, []}, fn child, {x, acc} ->
          {child_w, child_h} = Map.get(child, :measured_size)
          pos_child =
            child
            |> Map.put(:position, {x, line_idx})
            |> Map.put(:size, {child_w, child_h})
          {x + child_w + gap, [pos_child | acc]}
        end)
        |> elem(1)
        |> Enum.reverse()
      end
    end)
  end

  defp wrap_flex_layout(children, :column, {_width, height}, gap) do
    {lines, current_line, _} =
      Enum.reduce(children, {[], [], 0}, fn child, {lines, line, line_height} ->
        {_child_w, child_h} = Map.get(child, :measured_size)
        new_height = if line_height == 0, do: child_h, else: line_height + gap + child_h
        if new_height > height and line_height > 0 do
          # Start new column with current child
          {[line | lines], [child], child_h}
        else
          # Add to current column
          {lines, [child | line], new_height}
        end
      end)

    # Add the last column and filter out empty columns
    all_lines =
      [current_line | lines]
      |> Enum.reverse()
      |> Enum.map(&Enum.reverse/1)
      |> Enum.reject(&(&1 == []))

    # Position children in columns
    all_lines
    |> Enum.with_index()
    |> Enum.flat_map(fn {line, col_idx} ->
      # Skip empty lines
      if line == [] do
        []
      else
        Enum.reduce(line, {0, []}, fn child, {y, acc} ->
          {child_w, child_h} = Map.get(child, :measured_size)
          pos_child =
            child
            |> Map.put(:position, {col_idx, y})
            |> Map.put(:size, {child_w, child_h})
          {y + child_h + gap, [pos_child | acc]}
        end)
        |> elem(1)
        |> Enum.reverse()
      end
    end)
  end

  defp measure_children(children, {width, height}) do
    Enum.map(children, fn child ->
      child_size = get_child_size(child, {width, height})
      Map.put(child, :measured_size, child_size)
    end)
  end

  defp get_child_size(child, {width, height}) do
    case Map.get(child, :size) do
      {child_width, child_height} when is_integer(child_width) and is_integer(child_height) ->
        {child_width, child_height}
      _ ->
        child_width = Map.get(child, :width)
        child_height = Map.get(child, :height)
        {calculate_width(child_width, width), calculate_height(child_height, height)}
    end
  end

  defp calculate_width(nil, available_width), do: min(50, available_width)

  defp calculate_width(width, available_width) when integer?(width),
    do: min(width, available_width)

  defp calculate_width(_, available_width), do: min(50, available_width)

  defp calculate_height(nil, available_height), do: min(1, available_height)

  defp calculate_height(height, available_height) when integer?(height),
    do: min(height, available_height)

  defp calculate_height(_, available_height), do: min(1, available_height)

  defp get_axis_sizes(direction, {width, height}) do
    case direction do
      # Main axis: width, Cross axis: height
      :row -> {width, height}
      # Main axis: height, Cross axis: width
      :column -> {height, width}
      _ -> {width, height}
    end
  end

  defp calculate_total_content_size(children, gap) do
    total_items = length(children)
    total_gaps = max(0, total_items - 1) * gap

    children
    |> Enum.map(&Map.get(&1, :measured_size))
    # Use width for main axis size
    |> Enum.map(fn {w, _h} -> w end)
    |> Enum.sum()
    |> Kernel.+(total_gaps)
  end

  defp apply_justification(
         children,
         justify,
         main_axis_size,
         total_content_size,
         gap
       ) do
    case justify do
      :start ->
        justify_start(children, gap)

      :center ->
        justify_center(children, main_axis_size, total_content_size, gap)

      :end ->
        justify_end(children, main_axis_size, total_content_size, gap)

      :space_between ->
        justify_space_between(children, main_axis_size, total_content_size, gap)

      _ ->
        justify_start(children, gap)
    end
  end

  defp justify_start(children, gap) do
    justify_children(children, 0, gap)
  end

  defp justify_center(children, main_axis_size, total_content_size, gap) do
    start_offset = (main_axis_size - total_content_size) / 2
    justify_children(children, start_offset, gap)
  end

  defp justify_end(children, main_axis_size, total_content_size, gap) do
    start_offset = main_axis_size - total_content_size
    justify_children(children, start_offset, gap)
  end

  defp justify_space_between(children, main_axis_size, total_content_size, gap) do
    total_items = length(children)

    if total_items <= 1 do
      justify_start(children, gap)
    else
      # Calculate space between items
      total_item_width = total_content_size - gap * (total_items - 1)
      space_between = (main_axis_size - total_item_width) / (total_items - 1)
      justify_children(children, 0, space_between)
    end
  end

  defp justify_children(children, start_offset, gap) do
    children
    |> Enum.scan({start_offset, nil}, fn child, {pos, _prev_child} ->
      {child_width, _child_height} = Map.get(child, :measured_size)
      positioned_child = Map.put(child, :main_axis_position, pos)
      {pos + child_width + gap, positioned_child}
    end)
    |> Enum.map(fn {_pos, child} -> child end)
  end

  defp apply_alignment(children, align, cross_axis_size, _direction) do
    Enum.map(children, fn child ->
      {_child_width, child_height} = Map.get(child, :measured_size)

      cross_axis_position =
        calculate_cross_axis_position(align, cross_axis_size, child_height)

      Map.put(child, :cross_axis_position, cross_axis_position)
    end)
  end

  defp calculate_cross_axis_position(align, cross_axis_size, child_size) do
    case align do
      :start -> 0
      :center -> (cross_axis_size - child_size) / 2
      :end -> cross_axis_size - child_size
      _ -> 0
    end
  end

  defp apply_gap_spacing(children, _gap, direction) do
    # Convert main_axis_position and cross_axis_position to actual x,y coordinates
    Enum.map(children, fn child ->
      main_pos = Map.get(child, :main_axis_position, 0)
      cross_pos = Map.get(child, :cross_axis_position, 0)
      {child_width, child_height} = Map.get(child, :measured_size)

      {x, y} =
        case direction do
          :row -> {main_pos, cross_pos}
          :column -> {cross_pos, main_pos}
          _ -> {main_pos, cross_pos}
        end

      child
      |> Map.put(:position, {x, y})
      |> Map.put(:size, {child_width, child_height})
      |> Map.delete(:measured_size)
      |> Map.delete(:main_axis_position)
      |> Map.delete(:cross_axis_position)
    end)
  end
end
