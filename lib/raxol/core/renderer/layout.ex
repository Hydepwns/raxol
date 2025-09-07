defmodule Raxol.Core.Renderer.Layout do
  @moduledoc """
  Central layout coordinator for the Raxol renderer system.

  This module provides a unified interface for layout calculations and delegates
  to specific layout modules (Flex, Grid, etc.) based on the layout type.
  """

  alias Raxol.Core.Renderer.View.Layout.{Flex, Grid}

  @doc """
  Applies layout to a view or list of views, calculating absolute positions.

  ## Parameters
    * `view` - A single view or list of views to layout
    * `dimensions` - Available space dimensions `%{width: w, height: h}`

  ## Returns
    A list of positioned elements with absolute coordinates.
  """
  def apply_layout(view, dimensions) when is_map(view) do
    apply_layout([view], dimensions)
  end

  def apply_layout(views, %{width: width, height: height})
      when is_list(views) do
    available_space = {width, height}

    views
    |> Enum.flat_map(fn view -> layout_single_view(view, available_space) end)
    |> Enum.reject(&is_nil/1)
  end

  def apply_layout(views, {width, height}) when is_list(views) do
    apply_layout(views, %{width: width, height: height})
  end

  @doc """
  Creates a flex layout container.

  ## Options
    * `:direction` - Layout direction (`:row` or `:column`)
    * `:align` - Alignment of children (`:start`, `:center`, `:end`)
    * `:justify` - Justification of children (`:start`, `:center`, `:end`, `:space_between`)
    * `:gap` - Space between children (integer)
    * `:wrap` - Whether to wrap children (boolean)
    * `:children` - List of child views
    * `:style` - Style options for the container

  ## Examples
      Layout.flex(direction: :row, children: [view1, view2])
      Layout.flex(direction: :column, align: :center, children: [view1, view2])
  """
  def flex(opts \\ []) do
    Flex.container(opts)
  end

  @doc """
  Creates a row layout container.

  ## Options
    * `:align` - Alignment of children (`:start`, `:center`, `:end`)
    * `:justify` - Justification of children (`:start`, `:center`, `:end`, `:space_between`)
    * `:gap` - Space between children (integer)
    * `:children` - List of child views
    * `:style` - Style options for the container

  ## Examples
      Layout.row(children: [view1, view2])
      Layout.row(align: :center, justify: :space_between, children: [view1, view2])
  """
  def row(opts \\ []) do
    Flex.row(opts)
  end

  @doc """
  Creates a column layout container.

  ## Options
    * `:align` - Alignment of children (`:start`, `:center`, `:end`)
    * `:justify` - Justification of children (`:start`, `:center`, `:end`, `:space_between`)
    * `:gap` - Space between children (integer)
    * `:children` - List of child views
    * `:style` - Style options for the container

  ## Examples
      Layout.column(children: [view1, view2])
      Layout.column(align: :center, justify: :space_between, children: [view1, view2])
  """
  def column(opts \\ []) do
    Flex.column(opts)
  end

  @doc """
  Creates a grid layout container.

  ## Options
    * `:columns` - Number of columns or list of column sizes
    * `:rows` - Number of rows or list of row sizes
    * `:gap` - Gap between grid items `{x, y}`
    * `:align` - Alignment of items within grid cells
    * `:justify` - Justification of items within grid cells
    * `:children` - List of child views to place in the grid

  ## Examples
      Layout.grid(columns: 3, rows: 2, children: [view1, view2, view3, view4])
      Layout.grid(columns: [1, 2, 1], rows: ["auto", "1fr"], children: [view1, view2, view3])
  """
  def grid(opts \\ []) do
    Grid.new(opts)
  end

  @doc """
  Calculates the layout for a single view based on its type.
  """
  def layout_single_view(view, available_space) do
    {view_type, view_data} = get_view_type(view)
    apply_layout_by_type(view_type, view_data, available_space)
  end

  defp apply_layout_by_type(:flex, flex_view, available_space),
    do: Flex.calculate_layout(flex_view, available_space)

  defp apply_layout_by_type(:grid, grid_view, available_space),
    do: Grid.calculate_layout(grid_view, available_space)

  defp apply_layout_by_type(:box, box_view, available_space),
    do: layout_box(box_view, available_space)

  defp apply_layout_by_type(:shadow_wrapper, shadow_view, available_space),
    do: layout_shadow_wrapper(shadow_view, available_space)

  defp apply_layout_by_type(:scroll, scroll_view, available_space),
    do: layout_scroll(scroll_view, available_space)

  defp apply_layout_by_type(:text, text_view, available_space),
    do: layout_text(text_view, available_space)

  defp apply_layout_by_type(:label, label_view, available_space),
    do: layout_label(label_view, available_space)

  defp apply_layout_by_type(:button, button_view, available_space),
    do: layout_button(button_view, available_space)

  defp apply_layout_by_type(:checkbox, checkbox_view, available_space),
    do: layout_checkbox(checkbox_view, available_space)

  defp apply_layout_by_type(:container, view, available_space),
    do: layout_container_children(view, available_space)

  defp apply_layout_by_type(:unknown, view, _available_space), do: [view]

  defp get_view_type(%{type: :flex} = flex_view), do: {:flex, flex_view}
  defp get_view_type(%{type: :grid} = grid_view), do: {:grid, grid_view}
  defp get_view_type(%{type: :box} = box_view), do: {:box, box_view}

  defp get_view_type(%{type: :shadow_wrapper} = shadow_view),
    do: {:shadow_wrapper, shadow_view}

  defp get_view_type(%{type: :scroll} = scroll_view), do: {:scroll, scroll_view}
  defp get_view_type(%{type: :text} = text_view), do: {:text, text_view}
  defp get_view_type(%{type: :label} = label_view), do: {:label, label_view}
  defp get_view_type(%{type: :button} = button_view), do: {:button, button_view}

  defp get_view_type(%{type: :checkbox} = checkbox_view),
    do: {:checkbox, checkbox_view}

  defp get_view_type(%{children: children} = view) when is_list(children),
    do: {:container, view}

  defp get_view_type(view), do: {:unknown, view}

  defp layout_container_children(view, available_space) do
    view.children
    |> Enum.flat_map(fn child ->
      layout_single_view(child, available_space)
    end)
  end

  defp layout_shadow_wrapper(shadow_view, available_space) do
    children = shadow_view.children

    children_list =
      case children do
        children when is_list(children) -> children
        children -> [children]
      end

    Enum.flat_map(children_list, fn child ->
      layout_single_view(child, available_space)
    end)
  end

  defp layout_scroll(scroll_view, available_space) do
    {offset_x, offset_y} = scroll_view.offset

    children = scroll_view.children

    children_list =
      case children do
        children when is_list(children) -> children
        children -> [children]
      end

    positioned_children =
      Enum.flat_map(children_list, fn child ->
        layout_single_view(child, available_space)
      end)

    Enum.map(positioned_children, fn child ->
      {x, y} = Map.get(child, :position, {0, 0})
      Map.put(child, :position, {x - offset_x, y - offset_y})
    end)
  end

  @doc """
  Calculates layout for a box container.
  """
  def layout_box(box, {width, height}) do
    children = Map.get(box, :children, [])
    padding = Map.get(box, :padding, {0, 0, 0, 0})
    margin = Map.get(box, :margin, {0, 0, 0, 0})
    border = Map.get(box, :border, false)

    box_size = calculate_box_size(box, {width, height})

    {content_x, content_y, content_width, content_height} =
      calculate_content_area(box_size, padding, margin, border)

    positioned_box =
      box
      |> Map.put(:position, {content_x, content_y})
      |> Map.put(:size, box_size)

    case {is_list(children), children != []} do
      {true, true} ->
        [
          positioned_box
          | position_children(
              children,
              {content_x, content_y},
              {content_width, content_height}
            )
        ]

      _ ->
        [positioned_box]
    end
  end

  defp position_children(
         children,
         {content_x, content_y},
         {content_width, content_height}
       ) do
    children
    |> Enum.flat_map(fn child ->
      layout_single_view(child, {content_width, content_height})
    end)
    |> Enum.map(fn child ->
      {child_x, child_y} = Map.get(child, :position, {0, 0})
      Map.put(child, :position, {child_x + content_x, child_y + content_y})
    end)
  end

  @doc """
  Calculates layout for a text element.
  """
  def layout_text(text, {width, height}) do
    content = Map.get(text, :content, "")
    text_width = String.length(content)
    text_height = 1

    positioned_text =
      text
      |> Map.put(:position, {0, 0})
      |> Map.put(:size, {min(text_width, width), min(text_height, height)})

    [positioned_text]
  end

  @doc """
  Calculates layout for a label element.
  """
  def layout_label(label, {width, height}) do
    content = Map.get(label, :content, Map.get(label, :text, ""))
    text_width = String.length(content)
    text_height = 1

    positioned_label =
      label
      |> Map.put(:position, {0, 0})
      |> Map.put(:size, {min(text_width, width), min(text_height, height)})

    [positioned_label]
  end

  @doc """
  Calculates layout for a button element.
  """
  def layout_button(button, {width, _height}) do
    label = Map.get(button, :label, "Button")
    button_width = min(String.length(label) + 4, width)
    button_height = 3

    positioned_button =
      button
      |> Map.put(:position, {0, 0})
      |> Map.put(:size, {button_width, button_height})

    [positioned_button]
  end

  @doc """
  Calculates layout for a checkbox element.
  """
  def layout_checkbox(checkbox, {width, height}) do
    checked = Map.get(checkbox, :checked, false)
    label = Map.get(checkbox, :label, "")

    checkbox_text =
      case checked do
        true -> "[✓]"
        false -> "[ ]"
      end

    text = "#{checkbox_text} #{label}"
    text_width = String.length(text)
    text_height = 1

    positioned_checkbox =
      checkbox
      |> Map.put(:position, {0, 0})
      |> Map.put(:size, {min(text_width, width), min(text_height, height)})

    [positioned_checkbox]
  end

  defp calculate_box_size(box, {available_width, available_height}) do
    size = Map.get(box, :size, :auto)
    calculate_dimensions(size, available_width, available_height)
  end

  defp calculate_dimensions({w, h}, _available_width, _available_height)
       when is_integer(w) and is_integer(h) do
    {max(0, w), max(0, h)}
  end

  defp calculate_dimensions({w, :auto}, _available_width, available_height)
       when is_integer(w) do
    {max(0, w), max(0, available_height)}
  end

  defp calculate_dimensions({:auto, h}, available_width, _available_height)
       when is_integer(h) do
    {max(0, available_width), max(0, h)}
  end

  defp calculate_dimensions(:auto, available_width, available_height) do
    {max(0, available_width), max(0, available_height)}
  end

  defp calculate_dimensions(_, available_width, available_height) do
    {max(0, available_width), max(0, available_height)}
  end

  defp calculate_content_area(box_size, padding, margin, border) do
    {box_width, box_height} = box_size
    {padding_top, padding_right, padding_bottom, padding_left} = padding
    {margin_top, _margin_right, _margin_bottom, margin_left} = margin

    border_width =
      case border do
        true -> 2
        false -> 0
      end

    content_width = box_width - padding_left - padding_right - border_width
    content_height = box_height - padding_top - padding_bottom - border_width

    content_x =
      margin_left + padding_left +
        case border do
          true -> 1
          false -> 0
        end

    content_y =
      margin_top + padding_top +
        case border do
          true -> 1
          false -> 0
        end

    {content_x, content_y, max(0, content_width), max(0, content_height)}
  end
end
