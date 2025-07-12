defmodule Raxol.UI.Renderer do
  @moduledoc """
  UI Renderer for Raxol terminal applications.

  This module provides rendering capabilities for various UI elements
  including panels, boxes, text, and tables with theme support.
  """

  alias Raxol.Core.ColorSystem
  alias Raxol.UI.Theming.Theme

  # Default colors
  @default_fg :white
  @default_bg :black

  @doc """
  Renders a single element or list of elements to cells.
  This is the main public API for the renderer.

  ## Parameters
    * `element_or_elements` - Single element map, list of elements, or nil
    * `theme` - Optional theme (defaults to default theme)

  ## Returns
    * List of cells in the format {x, y, char, fg, bg, attrs}
  """
  def render_to_cells(element_or_elements, theme \\ nil) do
    # Handle nil case
    if is_nil(element_or_elements) do
      []
    else
      # Ensure we have a list of elements
      elements = ensure_list(element_or_elements)

      # Get default theme if none provided
      theme = theme || Raxol.UI.Theming.Theme.get(:default)

      # Render each element and flatten results
      elements
      |> Enum.flat_map(fn element -> render_element(element, theme, %{}) end)
      |> filter_valid_cells()
    end
  end

  @doc """
  Renders a UI element to a list of cells.

  ## Parameters
    * `element` - The element to render
    * `theme` - The theme to use for rendering
    * `parent_style` - Parent style to inherit from (optional)

  ## Returns
    * List of cells in the format {x, y, char, fg, bg, attrs}
  """
  def render_element(element, theme, parent_style \\ %{}) do
    case validate_element(element) do
      {:ok, valid_element} ->
        # Check for zero dimensions
        if Map.get(valid_element, :width, 0) == 0 or
             Map.get(valid_element, :height, 0) == 0 do
          []
        else
          render_visible_element(valid_element, theme, parent_style)
        end

      {:error, _reason} ->
        []
    end
  end

  # --- Helper Functions for Edge Case Handling ---

  # Handle elements with invalid dimensions
  defp filter_valid_cells(cells) do
    Enum.filter(cells, fn {x, y, _char, _fg, _bg, _attrs} ->
      # Filter out cells with negative or invalid coordinates
      x >= 0 and y >= 0
    end)
  end

  # Validate element before rendering
  defp validate_element(element) do
    cond do
      is_nil(element) -> {:error, :nil_element}
      not is_map(element) -> {:error, :invalid_element}
      not Map.has_key?(element, :type) -> {:error, :missing_type}
      Map.get(element, :width, 0) < 0 -> {:error, :negative_width}
      Map.get(element, :height, 0) < 0 -> {:error, :negative_height}
      true -> {:ok, element}
    end
  end

  defp get_border_chars(:single) do
    %{
      top_left: "┌",
      top_right: "┐",
      bottom_left: "└",
      bottom_right: "┘",
      horizontal: "─",
      vertical: "│"
    }
  end

  defp get_border_chars(:double) do
    %{
      top_left: "╔",
      top_right: "╗",
      bottom_left: "╚",
      bottom_right: "╝",
      horizontal: "═",
      vertical: "║"
    }
  end

  defp get_border_chars(:rounded) do
    %{
      top_left: "╭",
      top_right: "╮",
      bottom_left: "╰",
      bottom_right: "╯",
      horizontal: "─",
      vertical: "│"
    }
  end

  # Fallback for unknown or :none
  defp get_border_chars(_) do
    %{
      top_left: " ",
      top_right: " ",
      bottom_left: " ",
      bottom_right: " ",
      horizontal: " ",
      vertical: " "
    }
  end

  # --- Theme Helper Functions ---

  @doc false
  # Resolves fg, bg, and style attributes based on element attrs, component type, and theme.
  # Priority:
  # 1. Explicit attrs (:fg, :bg, :style)
  # 2. Component-specific theme styles (e.g., theme.component_styles.button.fg)
  # 3. General theme colors (looked up via ColorSystem.get)
  # 4. Global defaults (@default_fg / @default_bg / [])
  defp resolve_styles(attrs, component_type, %Raxol.UI.Theming.Theme{} = theme) do
    component_styles = get_component_styles(component_type, theme)
    fg_color = resolve_fg_color(attrs, component_styles, theme)
    bg_color = resolve_bg_color(attrs, component_styles, theme)
    style_attrs = resolve_style_attrs(attrs, component_styles)

    {fg_color, bg_color, style_attrs}
  end

  # Clause to handle nil theme (fallback to defaults)
  defp resolve_styles(attrs, _component_type, nil) when is_map(attrs) do
    fg_color = Map.get(attrs, :fg, @default_fg)
    bg_color = Map.get(attrs, :bg, @default_bg)
    style_attrs = Map.get(attrs, :style, []) |> Enum.uniq()
    {fg_color, bg_color, style_attrs}
  end

  # Catch-all clause for other cases
  defp resolve_styles(attrs, _component_type, _theme) when is_map(attrs) do
    fg_color = Map.get(attrs, :fg, @default_fg)
    bg_color = Map.get(attrs, :bg, @default_bg)
    style_attrs = Map.get(attrs, :style, []) |> Enum.uniq()
    {fg_color, bg_color, style_attrs}
  end

  defp get_component_styles(component_type, theme) do
    if component_type do
      Map.get(theme.component_styles, component_type, %{})
    else
      %{}
    end
  end

  defp resolve_fg_color(attrs, _component_styles, theme) do
    result =
      cond do
        Map.has_key?(attrs, :fg) and not is_nil(Map.get(attrs, :fg)) ->
          Map.get(attrs, :fg)

        Map.has_key?(attrs, :foreground) and
            not is_nil(Map.get(attrs, :foreground)) ->
          Map.get(attrs, :foreground)

        true ->
          # Try to get color from theme directly first
          case get_in(theme, [:colors, :foreground]) do
            nil ->
              # Fallback to ColorSystem, then :default
              Raxol.Core.ColorSystem.get(theme.id, :foreground) || :default

            color ->
              color
          end
      end

    result
  end

  defp resolve_bg_color(attrs, _component_styles, theme) do
    result =
      cond do
        Map.has_key?(attrs, :bg) and not is_nil(Map.get(attrs, :bg)) ->
          Map.get(attrs, :bg)

        Map.has_key?(attrs, :background) and
            not is_nil(Map.get(attrs, :background)) ->
          Map.get(attrs, :background)

        true ->
          # Try to get color from theme directly first
          case get_in(theme, [:colors, :background]) do
            nil ->
              # Fallback to ColorSystem, then :default
              Raxol.Core.ColorSystem.get(theme.id, :background) || :default

            color ->
              color
          end
      end

    result
  end

  defp resolve_style_attrs(attrs, component_styles) do
    explicit_attrs = Map.get(attrs, :style, []) |> ensure_list()
    component_attrs = Map.get(component_styles, :style, []) |> ensure_list()
    (explicit_attrs ++ component_attrs) |> Enum.uniq()
  end

  defp ensure_list(value) when is_list(value), do: value
  defp ensure_list(value), do: [value]

  # Helper function to flatten merged styles
  defp flatten_merged_style(parent_element, child_element) do
    parent_style_map = Map.get(parent_element, :style, %{})
    child_style_map = Map.get(child_element, :style, %{})
    merged_style_map = Map.merge(parent_style_map, child_style_map)
    child_other_attrs = Map.drop(child_element, [:style])

    inherited_colors =
      inherit_colors(child_style_map, parent_element, parent_style_map)

    promoted_attrs =
      child_other_attrs
      |> Map.put_new(:foreground, inherited_colors.fg)
      |> Map.put_new(:background, inherited_colors.bg)
      |> Map.put_new(:fg, inherited_colors.fg_short)
      |> Map.put_new(:bg, inherited_colors.bg_short)

    Map.merge(promoted_attrs, merged_style_map)
  end

  defp inherit_colors(child_style_map, parent_element, parent_style_map) do
    %{
      fg:
        Map.get(child_style_map, :foreground) ||
          Map.get(parent_element, :foreground) ||
          Map.get(parent_style_map, :foreground),
      bg:
        Map.get(child_style_map, :background) ||
          Map.get(parent_element, :background) ||
          Map.get(parent_style_map, :background),
      fg_short:
        Map.get(child_style_map, :fg) || Map.get(parent_element, :fg) ||
          Map.get(parent_style_map, :fg),
      bg_short:
        Map.get(child_style_map, :bg) || Map.get(parent_element, :bg) ||
          Map.get(parent_style_map, :bg)
    }
  end

  # Helper function to put a key-value pair only if the value is not nil
  defp maybe_put_if_not_nil(map, _key, nil), do: map
  defp maybe_put_if_not_nil(map, key, value), do: Map.put(map, key, value)

  # Helper function to merge parent and child styles for inheritance
  defp merge_styles_for_inheritance(parent_style, child_style) do
    # Extract style maps from both parent and child
    parent_style_map = Map.get(parent_style, :style, %{})
    child_style_map = Map.get(child_style, :style, %{})

    # Merge the style maps (child overrides parent)
    merged_style_map = Map.merge(parent_style_map, child_style_map)

    # Create a complete inherited style that includes both the merged style map
    # and the promoted keys for proper inheritance
    %{}
    |> Map.put(:style, merged_style_map)
    |> maybe_put_if_not_nil(
      :foreground,
      Map.get(merged_style_map, :foreground)
    )
    |> maybe_put_if_not_nil(
      :background,
      Map.get(merged_style_map, :background)
    )
    |> maybe_put_if_not_nil(:fg, Map.get(merged_style_map, :fg))
    |> maybe_put_if_not_nil(:bg, Map.get(merged_style_map, :bg))
  end

  defp render_visible_element(
         %{type: :panel, x: x, y: y, width: w, height: h} = panel_element,
         theme,
         parent_style \\ %{}
       ) do
    merged_style = flatten_merged_style(parent_style, panel_element)
    panel_box_cells = render_box(x, y, w, h, merged_style, theme)
    children = Map.get(panel_element, :children)

    # Check if clipping is enabled for this panel
    clip_enabled = Map.get(panel_element, :clip, false)
    clip_bounds = if clip_enabled, do: {x, y, x + w - 1, y + h - 1}, else: nil

    # Render children with clipping and style inheritance
    children_cells =
      render_panel_children(children, clip_bounds, theme, merged_style)

    # Merge cells so that children overwrite panel cells at the same coordinates
    all_cells = merge_cells(panel_box_cells, children_cells)
    clip_cells_to_bounds(all_cells, clip_bounds)
  end

  defp render_visible_element(
         %{type: :box, x: x, y: y, width: w, height: h} = box_element,
         theme,
         parent_style
       ) do
    merged_style = flatten_merged_style(parent_style, box_element)
    cells = render_box(x, y, w, h, merged_style, theme)
    clip_cells_to_bounds(cells, Map.get(box_element, :clip_bounds))
  end

  defp render_visible_element(
         %{type: :text, text: text_content, x: x, y: y} = text_element,
         theme,
         parent_style
       ) do
    merged_style = flatten_merged_style(parent_style, text_element)
    cells = render_text(x, y, text_content, merged_style, theme)
    clip_cells_to_bounds(cells, Map.get(text_element, :clip_bounds))
  end

  defp render_visible_element(
         %{type: :table, x: x, y: y} = table_element,
         theme,
         parent_style
       ) do
    _merged_style = flatten_merged_style(parent_style, table_element)

    # Extract table data from the element
    headers = Map.get(table_element, :headers, [])
    data = Map.get(table_element, :data, [])
    column_widths = Map.get(table_element, :column_widths, [])

    # Calculate table width if not provided
    width = calculate_table_width(headers, data, column_widths)

    # Build attrs with table data and custom styles
    attrs = build_table_attrs(table_element, headers, data, column_widths)

    cells = render_table(x, y, width, 0, attrs, theme)
    clip_cells_to_bounds(cells, Map.get(table_element, :clip_bounds))
  end

  # Fallback for tables with explicit width/height
  defp render_visible_element(
         %{type: :table, x: x, y: y, width: w, height: h} = table_element,
         theme,
         parent_style
       ) do
    _merged_style = flatten_merged_style(parent_style, table_element)

    # Extract table data from the element
    headers = Map.get(table_element, :headers, [])
    data = Map.get(table_element, :data, [])
    column_widths = Map.get(table_element, :column_widths, [])

    # Build attrs with table data and custom styles
    attrs = build_table_attrs(table_element, headers, data, column_widths)

    cells = render_table(x, y, w, h, attrs, theme)
    clip_cells_to_bounds(cells, Map.get(table_element, :clip_bounds))
  end

  defp clip_cells_to_bounds(cells, nil), do: cells

  defp clip_cells_to_bounds(cells, {min_x, min_y, max_x, max_y}) do
    Enum.filter(cells, fn {x, y, _char, _fg, _bg, _attrs} ->
      x >= min_x and x <= max_x and y >= min_y and y <= max_y
    end)
  end

  # Helper to merge two cell lists, with the second list taking precedence at overlapping coordinates
  defp merge_cells(base_cells, overlay_cells) do
    base_cells
    |> build_cell_map()
    |> overlay_cells(overlay_cells)
    |> Map.values()
  end

  defp build_cell_map(cells) do
    Enum.reduce(cells, %{}, fn {x, y, c, fg, bg, attrs}, acc ->
      Map.put(acc, {x, y}, {x, y, c, fg, bg, attrs})
    end)
  end

  defp overlay_cells(cell_map, overlay_cells) do
    Enum.reduce(overlay_cells, cell_map, fn {x, y, c, fg, bg, attrs}, acc ->
      Map.put(acc, {x, y}, {x, y, c, fg, bg, attrs})
    end)
  end

  # Calculate table width based on headers, data, and column widths
  defp calculate_table_width(headers, data, column_widths) do
    # If column widths are provided, use their sum
    if column_widths != [] do
      Enum.sum(column_widths)
    else
      calculate_content_based_width(headers, data)
    end
  end

  # Helper function to calculate width based on content
  defp calculate_content_based_width(headers, data) do
    all_rows = [headers | data]
    max_columns = get_max_columns(all_rows)
    column_max_widths = calculate_column_widths(all_rows, max_columns)

    # Add padding and borders
    total_width =
      Enum.sum(column_max_widths) + length(column_max_widths) * 3 + 2

    # Minimum width of 20
    max(total_width, 20)
  end

  defp get_max_columns(all_rows) do
    Enum.reduce(all_rows, 0, fn row, max_cols ->
      max(length(row), max_cols)
    end)
  end

  defp calculate_column_widths(all_rows, max_columns) do
    for col_index <- 0..(max_columns - 1) do
      column_content = get_column_content(all_rows, col_index)
      get_max_column_width(column_content)
    end
  end

  defp get_column_content(all_rows, col_index) do
    Enum.map(all_rows, fn row ->
      Enum.at(row, col_index, "")
    end)
  end

  defp get_max_column_width(column_content) do
    Enum.reduce(column_content, 0, fn cell, max_width ->
      cell_width = String.graphemes(to_string(cell)) |> length()
      max(cell_width, max_width)
    end)
  end

  # Helper function to build table attributes
  defp build_table_attrs(table_element, headers, data, column_widths) do
    Map.get(table_element, :attrs, %{})
    |> Map.put(:_headers, headers)
    |> Map.put(:_data, data)
    |> Map.put(:_col_widths, column_widths)
    |> Map.put(:_component_type, :table)
    |> Map.put(:header_style, Map.get(table_element, :header_style, %{}))
    |> Map.put(:row_style, Map.get(table_element, :row_style, %{}))
  end

  # Helper function to render panel children with clipping
  defp render_panel_children(children, clip_bounds, theme, merged_style) do
    Enum.flat_map(children || [], fn child ->
      # Pass clip bounds and merged style as parent style to children
      child_with_clip =
        if clip_bounds do
          Map.put(child, :clip_bounds, clip_bounds)
        else
          child
        end

      render_element(child_with_clip, theme, merged_style)
    end)
  end

  defp render_box(x, y, width, height, style, _theme) do
    {clip_x, clip_y, clip_width, clip_height} =
      clip_coordinates(x, y, width, height)

    if clip_width == 0 or clip_height == 0 do
      []
    else
      border_chars = get_border_chars(Map.get(style, :border_style, :single))

      render_box_borders(
        clip_x,
        clip_y,
        clip_width,
        clip_height,
        border_chars,
        style
      )
    end
  end

  defp clip_coordinates(x, y, width, height) do
    {max(0, x), max(0, y), max(0, width), max(0, height)}
  end

  defp render_box_borders(x, y, width, height, border_chars, style) do
    # For 1x1 boxes, just create a single cell with a space
    if width == 1 and height == 1 do
      [{x, y, " ", style.fg, style.bg, []}]
    else
      []
      |> add_horizontal_borders(x, y, width, height, border_chars, style)
      |> add_vertical_borders(x, y, width, height, border_chars, style)
      |> add_corners(x, y, width, height, border_chars, style)
    end
  end

  defp add_horizontal_borders(cells, x, y, width, height, border_chars, style) do
    cells
    |> add_line(
      render_horizontal_line(x, y, width, border_chars.horizontal, style, nil)
    )
    |> add_line(
      render_horizontal_line(
        x,
        y + height - 1,
        width,
        border_chars.horizontal,
        style,
        nil
      )
    )
  end

  defp add_vertical_borders(cells, x, y, width, height, border_chars, style) do
    cells
    |> add_line(
      render_vertical_line(x, y, height, border_chars.vertical, style, nil)
    )
    |> add_line(
      render_vertical_line(
        x + width - 1,
        y,
        height,
        border_chars.vertical,
        style,
        nil
      )
    )
  end

  defp add_corners(cells, x, y, width, height, border_chars, style) do
    cells ++
      [
        {x, y, border_chars.top_left, style.fg, style.bg, []},
        {x + width - 1, y, border_chars.top_right, style.fg, style.bg, []},
        {x, y + height - 1, border_chars.bottom_left, style.fg, style.bg, []},
        {x + width - 1, y + height - 1, border_chars.bottom_right, style.fg,
         style.bg, []}
      ]
  end

  defp add_line(cells, line_cells), do: cells ++ line_cells

  defp render_text(x, y, text, style, _theme) do
    # Handle negative coordinates
    if x < 0 or y < 0 do
      []
    else
      # Simple text rendering - one character per cell
      text
      |> String.graphemes()
      |> Enum.with_index()
      |> Enum.map(fn {char, index} ->
        {x + index, y, char, style.fg, style.bg, []}
      end)
    end
  end

  defp render_table(x, y, _width, _height, attrs, _theme) do
    # Simple table rendering - just create a basic structure
    headers = Map.get(attrs, :_headers, [])
    data = Map.get(attrs, :_data, [])

    cells = []

    # Render headers
    cells =
      if headers != [] do
        cells ++ render_table_row(x, y, headers, attrs, _theme)
      else
        cells
      end

    # Render data rows
    cells =
      data
      |> Enum.with_index()
      |> Enum.reduce(cells, fn {row, index}, acc ->
        acc ++ render_table_row(x, y + index + 1, row, attrs, _theme)
      end)

    cells
  end

  defp render_table_row(x, y, row, _attrs, _theme) do
    row
    |> Enum.with_index()
    |> Enum.map(fn {cell, index} ->
      cell_text = to_string(cell)
      {x + index * 10, y, cell_text, :white, :black, []}
    end)
  end

  defp render_horizontal_line(x, y, width, char, style, _theme) do
    for i <- 1..(width - 2) do
      {x + i, y, char, style.fg, style.bg, []}
    end
  end

  defp render_vertical_line(x, y, height, char, style, _theme) do
    for i <- 1..(height - 2) do
      {x, y + i, char, style.fg, style.bg, []}
    end
  end
end
