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

  @type padding :: non_neg_integer() | {non_neg_integer(), non_neg_integer()} |
                  {non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()}
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
    %{
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
  end

  @doc """
  Creates a text view.
  """
  def text(content, opts \\ []) do
    new(:text, Keyword.merge([content: content], opts))
  end

  @doc """
  Creates a box view for layout.
  """
  def box(opts \\ [], do: block) do
    new(:box, Keyword.merge([children: block], opts))
  end

  @doc """
  Creates a flex container.
  """
  def flex(opts \\ [], do: block) do
    new(:flex, Keyword.merge([
      children: block,
      direction: Keyword.get(opts, :direction, :row),
      justify: Keyword.get(opts, :justify, :start),
      align: Keyword.get(opts, :align, :start),
      wrap: Keyword.get(opts, :wrap, false)
    ], opts))
  end

  @doc """
  Creates a grid container.
  """
  def grid(opts \\ [], do: block) do
    new(:grid, Keyword.merge([
      children: block,
      columns: Keyword.get(opts, :columns, 1),
      rows: Keyword.get(opts, :rows, :auto),
      gap: normalize_spacing(Keyword.get(opts, :gap, 0))
    ], opts))
  end

  @doc """
  Creates a border around a view.
  """
  def border(style \\ :single, opts \\ [], do: block) do
    new(:border, Keyword.merge([
      children: [block],
      border: style,
      title: Keyword.get(opts, :title)
    ], opts))
  end

  @doc """
  Creates a scrollable view.
  """
  def scroll(opts \\ [], do: block) do
    new(:scroll, Keyword.merge([
      children: [block],
      viewport: Keyword.get(opts, :viewport),
      offset: Keyword.get(opts, :offset, {0, 0}),
      scrollbars: Keyword.get(opts, :scrollbars, true)
    ], opts))
  end

  @doc """
  Creates a shadow effect.
  """
  def shadow(opts \\ [], do: block) do
    new(:shadow, Keyword.merge([
      children: [block],
      offset: Keyword.get(opts, :offset, {1, 1}),
      color: Keyword.get(opts, :color, :bright_black)
    ], opts))
  end

  @doc """
  Creates an absolutely positioned view.
  """
  def absolute(opts \\ [], do: block) do
    new(:box, Keyword.merge([
      children: block,
      position_type: :absolute
    ], opts))
  end

  @doc """
  Creates a fixed position view (relative to viewport).
  """
  def fixed(opts \\ [], do: block) do
    new(:box, Keyword.merge([
      children: block,
      position_type: :fixed
    ], opts))
  end

  @doc """
  Calculates the layout for a view tree.
  Returns a list of positioned views ready for rendering.
  """
  def layout(view, available_size) do
    # First layout the view and its children
    laid_out_view = case view.type do
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

  defp normalize_spacing({h, v}) when is_integer(h) and is_integer(v) do
    {v, h, v, h}
  end

  defp normalize_spacing({top, right, bottom, left}) do
    {top, right, bottom, left}
  end

  defp layout_flex(view, {width, height} = size) do
    direction = view.direction || :row
    justify = view.justify || :start
    align = view.align || :start
    wrap = view.wrap || false

    # Calculate available space for children
    {inner_width, inner_height} = apply_spacing(size, view.padding, view.margin)
    
    # Position children based on flex rules
    {positioned_children, _} = Enum.reduce(view.children, {[], {0, 0}}, fn child, {acc, pos} ->
      child_size = calculate_child_size(child, {inner_width, inner_height})
      child_pos = calculate_flex_position(pos, child_size, direction, wrap, {inner_width, inner_height})
      
      if child_pos do
        {[{child, child_pos} | acc], advance_position(pos, child_size, direction)}
      else
        {acc, pos}
      end
    end)

    # Apply justification and alignment
    positioned_children
    |> Enum.reverse()
    |> adjust_flex_positions(direction, justify, align, {inner_width, inner_height})
    |> Enum.map(fn {child, pos} -> %{child | position: pos} end)
  end

  defp layout_grid(view, {width, height} = size) do
    columns = view.columns || 1
    rows = view.rows || :auto
    gap = view.gap || {0, 0, 0, 0}

    # Calculate cell size
    cell_width = div(width - elem(gap, 1) * (columns - 1), columns)
    
    Enum.with_index(view.children)
    |> Enum.map(fn {child, i} ->
      row = div(i, columns)
      col = rem(i, columns)
      x = col * (cell_width + elem(gap, 1))
      y = row * (height + elem(gap, 0))
      
      %{child |
        position: {x, y},
        size: {cell_width, height}
      }
    end)
  end

  defp layout_border(view, size) do
    style = @border_chars[view.border || :single]
    {width, height} = size
    
    # Create border cells
    border = [
      # Top border
      {0, 0, style.top_left},
      {width - 1, 0, style.top_right},
      # Bottom border
      {0, height - 1, style.bottom_left},
      {width - 1, height - 1, style.bottom_right}
    ] ++ 
    # Horizontal borders
    for x <- 1..(width - 2) do
      [{x, 0, style.horizontal}, {x, height - 1, style.horizontal}]
    end ++
    # Vertical borders
    for y <- 1..(height - 2) do
      [{0, y, style.vertical}, {width - 1, y, style.vertical}]
    end

    # Layout child with reduced size
    inner_size = {width - 2, height - 2}
    child = List.first(view.children)
    
    [
      # Border cells
      border |> List.flatten() |> Enum.map(fn {x, y, char} ->
        text(char, position: {x, y})
      end),
      
      # Child content
      if child do
        %{child |
          position: {1, 1},
          size: inner_size
        }
      end
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
  end

  defp layout_scroll(view, size) do
    child = List.first(view.children)
    {offset_x, offset_y} = view.offset || {0, 0}
    
    if child do
      %{child |
        position: {-offset_x, -offset_y},
        size: size
      }
    end
  end

  defp layout_shadow(view, {width, height} = size) do
    child = List.first(view.children)
    {offset_x, offset_y} = view.offset || {1, 1}
    shadow_color = view.color || :bright_black
    
    [
      # Shadow
      for x <- offset_x..(width - 1),
          y <- offset_y..(height - 1) do
        text(" ",
          position: {x, y},
          bg: shadow_color,
          style: [:dim]
        )
      end,
      
      # Main content
      if child do
        %{child |
          position: {0, 0},
          size: {width - offset_x, height - offset_y}
        }
      end
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
  end

  defp layout_basic(view, size) do
    %{view | size: size}
  end

  defp apply_spacing({width, height}, {pt, pr, pb, pl}, {mt, mr, mb, ml}) do
    {
      width - (pl + pr + ml + mr),
      height - (pt + pb + mt + mb)
    }
  end

  defp calculate_child_size(child, parent_size) do
    child.size || parent_size
  end

  defp calculate_flex_position(current_pos, child_size, direction, wrap, container_size)

  defp calculate_flex_position({x, y}, {w, h}, :row, true, {container_w, _}) do
    if x + w > container_w do
      {0, y + h}  # Wrap to next line
    else
      {x, y}
    end
  end

  defp calculate_flex_position({x, y}, {w, h}, :row, false, _) do
    {x, y}
  end

  defp calculate_flex_position({x, y}, {w, h}, :column, true, {_, container_h}) do
    if y + h > container_h do
      {x + w, 0}  # Wrap to next column
    else
      {x, y}
    end
  end

  defp calculate_flex_position({x, y}, {w, h}, :column, false, _) do
    {x, y}
  end

  defp advance_position({x, y}, {w, h}, :row) do
    {x + w, y}
  end

  defp advance_position({x, y}, {w, h}, :column) do
    {x, y + h}
  end

  defp adjust_flex_positions(positions, direction, justify, align, container_size) do
    # Implement justification and alignment adjustments
    positions
  end

  defp flatten_view_tree(view) do
    [view | Enum.flat_map(view.children || [], &flatten_view_tree/1)]
  end

  defp sort_by_z_index(views) do
    Enum.sort_by(views, & &1.z_index)
  end

  defp apply_position_types(views, viewport_size) do
    Enum.map(views, fn view ->
      case view.position_type do
        :relative -> view  # Already handled by layout functions
        :absolute -> apply_absolute_position(view, viewport_size)
        :fixed -> apply_fixed_position(view, viewport_size)
      end
    end)
  end

  defp apply_absolute_position(view, viewport_size) do
    case view.position do
      nil -> view
      {x, y} -> %{view | position: {x, y}}
      {:right, x} -> %{view | position: {elem(viewport_size, 0) - x, elem(view.position, 1)}}
      {:bottom, y} -> %{view | position: {elem(view.position, 0), elem(viewport_size, 1) - y}}
      {:center, _} -> center_view(view, viewport_size)
    end
  end

  defp apply_fixed_position(view, viewport_size) do
    # Fixed position is the same as absolute, but relative to the viewport
    apply_absolute_position(view, viewport_size)
  end

  defp center_view(view, {width, height}) do
    case view.size do
      {view_width, view_height} ->
        x = div(width - view_width, 2)
        y = div(height - view_height, 2)
        %{view | position: {x, y}}
      _ ->
        view
    end
  end
end 