defmodule Raxol.Renderer.Layout.Flex do
  @moduledoc """
  Handles flex layout calculations for UI elements.

  This module provides flex layout algorithms including:
  - Row and column layouts
  - Wrapping behavior
  - Gap handling
  - Child size calculations
  """

  import Raxol.Guards

  @doc """
  Processes a flex element and returns positioned children.

  ## Parameters

  * `element_map` - The flex element configuration
  * `space` - Available space for layout
  * `acc` - Accumulator for processed elements

  ## Returns

  A list of positioned elements within the flex container.
  """
  def process_flex_element(%{children: children} = element_map, space, acc) do
    flex_config = extract_flex_config(element_map)
    child_sizes = calculate_child_sizes(children)

    processed_children =
      process_flex_layout(children, child_sizes, space, flex_config)

    # Return a flex container with positioned children instead of a flat list
    flex_container = %{
      type: :flex,
      position: {space.x, space.y},
      size: {space.width, space.height},
      direction: flex_config.direction,
      wrap: flex_config.wrap,
      gap: flex_config.gap,
      children: processed_children
    }

    [flex_container | acc]
  end

  defp extract_flex_config(element_map) do
    %{
      direction: Map.get(element_map, :direction, :column),
      wrap: Map.get(element_map, :wrap, false),
      gap: Map.get(element_map, :gap, 0)
    }
  end

  defp calculate_child_sizes(children) do
    Enum.map(children, fn child ->
      case Map.get(child, :size) do
        {w, h} when integer?(w) and integer?(h) and w >= 0 and h >= 0 -> {w, h}
        _ -> {1, 1}
      end
    end)
  end

  defp process_flex_layout(children, child_sizes, space, %{
         direction: direction,
         wrap: wrap,
         gap: gap
       }) do
    case {direction, wrap} do
      {:row, true} ->
        process_wrapped_row(children, child_sizes, space, gap)

      {:column, true} ->
        process_wrapped_column(children, child_sizes, space, gap)

      _ ->
        process_non_wrapped(children, child_sizes, space, direction, gap)
    end
  end

  # Helper functions for flex layout
  defp process_wrapped_row(children, child_sizes, space, gap) do
    {reversed_elements, _, _, _} =
      Enum.reduce(
        Enum.zip(children, child_sizes),
        {[], 0, 0, 0},
        &process_wrapped_row_item(&1, &2, space, gap)
      )

    Enum.reverse(reversed_elements) |> List.flatten()
  end

  defp process_wrapped_row_item(
         {child, {cw, ch}},
         {acc, x, y, line_h},
         space,
         gap
       ) do
    x_start = x + if(x == 0, do: 0, else: gap)
    needs_wrap = x > 0 and x_start + cw > space.width

    if needs_wrap do
      process_wrapped_row_wrap(child, {cw, ch}, {acc, x, y, line_h}, space, gap)
    else
      process_wrapped_row_no_wrap(
        child,
        {cw, ch},
        {acc, x, y, line_h},
        space,
        x_start
      )
    end
  end

  defp process_wrapped_row_wrap(
         child,
         {cw, ch},
         {acc, _x, y, line_h},
         space,
         gap
       ) do
    new_y = y + line_h + gap
    child_space = create_child_space(space, space.x, space.y + new_y, cw, ch)
    processed = Raxol.Renderer.Layout.process_element(child, child_space, [])
    {[processed | acc], cw, new_y, ch}
  end

  defp process_wrapped_row_no_wrap(
         child,
         {cw, ch},
         {acc, _x, y, line_h},
         space,
         x_start
       ) do
    child_space =
      create_child_space(space, space.x + x_start, space.y + y, cw, ch)

    processed = Raxol.Renderer.Layout.process_element(child, child_space, [])
    {[processed | acc], x_start + cw, y, max(line_h, ch)}
  end

  defp create_child_space(space, x, y, width, height) do
    %{space | x: x, y: y, width: width, height: height}
  end

  defp process_wrapped_column(children, child_sizes, space, gap) do
    {reversed_elements, _, _, _} =
      Enum.reduce(
        Enum.zip(children, child_sizes),
        {[], 0, 0, 0},
        &process_wrapped_column_item(&1, &2, space, gap)
      )

    Enum.reverse(reversed_elements) |> List.flatten()
  end

  defp process_wrapped_column_item(
         {child, {cw, ch}},
         {acc, x, y, col_w},
         space,
         gap
       ) do
    y_start = y + if(y == 0, do: 0, else: gap)
    needs_wrap = y > 0 and y_start + ch > space.height

    if needs_wrap do
      process_wrapped_column_wrap(child, {cw, ch}, {acc, x, y, col_w}, space, gap)
    else
      process_wrapped_column_no_wrap(
        child,
        {cw, ch},
        {acc, x, y, col_w},
        space,
        y_start
      )
    end
  end

  defp process_wrapped_column_wrap(
         child,
         {cw, ch},
         {acc, x, _y, col_w},
         space,
         gap
       ) do
    new_x = x + col_w + gap
    child_space = create_child_space(space, space.x + new_x, space.y, cw, ch)
    processed = Raxol.Renderer.Layout.process_element(child, child_space, [])
    {[processed | acc], new_x, ch, cw}
  end

  defp process_wrapped_column_no_wrap(
         child,
         {cw, ch},
         {acc, x, _y, col_w},
         space,
         y_start
       ) do
    child_space =
      create_child_space(space, space.x + x, space.y + y_start, cw, ch)

    processed = Raxol.Renderer.Layout.process_element(child, child_space, [])
    {[processed | acc], x, y_start + ch, max(col_w, cw)}
  end

  defp process_non_wrapped(children, child_sizes, space, direction, gap) do
    case direction do
      :row ->
        process_row_layout(children, child_sizes, space, gap)

      :column ->
        process_column_layout(children, child_sizes, space, gap)

      _ ->
        process_column_layout(children, child_sizes, space, gap)
    end
  end

  defp process_row_layout(children, child_sizes, space, gap) do
    {reversed_elements, _} =
      Enum.reduce(
        Enum.zip(children, child_sizes),
        {[], 0},
        fn {child, {cw, ch}}, {acc, x} ->
          x_start = x + if(x == 0, do: 0, else: gap)
          child_space = create_child_space(space, space.x + x_start, space.y, cw, ch)
          processed = Raxol.Renderer.Layout.process_element(child, child_space, [])
          {[processed | acc], x_start + cw}
        end
      )

    Enum.reverse(reversed_elements) |> List.flatten()
  end

  defp process_column_layout(children, child_sizes, space, gap) do
    {reversed_elements, _} =
      Enum.reduce(
        Enum.zip(children, child_sizes),
        {[], 0},
        fn {child, {cw, ch}}, {acc, y} ->
          y_start = y + if(y == 0, do: 0, else: gap)
          child_space = create_child_space(space, space.x, space.y + y_start, cw, ch)
          processed = Raxol.Renderer.Layout.process_element(child, child_space, [])
          {[processed | acc], y_start + ch}
        end
      )

    Enum.reverse(reversed_elements) |> List.flatten()
  end
end
