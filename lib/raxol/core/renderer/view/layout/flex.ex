defmodule Raxol.Core.Renderer.View.Layout.Flex do
  @moduledoc """
  Handles flex layout functionality for the Raxol view system.
  Provides row and column layouts with various alignment and justification options.
  """

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
    validate_flex_direction(direction)

    # Get raw children from opts
    raw_children = Keyword.get(opts, :children)

    processed_children =
      case raw_children do
        children when is_list(children) -> children
        # Default to empty list if nil
        nil -> []
        # Wrap single child in a list
        single_child -> [single_child]
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

    do_calculate_layout(
      wrap,
      measured_children,
      direction,
      {width, height},
      gap,
      container
    )
  end

  # New: Implements wrapping for flex layout
  @spec wrap_flex_layout(
          [map()],
          :row,
          {non_neg_integer(), non_neg_integer()},
          non_neg_integer()
        ) :: [map()]
  defp wrap_flex_layout(children, :row, {width, _height}, gap) do
    children
    |> group_children_into_lines(width, gap)
    |> process_lines()
    |> position_children_in_lines(gap)
  end

  @spec wrap_flex_layout(
          [map()],
          :column,
          {non_neg_integer(), non_neg_integer()},
          non_neg_integer()
        ) :: [map()]
  defp wrap_flex_layout(children, :column, {_width, height}, gap) do
    children
    |> group_children_into_columns(height, gap)
    |> process_columns()
    |> position_children_in_columns(gap)
  end

  @spec group_children_into_lines([map()], non_neg_integer(), non_neg_integer()) ::
          [[map()]]
  defp group_children_into_lines(children, width, gap) do
    {lines, current_line, _} =
      Enum.reduce(children, {[], [], 0}, fn child, {lines, line, line_width} ->
        {child_w, _child_h} = Map.get(child, :measured_size)

        new_width = calculate_new_width(line_width, child_w, gap)

        handle_line_wrapping(
          new_width,
          width,
          line_width,
          lines,
          line,
          child,
          child_w
        )
      end)

    [current_line | lines]
  end

  @spec group_children_into_columns(
          [map()],
          non_neg_integer(),
          non_neg_integer()
        ) :: [[map()]]
  defp group_children_into_columns(children, height, gap) do
    {columns, current_column, _} =
      Enum.reduce(children, {[], [], 0}, fn child,
                                            {columns, column, column_height} ->
        {_child_w, child_h} = Map.get(child, :measured_size)

        new_height = calculate_new_height(column_height, child_h, gap)

        handle_column_wrapping(
          new_height,
          height,
          column_height,
          columns,
          column,
          child,
          child_h
        )
      end)

    [current_column | columns]
  end

  @spec process_lines([[map()]]) :: [[map()]]
  defp process_lines(lines) do
    lines
    |> Enum.reverse()
    |> Enum.map(&Enum.reverse/1)
    |> Enum.reject(&(&1 == []))
  end

  @spec process_columns([[map()]]) :: [[map()]]
  defp process_columns(columns), do: process_lines(columns)

  @spec position_children_in_lines([[map()]], non_neg_integer()) :: [map()]
  defp position_children_in_lines(lines, gap) do
    lines
    |> Enum.with_index()
    |> Enum.flat_map(fn {line, line_idx} ->
      handle_line_positioning(line, line_idx, gap)
    end)
  end

  @spec position_children_in_columns([[map()]], non_neg_integer()) :: [map()]
  defp position_children_in_columns(columns, gap) do
    columns
    |> Enum.with_index()
    |> Enum.flat_map(fn {column, col_idx} ->
      handle_column_positioning(column, col_idx, gap)
    end)
  end

  @spec position_children_in_line([map()], non_neg_integer(), non_neg_integer()) ::
          [map()]
  defp position_children_in_line(line, line_idx, gap) do
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

  @spec position_children_in_column(
          [map()],
          non_neg_integer(),
          non_neg_integer()
        ) :: [map()]
  defp position_children_in_column(column, col_idx, gap) do
    Enum.reduce(column, {0, []}, fn child, {y, acc} ->
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

  @spec measure_children([map()], {non_neg_integer(), non_neg_integer()}) :: [
          map()
        ]
  defp measure_children(children, {width, height}) do
    Enum.map(children, fn child ->
      child_size = get_child_size(child, {width, height})
      Map.put(child, :measured_size, child_size)
    end)
  end

  @spec get_child_size(map(), {non_neg_integer(), non_neg_integer()}) ::
          {non_neg_integer(), non_neg_integer()}
  defp get_child_size(child, {width, height}) do
    case Map.get(child, :size) do
      {child_width, child_height}
      when is_integer(child_width) and is_integer(child_height) ->
        {child_width, child_height}

      _ ->
        child_width = Map.get(child, :width)
        child_height = Map.get(child, :height)

        {calculate_width(child_width, width),
         calculate_height(child_height, height)}
    end
  end

  @spec calculate_width(non_neg_integer() | nil, non_neg_integer()) ::
          non_neg_integer()
  defp calculate_width(nil, available_width), do: min(50, available_width)

  @spec calculate_width(non_neg_integer(), non_neg_integer()) ::
          non_neg_integer()
  defp calculate_width(width, available_width) when is_integer(width),
    do: min(width, available_width)

  @spec calculate_width(term(), non_neg_integer()) :: non_neg_integer()
  defp calculate_width(_, available_width), do: min(50, available_width)

  @spec calculate_height(non_neg_integer() | nil, non_neg_integer()) ::
          non_neg_integer()
  defp calculate_height(nil, available_height), do: min(1, available_height)

  @spec calculate_height(non_neg_integer(), non_neg_integer()) ::
          non_neg_integer()
  defp calculate_height(height, available_height) when is_integer(height),
    do: min(height, available_height)

  @spec calculate_height(term(), non_neg_integer()) :: non_neg_integer()
  defp calculate_height(_, available_height), do: min(1, available_height)

  @spec get_axis_sizes(atom(), {non_neg_integer(), non_neg_integer()}) ::
          {non_neg_integer(), non_neg_integer()}
  defp get_axis_sizes(direction, {width, height}) do
    case direction do
      # Main axis: width, Cross axis: height
      :row -> {width, height}
      # Main axis: height, Cross axis: width
      :column -> {height, width}
      _ -> {width, height}
    end
  end

  @spec calculate_total_content_size([map()], non_neg_integer()) :: number()
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

  @spec apply_justification([any()], any(), any(), number(), number()) :: [
          any()
        ]
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

  @spec justify_start([map()], number()) :: [map()]
  defp justify_start(children, gap) do
    justify_children(children, 0, gap)
  end

  @spec justify_center([map()], number(), number(), number()) :: [map()]
  defp justify_center(children, main_axis_size, total_content_size, gap) do
    start_offset = (main_axis_size - total_content_size) / 2
    justify_children(children, start_offset, gap)
  end

  @spec justify_end([map()], number(), number(), number()) :: [map()]
  defp justify_end(children, main_axis_size, total_content_size, gap) do
    start_offset = main_axis_size - total_content_size
    justify_children(children, start_offset, gap)
  end

  @spec justify_space_between([map()], number(), number(), number()) :: [map()]
  defp justify_space_between(children, main_axis_size, total_content_size, gap) do
    total_items = length(children)

    do_justify_space_between(
      total_items,
      children,
      main_axis_size,
      total_content_size,
      gap
    )
  end

  @spec justify_children([map()], number(), number()) :: [map()]
  defp justify_children(children, start_offset, gap) do
    children
    |> Enum.scan({start_offset, nil}, fn child, {pos, _prev_child} ->
      {child_width, _child_height} = Map.get(child, :measured_size)
      positioned_child = Map.put(child, :main_axis_position, pos)
      {pos + child_width + gap, positioned_child}
    end)
    |> Enum.map(fn {_pos, child} -> child end)
  end

  @spec apply_alignment([map()], atom(), number(), atom()) :: [map()]
  defp apply_alignment(children, align, cross_axis_size, _direction) do
    Enum.map(children, fn child ->
      {_child_width, child_height} = Map.get(child, :measured_size)

      cross_axis_position =
        calculate_cross_axis_position(align, cross_axis_size, child_height)

      Map.put(child, :cross_axis_position, cross_axis_position)
    end)
  end

  @spec calculate_cross_axis_position(atom(), number(), number()) :: number()
  defp calculate_cross_axis_position(align, cross_axis_size, child_size) do
    case align do
      :start -> 0
      :center -> (cross_axis_size - child_size) / 2
      :end -> cross_axis_size - child_size
      _ -> 0
    end
  end

  @spec apply_gap_spacing([map()], number(), atom()) :: [map()]
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

  @spec validate_flex_direction(:row | :column) :: :row | :column
  defp validate_flex_direction(:row), do: :row
  @spec validate_flex_direction(:row | :column) :: :row | :column
  defp validate_flex_direction(:column), do: :column

  @spec validate_flex_direction(term()) :: no_return()
  defp validate_flex_direction(direction) do
    raise ArgumentError, "Invalid flex direction: #{inspect(direction)}"
  end

  @spec calculate_new_width(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: non_neg_integer()
  defp calculate_new_width(0, child_w, _gap), do: child_w

  @spec calculate_new_width(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: non_neg_integer()
  defp calculate_new_width(line_width, child_w, gap),
    do: line_width + gap + child_w

  @spec handle_line_wrapping(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          [[map()]],
          [map()],
          map(),
          non_neg_integer()
        ) :: {[[map()]], [map()], non_neg_integer()}
  defp handle_line_wrapping(
         new_width,
         width,
         line_width,
         lines,
         line,
         child,
         child_w
       )
       when new_width > width and line_width > 0 do
    {[line | lines], [child], child_w}
  end

  @spec handle_line_wrapping(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          [[map()]],
          [map()],
          map(),
          non_neg_integer()
        ) :: {[[map()]], [map()], non_neg_integer()}
  defp handle_line_wrapping(
         new_width,
         _width,
         _line_width,
         lines,
         line,
         child,
         _child_w
       ) do
    {lines, [child | line], new_width}
  end

  @spec calculate_new_height(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: non_neg_integer()
  defp calculate_new_height(0, child_h, _gap), do: child_h

  @spec calculate_new_height(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: non_neg_integer()
  defp calculate_new_height(column_height, child_h, gap),
    do: column_height + gap + child_h

  @spec handle_column_wrapping(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          [[map()]],
          [map()],
          map(),
          non_neg_integer()
        ) :: {[[map()]], [map()], non_neg_integer()}
  defp handle_column_wrapping(
         new_height,
         height,
         column_height,
         columns,
         column,
         child,
         child_h
       )
       when new_height > height and column_height > 0 do
    {[column | columns], [child], child_h}
  end

  @spec handle_column_wrapping(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          [[map()]],
          [map()],
          map(),
          non_neg_integer()
        ) :: {[[map()]], [map()], non_neg_integer()}
  defp handle_column_wrapping(
         new_height,
         _height,
         _column_height,
         columns,
         column,
         child,
         _child_h
       ) do
    {columns, [child | column], new_height}
  end

  @spec handle_line_positioning([map()], non_neg_integer(), non_neg_integer()) ::
          [map()]
  defp handle_line_positioning([], _line_idx, _gap), do: []

  @spec handle_line_positioning([map()], non_neg_integer(), non_neg_integer()) ::
          [map()]
  defp handle_line_positioning(line, line_idx, gap) do
    position_children_in_line(line, line_idx, gap)
  end

  @spec handle_column_positioning([map()], non_neg_integer(), non_neg_integer()) ::
          [map()]
  defp handle_column_positioning([], _col_idx, _gap), do: []

  @spec handle_column_positioning([map()], non_neg_integer(), non_neg_integer()) ::
          [map()]
  defp handle_column_positioning(column, col_idx, gap) do
    position_children_in_column(column, col_idx, gap)
  end

  @spec do_justify_space_between(
          non_neg_integer(),
          [map()],
          number(),
          number(),
          number()
        ) :: [map()]
  defp do_justify_space_between(
         total_items,
         children,
         _main_axis_size,
         _total_content_size,
         gap
       )
       when total_items <= 1 do
    justify_start(children, gap)
  end

  @spec do_justify_space_between(
          non_neg_integer(),
          [map()],
          number(),
          number(),
          number()
        ) :: [map()]
  defp do_justify_space_between(
         total_items,
         children,
         main_axis_size,
         total_content_size,
         gap
       ) do
    # Calculate space between items
    total_item_width = total_content_size - gap * (total_items - 1)
    space_between = (main_axis_size - total_item_width) / (total_items - 1)
    justify_children(children, 0, space_between)
  end

  @spec do_calculate_layout(
          boolean(),
          [map()],
          atom(),
          {non_neg_integer(), non_neg_integer()},
          non_neg_integer(),
          map()
        ) :: [map()]
  defp do_calculate_layout(
         true,
         measured_children,
         direction,
         dimensions,
         gap,
         _container
       ) do
    wrap_flex_layout(measured_children, direction, dimensions, gap)
  end

  @spec do_calculate_layout(
          boolean(),
          [map()],
          atom(),
          {non_neg_integer(), non_neg_integer()},
          non_neg_integer(),
          map()
        ) :: [map()]
  defp do_calculate_layout(
         false,
         measured_children,
         direction,
         {width, height},
         gap,
         container
       ) do
    # Existing non-wrapping logic
    {main_axis_size, cross_axis_size} =
      get_axis_sizes(direction, {width, height})

    total_content_size = calculate_total_content_size(measured_children, gap)

    justified_children =
      apply_justification(
        measured_children,
        container.justify,
        main_axis_size,
        total_content_size,
        gap
      )

    aligned_children =
      apply_alignment(
        justified_children,
        container.align,
        cross_axis_size,
        direction
      )

    apply_gap_spacing(aligned_children, gap, direction)
  end
end
