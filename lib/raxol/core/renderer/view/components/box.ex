defmodule Raxol.Core.Renderer.View.Components.Box do
  @moduledoc '''
  Handles box layout functionality for the Raxol view system.
  Provides box model layout with content, padding, border, and margin.
  '''

  @doc '''
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
  '''
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

  @doc '''
  Calculates the layout of a box and its children.
  '''
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

  defp layout_children(children, _size) do
    # Implement child layout logic here
    # This would handle:
    # - Child positioning
    # - Size constraints
    # - Overflow handling
    children
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

  defp apply_margins(layout, {_top, _right, _bottom, _left}) do
    # Apply margins to layout
    layout
  end

  defp apply_padding(layout, {_top, _right, _bottom, _left}) do
    # Apply padding to layout
    layout
  end

  defp apply_border(layout, style) do
    # Apply border to layout
    apply_border_top(layout, style)
    apply_border_right(layout, style)
    apply_border_bottom(layout, style)
    apply_border_left(layout, style)
    layout
  end

  defp apply_border_top(layout, _style) do
    # Apply top border to layout
    layout
  end

  defp apply_border_right(layout, _style) do
    # Apply right border to layout
    layout
  end

  defp apply_border_bottom(layout, _style) do
    # Apply bottom border to layout
    layout
  end

  defp apply_border_left(layout, _style) do
    # Apply left border to layout
    layout
  end

  # Helper function to normalize spacing values
  defp normalize_spacing(spacing) do
    case spacing do
      n when is_integer(n) and n >= 0 ->
        {n, n, n, n}

      {n} when is_integer(n) and n >= 0 ->
        {n, n, n, n}

      {h, v} when is_integer(h) and is_integer(v) and h >= 0 and v >= 0 ->
        {h, v, h, v}

      {t, r, b, l}
      when is_integer(t) and is_integer(r) and is_integer(b) and is_integer(l) and
             t >= 0 and r >= 0 and b >= 0 and l >= 0 ->
        {t, r, b, l}

      _ ->
        {0, 0, 0, 0}
    end
  end
end
