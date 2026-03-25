defmodule Raxol.UI.Layout.Flexbox.Positioner do
  @moduledoc """
  Main-axis and cross-axis positioning for flex items, including
  justify-content and align-items logic.
  """

  @doc "Position sized children along the main axis."
  def position_main_axis(sized_children, space, flex_props, main_axis) do
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

    start_coord = get_coord(space, main_axis) + start_pos

    {_, positioned} =
      Enum.reduce(sized_children, {start_coord, []}, fn {child, dims, flex},
                                                        {current_pos, acc} ->
        child_space = build_child_space(space, dims, main_axis, current_pos)
        next_pos = current_pos + get_dimension(dims, main_axis) + item_gap
        {next_pos, [{child, child_space, flex} | acc]}
      end)

    Enum.reverse(positioned)
  end

  @doc "Position children along the cross axis according to align-items."
  def position_cross_axis(positioned_children, space, flex_props, cross_axis) do
    Enum.map(positioned_children, fn {child, child_space, flex} ->
      alignment = flex.align_self || flex_props.align_items
      new_child_space = align_cross(child_space, space, cross_axis, alignment)
      {child, new_child_space}
    end)
  end

  def align_cross(child_space, space, cross_axis, alignment) do
    origin = get_coord(space, cross_axis)
    total = get_dimension(space, cross_axis)
    child_size = get_dimension(child_space, cross_axis)

    case alignment do
      :flex_start ->
        set_cross_coord(child_space, cross_axis, origin)

      :flex_end ->
        set_cross_coord(child_space, cross_axis, origin + total - child_size)

      :center ->
        set_cross_coord(
          child_space,
          cross_axis,
          origin + div(total - child_size, 2)
        )

      :stretch ->
        child_space
        |> set_cross_coord(cross_axis, origin)
        |> set_cross_dimension(cross_axis, total)

      _ ->
        child_space
    end
  end

  # ---------------------------------------------------------------------------
  # justify-content positioning
  # ---------------------------------------------------------------------------

  def calculate_justify_positioning(
        :flex_start,
        _available_space,
        _item_count,
        gap
      ) do
    {0, gap}
  end

  def calculate_justify_positioning(
        :flex_end,
        available_space,
        _item_count,
        gap
      ) do
    {available_space, gap}
  end

  def calculate_justify_positioning(:center, available_space, _item_count, gap) do
    {div(available_space, 2), gap}
  end

  def calculate_justify_positioning(
        :space_between,
        available_space,
        item_count,
        _gap
      )
      when item_count > 1 do
    {0, div(available_space, item_count - 1)}
  end

  def calculate_justify_positioning(
        :space_around,
        available_space,
        item_count,
        _gap
      ) do
    space_per_item = div(available_space, item_count)
    {div(space_per_item, 2), space_per_item}
  end

  def calculate_justify_positioning(
        :space_evenly,
        available_space,
        item_count,
        _gap
      ) do
    space_per_gap = div(available_space, item_count + 1)
    {space_per_gap, space_per_gap}
  end

  def calculate_justify_positioning(_, _available_space, _item_count, gap) do
    {0, gap}
  end

  # ---------------------------------------------------------------------------
  # Cross-axis line positioning (align-content)
  # ---------------------------------------------------------------------------

  @doc "Position wrapped lines along the cross axis."
  def position_lines_cross_axis(
        lines_with_layout,
        space,
        flex_props,
        cross_axis
      ) do
    line_heights =
      Enum.map(lines_with_layout, fn line ->
        Enum.reduce(line, 0, fn item, acc ->
          max(acc, get_dimension(item_space(item), cross_axis))
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

    start_coord = get_coord(space, cross_axis) + start_pos

    {_, positioned_lines} =
      lines_with_layout
      |> Enum.zip(line_heights)
      |> Enum.reduce({start_coord, []}, fn {line, line_height},
                                           {current_pos, acc} ->
        positioned_line =
          Enum.map(line, &set_item_cross_pos(&1, cross_axis, current_pos))

        next_pos = current_pos + line_height + line_gap
        {next_pos, positioned_line ++ acc}
      end)

    positioned_lines
  end

  def calculate_align_content_positioning(
        :flex_start,
        _available_space,
        _line_count,
        gap
      ) do
    {0, gap}
  end

  def calculate_align_content_positioning(
        :flex_end,
        available_space,
        _line_count,
        gap
      ) do
    {available_space, gap}
  end

  def calculate_align_content_positioning(
        :center,
        available_space,
        _line_count,
        gap
      ) do
    {div(available_space, 2), gap}
  end

  def calculate_align_content_positioning(
        :space_between,
        available_space,
        line_count,
        _gap
      )
      when line_count > 1 do
    {0, div(available_space, line_count - 1)}
  end

  def calculate_align_content_positioning(
        :space_around,
        available_space,
        line_count,
        _gap
      ) do
    space_per_line = div(available_space, line_count)
    {div(space_per_line, 2), space_per_line}
  end

  def calculate_align_content_positioning(_, _available_space, _line_count, gap) do
    {0, gap}
  end

  # ---------------------------------------------------------------------------
  # Coordinate helpers
  # ---------------------------------------------------------------------------

  def get_coord(space, :horizontal), do: space.x
  def get_coord(space, :vertical), do: space.y

  def get_dimension(dims, :horizontal), do: dims.width
  def get_dimension(dims, :vertical), do: dims.height

  def get_gap_size(gap, :horizontal), do: gap.column
  def get_gap_size(gap, :vertical), do: gap.row

  def set_cross_coord(space, :horizontal, pos), do: %{space | x: pos}
  def set_cross_coord(space, :vertical, pos), do: %{space | y: pos}

  def set_cross_dimension(space, :horizontal, val), do: %{space | width: val}
  def set_cross_dimension(space, :vertical, val), do: %{space | height: val}

  def build_child_space(space, dims, :horizontal, main_pos) do
    %{x: main_pos, y: space.y, width: dims.width, height: dims.height}
  end

  def build_child_space(space, dims, :vertical, main_pos) do
    %{x: space.x, y: main_pos, width: dims.width, height: dims.height}
  end

  def item_space({_child, child_space, _flex}), do: child_space
  def item_space({_child, child_space}), do: child_space

  def set_item_cross_pos({child, child_space}, cross_axis, pos) do
    {child, set_cross_coord(child_space, cross_axis, pos)}
  end

  def set_item_cross_pos({child, child_space, _flex}, cross_axis, pos) do
    {child, set_cross_coord(child_space, cross_axis, pos)}
  end
end
