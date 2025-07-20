defmodule Raxol.UI.Renderer do
  @moduledoc """
  UI Renderer for Raxol terminal applications.

  This module provides rendering capabilities for various UI elements
  including panels, boxes, text, and tables with theme support.
  """

  alias Raxol.UI.{CellManager, ElementRenderer, StyleProcessor, ThemeResolver}

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
      elements = CellManager.ensure_list(element_or_elements)

      # Get default theme if none provided
      default_theme = theme || ThemeResolver.get_default_theme()

      # Render each element and flatten results
      elements
      |> Enum.flat_map(fn element ->
        # Use element's theme if available, otherwise use default theme
        element_theme = ThemeResolver.resolve_element_theme_with_inheritance(element, default_theme)
        render_element(element, element_theme, %{})
      end)
      |> CellManager.filter_valid_cells()
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

  # --- Element Validation ---

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

  # --- Element Type Rendering ---

  defp render_visible_element(
         %{type: :panel, x: x, y: y, width: w, height: h} = panel_element,
         theme,
         parent_style
       ) do
    ElementRenderer.render_panel(x, y, w, h, panel_element, theme, parent_style)
  end

  defp render_visible_element(
         %{type: :box, x: x, y: y, width: w, height: h} = box_element,
         theme,
         parent_style
       ) do
    merged_style = StyleProcessor.flatten_merged_style(parent_style, box_element, theme)
    cells = ElementRenderer.render_box(x, y, w, h, merged_style, theme)
    CellManager.clip_cells_to_bounds(cells, Map.get(box_element, :clip_bounds))
  end

  defp render_visible_element(
         %{type: :text, text: text_content, x: x, y: y} = text_element,
         theme,
         parent_style
       ) do
    merged_style = StyleProcessor.flatten_merged_style(parent_style, text_element, theme)
    cells = ElementRenderer.render_text(x, y, text_content, merged_style, theme)
    CellManager.clip_cells_to_bounds(cells, Map.get(text_element, :clip_bounds))
  end

  defp render_visible_element(
         %{type: :table, x: x, y: y} = table_element,
         theme,
         parent_style
       ) do
    _merged_style = StyleProcessor.flatten_merged_style(parent_style, table_element, theme)

    # Extract table data from the element or attrs
    attrs = Map.get(table_element, :attrs, %{})
    headers = Map.get(table_element, :headers) || Map.get(attrs, :_headers, [])
    data = Map.get(table_element, :data) || Map.get(attrs, :_data, [])

    column_widths =
      Map.get(table_element, :column_widths) || Map.get(attrs, :_col_widths, [])

    # Calculate table width if not provided
    width = ElementRenderer.calculate_table_width(headers, data, column_widths)

    # Build attrs with table data and custom styles
    merged_attrs =
      ElementRenderer.build_table_attrs(table_element, headers, data, column_widths)

    cells = ElementRenderer.render_table(x, y, width, 0, merged_attrs, theme)
    CellManager.clip_cells_to_bounds(cells, Map.get(table_element, :clip_bounds))
  end

  defp render_visible_element(
         %{type: :table, x: x, y: y, width: w, height: h} = table_element,
         theme,
         parent_style
       ) do
    _merged_style = StyleProcessor.flatten_merged_style(parent_style, table_element, theme)

    # Extract table data from the element or attrs
    attrs = Map.get(table_element, :attrs, %{})
    headers = Map.get(table_element, :headers) || Map.get(attrs, :_headers, [])
    data = Map.get(table_element, :data) || Map.get(attrs, :_data, [])

    column_widths =
      Map.get(table_element, :column_widths) || Map.get(attrs, :_col_widths, [])

    # Build attrs with table data and custom styles
    merged_attrs =
      ElementRenderer.build_table_attrs(table_element, headers, data, column_widths)

    cells = ElementRenderer.render_table(x, y, w, h, merged_attrs, theme)
    CellManager.clip_cells_to_bounds(cells, Map.get(table_element, :clip_bounds))
  end
end
