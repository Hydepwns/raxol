defmodule Raxol.Core.Renderer.Layout do
  import Raxol.Guards

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
  def apply_layout(view, dimensions) when map?(view) do
    apply_layout([view], dimensions)
  end

  def apply_layout(views, %{width: width, height: height}) when list?(views) do
    available_space = {width, height}

    views
    |> Enum.flat_map(fn view -> layout_single_view(view, available_space) end)
    |> Enum.reject(&is_nil/1)
  end

  def apply_layout(views, {width, height}) when list?(views) do
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
    case view do
      %{type: :flex} = flex_view ->
        Flex.calculate_layout(flex_view, available_space)

      %{type: :grid} = grid_view ->
        Grid.calculate_layout(grid_view, available_space)

      %{type: :box} = box_view ->
        layout_box(box_view, available_space)

      %{type: :shadow_wrapper} = shadow_view ->
        layout_shadow_wrapper(shadow_view, available_space)

      %{type: :scroll} = scroll_view ->
        layout_scroll(scroll_view, available_space)

      %{type: :text} = text_view ->
        layout_text(text_view, available_space)

      %{type: :label} = label_view ->
        layout_label(label_view, available_space)

      %{type: :button} = button_view ->
        layout_button(button_view, available_space)

      %{type: :checkbox} = checkbox_view ->
        layout_checkbox(checkbox_view, available_space)

      %{children: children} when list?(children) ->
        # Container with children - layout children recursively
        children
        |> Enum.flat_map(fn child ->
          layout_single_view(child, available_space)
        end)

      _ ->
        # Unknown or simple view - return as is
        [view]
    end
  end

  defp layout_shadow_wrapper(shadow_view, available_space) do
    children = shadow_view.children
    children_list = if is_list(children), do: children, else: [children]
    # For now, just layout the children as normal
    Enum.flat_map(children_list, fn child ->
      layout_single_view(child, available_space)
    end)
  end

  defp layout_scroll(scroll_view, available_space) do
    {offset_x, offset_y} = scroll_view.offset

    # Layout the children normally first
    children = scroll_view.children
    children_list = if is_list(children), do: children, else: [children]

    positioned_children =
      Enum.flat_map(children_list, fn child ->
        layout_single_view(child, available_space)
      end)

    # Apply scroll offset by subtracting from positions
    Enum.map(positioned_children, fn child ->
      {x, y} = Map.get(child, :position, {0, 0})
      Map.put(child, :position, {x - offset_x, y - offset_y})
    end)
  end

  @doc """
  Calculates layout for a box container.
  """
  def layout_box(box, {width, height}) do
    # Get box configuration
    children = Map.get(box, :children, [])
    padding = Map.get(box, :padding, {0, 0, 0, 0})
    margin = Map.get(box, :margin, {0, 0, 0, 0})
    border = Map.get(box, :border, false)

    # Calculate box size
    box_size = calculate_box_size(box, {width, height})

    # Apply margins and padding
    {content_x, content_y, content_width, content_height} =
      calculate_content_area(box_size, padding, margin, border)

    # Create positioned box
    positioned_box =
      box
      |> Map.put(:position, {content_x, content_y})
      |> Map.put(:size, box_size)

    # Layout children if any
    if list?(children) and children != [] do
      child_space = {content_width, content_height}

      positioned_children =
        children
        |> Enum.flat_map(fn child -> layout_single_view(child, child_space) end)
        |> Enum.map(fn child ->
          {child_x, child_y} = Map.get(child, :position, {0, 0})
          Map.put(child, :position, {child_x + content_x, child_y + content_y})
        end)

      [positioned_box | positioned_children]
    else
      [positioned_box]
    end
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
    checkbox_text = if checked, do: "[✓]", else: "[ ]"
    text = "#{checkbox_text} #{label}"
    text_width = String.length(text)
    text_height = 1

    positioned_checkbox =
      checkbox
      |> Map.put(:position, {0, 0})
      |> Map.put(:size, {min(text_width, width), min(text_height, height)})

    [positioned_checkbox]
  end

  # Private helper functions

  defp calculate_box_size(box, {available_width, available_height}) do
    case Map.get(box, :size) do
      {w, h} when integer?(w) and integer?(h) ->
        {max(0, w), max(0, h)}

      {w, :auto} when integer?(w) ->
        {max(0, w), max(0, available_height)}

      {:auto, h} when integer?(h) ->
        {max(0, available_width), max(0, h)}

      :auto ->
        {max(0, available_width), max(0, available_height)}

      _ ->
        {max(0, available_width), max(0, available_height)}
    end
  end

  defp calculate_content_area(box_size, padding, margin, border) do
    {box_width, box_height} = box_size
    {padding_top, padding_right, padding_bottom, padding_left} = padding
    {margin_top, _margin_right, _margin_bottom, margin_left} = margin

    border_width = if border, do: 2, else: 0

    content_width = box_width - padding_left - padding_right - border_width
    content_height = box_height - padding_top - padding_bottom - border_width

    content_x = margin_left + padding_left + if border, do: 1, else: 0
    content_y = margin_top + padding_top + if border, do: 1, else: 0

    {content_x, content_y, max(0, content_width), max(0, content_height)}
  end
end
