defmodule Raxol.Core.Renderer.View do
  @moduledoc """
  Defines the view system for Raxol components.

  Provides:
  * Box model layout (content, padding, border, margin)
  * Flexible layouts (grid, flex)
  * Rich text rendering
  * Borders and shadows
  """

  alias Raxol.Core.Renderer.Color

  @type position :: {non_neg_integer(), non_neg_integer()}
  @type size :: {non_neg_integer(), non_neg_integer()}
  @type color :: Color.color()
  @type style :: [atom()]
  @type border_style :: :none | :single | :double | :rounded | :bold | :dashed
  @type layout_type :: :flex | :grid | :flow | :absolute
  @type position_type :: :relative | :absolute | :fixed
  @type z_index :: integer()

  @type view :: %{
          type: atom(),
          position: position() | nil,
          position_type: position_type(),
          z_index: z_index(),
          size: size() | nil,
          style: style(),
          fg: color() | nil,
          bg: color() | nil,
          border: border_style(),
          padding: padding(),
          margin: margin(),
          children: [view()],
          content: term()
        }

  @type padding ::
          non_neg_integer()
          | {non_neg_integer(), non_neg_integer()}
          | {non_neg_integer(), non_neg_integer(), non_neg_integer(),
             non_neg_integer()}
  @type margin :: padding()

  @border_chars %{
    single: %{
      top_left: "┌",
      top_right: "┐",
      bottom_left: "└",
      bottom_right: "┘",
      horizontal: "─",
      vertical: "│"
    },
    double: %{
      top_left: "╔",
      top_right: "╗",
      bottom_left: "╚",
      bottom_right: "╝",
      horizontal: "═",
      vertical: "║"
    },
    rounded: %{
      top_left: "╭",
      top_right: "╮",
      bottom_left: "╰",
      bottom_right: "╯",
      horizontal: "─",
      vertical: "│"
    },
    bold: %{
      top_left: "┏",
      top_right: "┓",
      bottom_left: "┗",
      bottom_right: "┛",
      horizontal: "━",
      vertical: "┃"
    },
    dashed: %{
      top_left: "┌",
      top_right: "┐",
      bottom_left: "└",
      bottom_right: "┘",
      horizontal: "┄",
      vertical: "┆"
    }
  }

  @doc """
  Creates a new view with the given type and options.
  """
  def new(type, opts \\ []) do
    base = %{
      type: type,
      position: Keyword.get(opts, :position),
      position_type: Keyword.get(opts, :position_type, :relative),
      z_index: Keyword.get(opts, :z_index, 0),
      size: Keyword.get(opts, :size),
      style: Keyword.get(opts, :style, []),
      fg: Keyword.get(opts, :fg),
      bg: Keyword.get(opts, :bg),
      border: Keyword.get(opts, :border, :none),
      padding: normalize_spacing(Keyword.get(opts, :padding, 0)),
      margin: normalize_spacing(Keyword.get(opts, :margin, 0)),
      children: Keyword.get(opts, :children, []),
      content: Keyword.get(opts, :content)
    }

    Map.merge(base, Map.new(opts))
  end

  @doc """
  Creates a text view.
  """
  def text(content, opts \\ []) when is_binary(content) do
    new(:text, Keyword.merge([content: content], opts))
  end

  @doc """
  Creates a box view for layout.
  """
  def box(opts \\ []) do
    new(:box, opts)
  end

  @doc """
  Creates a flex container.
  """
  def flex(opts \\ [], do: block) do
    new(
      :flex,
      Keyword.merge(
        [
          children: block,
          direction: Keyword.get(opts, :direction, :row),
          justify: Keyword.get(opts, :justify, :start),
          align: Keyword.get(opts, :align, :start),
          wrap: Keyword.get(opts, :wrap, false)
        ],
        opts
      )
    )
  end

  @doc """
  Creates a grid container.
  """
  def grid(opts \\ [], do: block) do
    new(
      :grid,
      Keyword.merge(
        [
          children: block,
          columns: Keyword.get(opts, :columns, 1),
          rows: Keyword.get(opts, :rows, :auto),
          gap: normalize_spacing(Keyword.get(opts, :gap, 0))
        ],
        opts
      )
    )
  end

  @doc """
  Creates a border around a view.
  """
  def border(style \\ :single, opts \\ [], do: block) do
    new(
      :border,
      Keyword.merge(
        [
          children: [block],
          border: style,
          title: Keyword.get(opts, :title)
        ],
        opts
      )
    )
  end

  @doc """
  Creates a scrollable view.
  """
  def scroll(opts \\ [], do: block) do
    new(
      :scroll,
      Keyword.merge(
        [
          children: [block],
          viewport: Keyword.get(opts, :viewport),
          offset: Keyword.get(opts, :offset, {0, 0}),
          scrollbars: Keyword.get(opts, :scrollbars, true)
        ],
        opts
      )
    )
  end

  @doc """
  Creates a shadow effect.
  """
  def shadow(opts \\ [], do: block) do
    new(
      :shadow,
      Keyword.merge(
        [
          children: [block],
          offset: Keyword.get(opts, :offset, {1, 1}),
          color: Keyword.get(opts, :color, :bright_black)
        ],
        opts
      )
    )
  end

  @doc """
  Creates an absolutely positioned view.
  """
  def absolute(opts \\ [], do: block) do
    new(
      :box,
      Keyword.merge(
        [
          children: block,
          position_type: :absolute
        ],
        opts
      )
    )
  end

  @doc """
  Creates a fixed position view (relative to viewport).
  """
  def fixed(opts \\ [], do: block) do
    new(
      :box,
      Keyword.merge(
        [
          children: block,
          position_type: :fixed
        ],
        opts
      )
    )
  end

  @doc """
  Calculates the layout for a view tree.
  Returns a list of positioned views ready for rendering.
  """
  def layout(view, available_size) do
    # First layout the view and its children
    laid_out_view =
      case view.type do
        :flex -> layout_flex(view, available_size)
        :grid -> layout_grid(view, available_size)
        :border -> layout_border(view, available_size)
        :scroll -> layout_scroll(view, available_size)
        :shadow -> layout_shadow(view, available_size)
        _ -> layout_basic(view, available_size)
      end

    # Then handle absolute and fixed positioning
    laid_out_view
    |> flatten_view_tree()
    |> sort_by_z_index()
    |> apply_position_types(available_size)
  end

  # Private Helpers

  defp normalize_spacing(spacing) when is_integer(spacing) do
    {spacing, spacing, spacing, spacing}
  end

  defp normalize_spacing({v, h}) when is_integer(v) and is_integer(h) do
    {v, h, v, h}
  end

  defp normalize_spacing({top, right, bottom, left}) do
    {top, right, bottom, left}
  end

  defp layout_flex(view, {_width, _height} = size) do
    direction = view.direction || :row
    justify = view.justify || :start
    align = view.align || :start
    wrap = view.wrap || false

    # Calculate available space for children
    {inner_width, inner_height} = apply_spacing(size, view.padding, view.margin)

    # Position children based on flex rules
    {positioned_children, _} =
      Enum.reduce(view.children, {[], {0, 0}}, fn child, {acc, pos} ->
        child_size = calculate_child_size(child, {inner_width, inner_height})

        child_pos =
          calculate_flex_position(
            pos,
            child_size,
            direction,
            wrap,
            {inner_width, inner_height}
          )

        {[{child, child_pos} | acc],
         advance_position(pos, child_size, direction)}
      end)

    # Apply justification and alignment
    positioned_children
    |> Enum.reverse()
    |> adjust_flex_positions(
      direction,
      justify,
      align,
      {inner_width, inner_height}
    )
    |> Enum.map(fn {child, pos} -> %{child | position: pos} end)
  end

  defp layout_grid(view, {width, height} = _size) do
    # Default rows to :auto if not provided
    _rows = view.rows || :auto
    columns = view.columns || 1
    gap = view.gap || {0, 0, 0, 0}

    # Calculate cell size
    cell_width = div(width - elem(gap, 1) * (columns - 1), columns)

    Enum.with_index(view.children)
    |> Enum.map(fn {child, i} ->
      row = div(i, columns)
      col = rem(i, columns)
      x = col * (cell_width + elem(gap, 1))
      y = row * (height + elem(gap, 0))
      # Recursively layout grid children
      # Assuming cell height is full row height for now
      layout(child, {cell_width, height})
      |> Map.put(:position, {x, y})
    end)
  end

  defp layout_border(view, size) do
    style = @border_chars[view.border || :single]
    {width, height} = size

    # Create border cells
    # Horizontal borders
    # Vertical borders
    border =
      [
        # Top border
        {0, 0, style.top_left},
        {width - 1, 0, style.top_right},
        # Bottom border
        {0, height - 1, style.bottom_left},
        {width - 1, height - 1, style.bottom_right}
      ] ++
        for x <- 1..(width - 2) do
          [{x, 0, style.horizontal}, {x, height - 1, style.horizontal}]
        end ++
        for y <- 1..(height - 2) do
          [{0, y, style.vertical}, {width - 1, y, style.vertical}]
        end

    # Layout child with reduced size
    inner_size = {max(0, width - 2), max(0, height - 2)}
    child = List.first(view.children)

    laid_out_child =
      if child do
        # Recursively layout the child within the border's inner dimensions
        layout(child, inner_size)
        # Position child relative to border
        |> Map.put(:position, {1, 1})
      else
        nil
      end

    # Return the border cells and the laid-out child
    [
      border
      |> List.flatten()
      |> Enum.map(fn {x, y, char} ->
        text(char, position: {x, y})
      end),
      laid_out_child
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
  end

  defp layout_scroll(view, size) do
    child = List.first(view.children)
    {offset_x, offset_y} = view.offset || {0, 0}

    # Layout the child using its *intrinsic* size first, if available,
    # or the scroll container's size otherwise.
    # This is simplified; real scroll layout is complex.
    child_layout_size = child.size || size

    laid_out_child_content =
      if child do
        # Layout child first
        layout(child, child_layout_size)
      else
        []
      end

    # Position the laid-out content within the scroll view
    positioned_content =
      laid_out_child_content
      # Flatten the child's layout result
      |> flatten_view_tree()
      |> Enum.map(fn elem ->
        {cx, cy} = elem.position || {0, 0}
        # Adjust child element positions by scroll offset
        Map.put(elem, :position, {cx - offset_x, cy - offset_y})
      end)

    # Return the scroll container itself, plus the positioned child content
    # The renderer will handle clipping based on the scroll container's size.
    # Don't nest children here
    [%{view | children: [], size: size} | positioned_content]
  end

  defp layout_shadow(view, {width, height} = size) do
    child = List.first(view.children)
    {offset_x, offset_y} = view.offset || {1, 1}
    shadow_color = view.color || :bright_black

    # Calculate shadow cells based on the final size of the child
    # First, layout the child to determine its size
    content_size = {max(0, width - offset_x), max(0, height - offset_y)}

    laid_out_child_content =
      if child do
        layout(child, content_size)
        # Position child at top-left
        |> Map.put(:position, {0, 0})
      else
        nil
      end

    # Determine actual size occupied by the laid-out child
    actual_child_width =
      if laid_out_child_content,
        do: elem(laid_out_child_content.size, 0),
        else: 0

    actual_child_height =
      if laid_out_child_content,
        do: elem(laid_out_child_content.size, 1),
        else: 0

    shadow_views =
      for x <- offset_x..(actual_child_width + offset_x - 1),
          y <- offset_y..(actual_child_height + offset_y - 1) do
        # Avoid drawing shadow where content is
        is_content_area = x < actual_child_width and y < actual_child_height

        unless is_content_area do
          text(" ", position: {x, y}, bg: shadow_color, style: [:dim])
        end
      end
      |> Enum.reject(&is_nil/1)

    # Flatten the laid_out_child_content if it has children
    flat_child_content =
      flatten_view_tree(laid_out_child_content)
      |> Enum.reject(&is_nil/1)

    # Return shadow views and the laid-out child content
    [shadow_views, flat_child_content]
    |> List.flatten()
  end

  defp layout_basic(view, size) do
    # If basic view has children, layout them too
    laid_out_children = Enum.map(view.children || [], &layout(&1, size))
    %{view | size: size, children: laid_out_children}
  end

  defp apply_spacing({width, height}, {pt, pr, pb, pl}, {mt, mr, mb, ml}) do
    inner_width = width - (pl + pr + ml + mr)
    inner_height = height - (pt + pb + mt + mb)
    # Ensure non-negative
    {max(0, inner_width), max(0, inner_height)}
  end

  defp calculate_child_size(child, parent_size) do
    # Prioritize child's explicit size, fallback to calculated or parent size
    child.size || calculate_intrinsic_size(child) || parent_size
  end

  defp calculate_intrinsic_size(view) do
    case view.type do
      # Basic text size
      :text -> {String.length(view.content || ""), 1}
      # Add calculations for other types if needed
      _ -> nil
    end
  end

  defp calculate_flex_position({x, y}, {w, h}, :row, true, {container_w, _}) do
    if x + w > container_w do
      {0, y + h}
    else
      {x, y}
    end
  end

  defp calculate_flex_position({x, y}, {w, _h}, :row, false, _) do
    {x + w, y}
  end

  defp calculate_flex_position({x, y}, {w, h}, :column, true, {_, container_h}) do
    if y + h > container_h do
      {x + w, 0}
    else
      {x, y}
    end
  end

  defp calculate_flex_position({x, y}, {_w, h}, :column, false, _) do
    {x, y + h}
  end

  defp advance_position({x, y}, {w, _h}, :row) do
    {x + w, y}
  end

  defp advance_position({x, y}, {_w, h}, :column) do
    {x, y + h}
  end

  defp adjust_flex_positions(
         positioned_children,
         direction,
         justify,
         align,
         container_size
       ) do
    # Simplified placeholder - Real flexbox alignment/justification is complex!
    positioned_children
  end

  defp flatten_view_tree(nil), do: []
  # Handle non-map children (like text content)
  defp flatten_view_tree(view) when not is_map(view), do: [view]

  defp flatten_view_tree(view) do
    # For containers like :scroll, :shadow, :border that were handled specially,
    # their children might already be flattened or positioned correctly.
    # Others like :flex, :grid might need their children flattened here.
    # This needs refinement based on how layout functions structure output.
    # Assuming layout functions now return laid-out children correctly:
    # Return the container itself without children
    [
      Map.put(view, :children, [])
      | Enum.flat_map(view.children || [], &flatten_view_tree/1)
    ]
  end

  defp sort_by_z_index(views) do
    Enum.sort_by(views, &(&1.z_index || 0))
  end

  defp apply_position_types(views, viewport_size) do
    Enum.map(views, fn view ->
      case view.position_type do
        # Relative positioning handled during layout
        :relative -> view
        :absolute -> apply_absolute_position(view, viewport_size)
        :fixed -> apply_fixed_position(view, viewport_size)
        _ -> view
      end
    end)
  end

  defp apply_absolute_position(view, viewport_size) do
    # Absolute positioning relative to nearest positioned ancestor
    # Simplified: Assuming relative to the initial viewport for now
    view
  end

  defp apply_fixed_position(view, viewport_size) do
    # Fixed positioning relative to the viewport
    view
  end
end
