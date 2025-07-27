defmodule Raxol.UI.ElementRenderer do
  @moduledoc """
  Handles rendering of specific UI element types (box, text, table, panel).
  """

  alias Raxol.UI.{BorderRenderer, CellManager, StyleProcessor, ThemeResolver}

  @doc """
  Renders a box element.
  """
  def render_box(x, y, width, height, style, _theme) do
    {clip_x, clip_y, clip_width, clip_height} =
      CellManager.clip_coordinates(x, y, width, height)

    if clip_width == 0 or clip_height == 0 do
      []
    else
      # Check if borders are disabled
      border_enabled = Map.get(style, :border, true)

      if border_enabled do
        border_chars =
          BorderRenderer.get_border_chars(
            Map.get(style, :border_style, :single)
          )

        BorderRenderer.render_box_borders(
          clip_x,
          clip_y,
          clip_width,
          clip_height,
          border_chars,
          style
        )
      else
        # No borders - render empty box
        BorderRenderer.render_empty_box(
          clip_x,
          clip_y,
          clip_width,
          clip_height,
          style
        )
      end
    end
  end

  @doc """
  Renders a text element.
  """
  def render_text(x, y, text, style, _theme) do
    # Handle negative coordinates
    if x < 0 or y < 0 do
      []
    else
      # Resolve colors properly
      fg = Map.get(style, :fg) || Map.get(style, :foreground, :white)
      bg = Map.get(style, :bg) || Map.get(style, :background, :black)

      # Simple text rendering - one character per cell
      text
      |> String.graphemes()
      |> Enum.with_index()
      |> Enum.map(fn {char, index} ->
        {x + index, y, char, fg, bg, []}
      end)
    end
  end

  @doc """
  Renders a table element.
  """
  def render_table(x, y, _width, _height, attrs, theme) do
    headers = Map.get(attrs, :_headers, [])
    data = Map.get(attrs, :_data, [])
    col_widths = Map.get(attrs, :_col_widths, [])

    # Get table styles from theme
    table_styles = ThemeResolver.get_component_styles(:table, theme)

    # Use custom styles from attrs if present, else fall back to theme
    header_style =
      Map.get(attrs, :header_style, %{})
      |> Map.merge(Map.get(table_styles, :header, %{}))

    data_style =
      Map.get(attrs, :row_style, %{})
      |> Map.merge(Map.get(table_styles, :data, %{}))

    cells = []

    # Render headers
    cells =
      if headers != [] do
        cells ++ render_table_row(x, y, headers, col_widths, header_style)
      else
        cells
      end

    # Calculate starting y position for data rows
    data_start_y = if headers != [], do: y + 2, else: y

    # Render data rows
    cells =
      data
      |> Enum.with_index()
      |> Enum.reduce(cells, fn {row, index}, acc ->
        row_cells =
          render_table_row(x, data_start_y + index, row, col_widths, data_style)

        acc ++ row_cells
      end)

    cells
  end

  @doc """
  Renders a panel element with children.
  """
  def render_panel(x, y, width, height, panel_element, theme, parent_style) do
    merged_style =
      StyleProcessor.flatten_merged_style(parent_style, panel_element, theme)

    panel_box_cells = render_box(x, y, width, height, merged_style, theme)
    children = Map.get(panel_element, :children)

    # Check if clipping is enabled for this panel
    clip_enabled = Map.get(panel_element, :clip, false)

    clip_bounds =
      if clip_enabled, do: {x, y, x + width - 1, y + height - 1}, else: nil

    # Render children with clipping and style inheritance
    children_cells =
      render_panel_children(children, clip_bounds, theme, merged_style)

    # Merge cells so that children overwrite panel cells at the same coordinates
    all_cells = CellManager.merge_cells(panel_box_cells, children_cells)
    CellManager.clip_cells_to_bounds(all_cells, clip_bounds)
  end

  @doc """
  Calculates table width based on headers, data, and column widths.
  """
  def calculate_table_width(headers, data, column_widths) do
    # If column widths are provided, use their sum
    if column_widths != [] do
      Enum.sum(column_widths)
    else
      calculate_content_based_width(headers, data)
    end
  end

  @doc """
  Builds table attributes with data and styles.
  """
  def build_table_attrs(table_element, headers, data, column_widths) do
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

      # Render the child element recursively
      Raxol.UI.Renderer.render_element(child_with_clip, theme, merged_style)
    end)
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

  defp render_table_row(x, y, row, col_widths, style) do
    Enum.reduce(Enum.with_index(row), {[], x}, fn {cell, index}, {acc, cur_x} ->
      cell_cells =
        render_table_cell(cell, cur_x, y, Enum.at(col_widths, index, 5), style)

      {acc ++ cell_cells, cur_x + Enum.at(col_widths, index, 5)}
    end)
    |> elem(0)
  end

  defp render_table_cell(cell, x, y, _col_width, style) do
    cell_text = to_string(cell)
    cell_fg = Map.get(style, :foreground, Map.get(style, :fg, :white))
    cell_bg = Map.get(style, :background, Map.get(style, :bg, :black))

    String.graphemes(cell_text)
    |> Enum.with_index()
    |> Enum.map(fn {char, char_index} ->
      {x + char_index, y, char, cell_fg, cell_bg, []}
    end)
  end
end
