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
    # Merge opts first to get all explicit values
    merged_opts = Map.new(opts)

    base = %{
      type: type,
      position: Map.get(merged_opts, :position),
      position_type: Map.get(merged_opts, :position_type, :relative),
      z_index: Map.get(merged_opts, :z_index, 0),
      size: Map.get(merged_opts, :size),
      style: Map.get(merged_opts, :style, []),
      fg: Map.get(merged_opts, :fg),
      bg: Map.get(merged_opts, :bg),
      border: Map.get(merged_opts, :border, :none),
      children: Map.get(merged_opts, :children, []),
      content: Map.get(merged_opts, :content)
    }

    # Merge base defaults, then explicitly put normalized spacing
    merged_opts
    |> Map.merge(base)
    |> Map.put(:padding, normalize_spacing(Map.get(merged_opts, :padding, 0)))
    |> Map.put(:margin, normalize_spacing(Map.get(merged_opts, :margin, 0)))
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
    # First layout the view and its children. Specific layout functions return lists.
    laid_out_view_list =
      case view.type do
        :flex -> layout_flex(view, available_size)
        :grid -> layout_grid(view, available_size)
        :border -> layout_border(view, available_size)
        :scroll -> layout_scroll(view, available_size)
        :shadow -> layout_shadow(view, available_size)
        _ -> layout_basic(view, available_size)
      end

    # Flatten, sort by z-index, and apply absolute/fixed positioning
    laid_out_view_list
    |> flatten_view_tree() # Should now handle the list input
    |> sort_by_z_index()   # Should be safe with default z-index
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

  defp layout_flex(view, available_size) do
    direction = view.direction || :row
    justify = view.justify || :start
    align = view.align || :start
    wrap = view.wrap || false

    # Calculate available space for children inside padding/margin
    {inner_width, inner_height} = apply_spacing(available_size, view.padding, view.margin)
    inner_avail_size = {inner_width, inner_height}

    # Recursively layout children first
    laid_out_children_results = Enum.map(view.children, &layout(&1, inner_avail_size))

    # Flatten the results and get necessary info (size, margin, etc.)
    children_to_position =
      laid_out_children_results
      |> List.flatten()
      |> Enum.map(fn child_element ->
        {child_width, child_height} = child_element.size || {0, 0}
        {_, child_margin_right, _, child_margin_left} = child_element.margin
        {child_margin_top, _, child_margin_bottom, _} = child_element.margin

        %{element: child_element, size: {child_width, child_height}, margin: child_element.margin}
      end)

    # Position children based on flex rules (Simplified positioning logic for now)
    {positioned_children, _last_pos} =
      Enum.reduce(children_to_position, {[], {0, 0}}, fn child_info, {acc, current_pos} ->
        child_size = child_info.size
        child_margin = child_info.margin

        child_pos =
          calculate_flex_position(
            current_pos,
            child_size,
            child_margin,
            direction,
            wrap,
            inner_avail_size
          )

        next_pos = advance_position(child_pos, child_size, child_margin, direction)

        {[Map.put(child_info.element, :position, child_pos) | acc], next_pos}
      end)

    # Apply justification and alignment (Simplified)
    adjusted_children =
      positioned_children
      |> Enum.reverse()
      # |> adjust_flex_positions(direction, justify, align, inner_avail_size)

    # Return the flex container itself (positioned/sized) + adjusted children
    parent_position = {elem(view.margin, 3), elem(view.margin, 0)} # {left, top}
    [%{view | children: [], size: available_size, position: parent_position} | adjusted_children]
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
      |> Enum.map(&Map.update!(&1, :position, fn {cx, cy} -> {cx + x, cy + y} end))
    end)
    |> List.flatten()
  end

  defp layout_border(view, size) do
    style = @border_chars[view.border || :single]
    {width, height} = size

    # Create border cells
    border_cells = create_border_cells(style, width, height)

    # Layout child with reduced size
    inner_size = {max(0, width - 2), max(0, height - 2)}
    child = List.first(view.children)

    laid_out_child_elements =
      if child do
        # Recursively layout the child within the border's inner dimensions
        layout(child, inner_size)
        # Position child elements relative to border
        |> Enum.map(&Map.update!(&1, :position, fn {cx, cy} -> {cx + 1, cy + 1} end))
      else
        []
      end

    # Return the border cells and the laid-out child elements
    border_cells ++ laid_out_child_elements
  end

  defp layout_scroll(view, size) do
    child = List.first(view.children)
    {offset_x, offset_y} = view.offset || {0, 0}

    # Layout the child using its *intrinsic* size first, if available,
    # or the scroll container's size otherwise.
    child_layout_size = child.size || size

    laid_out_child_content =
      if child do
        layout(child, child_layout_size)
      else
        []
      end

    # Position the laid-out content within the scroll view
    positioned_content =
      laid_out_child_content
      # Flattening happens in the main layout function now
      # |> flatten_view_tree()
      |> Enum.map(fn elem ->
        {cx, cy} = elem.position || {0, 0}
        # Adjust child element positions by scroll offset
        Map.put(elem, :position, {cx - offset_x, cy - offset_y})
      end)

    # Return the scroll container itself (sized, positioned at {0,0}), plus the positioned child content
    # The renderer will handle clipping.
    [%{view | children: [], size: size, position: {0, 0}} | positioned_content]
  end

  defp layout_shadow(view, {width, height} = size) do
    child = List.first(view.children)
    {offset_x, offset_y} = view.offset || {1, 1}
    shadow_color = view.color || :bright_black

    # First, layout the child to determine its size and content
    content_size = {max(0, width - offset_x), max(0, height - offset_y)}

    laid_out_child_elements =
      if child do
        layout(child, content_size)
        # Position child elements at top-left within the shadow container
        |> Enum.map(&Map.update!(&1, :position, fn _pos -> {0, 0} end))
      else
        []
      end

    # Determine actual size occupied by the laid-out child (find max x/y)
    {actual_child_width, actual_child_height} = calculate_bounding_box(laid_out_child_elements)

    shadow_views =
      create_shadow_cells(
        offset_x,
        offset_y,
        actual_child_width,
        actual_child_height,
        shadow_color
      )

    # Return shadow views first (lower z-index implicitly), then child content
    shadow_views ++ laid_out_child_elements
  end

  # --- Helper functions for border/shadow cell creation ---

  defp create_border_cells(style, width, height) do
    border =
      [
        {0, 0, style.top_left},
        {width - 1, 0, style.top_right},
        {0, height - 1, style.bottom_left},
        {width - 1, height - 1, style.bottom_right}
      ] ++
        Enum.flat_map(1..(width - 2), fn x ->
          [{x, 0, style.horizontal}, {x, height - 1, style.horizontal}]
        end) ++
        Enum.flat_map(1..(height - 2), fn y ->
          [{0, y, style.vertical}, {width - 1, y, style.vertical}]
        end)

    Enum.map(border, fn {x, y, char} ->
      text(char, position: {x, y})
    end)
  end

  defp create_shadow_cells(offset_x, offset_y, child_width, child_height, shadow_color) do
    for x <- offset_x..(child_width + offset_x - 1),
        y <- offset_y..(child_height + offset_y - 1) do
      is_content_area = x < child_width and y < child_height

      unless is_content_area do
        text(" ", position: {x, y}, bg: shadow_color, style: [:dim])
      end
    end
    |> Enum.reject(&is_nil/1)
  end

  defp calculate_bounding_box(elements) do
    Enum.reduce(elements, {0, 0}, fn element, {max_w, max_h} ->
      {x, y} = element.position || {0, 0}
      {w, h} = element.size || {0, 0}
      {max(max_w, x + w), max(max_h, y + h)}
    end)
  end

  # --- End Helper functions ---

  defp layout_basic(view, {avail_width, avail_height} = available_size) do
    {padding_top, padding_right, padding_bottom, padding_left} = view.padding
    {margin_top, margin_right, margin_bottom, margin_left} = view.margin

    # Determine content size
    content_width =
      case view.content do
        t when is_binary(t) -> String.length(t)
        _ -> 0
      end

    content_height = 1 # Assuming single line for text, or needs explicit height for box

    # Explicit size overrides calculated content size
    {width, height} =
      view.size || {content_width + padding_left + padding_right, content_height + padding_top + padding_bottom}

    # Constrain size by available space minus margins
    max_width = max(0, avail_width - margin_left - margin_right)
    max_height = max(0, avail_height - margin_top - margin_bottom)

    final_width = min(width, max_width)
    final_height = min(height, max_height)

    # Position is relative to parent, start at margin offset
    final_position = {margin_left, margin_top}

    # Basic layout returns the element itself, positioned and sized
    [%{view | size: {final_width, final_height}, position: final_position}]
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

  defp calculate_flex_position({current_x, current_y}, _child_size, {m_top, _, _, m_left}, :row, false, {_avail_width, _avail_height}) do
    # Simple row layout: place next to previous, considering margin
    {current_x + m_left, current_y + m_top}
  end

  defp calculate_flex_position({current_x, current_y}, _child_size, {m_top, _, _, m_left}, :column, false, {_avail_width, _avail_height}) do
    # Simple column layout: place below previous, considering margin
    {current_x + m_left, current_y + m_top}
  end

  # TODO: Implement wrap logic for calculate_flex_position
  defp calculate_flex_position(current_pos, _child_size, child_margin, direction, _wrap, _inner_avail_size) do
    calculate_flex_position(current_pos, nil, child_margin, direction, false, nil)
  end

  defp advance_position({pos_x, pos_y}, {child_w, child_h}, {m_top, m_right, m_bottom, m_left}, :row) do
    {pos_x + child_w + m_right, pos_y}
  end

  defp advance_position({pos_x, pos_y}, {child_w, child_h}, {m_top, m_right, m_bottom, m_left}, :column) do
    {pos_x, pos_y + child_h + m_bottom}
  end

  # Placeholder for more complex flex logic
  defp adjust_flex_positions(positioned_children, _direction, _justify, _align, _container_size) do
    # TODO: Implement actual justification and alignment logic
    positioned_children # Return as is for now
  end

  defp flatten_view_tree(nil), do: []
  # Handle non-map children (like text content)
  defp flatten_view_tree(view) when not is_map(view), do: [view]
  # Add clause for list input
  defp flatten_view_tree(views) when is_list(views) do
    Enum.flat_map(views, &flatten_view_tree/1)
  end

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
    # Default to z_index 0 if missing
    Enum.sort_by(views, fn view ->
      case Map.fetch(view, :z_index) do
        {:ok, z} -> z
        :error ->
          IO.inspect(view, label: "View missing z_index in sort_by_z_index")
          0 # Default to 0
      end
    end, :asc)
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
