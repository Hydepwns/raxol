defmodule Raxol.Core.Renderer.View.Components.Box do
  @moduledoc """
  Handles box layout functionality for the Raxol view system.
  Provides box model layout with content, padding, border, and margin.
  """

  import Raxol.Guards

  @doc """
  Creates a new box view.

  ## Options
    * `:children` - List of child views
    * `:padding` - Padding around content (integer or {top, right, bottom, left})
    * `:margin` - Margin around box (integer or {top, right, bottom, left})
    * `:border` - Border style (:none, :single, :double, :rounded, :bold, :dashed)
    * `:fg` - Foreground color
    * `:bg` - Background color
    * `:size` - Box size {width, height}

  ## Examples

      Box.new(children: [view1, view2], padding: 1)
      Box.new(padding: {1, 2, 1, 2}, border: :single)
  """
  def new(opts \\ []) do
    style = Keyword.get(opts, :style, [])
    border = Keyword.get(style, :border, Keyword.get(opts, :border, :none))
    padding = Keyword.get(style, :padding, Keyword.get(opts, :padding, 0))

    %{
      type: :box,
      children: Keyword.get(opts, :children, []),
      padding: normalize_spacing(padding),
      margin: normalize_spacing(Keyword.get(opts, :margin, 0)),
      border: border,
      fg: Keyword.get(opts, :fg),
      bg: Keyword.get(opts, :bg),
      size: Keyword.get(opts, :size),
      style: style
    }
  end

  @doc """
  Calculates the layout of a box and its children.
  """
  def calculate_layout(box, available_size) do
    # Calculate content size by subtracting padding and border
    content_size = calculate_content_size(box, available_size)

    # Layout children within content area
    children_layout = layout_children(box.children, content_size)

    # Apply padding and border
    apply_box_model(box, children_layout, available_size)
  end

  defp calculate_content_size(box, {width, height}) do
    {padding_left, padding_right, padding_top, padding_bottom} = box.padding
    border_width = if box.border == :none, do: 0, else: 2

    content_width = width - padding_left - padding_right - border_width
    content_height = height - padding_top - padding_bottom - border_width

    {content_width, content_height}
  end

  defp layout_children(children, {width, height}) do
    # Get layout mode from box style or default to vertical
    layout_mode = get_layout_mode(children)

    case layout_mode do
      :horizontal -> layout_horizontal(children, {width, height})
      :stack -> layout_stack(children, {width, height})
      _ -> layout_vertical(children, {width, height}) # Default
    end
  end

  defp get_layout_mode(children) do
    # Check if any child has a layout mode specified
    Enum.find_value(children, :vertical, fn child ->
      Map.get(child, :layout_mode)
    end)
  end

  defp layout_vertical(children, {width, height}) do
    children
    |> Enum.scan({0, 0}, fn child, {_prev_x, prev_y} ->
      child_height = get_child_height(child, height)
      child_width = get_child_width(child, width)

      # Position child at top of remaining space
      _positioned_child = child
      |> Map.put(:position, {0, prev_y})
      |> Map.put(:size, {child_width, child_height})

      {0, prev_y + child_height}
    end)
    |> Enum.map(fn {_pos, child} -> child end)
  end

  defp layout_horizontal(children, {width, height}) do
    children
    |> Enum.scan({0, 0}, fn child, {prev_x, _prev_y} ->
      child_width = get_child_width(child, width)
      child_height = get_child_height(child, height)

      # Position child to the right of previous child
      _positioned_child = child
      |> Map.put(:position, {prev_x, 0})
      |> Map.put(:size, {child_width, child_height})

      {prev_x + child_width, 0}
    end)
    |> Enum.map(fn {_pos, child} -> child end)
  end

  defp layout_stack(children, {width, height}) do
    # Stack all children at the same position, only the last one visible
    children
    |> Enum.with_index()
    |> Enum.map(fn {child, index} ->
      child_height = get_child_height(child, height)
      child_width = get_child_width(child, width)

      # All children get the same position, but only the last one is visible
      visible = index == length(children) - 1

      _positioned_child = child
      |> Map.put(:position, {0, 0})
      |> Map.put(:size, {child_width, child_height})
      |> Map.put(:visible, visible)
    end)
  end

  defp get_child_width(child, available_width) do
    case Map.get(child, :width) do
      nil -> available_width
      width when integer?(width) -> min(width, available_width)
      :auto -> available_width
      _ -> available_width
    end
  end

  defp get_child_height(child, available_height) do
    case Map.get(child, :height) do
      nil -> 1 # Default height for text-like content
      height when integer?(height) -> min(height, available_height)
      :auto -> 1
      _ -> 1
    end
  end

  defp apply_box_model(box, children_layout, {_width, _height}) do
    {margin_top, margin_right, margin_bottom, margin_left} = box.margin
    {padding_top, padding_right, padding_bottom, padding_left} = box.padding

    # Apply margins
    layout =
      apply_margins(
        children_layout,
        {margin_top, margin_right, margin_bottom, margin_left}
      )

    # Apply padding
    layout =
      apply_padding(
        layout,
        {padding_top, padding_right, padding_bottom, padding_left}
      )

    # Apply border if needed
    if box.border != :none do
      apply_border(layout, box.border)
    else
      layout
    end
  end

  defp apply_margins(layout, {top, _right, _bottom, left}) do
    # Apply margins by adjusting the overall box position
    # This affects the box's position relative to its parent
    Enum.map(layout, fn child ->
      {child_x, child_y} = Map.get(child, :position, {0, 0})
      {child_width, child_height} = Map.get(child, :size, {0, 0})

      # Adjust position by margins
      new_x = child_x + left
      new_y = child_y + top

      child
      |> Map.put(:position, {new_x, new_y})
      |> Map.put(:size, {child_width, child_height})
      |> Map.put(:margined, true)
    end)
  end

  defp apply_padding(layout, {top, right, bottom, left}) do
    # Apply padding by adjusting child positions
    Enum.map(layout, fn child ->
      {child_x, child_y} = Map.get(child, :position, {0, 0})
      {child_width, child_height} = Map.get(child, :size, {0, 0})

      # Adjust position by padding
      new_x = child_x + left
      new_y = child_y + top

      # Adjust size to account for padding
      new_width = max(0, child_width - left - right)
      new_height = max(0, child_height - top - bottom)

      child
      |> Map.put(:position, {new_x, new_y})
      |> Map.put(:size, {new_width, new_height})
      |> Map.put(:padded, true)
    end)
  end

  defp apply_border(layout, style) do
    # Get border characters for the style
    border_chars = get_border_characters(style)

    # Apply border by adjusting content area and adding border elements
    layout
    |> Enum.map(fn child ->
      {child_x, child_y} = Map.get(child, :position, {0, 0})
      {child_width, child_height} = Map.get(child, :size, {0, 0})

      # Adjust position to account for border
      new_x = child_x + 1  # Left border
      new_y = child_y + 1  # Top border

      # Adjust size to account for borders
      new_width = max(0, child_width - 2)  # Left and right borders
      new_height = max(0, child_height - 2) # Top and bottom borders

      child
      |> Map.put(:position, {new_x, new_y})
      |> Map.put(:size, {new_width, new_height})
      |> Map.put(:bordered, true)
      |> Map.put(:border_style, style)
      |> Map.put(:border_chars, border_chars)
    end)
  end

  defp get_border_characters(style) do
    case style do
      :single -> %{
        top_left: "┌", top: "─", top_right: "┐",
        left: "│", right: "│",
        bottom_left: "└", bottom: "─", bottom_right: "┘"
      }
      :double -> %{
        top_left: "╔", top: "═", top_right: "╗",
        left: "║", right: "║",
        bottom_left: "╚", bottom: "═", bottom_right: "╝"
      }
      :rounded -> %{
        top_left: "╭", top: "─", top_right: "╮",
        left: "│", right: "│",
        bottom_left: "╰", bottom: "─", bottom_right: "╯"
      }
      :bold -> %{
        top_left: "┏", top: "━", top_right: "┓",
        left: "┃", right: "┃",
        bottom_left: "┗", bottom: "━", bottom_right: "┛"
      }
      :dashed -> %{
        top_left: "┌", top: "┄", top_right: "┐",
        left: "┆", right: "┆",
        bottom_left: "└", bottom: "┄", bottom_right: "┘"
      }
      _ -> %{
        top_left: "┌", top: "─", top_right: "┐",
        left: "│", right: "│",
        bottom_left: "└", bottom: "─", bottom_right: "┘"
      }
    end
  end

  # Helper function to normalize spacing values
  defp normalize_spacing(n) when integer?(n) and n >= 0, do: {n, n, n, n}
  defp normalize_spacing({n}) when integer?(n) and n >= 0, do: {n, n, n, n}
  defp normalize_spacing({h, v}) when integer?(h) and integer?(v) and h >= 0 and v >= 0, do: {h, v, h, v}
  defp normalize_spacing({t, r, b, l})
       when integer?(t) and integer?(r) and integer?(b) and integer?(l) and
            t >= 0 and r >= 0 and b >= 0 and l >= 0, do: {t, r, b, l}
  defp normalize_spacing(_), do: {0, 0, 0, 0}
end
