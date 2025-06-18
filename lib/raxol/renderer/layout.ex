defmodule Raxol.Renderer.Layout do
  import Kernel, except: [to_string: 1]
  require Raxol.Core.Renderer.View

  @moduledoc '''
  Handles layout calculations for UI elements.

  This module translates the logical layout (panels, rows, columns)
  into absolute positions for rendering.
  '''

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

  @doc '''
  Applies layout to a view, calculating absolute positions for all elements.

  ## Parameters

  * `view` - The view to calculate layout for
  * `dimensions` - Terminal dimensions `%{width: w, height: h}`

  ## Returns

  A list of positioned elements with absolute coordinates.
  '''
  def apply_layout(view, dimensions) do
    # Start with the full screen as available space
    available_space = %{
      x: 0,
      y: 0,
      width: dimensions.width,
      height: dimensions.height
    }

    # Deeply normalize the view tree before processing
    [normalized_view] = deep_normalize_child(view, available_space, :box, true)

    # Process the view tree
    result = process_element(normalized_view, available_space, [])
    flat = List.flatten(result) |> Enum.reject(&is_nil/1)

    # If the result is a single map, return it directly.
    # Otherwise, return the list (for multi-root, empty, or already correctly processed lists).
    case flat do
      [single_map] when is_map(single_map) -> single_map
      # Handles [], [map1, map2], etc.
      _ -> flat
    end
  end

  # Process element functions
  defp process_element(%{type: :view, children: children}, space, acc)
       when is_list(children) do
    # Process children with the available space
    process_children(children, space, acc)
  end

  defp process_element(%{type: :view, children: children}, space, acc) do
    # Handle case where children is not a list
    process_element(children, space, acc)
  end

  defp process_element(
         %{type: :panel, attrs: attrs, children: children},
         space,
         acc
       )
       when is_list(children) do
    # Apply panel specific layout (add border, title, etc)
    panel_space = apply_panel_layout(space, attrs)

    # Add the panel border to the accumulator
    panel_elements = create_panel_elements(space, attrs)

    # Process panel children with the new available space
    inner_elements = process_children(children, panel_space, [])

    [panel_elements, inner_elements | acc]
  end

  defp process_element(%{type: :label, attrs: attrs}, space, acc) do
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

  defp process_element(%{type: :button, attrs: attrs}, space, acc) do
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

  defp process_element(%{type: :text_input, attrs: attrs}, space, acc) do
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

  defp process_element(%{type: :checkbox, attrs: attrs}, space, acc) do
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

  defp process_element(%{type: :table} = element_map, space, acc) do
    # Extract table configuration
    column_defs = Map.get(element_map, :columns, [])
    table_data = Map.get(element_map, :data, [])
    headers = Enum.map(column_defs, &Map.get(&1, :header, ""))

    # Get styles with defaults
    default_style = %{fg: :white, bg: :black}

    header_style =
      Map.get(element_map, :header_style, Map.put(default_style, :bold, true))

    row_style = Map.get(element_map, :row_style, default_style)

    # Create header row if headers exist
    header_row_elements =
      if headers != [] do
        header_cells =
          Enum.map(column_defs, fn col_def ->
            %{
              type: :text,
              content: pad_cell_content(Map.get(col_def, :header, ""), col_def),
              style: header_style
            }
          end)

        [
          %{
            type: :row,
            children: header_cells,
            position: {space.x, space.y},
            style: header_style
          },
          %{
            type: :row,
            children: [
              %{type: :text, content: String.duplicate("-", space.width)}
            ],
            position: {space.x, space.y + 1}
          }
        ]
      else
        []
      end

    # Create data rows
    data_row_elements =
      table_data
      |> Enum.with_index()
      |> Enum.map(fn {row_data, row_index} ->
        cells =
          Enum.map(column_defs, fn col_def ->
            key = Map.get(col_def, :key)
            raw_value = Map.get(row_data, key, "")

            # Format and create cell element
            cell_element =
              cond do
                is_function(Map.get(col_def, :format), 1) ->
                  col_def.format.(raw_value)

                is_struct(raw_value) ->
                  raw_value
                  |> Map.from_struct()
                  |> Map.put(
                    :type,
                    raw_value.__struct__
                    |> Module.split()
                    |> List.last()
                    |> Macro.underscore()
                    |> String.to_atom()
                  )

                is_map(raw_value) and Map.has_key?(raw_value, :type) ->
                  raw_value

                true ->
                  %{
                    type: :text,
                    content:
                      pad_cell_content(Kernel.to_string(raw_value), col_def),
                    style: row_style
                  }
              end

            # Ensure cell has style
            Map.put_new(cell_element, :style, row_style)
          end)

        %{
          type: :row,
          children: cells,
          position:
            {space.x, space.y + row_index + length(header_row_elements)},
          size: {space.width, 1},
          style: row_style
        }
      end)

    # Combine and return final table
    [
      Map.merge(element_map, %{
        position: {space.x, space.y},
        size: {space.width, space.height},
        children: header_row_elements ++ data_row_elements
      })
      | acc
    ]
  end

  defp process_element(
         %{type: :scroll, children: children} = scroll_map,
         space,
         acc
       )
       when is_list(children) do
    # Extract scroll configuration
    {ox, oy} = Map.get(scroll_map, :offset, {0, 0})
    scrollbar_thickness = Map.get(scroll_map, :scrollbar_thickness, 1)
    render_v_bar = Map.get(scroll_map, :vertical_scrollbar, true)
    render_h_bar = Map.get(scroll_map, :horizontal_scrollbar, true)

    # Get scrollbar styles
    default_sb_attrs = %{
      track_fg: :gray,
      track_bg: nil,
      thumb_fg: :white,
      thumb_bg: :darkgray
    }

    scrollbar_attrs =
      Map.merge(
        default_sb_attrs,
        Map.get(scroll_map, :scrollbar_attrs, Map.get(scroll_map, :attrs, %{}))
      )

    # Process scrolled content
    scrolled_children =
      Enum.flat_map(children, fn child ->
        process_element(child, %{space | x: space.x - ox, y: space.y - oy}, [])
      end)

    # Calculate content dimensions
    {content_width, content_height} =
      calculate_content_dimensions(scrolled_children)

    # Calculate viewport dimensions
    viewport_width =
      max(0, space.width - if(render_v_bar, do: scrollbar_thickness, else: 0))

    viewport_height =
      max(0, space.height - if(render_h_bar, do: scrollbar_thickness, else: 0))

    # Create scrollbar elements
    scrollbar_elements =
      create_scrollbar_elements(
        space,
        viewport_width,
        viewport_height,
        content_width,
        content_height,
        ox,
        oy,
        scrollbar_thickness,
        render_v_bar,
        render_h_bar,
        scrollbar_attrs
      )

    scrolled_children ++ scrollbar_elements ++ acc
  end

  defp process_element(
         %{type: :shadow_wrapper, opts: attrs, children: child_view_node},
         space,
         acc
       ) do
    shadow_offset_x = Map.get(attrs, :offset_x, 1)
    shadow_offset_y = Map.get(attrs, :offset_y, 1)
    shadow_color = Map.get(attrs, :color, :darkgray)

    shadow_box_element = %{
      type: :box,
      position: {space.x + shadow_offset_x, space.y + shadow_offset_y},
      size: {space.width - shadow_offset_x, space.height - shadow_offset_y},
      style: %{bg: shadow_color, fg: shadow_color}
    }

    # Define the space for the actual content (on top of the shadow)
    content_space = %{
      space
      | # Content is smaller if shadow is outside
        width: space.width - shadow_offset_x,
        height: space.height - shadow_offset_y
    }

    # Process the actual child content within the content_space
    processed_child_content_elements =
      process_element(child_view_node, content_space, [])

    # The shadow box goes "behind" the content
    [shadow_box_element | processed_child_content_elements] ++ acc
  end

  defp process_element(%{type: :box} = element_map, space, acc) do
    # Get box configuration
    children = Map.get(element_map, :children, [])
    style = Map.get(element_map, :style, %{})
    border = Map.get(element_map, :border, false)

    # Calculate box size
    size =
      case Map.get(element_map, :size) do
        {w, h} when is_integer(w) and is_integer(h) -> {max(0, w), max(0, h)}
        {w, :auto} when is_integer(w) -> {max(0, w), max(0, space.height)}
        {:auto, h} when is_integer(h) -> {max(0, space.width), max(0, h)}
        :auto -> {max(0, space.width), max(0, space.height)}
        _ -> {max(0, space.width), max(0, space.height)}
      end

    # Create box element
    box = %{
      type: :box,
      position: {space.x, space.y},
      size: size,
      style: style,
      border: border
    }

    # Process children if any
    if is_list(children) and children != [] do
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

  defp process_element(%{type: flex_type} = element_map, space, acc)
       when flex_type == :flex and is_map(element_map) do
    children = Map.get(element_map, :children, [])
    direction = Map.get(element_map, :direction, :column)
    wrap = Map.get(element_map, :wrap, false)
    gap = Map.get(element_map, :gap, 0)

    # Get child sizes once and validate them
    child_sizes =
      Enum.map(children, fn child ->
        case Map.get(child, :size) do
          {w, h} when is_integer(w) and is_integer(h) and w >= 0 and h >= 0 ->
            {w, h}

          _ ->
            {1, 1}
        end
      end)

    # Process children based on direction and wrap
    processed_children =
      case {direction, wrap} do
        {:row, true} ->
          process_wrapped_row(children, child_sizes, space, gap)

        {:column, true} ->
          process_wrapped_column(children, child_sizes, space, gap)

        _ ->
          process_non_wrapped(children, child_sizes, space, direction, gap)
      end

    # Return flex container with processed children
    [
      Map.merge(element_map, %{
        children: processed_children,
        position: {space.x, space.y},
        size: {space.width, space.height}
      })
      | acc
    ]
  end

  # Helper function to calculate content dimensions
  defp calculate_content_dimensions(scrolled_children) do
    if Enum.empty?(scrolled_children) do
      {0, 0}
    else
      positions = Enum.map(scrolled_children, &Map.get(&1, :position, {0, 0}))
      sizes = Enum.map(scrolled_children, &Map.get(&1, :size, {0, 0}))

      min_x = Enum.map(positions, &elem(&1, 0)) |> Enum.min()
      min_y = Enum.map(positions, &elem(&1, 1)) |> Enum.min()

      max_x =
        Enum.zip_with(positions, sizes, fn {x, _}, {w, _} -> x + w end)
        |> Enum.max()

      max_y =
        Enum.zip_with(positions, sizes, fn {_, y}, {_, h} -> y + h end)
        |> Enum.max()

      {max(0, max_x - min_x), max(0, max_y - min_y)}
    end
  end

  # Helper function to create scrollbar elements
  defp create_scrollbar_elements(
         space,
         viewport_width,
         viewport_height,
         content_width,
         content_height,
         ox,
         oy,
         scrollbar_thickness,
         render_v_bar,
         render_h_bar,
         scrollbar_attrs
       ) do
    elements = []

    # Add vertical scrollbar
    elements =
      if render_v_bar and space.width >= scrollbar_thickness and
           viewport_height > 0 do
        track = %{
          type: :box,
          position: {space.x + viewport_width, space.y},
          size: {scrollbar_thickness, viewport_height},
          style: %{fg: scrollbar_attrs.track_fg, bg: scrollbar_attrs.track_bg}
        }

        if content_height > viewport_height do
          thumb_height =
            max(1, round(viewport_height * (viewport_height / content_height)))

          scroll_ratio = oy / (content_height - viewport_height)

          thumb_y =
            space.y + round(scroll_ratio * (viewport_height - thumb_height))

          thumb = %{
            type: :box,
            position: {space.x + viewport_width, thumb_y},
            size: {scrollbar_thickness, thumb_height},
            style: %{fg: scrollbar_attrs.thumb_fg, bg: scrollbar_attrs.thumb_bg}
          }

          [thumb, track | elements]
        else
          [track | elements]
        end
      else
        elements
      end

    # Add horizontal scrollbar
    elements =
      if render_h_bar and space.height >= scrollbar_thickness and
           viewport_width > 0 do
        track = %{
          type: :box,
          position: {space.x, space.y + viewport_height},
          size: {viewport_width, scrollbar_thickness},
          style: %{fg: scrollbar_attrs.track_fg, bg: scrollbar_attrs.track_bg}
        }

        if content_width > viewport_width do
          thumb_width =
            max(1, round(viewport_width * (viewport_width / content_width)))

          scroll_ratio = ox / (content_width - viewport_width)

          thumb_x =
            space.x + round(scroll_ratio * (viewport_width - thumb_width))

          thumb = %{
            type: :box,
            position: {thumb_x, space.y + viewport_height},
            size: {thumb_width, scrollbar_thickness},
            style: %{fg: scrollbar_attrs.thumb_fg, bg: scrollbar_attrs.thumb_bg}
          }

          [thumb, track | elements]
        else
          [track | elements]
        end
      else
        elements
      end

    # Add corner box
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

  # Helper functions for flex layout
  defp process_wrapped_row(children, child_sizes, space, gap) do
    {reversed_elements, _, _, _} =
      Enum.reduce(
        Enum.zip(children, child_sizes),
        {[], 0, 0, 0},
        fn {child, {cw, ch}}, {acc, x, y, line_h} ->
          x_start = x + if(x == 0, do: 0, else: gap)
          needs_wrap = x > 0 and x_start + cw > space.width

          if needs_wrap do
            new_y = y + line_h + gap

            child_space = %{
              space
              | x: space.x,
                y: space.y + new_y,
                width: cw,
                height: ch
            }

            processed = process_element(child, child_space, [])
            {[processed | acc], cw, new_y, ch}
          else
            child_space = %{
              space
              | x: space.x + x_start,
                y: space.y + y,
                width: cw,
                height: ch
            }

            processed = process_element(child, child_space, [])
            {[processed | acc], x_start + cw, y, max(line_h, ch)}
          end
        end
      )

    Enum.reverse(reversed_elements) |> List.flatten()
  end

  defp process_wrapped_column(children, child_sizes, space, gap) do
    {reversed_elements, _, _, _} =
      Enum.reduce(
        Enum.zip(children, child_sizes),
        {[], 0, 0, 0},
        fn {child, {cw, ch}}, {acc, y, x, col_w} ->
          y_start = y + if(y == 0, do: 0, else: gap)
          needs_wrap = y > 0 and y_start + ch > space.height

          if needs_wrap do
            new_x = x + col_w + gap

            child_space = %{
              space
              | x: space.x + new_x,
                y: space.y,
                width: cw,
                height: ch
            }

            processed = process_element(child, child_space, [])
            {[processed | acc], ch, new_x, cw}
          else
            child_space = %{
              space
              | x: space.x + x,
                y: space.y + y_start,
                width: cw,
                height: ch
            }

            processed = process_element(child, child_space, [])
            {[processed | acc], y_start + ch, x, max(col_w, cw)}
          end
        end
      )

    Enum.reverse(reversed_elements) |> List.flatten()
  end

  defp process_non_wrapped(children, child_sizes, space, direction, gap) do
    {reversed_elements, _} =
      Enum.reduce(
        Enum.zip(children, child_sizes),
        {[], 0},
        fn {child, {cw, ch}}, {acc, offset} ->
          child_space = %{
            space
            | x: if(direction == :row, do: space.x + offset, else: space.x),
              y: if(direction == :column, do: space.y + offset, else: space.y),
              width: cw,
              height: ch
          }

          processed = process_element(child, child_space, [])
          next_offset = offset + if(direction == :row, do: cw, else: ch) + gap
          {processed ++ acc, next_offset}
        end
      )

    Enum.reverse(reversed_elements) |> List.flatten()
  end

  # Apply panel layout, adjusting available space for contents
  defp apply_panel_layout(space, attrs) do
    # Extract and normalize spacing values
    padding = normalize_spacing_value(Map.get(attrs, :padding, 0))
    margin = normalize_spacing_value(Map.get(attrs, :margin, 0))
    border_thickness = 1

    # Calculate content dimensions
    {pt, pr, pb, pl} = padding
    {mt, mr, mb, ml} = margin

    content_x = space.x + ml + border_thickness + pl
    content_y = space.y + mt + border_thickness + pt

    content_width =
      max(0, space.width - ml - mr - border_thickness * 2 - pl - pr)

    content_height =
      max(0, space.height - mt - mb - border_thickness * 2 - pt - pb)

    %{
      x: content_x,
      y: content_y,
      width: content_width,
      height: content_height
    }
  end

  # Create panel border elements
  defp create_panel_elements(space, attrs) do
    # Extract panel configuration
    title = Map.get(attrs, :title, "")
    margin = normalize_spacing_value(Map.get(attrs, :margin, 0))
    {mt, mr, mb, ml} = margin

    # Calculate panel dimensions
    panel_box_x = space.x + ml
    panel_box_y = space.y + mt
    panel_box_width = max(0, space.width - ml - mr)
    panel_box_height = max(0, space.height - mt - mb)

    # Get styles with defaults
    panel_style = Map.get(attrs, :style, @default_style)
    title_style = Map.get(attrs, :title_style, panel_style)

    # Create panel box
    box = %{
      type: :box,
      position: {panel_box_x, panel_box_y},
      size: {panel_box_width, panel_box_height},
      style: panel_style
    }

    # Create title element if needed
    title_element =
      if title != "" and panel_box_width > 4 and panel_box_height > 0 do
        %{
          type: :text,
          position: {panel_box_x + 2, panel_box_y},
          size: {String.length(title) + 2, 1},
          content: " #{title} ",
          style: title_style
        }
      end

    if title_element, do: [box, title_element], else: [box]
  end

  # Helper to normalize spacing values
  defp normalize_spacing_value(value) when is_integer(value) and value >= 0,
    do: {value, value, value, value}

  defp normalize_spacing_value({v, h})
       when is_integer(v) and is_integer(h) and v >= 0 and h >= 0,
       do: {v, h, v, h}

  defp normalize_spacing_value({t, r, b, l})
       when is_integer(t) and is_integer(r) and is_integer(b) and is_integer(l) and
              t >= 0 and r >= 0 and b >= 0 and l >= 0,
       do: {t, r, b, l}

  defp normalize_spacing_value(_), do: {0, 0, 0, 0}

  # --- RECURSIVE NORMALIZATION FOR ALL CHILDREN ---
  # Helper to deeply normalize a child (struct, map, keyword, atom, etc)
  defp deep_normalize_child(child, space, default_type, for_layout) do
    # Helper function to normalize children
    normalize_children = fn children ->
      case children do
        list when is_list(list) ->
          Enum.flat_map(list, &deep_normalize_child(&1, space, :box, true))

        nil ->
          []

        single_item ->
          deep_normalize_child(single_item, space, :box, true)
      end
    end

    # Helper function to resolve type
    resolve_type = fn map, struct_name ->
      cond do
        Map.has_key?(map, :type) -> map.type
        struct_name == "chart" -> :chart
        struct_name == "table" -> :table
        struct_name == "border" -> :border
        struct_name == "grid" -> :grid
        true -> String.to_atom(struct_name)
      end
    end

    cond do
      is_struct(child) ->
        map = Map.from_struct(child)

        struct_name =
          child.__struct__
          |> Module.split()
          |> List.last()
          |> Macro.underscore()

        intended_type = resolve_type.(map, struct_name)

        map
        |> Map.put(:type, intended_type)
        |> then(fn m ->
          if intended_type in @container_types,
            do: Map.put_new(m, :children, []),
            else: m
        end)
        |> then(fn m ->
          if Map.has_key?(m, :children),
            do: Map.put(m, :children, normalize_children.(m.children)),
            else: m
        end)
        |> then(&ensure_required_keys(&1, space))
        |> List.wrap()

      is_list(child) and Keyword.keyword?(child) and for_layout ->
        child
        |> Enum.into(%{})
        |> Map.put_new(:type, default_type)
        |> Map.put_new(:position, {space.x, space.y})
        |> Map.put_new(:size, {space.width, space.height})
        |> then(fn m ->
          if Map.has_key?(m, :children),
            do: Map.put(m, :children, normalize_children.(m.children)),
            else: Map.put_new(m, :children, [])
        end)
        |> then(fn m ->
          if Map.get(m, :type) in @container_types,
            do: Map.put_new(m, :children, []),
            else: m
        end)
        |> then(&ensure_required_keys(&1, space))
        |> List.wrap()

      is_list(child) ->
        child
        |> List.flatten()
        |> Enum.flat_map(&deep_normalize_child(&1, space, :box, true))

      is_map(child) ->
        child
        |> Map.put_new(:position, {space.x, space.y})
        |> Map.put_new(:size, {space.width, space.height})
        |> then(fn m ->
          if Map.has_key?(m, :children),
            do: Map.put(m, :children, normalize_children.(m.children)),
            else: m
        end)
        |> then(fn m ->
          type = Map.get(m, :type, default_type)

          if type in @container_types,
            do: Map.put_new(m, :children, []),
            else: m
        end)
        |> then(fn m ->
          final_type =
            cond do
              Map.has_key?(child, :__struct__) ->
                struct_name =
                  child.__struct__
                  |> Module.split()
                  |> List.last()
                  |> Macro.underscore()

                resolve_type.(m, struct_name)

              Map.has_key?(m, :type) ->
                m.type

              true ->
                default_type
            end

          Map.put(m, :type, final_type)
        end)
        |> then(&ensure_required_keys(&1, space))
        |> List.wrap()

      is_atom(child) and for_layout ->
        if child in @valid_types do
          [ensure_required_keys(%{type: child, children: []}, space)]
        else
          [nil]
        end

      is_atom(child) and not for_layout ->
        [%{type: child}]

      is_binary(child) and not for_layout ->
        [%{type: child}]

      is_number(child) and not for_layout ->
        [%{type: child}]

      true ->
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
  end

  # Ensure a map has :type, :position, :size, and :children (default []) if it is a container type
  defp ensure_required_keys(map_candidate, space) do
    map_candidate
    |> then(fn m ->
      if is_map(m) do
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

  # Re-add the missing process_children/3 function
  defp process_children(children, space, acc) when is_list(children) do
    # Process each child and flatten the results, then add to the accumulator
    new_child_elements =
      Enum.flat_map(children, fn child_node ->
        normalized_child =
          if is_map(child_node) and Map.has_key?(child_node, :type) and
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

  # Single child map passed
  defp process_children(child, space, acc) do
    normalized_child =
      if is_map(child) and Map.has_key?(child, :type) and
           Map.has_key?(child, :position) and Map.has_key?(child, :size) do
        child
      else
        ensure_required_keys(child, space)
      end

    process_element(normalized_child, space, acc)
  end
end
