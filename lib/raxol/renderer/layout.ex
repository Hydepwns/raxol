defmodule Raxol.Renderer.Layout do
  import Raxol.Guards
  import Kernel, except: [to_string: 1]
  require Raxol.Core.Renderer.View

  @moduledoc """
  Handles layout calculations for UI elements.

  This module translates the logical layout (panels, rows, columns)
  into absolute positions for rendering.
  """

  # Define container and valid types as module attributes
  @container_types [
    :box,
    :row,
    :column,
    :flex,
    :table,
    :border,
    :grid,
    :chart,
    :scroll,
    :shadow_wrapper,
    :view,
    :panel
  ]
  @valid_types [
    :box,
    :row,
    :column,
    :flex,
    :table,
    :border,
    :grid,
    :chart,
    :text,
    :label,
    :button,
    :checkbox,
    :scroll,
    :shadow_wrapper
  ]

  # Default styles
  @default_style %{fg: :white, bg: :black}
  @default_button_style %{fg: :white, bg: :blue}
  @default_text_input_style %{fg: :white, bg: :black}
  @default_placeholder_style %{fg: :gray, bg: :black}

  # Define element processors map
  @element_processors %{
    view: :process_view_element,
    panel: :process_panel_element,
    label: :process_label_element,
    button: :process_button_element,
    text_input: :process_text_input_element,
    checkbox: :process_checkbox_element,
    table: :process_table_element,
    scroll: :process_scroll_element,
    shadow_wrapper: :process_shadow_wrapper_element,
    box: :process_box_element,
    flex: :process_flex_element,
    text: :process_text_element,
    border: :process_border_element,
    grid: :process_grid_element
  }

  @doc """
  Applies layout to a view, calculating absolute positions for all elements.

  ## Parameters

  * `view` - The view to calculate layout for
  * `dimensions` - Terminal dimensions `%{width: w, height: h}`

  ## Returns

  A list of positioned elements with absolute coordinates.
  """
  def apply_layout(view, dimensions) do
    available_space = %{
      x: 0,
      y: 0,
      width: dimensions.width,
      height: dimensions.height
    }

    normalized_view =
      normalize_view_for_layout(view, available_space, dimensions)

    result = process_element(normalized_view, available_space, [])
    flatten_result(result)
  end

  defp normalize_view_for_layout(view, available_space, dimensions) do
    normalized_views = deep_normalize_child(view, available_space, :box, true)

    case normalized_views do
      [single_view] -> single_view
      [first_view | _rest] -> first_view
      [] -> create_default_view(dimensions)
      single_map when map?(single_map) -> single_map
      _other -> create_default_view(dimensions)
    end
  end

  defp create_default_view(dimensions) do
    %{
      type: :box,
      position: {0, 0},
      size: {dimensions.width, dimensions.height},
      children: []
    }
  end

  defp flatten_result(result) do
    flat = List.flatten(result) |> Enum.reject(&nil?/1)

    case flat do
      [single_map] when map?(single_map) -> single_map
      _ -> flat
    end
  end

  # Process element functions - simplified main function
  defp process_element(element, space, acc) do
    case element do
      %{type: type} = el ->
        process_function = @element_processors[type]

        if process_function,
          do: apply(__MODULE__, process_function, [el, space, acc]),
          else: acc

      _ ->
        acc
    end
  end

  # Extract each element type into its own function
  def process_view_element(%{children: children}, space, acc)
      when list?(children) do
    process_children(children, space, acc)
  end

  def process_view_element(%{children: children}, space, acc) do
    process_element(children, space, acc)
  end

  def process_panel_element(%{attrs: attrs, children: children}, space, acc)
      when list?(children) do
    panel_space = apply_panel_layout(space, attrs)
    panel_elements = create_panel_elements(space, attrs)
    inner_elements = process_children(children, panel_space, [])
    [panel_elements, inner_elements | acc]
  end

  def process_label_element(%{attrs: attrs}, space, acc) do
    text = Map.get(attrs, :content, "")
    style = Map.get(attrs, :style, @default_style)

    text_element = %{
      type: :text,
      position: {space.x, space.y},
      size: {space.width, 1},
      content: text,
      style: style
    }

    [text_element | acc]
  end

  def process_button_element(%{attrs: attrs}, space, acc) do
    text = Map.get(attrs, :label, "Button")
    style = Map.get(attrs, :style, @default_button_style)
    text_style = Map.get(attrs, :text_style, style)
    button_width = min(String.length(text) + 4, space.width)

    button_elements = [
      %{
        type: :box,
        position: {space.x, space.y},
        size: {button_width, 3},
        style: style
      },
      %{
        type: :text,
        position: {space.x + 2, space.y + 1},
        size: {button_width, 1},
        content: text,
        style: text_style
      }
    ]

    button_elements ++ acc
  end

  def process_text_input_element(%{attrs: attrs}, space, acc) do
    value = Map.get(attrs, :value, "")
    placeholder = Map.get(attrs, :placeholder, "")
    text = if value == "", do: placeholder, else: value
    style = Map.get(attrs, :style, @default_text_input_style)

    placeholder_style =
      Map.get(attrs, :placeholder_style, @default_placeholder_style)

    input_width = min(max(String.length(text) + 4, 10), space.width)

    text_input_elements = [
      %{
        type: :box,
        position: {space.x, space.y},
        size: {input_width, 3},
        style: style
      },
      %{
        type: :text,
        position: {space.x + 2, space.y + 1},
        size: {input_width, 1},
        content: text,
        style: if(value == "", do: placeholder_style, else: style)
      }
    ]

    text_input_elements ++ acc
  end

  def process_checkbox_element(%{attrs: attrs}, space, acc) do
    checked = Map.get(attrs, :checked, false)
    label = Map.get(attrs, :label, "")
    style = Map.get(attrs, :style, @default_style)
    checkbox_text = if checked, do: "[✓]", else: "[ ]"
    text = "#{checkbox_text} #{label}"

    checkbox_elements = [
      %{
        type: :text,
        position: {space.x, space.y},
        size: {String.length(text), 1},
        content: text,
        style: style
      }
    ]

    checkbox_elements ++ acc
  end

  def process_table_element(element_map, space, acc) do
    # Check if this is a table struct that has been converted to a map
    if Map.get(element_map, :__struct__) == Raxol.Core.Renderer.Views.Table do
      # Use the table's build_table_content function to get proper children with separator row
      table_children =
        Raxol.Core.Renderer.Views.Table.build_table_content(element_map)

      [
        Map.merge(element_map, %{
          position: {space.x, space.y},
          size: {space.width, space.height},
          children: table_children
        })
        | acc
      ]
    else
      # For non-table elements, process normally
      [element_map | acc]
    end
  end

  def process_scroll_element(%{children: children} = scroll_map, space, acc)
      when list?(children) do
    scroll_config = extract_scroll_config(scroll_map, space)

    scrolled_children =
      process_scrolled_children(children, space, scroll_config)

    scrollbar_elements = create_scrollbar_elements(scroll_config)

    scrolled_children ++ scrollbar_elements ++ acc
  end

  def process_shadow_wrapper_element(
        %{children: children, opts: opts},
        space,
        acc
      )
      when list?(children) do
    offset = Map.get(opts, :offset, {1, 1})
    {offset_x, offset_y} = offset

    # Process children without shadow offset (content should be at original position)
    shadow_children = process_children(children, space, [])

    # Add shadow effect elements
    shadow_elements = create_shadow_elements(space, offset)

    shadow_children ++ shadow_elements ++ acc
  end

  def process_shadow_wrapper_element(
        %{children: children, opts: opts},
        space,
        acc
      ) do
    offset = Map.get(opts, :offset, {1, 1})
    {offset_x, offset_y} = offset

    # Process single child without shadow offset (content should be at original position)
    shadow_child = process_element(children, space, [])

    # Add shadow effect elements
    shadow_elements = create_shadow_elements(space, offset)

    shadow_child ++ shadow_elements ++ acc
  end

  def process_box_element(%{children: children} = element_map, space, acc) do
    style = Map.get(element_map, :style, %{})
    border = Map.get(element_map, :border, false)
    size = calculate_box_size(element_map, space)

    box = %{
      type: :box,
      position: {space.x, space.y},
      size: size,
      style: style,
      border: border
    }

    if list?(children) and children != [] do
      inner_space = %{
        x: space.x,
        y: space.y,
        width: elem(size, 0),
        height: elem(size, 1)
      }

      processed_children = process_children(children, inner_space, [])
      [Map.put(box, :children, processed_children) | acc]
    else
      [box | acc]
    end
  end

  def process_box_element(element_map, space, acc) do
    # Handle case where element_map doesn't have :children key
    element_map_with_children = Map.put(element_map, :children, [])
    process_box_element(element_map_with_children, space, acc)
  end

  defp calculate_box_size(element_map, space) do
    size = Map.get(element_map, :size)
    calculate_size(size, space)
  end

  defp calculate_size({w, h}, _space) when integer?(w) and integer?(h),
    do: {max(0, w), max(0, h)}

  defp calculate_size({w, :auto}, space) when integer?(w),
    do: {max(0, w), max(0, space.height)}

  defp calculate_size({:auto, h}, space) when integer?(h),
    do: {max(0, space.width), max(0, h)}

  defp calculate_size(:auto, space),
    do: {max(0, space.width), max(0, space.height)}

  defp calculate_size(_, space), do: {max(0, space.width), max(0, space.height)}

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

  def process_text_element(%{content: content} = element_map, space, acc) do
    style = Map.get(element_map, :style, @default_style)
    size = Map.get(element_map, :size, {String.length(content), 1})

    text_element = %{
      type: :text,
      position: {space.x, space.y},
      size: size,
      content: content,
      style: style
    }

    [text_element | acc]
  end

  def process_border_element(
        %{children: children, border: border_style} = element_map,
        space,
        acc
      ) do
    # Create border container
    border_container = %{
      type: :border,
      position: {space.x, space.y},
      size: {space.width, space.height},
      style: Map.get(element_map, :style, @default_style),
      border: border_style,
      children: []
    }

    # Always process children if present (even if empty or not a list)
    processed_children =
      case children do
        nil ->
          []

        list when is_list(list) ->
          Enum.flat_map(list, fn child ->
            normalized_child = ensure_required_keys(child, space)
            process_element(normalized_child, space, [])
          end)

        single ->
          normalized_child = ensure_required_keys(single, space)
          process_element(normalized_child, space, [])
      end

    [Map.put(border_container, :children, processed_children) | acc]
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

  # Helper function to calculate content dimensions
  defp calculate_content_dimensions(scrolled_children) do
    if Enum.empty?(scrolled_children) do
      {0, 0}
    else
      {min_x, min_y, max_x, max_y} = calculate_bounds(scrolled_children)
      {max(0, max_x - min_x), max(0, max_y - min_y)}
    end
  end

  defp calculate_bounds(scrolled_children) do
    positions = Enum.map(scrolled_children, &Map.get(&1, :position, {0, 0}))
    sizes = Enum.map(scrolled_children, &Map.get(&1, :size, {0, 0}))

    {min_x, min_y} = calculate_min_bounds(positions)
    {max_x, max_y} = calculate_max_bounds(positions, sizes)

    {min_x, min_y, max_x, max_y}
  end

  defp calculate_min_bounds(positions) do
    {
      Enum.map(positions, &elem(&1, 0)) |> Enum.min(),
      Enum.map(positions, &elem(&1, 1)) |> Enum.min()
    }
  end

  defp calculate_max_bounds(positions, sizes) do
    {
      Enum.zip_with(positions, sizes, fn {x, _}, {w, _} -> x + w end)
      |> Enum.max(),
      Enum.zip_with(positions, sizes, fn {_, y}, {_, h} -> y + h end)
      |> Enum.max()
    }
  end

  # Helper function to create scrollbar elements
  defp create_scrollbar_elements(%{
         space: space,
         viewport_width: viewport_width,
         viewport_height: viewport_height,
         content_width: content_width,
         content_height: content_height,
         ox: ox,
         oy: oy,
         scrollbar_thickness: scrollbar_thickness,
         render_v_bar: render_v_bar,
         render_h_bar: render_h_bar,
         scrollbar_attrs: scrollbar_attrs
       }) do
    elements = []

    elements =
      create_vertical_scrollbar(elements, %{
        space: space,
        viewport_width: viewport_width,
        viewport_height: viewport_height,
        content_height: content_height,
        oy: oy,
        scrollbar_thickness: scrollbar_thickness,
        render_v_bar: render_v_bar,
        scrollbar_attrs: scrollbar_attrs
      })

    elements =
      create_horizontal_scrollbar(elements, %{
        space: space,
        viewport_width: viewport_width,
        viewport_height: viewport_height,
        content_width: content_width,
        ox: ox,
        scrollbar_thickness: scrollbar_thickness,
        render_h_bar: render_h_bar,
        scrollbar_attrs: scrollbar_attrs
      })

    create_corner_element(elements, %{
      space: space,
      viewport_width: viewport_width,
      viewport_height: viewport_height,
      scrollbar_thickness: scrollbar_thickness,
      render_v_bar: render_v_bar,
      render_h_bar: render_h_bar,
      scrollbar_attrs: scrollbar_attrs
    })
  end

  defp create_scrollbar_elements(_), do: []

  defp create_vertical_scrollbar(elements, %{
         space: space,
         viewport_width: viewport_width,
         viewport_height: viewport_height,
         content_height: content_height,
         oy: oy,
         scrollbar_thickness: scrollbar_thickness,
         render_v_bar: render_v_bar,
         scrollbar_attrs: scrollbar_attrs
       }) do
    if render_v_bar and space.width >= scrollbar_thickness and
         viewport_height > 0 do
      track =
        create_scrollbar_track(
          space.x + viewport_width,
          space.y,
          scrollbar_thickness,
          viewport_height,
          scrollbar_attrs
        )

      if content_height > viewport_height do
        thumb =
          create_vertical_thumb(
            space,
            viewport_width,
            viewport_height,
            content_height,
            oy,
            scrollbar_thickness,
            scrollbar_attrs
          )

        [thumb, track | elements]
      else
        [track | elements]
      end
    else
      elements
    end
  end

  defp create_horizontal_scrollbar(elements, %{
         space: space,
         viewport_width: viewport_width,
         viewport_height: viewport_height,
         content_width: content_width,
         ox: ox,
         scrollbar_thickness: scrollbar_thickness,
         render_h_bar: render_h_bar,
         scrollbar_attrs: scrollbar_attrs
       }) do
    if render_h_bar and space.height >= scrollbar_thickness and
         viewport_width > 0 do
      track =
        create_scrollbar_track(
          space.x,
          space.y + viewport_height,
          viewport_width,
          scrollbar_thickness,
          scrollbar_attrs
        )

      if content_width > viewport_width do
        thumb =
          create_horizontal_thumb(
            space,
            viewport_width,
            viewport_height,
            content_width,
            ox,
            scrollbar_thickness,
            scrollbar_attrs
          )

        [thumb, track | elements]
      else
        [track | elements]
      end
    else
      elements
    end
  end

  defp create_corner_element(elements, %{
         space: space,
         viewport_width: viewport_width,
         viewport_height: viewport_height,
         scrollbar_thickness: scrollbar_thickness,
         render_v_bar: render_v_bar,
         render_h_bar: render_h_bar,
         scrollbar_attrs: scrollbar_attrs
       }) do
    if render_v_bar and render_h_bar and space.width >= scrollbar_thickness and
         space.height >= scrollbar_thickness do
      corner = %{
        type: :box,
        position: {space.x + viewport_width, space.y + viewport_height},
        size: {scrollbar_thickness, scrollbar_thickness},
        style: %{fg: scrollbar_attrs.corner_fg, bg: scrollbar_attrs.corner_bg}
      }

      [corner | elements]
    else
      elements
    end
  end

  defp create_scrollbar_track(x, y, width, height, scrollbar_attrs) do
    %{
      type: :box,
      position: {x, y},
      size: {width, height},
      style: %{fg: scrollbar_attrs.track_fg, bg: scrollbar_attrs.track_bg}
    }
  end

  defp create_vertical_thumb(
         space,
         viewport_width,
         viewport_height,
         content_height,
         oy,
         scrollbar_thickness,
         scrollbar_attrs
       ) do
    thumb_height =
      max(1, round(viewport_height * (viewport_height / content_height)))

    scroll_ratio = oy / (content_height - viewport_height)
    thumb_y = space.y + round(scroll_ratio * (viewport_height - thumb_height))

    %{
      type: :box,
      position: {space.x + viewport_width, thumb_y},
      size: {scrollbar_thickness, thumb_height},
      style: %{fg: scrollbar_attrs.thumb_fg, bg: scrollbar_attrs.thumb_bg}
    }
  end

  defp create_horizontal_thumb(
         space,
         viewport_width,
         viewport_height,
         content_width,
         ox,
         scrollbar_thickness,
         scrollbar_attrs
       ) do
    thumb_width =
      max(1, round(viewport_width * (viewport_width / content_width)))

    scroll_ratio = ox / (content_width - viewport_width)
    thumb_x = space.x + round(scroll_ratio * (viewport_width - thumb_width))

    %{
      type: :box,
      position: {thumb_x, space.y + viewport_height},
      size: {thumb_width, scrollbar_thickness},
      style: %{fg: scrollbar_attrs.thumb_fg, bg: scrollbar_attrs.thumb_bg}
    }
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
         {acc, x, y, line_h},
         space,
         gap
       ) do
    new_y = y + line_h + gap
    child_space = create_child_space(space, space.x, space.y + new_y, cw, ch)
    processed = process_element(child, child_space, [])
    {[processed | acc], cw, new_y, ch}
  end

  defp process_wrapped_row_no_wrap(
         child,
         {cw, ch},
         {acc, x, y, line_h},
         space,
         x_start
       ) do
    child_space =
      create_child_space(space, space.x + x_start, space.y + y, cw, ch)

    processed = process_element(child, child_space, [])
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
         {acc, x, y, col_h},
         space,
         gap
       ) do
    y_start = y + if(y == 0, do: 0, else: gap)
    needs_wrap = y > 0 and y_start + ch > space.height

    if needs_wrap do
      process_wrapped_column_wrap(
        child,
        {cw, ch},
        {acc, x, y, col_h},
        space,
        gap
      )
    else
      process_wrapped_column_no_wrap(
        child,
        {cw, ch},
        {acc, x, y, col_h},
        space,
        y_start
      )
    end
  end

  defp process_wrapped_column_wrap(
         child,
         {cw, ch},
         {acc, x, y, col_h},
         space,
         gap
       ) do
    new_x = x + col_h + gap
    child_space = create_child_space(space, space.x + new_x, space.y, cw, ch)
    processed = process_element(child, child_space, [])
    {[processed | acc], new_x, ch, col_h}
  end

  defp process_wrapped_column_no_wrap(
         child,
         {cw, ch},
         {acc, x, y, col_h},
         space,
         y_start
       ) do
    child_space =
      create_child_space(space, space.x + x, space.y + y_start, cw, ch)

    processed = process_element(child, child_space, [])
    {[processed | acc], x, y_start + ch, max(col_h, cw)}
  end

  defp process_non_wrapped(children, child_sizes, space, direction, gap) do
    case direction do
      :row -> process_row_layout(children, child_sizes, space, gap)
      :column -> process_column_layout(children, child_sizes, space, gap)
      _ -> process_row_layout(children, child_sizes, space, gap)
    end
  end

  defp process_row_layout(children, child_sizes, space, gap) do
    Enum.reduce(
      Enum.zip(children, child_sizes),
      {[], 0},
      fn {child, {cw, ch}}, {acc, x} ->
        child_space = create_child_space(space, space.x + x, space.y, cw, ch)
        processed = process_element(child, child_space, [])
        {processed ++ acc, x + cw + gap}
      end
    )
    |> elem(0)
    |> Enum.reverse()
  end

  defp process_column_layout(children, child_sizes, space, gap) do
    Enum.reduce(
      Enum.zip(children, child_sizes),
      {[], 0},
      fn {child, {cw, ch}}, {acc, y} ->
        child_space = create_child_space(space, space.x, space.y + y, cw, ch)
        processed = process_element(child, child_space, [])
        {processed ++ acc, y + ch + gap}
      end
    )
    |> elem(0)
    |> Enum.reverse()
  end

  # Apply panel layout, adjusting available space for contents
  defp apply_panel_layout(space, attrs) do
    padding = normalize_spacing_value(Map.get(attrs, :padding, 0))
    margin = normalize_spacing_value(Map.get(attrs, :margin, 0))
    border_thickness = 1

    calculate_content_space(space, padding, margin, border_thickness)
  end

  defp calculate_content_space(
         space,
         {pt, pr, pb, pl},
         {mt, mr, mb, ml},
         border_thickness
       ) do
    %{
      x: calculate_content_x(space, ml, border_thickness, pl),
      y: calculate_content_y(space, mt, border_thickness, pt),
      width: calculate_content_width(space, ml, mr, border_thickness, pl, pr),
      height: calculate_content_height(space, mt, mb, border_thickness, pt, pb)
    }
  end

  defp calculate_content_x(space, ml, border_thickness, pl),
    do: space.x + ml + border_thickness + pl

  defp calculate_content_y(space, mt, border_thickness, pt),
    do: space.y + mt + border_thickness + pt

  defp calculate_content_width(space, ml, mr, border_thickness, pl, pr),
    do: max(0, space.width - ml - mr - border_thickness * 2 - pl - pr)

  defp calculate_content_height(space, mt, mb, border_thickness, pt, pb),
    do: max(0, space.height - mt - mb - border_thickness * 2 - pt - pb)

  # Create panel border elements
  defp create_panel_elements(space, attrs) do
    title = Map.get(attrs, :title, "")
    margin = normalize_spacing_value(Map.get(attrs, :margin, 0))
    {mt, mr, mb, ml} = margin

    panel_dimensions = calculate_panel_dimensions(space, {mt, mr, mb, ml})
    styles = extract_panel_styles(attrs)

    create_panel_components(panel_dimensions, styles, title)
  end

  defp calculate_panel_dimensions(space, {mt, mr, mb, ml}) do
    %{
      x: space.x + ml,
      y: space.y + mt,
      width: max(0, space.width - ml - mr),
      height: max(0, space.height - mt - mb)
    }
  end

  defp extract_panel_styles(attrs) do
    panel_style = Map.get(attrs, :style, @default_style)
    title_style = Map.get(attrs, :title_style, panel_style)
    %{panel: panel_style, title: title_style}
  end

  defp create_panel_components(dimensions, styles, title) do
    box = %{
      type: :box,
      position: {dimensions.x, dimensions.y},
      size: {dimensions.width, dimensions.height},
      style: styles.panel
    }

    title_element = create_title_element(dimensions, styles.title, title)

    if title_element, do: [box, title_element], else: [box]
  end

  defp create_title_element(dimensions, title_style, title) do
    if title != "" and dimensions.width > 4 and dimensions.height > 0 do
      %{
        type: :text,
        position: {dimensions.x + 2, dimensions.y},
        size: {String.length(title) + 2, 1},
        content: " #{title} ",
        style: title_style
      }
    end
  end

  # Helper to normalize spacing values
  defp normalize_spacing_value(value) when integer?(value) and value >= 0,
    do: {value, value, value, value}

  defp normalize_spacing_value({v, h})
       when integer?(v) and integer?(h) and v >= 0 and h >= 0,
       do: {v, h, v, h}

  defp normalize_spacing_value({t, r, b, l})
       when integer?(t) and integer?(r) and integer?(b) and integer?(l) and
              t >= 0 and r >= 0 and b >= 0 and l >= 0,
       do: {t, r, b, l}

  defp normalize_spacing_value(_), do: {0, 0, 0, 0}

  # --- RECURSIVE NORMALIZATION FOR ALL CHILDREN ---
  # Helper to deeply normalize a child (struct, map, keyword, atom, etc)
  defp deep_normalize_child(child, space, default_type, for_layout \\ false) do
    if is_tuple(child) do
      raise "deep_normalize_child received a tuple: #{inspect(child)}"
    end

    normalize_by_type(child, space, default_type)
  end

  defp normalize_by_type(child, space, default_type) do
    cond do
      is_struct(child) ->
        [normalize_struct(child, space, default_type)]

      Keyword.keyword?(child) ->
        [normalize_keyword(child, space, default_type)]

      list?(child) ->
        normalize_list(child, space, default_type)

      map?(child) ->
        normalize_map(child, space, default_type)

      is_binary(child) ->
        [normalize_text(child, space, default_type)]

      is_number(child) ->
        [normalize_number(child, space, default_type)]

      is_atom(child) ->
        [normalize_atom(child, space, default_type)]

      true ->
        [normalize_unknown(child, space, default_type)]
    end
  end

  defp normalize_child_by_type(child, space, default_type, for_layout) do
    case get_child_type(child, for_layout) do
      :struct -> normalize_struct(child, space, default_type)
      :keyword -> normalize_keyword(child, space, default_type)
      :list -> normalize_list(child, space, default_type)
      :map -> normalize_map(child, space, default_type)
      :atom_for_layout -> normalize_atom_for_layout(child, space)
      :simple -> [%{type: child}]
      :unknown -> normalize_unknown(child, space, for_layout)
    end
  end

  defp get_child_type(child, for_layout) do
    cond do
      struct?(child) -> :struct
      Keyword.keyword?(child) -> :keyword
      list?(child) -> :list
      map?(child) -> :map
      atom_for_layout?(child, for_layout) -> :atom_for_layout
      simple_type?(child) -> :simple
      true -> :unknown
    end
  end

  defp keyword_list?(child, for_layout),
    do: for_layout and list?(child) and Keyword.keyword?(child)

  defp atom_for_layout?(child, for_layout), do: for_layout and atom?(child)
  defp simple_type?(child), do: atom?(child) or binary?(child) or number?(child)

  defp normalize_struct(child, space, _default_type) do
    map = Map.from_struct(child)
    struct_name = get_struct_name(child)
    intended_type = resolve_type(map, struct_name)

    # For table structs, always set children using build_table_content
    map =
      if intended_type == :table and struct_name == "table" do
        table_children =
          Raxol.Core.Renderer.Views.Table.build_table_content(child)

        Map.put(map, :children, table_children)
      else
        map
      end

    map
    |> Map.put_new(:position, {space.x, space.y})
    |> Map.put_new(:size, {space.width, space.height})
    |> add_children_if_needed(space)
    |> resolve_final_type(intended_type)
    |> ensure_required_keys(space)
  end

  defp normalize_keyword(child, space, default_type) do
    child
    |> Enum.into(%{})
    |> Map.put_new(:type, default_type)
    |> Map.put_new(:position, {space.x, space.y})
    |> Map.put_new(:size, {space.width, space.height})
    |> add_children_if_needed(space)
    |> ensure_required_keys(space)
  end

  defp normalize_list(child, space, default_type) do
    child
    |> List.flatten()
    |> Enum.flat_map(&deep_normalize_child(&1, space, :box, true))
  end

  defp normalize_map(child, space, default_type) do
    if Map.has_key?(child, :__struct__) do
      # Treat as struct
      normalize_struct(child, space, default_type)
    else
      child
      |> Map.put_new(:position, {space.x, space.y})
      |> Map.put_new(:size, {space.width, space.height})
      |> add_children_if_needed(space)
      |> resolve_final_type(default_type)
      |> ensure_required_keys(space)
    end
  end

  defp normalize_atom_for_layout(child, space) do
    if child in @valid_types do
      [ensure_required_keys(%{type: child, children: []}, space)]
    else
      [nil]
    end
  end

  defp normalize_unknown(child, space, for_layout) do
    if for_layout do
      [
        ensure_required_keys(
          %{type: :unknown, value: child, children: []},
          space
        )
      ]
    else
      [%{type: child}]
    end
  end

  defp get_struct_name(child) do
    child.__struct__
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end

  defp resolve_type(map, struct_name) do
    cond do
      Map.has_key?(map, :type) -> map.type
      struct_name == "chart" -> :chart
      struct_name == "table" -> :table
      struct_name == "border" -> :border
      struct_name == "grid" -> :grid
      true -> String.to_atom(struct_name)
    end
  end

  defp add_children_if_container(map, type, space) do
    if type in @container_types do
      Map.put_new(map, :children, [])
    else
      map
    end
  end

  defp add_children_if_needed(map, space) do
    if Map.has_key?(map, :children) do
      Map.put(map, :children, normalize_children(map.children, space))
    else
      map
    end
  end

  defp normalize_children(children, space) when is_list(children) do
    children
    |> Enum.flat_map(fn child ->
      normalize_single_child(child, space)
    end)
  end

  defp normalize_single_child(child_node, space) do
    normalized_child =
      if child_node_fully_normalized?(child_node) do
        child_node
      else
        ensure_required_keys(child_node, space)
      end

    # Always return a list, let normalize_children handle flattening
    [normalized_child]
  end

  defp child_node_fully_normalized?(child_node) do
    map?(child_node) and Map.has_key?(child_node, :type) and
      Map.has_key?(child_node, :position) and
      Map.has_key?(child_node, :size)
  end

  defp resolve_final_type(map, default_type) do
    final_type =
      cond do
        Map.has_key?(map, :__struct__) ->
          struct_name = get_struct_name(map)
          resolve_type(map, struct_name)

        Map.has_key?(map, :type) ->
          map.type

        true ->
          default_type
      end

    Map.put(map, :type, final_type)
  end

  # Ensure a map has :type, :position, :size, and :children (default []) if it is a container type
  defp ensure_required_keys(map_candidate, space) do
    map_candidate
    |> then(fn m ->
      if map?(m) do
        m
        |> Map.put_new(:type, :unknown)
        |> Map.put_new(:position, {space.x, space.y})
        |> Map.put_new(:size, {space.width, space.height})
      else
        %{
          type: :error_not_a_map,
          original_value: m,
          position: {space.x, space.y},
          size: {space.width, space.height}
        }
      end
    end)
    |> then(fn m ->
      if Map.get(m, :type) in @container_types,
        do: Map.put_new(m, :children, []),
        else: m
    end)
  end

  # --- Helper for padding cell content ---
  defp pad_cell_content(text_content, col_def) do
    text = Kernel.to_string(text_content)
    width = Map.get(col_def, :width, String.length(text))
    align = Map.get(col_def, :align, :left)

    case align do
      :right ->
        String.pad_leading(text, width)

      :center ->
        padding = max(0, width - String.length(text))
        left_pad = div(padding, 2)
        String.pad_leading(text, width - left_pad) |> String.pad_trailing(width)

      _ ->
        String.pad_trailing(text, width)
    end
  end

  # Table-related helper functions
  defp extract_table_styles(element_map) do
    %{
      header_style:
        Map.get(element_map, :header_style, %{fg: :white, bg: :blue}),
      row_style: Map.get(element_map, :row_style, %{fg: :white, bg: :black}),
      border_style:
        Map.get(element_map, :border_style, %{fg: :gray, bg: :black})
    }
  end

  defp create_table_header(column_defs, space, styles) do
    header_cells =
      Enum.map(column_defs, fn col_def ->
        text = Map.get(col_def, :title, "")
        width = Map.get(col_def, :width, String.length(text))

        %{
          type: :text,
          position: {space.x, space.y},
          size: {width, 1},
          content: pad_cell_content(text, col_def),
          style: styles.header_style
        }
      end)

    %{type: :row, children: header_cells}
  end

  defp create_table_data_rows(
         table_data,
         column_defs,
         space,
         styles,
         header_height
       ) do
    Enum.with_index(table_data, 1)
    |> Enum.map(fn {row_data, row_index} ->
      y_offset = space.y + header_height + row_index

      row_cells =
        Enum.with_index(column_defs)
        |> Enum.map(fn {col_def, col_index} ->
          cell_value = get_cell_value(row_data, col_def, col_index)

          width =
            Map.get(
              col_def,
              :width,
              String.length(Kernel.to_string(cell_value))
            )

          x_offset = space.x + calculate_column_offset(column_defs, col_index)

          %{
            type: :text,
            position: {x_offset, y_offset},
            size: {width, 1},
            content: pad_cell_content(cell_value, col_def),
            style: styles.row_style
          }
        end)

      %{type: :row, children: row_cells}
    end)
  end

  defp get_cell_value(row_data, col_def, col_index) do
    case Map.get(col_def, :key) do
      nil -> Enum.at(row_data, col_index, "")
      key when is_atom(key) -> Map.get(row_data, key, "")
      key when is_binary(key) -> Map.get(row_data, String.to_atom(key), "")
      _ -> Enum.at(row_data, col_index, "")
    end
  end

  defp calculate_column_offset(column_defs, col_index) do
    Enum.take(column_defs, col_index)
    |> Enum.reduce(0, fn col_def, acc ->
      acc + Map.get(col_def, :width, 0)
    end)
  end

  # Re-add the missing process_children/3 function
  defp process_children(children, space, acc) when is_list(children) do
    # Process each child and flatten the results, then add to the accumulator
    new_child_elements =
      Enum.flat_map(children, fn child_node ->
        normalized_child =
          if map?(child_node) and Map.has_key?(child_node, :type) and
               Map.has_key?(child_node, :position) and
               Map.has_key?(child_node, :size) do
            child_node
          else
            ensure_required_keys(child_node, space)
          end

        # Pass empty acc, collect this child's elements
        process_element(normalized_child, space, [])
      end)

    # Add all new child elements to the parent's accumulator
    new_child_elements ++ acc
  end

  defp process_children(child, space, acc) when map?(child) do
    normalized_child =
      if Map.has_key?(child, :type) and Map.has_key?(child, :position) and
           Map.has_key?(child, :size) do
        child
      else
        ensure_required_keys(child, space)
      end

    process_element(normalized_child, space, acc)
  end

  defp process_children(_other, _space, acc), do: acc

  defp extract_scroll_config(scroll_map, space) do
    {ox, oy} = Map.get(scroll_map, :offset, {0, 0})
    scrollbar_thickness = Map.get(scroll_map, :scrollbar_thickness, 1)
    render_v_bar = Map.get(scroll_map, :vertical_scrollbar, true)
    render_h_bar = Map.get(scroll_map, :horizontal_scrollbar, true)

    default_sb_attrs = %{
      track_fg: :gray,
      track_bg: nil,
      thumb_fg: :white,
      thumb_bg: :darkgray,
      corner_fg: :gray,
      corner_bg: nil
    }

    scrollbar_attrs =
      Map.merge(
        default_sb_attrs,
        Map.get(scroll_map, :scrollbar_attrs, Map.get(scroll_map, :attrs, %{}))
      )

    %{
      space: space,
      ox: ox,
      oy: oy,
      scrollbar_thickness: scrollbar_thickness,
      render_v_bar: render_v_bar,
      render_h_bar: render_h_bar,
      scrollbar_attrs: scrollbar_attrs
    }
  end

  defp process_scrolled_children(children, space, scroll_config) do
    %{
      ox: ox,
      oy: oy,
      scrollbar_thickness: scrollbar_thickness,
      render_v_bar: render_v_bar,
      render_h_bar: render_h_bar
    } = scroll_config

    scrolled_children =
      Enum.flat_map(children, fn child ->
        process_element(child, %{space | x: space.x - ox, y: space.y - oy}, [])
      end)

    {content_width, content_height} =
      calculate_content_dimensions(scrolled_children)

    viewport_width =
      max(0, space.width - if(render_v_bar, do: scrollbar_thickness, else: 0))

    viewport_height =
      max(0, space.height - if(render_h_bar, do: scrollbar_thickness, else: 0))

    scrollbar_elements =
      create_scrollbar_elements(%{
        space: space,
        viewport_width: viewport_width,
        viewport_height: viewport_height,
        content_width: content_width,
        content_height: content_height,
        ox: ox,
        oy: oy,
        scrollbar_thickness: scrollbar_thickness,
        render_v_bar: render_v_bar,
        render_h_bar: render_h_bar,
        scrollbar_attrs: scroll_config.scrollbar_attrs
      })

    scrolled_children ++ scrollbar_elements
  end

  defp create_shadow_elements(space, {offset_x, offset_y}) do
    shadow_color = :darkgray

    shadow_box = %{
      type: :box,
      position: {space.x + offset_x, space.y + offset_y},
      size: {space.width - offset_x, space.height - offset_y},
      style: %{bg: shadow_color, fg: shadow_color}
    }

    [shadow_box]
  end

  def process_grid_element(
        %{children: children, columns: columns, rows: rows, gap: gap} =
          element_map,
        space,
        acc
      ) do
    # Ensure the grid element has required properties for calculate_layout
    grid_element =
      Map.merge(
        %{
          align: :start,
          justify: :start
        },
        element_map
      )

    # Calculate grid layout using the grid module
    grid_layout =
      Raxol.Core.Renderer.View.Layout.Grid.calculate_layout(
        grid_element,
        {space.width, space.height}
      )

    # For each child, process it at its assigned position and size
    processed_children =
      Enum.flat_map(grid_layout, fn child ->
        # Each child should have :position and :size set by calculate_layout
        child_space = %{
          space
          | x: elem(child.position, 0),
            y: elem(child.position, 1),
            width: elem(child.size, 0),
            height: elem(child.size, 1)
        }

        result = process_element(child, child_space, [])
        List.wrap(result)
      end)

    # Return a grid container with positioned children instead of a flat list
    grid_container = %{
      type: :grid,
      position: {space.x, space.y},
      size: {space.width, space.height},
      columns: columns,
      rows: rows,
      gap: gap,
      children: processed_children
    }

    [grid_container | acc]
  end

  # Add normalization helpers for text, number, and atom
  defp normalize_text(child, space, _default_type) do
    [
      %{
        type: :text,
        content: child,
        position: {space.x, space.y},
        size: {space.width, 1}
      }
    ]
  end

  defp normalize_number(child, space, _default_type) do
    [
      %{
        type: :number,
        value: child,
        position: {space.x, space.y},
        size: {space.width, 1}
      }
    ]
  end

  defp normalize_atom(child, space, _default_type) do
    [
      %{
        type: :atom,
        value: child,
        position: {space.x, space.y},
        size: {space.width, 1}
      }
    ]
  end
end
