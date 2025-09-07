defmodule Raxol.Renderer.Layout.Elements do
  @moduledoc """
  Handles element processing for different UI components.

  This module provides element-specific processing logic including:
  - View and panel elements
  - Form elements (buttons, text inputs, checkboxes)
  - Text and label elements
  - Border and box elements
  """

  # Default styles
  @default_style %{fg: :white, bg: :black}
  @default_button_style %{fg: :white, bg: :blue}
  @default_text_input_style %{fg: :white, bg: :black}
  @default_placeholder_style %{fg: :gray, bg: :black}

  @doc """
  Processes a view element.

  ## Parameters

  * `element` - The view element configuration
  * `space` - Available space for layout
  * `acc` - Accumulator for processed elements

  ## Returns

  A list of processed child elements.
  """
  def process_view_element(%{children: children}, space, acc)
      when is_list(children) do
    Raxol.Renderer.Layout.process_children(children, space, acc)
  end

  def process_view_element(%{children: children}, space, acc) do
    Raxol.Renderer.Layout.process_element(children, space, acc)
  end

  @doc """
  Processes a panel element.

  ## Parameters

  * `element` - The panel element configuration
  * `space` - Available space for layout
  * `acc` - Accumulator for processed elements

  ## Returns

  A list of processed panel elements.
  """
  def process_panel_element(%{attrs: attrs, children: children}, space, acc)
      when is_list(children) do
    panel_space = Raxol.Renderer.Layout.apply_panel_layout(space, attrs)
    panel_elements = Raxol.Renderer.Layout.create_panel_elements(space, attrs)

    inner_elements =
      Raxol.Renderer.Layout.process_children(children, panel_space, [])

    [panel_elements, inner_elements | acc]
  end

  @doc """
  Processes a label element.

  ## Parameters

  * `element` - The label element configuration
  * `space` - Available space for layout
  * `acc` - Accumulator for processed elements

  ## Returns

  A list containing the text element.
  """
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

  @doc """
  Processes a button element.

  ## Parameters

  * `element` - The button element configuration
  * `space` - Available space for layout
  * `acc` - Accumulator for processed elements

  ## Returns

  A list containing button elements (box and text).
  """
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

  @doc """
  Processes a text input element.

  ## Parameters

  * `element` - The text input element configuration
  * `space` - Available space for layout
  * `acc` - Accumulator for processed elements

  ## Returns

  A list containing text input elements (box and text).
  """
  def process_text_input_element(%{attrs: attrs}, space, acc) do
    value = Map.get(attrs, :value, "")
    placeholder = Map.get(attrs, :placeholder, "")
    text = get_display_text(value, placeholder)
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
        style: get_text_style(value, placeholder_style, style)
      }
    ]

    text_input_elements ++ acc
  end

  @doc """
  Processes a checkbox element.

  ## Parameters

  * `element` - The checkbox element configuration
  * `space` - Available space for layout
  * `acc` - Accumulator for processed elements

  ## Returns

  A list containing the checkbox text element.
  """
  def process_checkbox_element(%{attrs: attrs}, space, acc) do
    checked = Map.get(attrs, :checked, false)
    label = Map.get(attrs, :label, "")
    style = Map.get(attrs, :style, @default_style)
    checkbox_text = get_checkbox_text(checked)
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

  @doc """
  Processes a table element.

  ## Parameters

  * `element_map` - The table element configuration
  * `space` - Available space for layout
  * `acc` - Accumulator for processed elements

  ## Returns

  A list containing the table element.
  """
  def process_table_element(element_map, space, acc) do
    # Check if this is a table struct that has been converted to a map
    case Map.get(element_map, :__struct__) == Raxol.Core.Renderer.Views.Table do
      true ->
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

      false ->
        # For non-table elements, process normally
        [element_map | acc]
    end
  end

  @doc """
  Processes a shadow wrapper element.

  ## Parameters

  * `element` - The shadow wrapper element configuration
  * `space` - Available space for layout
  * `acc` - Accumulator for processed elements

  ## Returns

  A list containing shadow elements and processed children.
  """
  def process_shadow_wrapper_element(
        %{children: children, opts: opts},
        space,
        acc
      )
      when is_list(children) do
    offset = Map.get(opts, :offset, {1, 1})
    {_offset_x, _offset_y} = offset

    # Process children without shadow offset (content should be at original position)
    shadow_children =
      Raxol.Renderer.Layout.process_children(children, space, [])

    # Add shadow effect elements
    shadow_elements =
      Raxol.Renderer.Layout.Scroll.create_shadow_elements(space, offset)

    shadow_children ++ shadow_elements ++ acc
  end

  def process_shadow_wrapper_element(
        %{children: children, opts: opts},
        space,
        acc
      ) do
    offset = Map.get(opts, :offset, {1, 1})
    {_offset_x, _offset_y} = offset

    # Process single child without shadow offset (content should be at original position)
    shadow_child = Raxol.Renderer.Layout.process_element(children, space, [])

    # Add shadow effect elements
    shadow_elements =
      Raxol.Renderer.Layout.Scroll.create_shadow_elements(space, offset)

    shadow_child ++ shadow_elements ++ acc
  end

  @doc """
  Processes a box element.

  ## Parameters

  * `element_map` - The box element configuration
  * `space` - Available space for layout
  * `acc` - Accumulator for processed elements

  ## Returns

  A list containing the box element and its children.
  """
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

    case {is_list(children), children} do
      {true, children} when children != [] ->
        inner_space = %{
          x: space.x,
          y: space.y,
          width: elem(size, 0),
          height: elem(size, 1)
        }

        processed_children =
          Raxol.Renderer.Layout.process_children(children, inner_space, [])

        [Map.put(box, :children, processed_children) | acc]

      _ ->
        [box | acc]
    end
  end

  def process_box_element(element_map, space, acc) do
    # Handle case where element_map doesn't have :children key
    element_map_with_children = Map.put(element_map, :children, [])
    process_box_element(element_map_with_children, space, acc)
  end

  @doc """
  Processes a text element.

  ## Parameters

  * `element_map` - The text element configuration
  * `space` - Available space for layout
  * `acc` - Accumulator for processed elements

  ## Returns

  A list containing the text element.
  """
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

  @doc """
  Processes a border element.

  ## Parameters

  * `element_map` - The border element configuration
  * `space` - Available space for layout
  * `acc` - Accumulator for processed elements

  ## Returns

  A list containing the border container with processed children.
  """
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
            normalized_child =
              Raxol.Renderer.Layout.Utils.ensure_required_keys(
                child,
                space,
                :box
              )

            Raxol.Renderer.Layout.process_element(normalized_child, space, [])
          end)

        single ->
          normalized_child =
            Raxol.Renderer.Layout.Utils.ensure_required_keys(
              single,
              space,
              :box
            )

          Raxol.Renderer.Layout.process_element(normalized_child, space, [])
      end

    [Map.put(border_container, :children, processed_children) | acc]
  end

  @doc """
  Processes a grid element.

  ## Parameters

  * `element_map` - The grid element configuration
  * `space` - Available space for layout
  * `acc` - Accumulator for processed elements

  ## Returns

  A list containing the grid container with positioned children.
  """
  def process_grid_element(
        %{children: _children, columns: columns, rows: rows, gap: gap} =
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

        result = Raxol.Renderer.Layout.process_element(child, child_space, [])
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

  defp calculate_box_size(element_map, space) do
    size = Map.get(element_map, :size)
    Raxol.Renderer.Layout.calculate_size(size, space)
  end

  # Helper functions for pattern matching instead of if statements
  defp get_display_text("", placeholder), do: placeholder
  defp get_display_text(value, _placeholder), do: value

  defp get_text_style("", placeholder_style, _style), do: placeholder_style
  defp get_text_style(_value, _placeholder_style, style), do: style

  defp get_checkbox_text(true), do: "[✓]"
  defp get_checkbox_text(false), do: "[ ]"
end
