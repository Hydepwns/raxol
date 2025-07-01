defmodule Raxol.UI.Renderer do
  @moduledoc """
  Translates a positioned element tree into a flat list of renderable cells.

  Takes the output of the Layout Engine and converts UI primitives (text, boxes, etc.)
  into styled characters at specific coordinates.
  """

  import Raxol.Guards
  alias Raxol.UI.Theming.Theme

  require Raxol.Core.Runtime.Log

  # Map representing an element with x, y, width, height, type, attrs, etc.
  @type positioned_element :: map()
  @type cell ::
          {x :: integer(), y :: integer(), char :: String.t(), fg :: term(),
           bg :: term(), attrs :: list(atom())}
  # The theme is expected to be %Raxol.UI.Theming.Theme{} but we use map() for flexibility
  @type theme :: map()

  # Define a default foreground and background for fallback
  # Or use theme.colors.foreground? Requires theme passed everywhere
  @default_fg :default
  # Or use theme.colors.background?
  @default_bg :default

  @doc """
  Renders a tree of positioned elements into a list of cells.

  Args:
    - `elements`: A list or single map representing positioned elements from the Layout Engine.
    - `theme`: The current theme map (expected %Theme{}).

  Returns:
    - `list(cell())`
  """
  @spec render_to_cells(
          positioned_element() | list(positioned_element()),
          theme()
        ) :: list(cell())
  # Accept theme struct or map, provide default theme if needed
  # Use the full module name for clarity and to avoid alias issues
  def render_to_cells(
        elements_or_element,
        theme \\ Raxol.UI.Theming.Theme.default_theme()
      )

  # Clause for list of elements
  def render_to_cells(elements, theme) when list?(elements) do
    Enum.flat_map(elements, &render_element(&1, theme))
  end

  # Clause for single element
  def render_to_cells(element, theme) when map?(element) do
    render_element(element, theme)
  end

  # --- Private Element Rendering Functions ---

  defp render_element(nil, _theme) do
    # If the element itself is nil, render nothing
    []
  end

  defp render_element(
         %{type: :text, text: text_content, x: x, y: y} = text_element,
         theme
       ) do
    attrs = Map.get(text_element, :style, %{})
    render_text(x, y, text_content, attrs, theme)
  end

  defp render_element(
         %{type: :box, x: x, y: y, width: w, height: h} = box_element,
         theme
       ) do
    attrs = Map.get(box_element, :style, %{})
    render_box(x, y, w, h, attrs, theme)
  end

  defp render_element(%{type: :table, x: x, y: y} = table_element, theme) do
    width = Map.get(table_element, :width, 80)
    height = Map.get(table_element, :height, 24)
    attrs = Map.get(table_element, :attrs, %{})

    headers =
      Map.get(table_element, :headers) ||
        Map.get(attrs, :headers) ||
        Map.get(attrs, :_headers, [])

    data =
      Map.get(table_element, :data) ||
        Map.get(attrs, :data) ||
        Map.get(attrs, :_data, [])

    col_widths =
      Map.get(table_element, :col_widths) ||
        Map.get(attrs, :col_widths) ||
        Map.get(attrs, :_col_widths, [])

    component_type = Map.get(attrs, :_component_type, :table)
    style = Map.get(attrs, :style, %{})

    table_attrs = %{
      _headers: headers,
      _data: data,
      _col_widths: col_widths,
      _component_type: component_type,
      style: style
    }

    render_table(x, y, width, height, table_attrs, theme)
  end

  defp render_element(
         %{type: :panel, x: x, y: y, width: w, height: h} = panel_element,
         theme
       ) do
    attrs = Map.get(panel_element, :style, %{})
    panel_box_cells = render_box(x, y, w, h, attrs, theme)
    children = Map.get(panel_element, :children)
    children_cells = Enum.flat_map(children || [], &render_element(&1, theme))
    panel_box_cells ++ children_cells
  end

  defp render_element(element, theme) when map?(element) do
    Raxol.Core.Runtime.Log.warning(
      "[#{__MODULE__}] Unknown or unhandled element type for rendering: #{inspect(Map.get(element, :type))} - Element: #{inspect(element)}"
    )

    []
  end

  defp render_text(x, y, text, attrs, theme) when binary?(text) do
    # Determine component type from attrs for specific styling
    component_type =
      Map.get(attrs, :component_type) || Map.get(attrs, :original_type)

    # Resolve styles using component-specific theme styles if available
    {fg, bg, style_attrs} = resolve_styles(attrs, component_type, theme)

    text
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.map(fn {char, index} ->
      {x + index, y, char, fg, bg, style_attrs}
    end)
  end

  defp render_text(_x, _y, text, _attrs, _theme) do
    Raxol.Core.Runtime.Log.warning(
      "[#{__MODULE__}] Invalid text content for rendering: #{inspect(text)}. Expected binary."
    )

    []
  end

  defp render_box(x, y, w, h, attrs, theme) do
    {fg, bg, style_attrs} = resolve_box_styles(attrs, theme)
    border_style = get_border_style(attrs, theme)

    background_cells = render_box_background(x, y, w, h, fg, bg, style_attrs)

    border_cells =
      render_box_border(x, y, w, h, border_style, fg, bg, style_attrs)

    background_cells ++ border_cells
  end

  defp resolve_box_styles(attrs, theme) do
    component_type =
      Map.get(attrs, :component_type) || Map.get(attrs, :original_type)

    resolve_styles(attrs, component_type, theme)
  end

  defp get_border_style(attrs, theme) do
    component_type =
      Map.get(attrs, :component_type) || Map.get(attrs, :original_type)

    Map.get(attrs, :border) ||
      Map.get(theme.component_styles[component_type] || %{}, :border, :none)
  end

  defp render_box_background(x, y, w, h, fg, bg, style_attrs) do
    if w > 0 and h > 0 do
      for cur_y <- y..(y + h - 1), cur_x <- x..(x + w - 1) do
        {cur_x, cur_y, " ", fg, bg, style_attrs}
      end
    else
      []
    end
  end

  defp render_box_border(x, y, w, h, border_style, fg, bg, style_attrs) do
    if border_style != :none and w > 0 and h > 0 do
      border_chars = get_border_chars(border_style)

      corner_cells =
        render_box_corners(x, y, w, h, border_chars, fg, bg, style_attrs)

      horizontal_cells =
        render_box_horizontal_lines(
          x,
          y,
          w,
          h,
          border_chars,
          fg,
          bg,
          style_attrs
        )

      vertical_cells =
        render_box_vertical_lines(x, y, w, h, border_chars, fg, bg, style_attrs)

      corner_cells ++ horizontal_cells ++ vertical_cells
    else
      []
    end
  end

  defp render_box_corners(x, y, w, h, border_chars, fg, bg, style_attrs) do
    [
      {x, y, border_chars.top_left, fg, bg, style_attrs},
      {x + w - 1, y, border_chars.top_right, fg, bg, style_attrs},
      {x, y + h - 1, border_chars.bottom_left, fg, bg, style_attrs},
      {x + w - 1, y + h - 1, border_chars.bottom_right, fg, bg, style_attrs}
    ]
  end

  defp render_box_horizontal_lines(
         x,
         y,
         w,
         h,
         border_chars,
         fg,
         bg,
         style_attrs
       ) do
    if w > 1 do
      for cur_x <- (x + 1)..(x + w - 2) do
        [
          {cur_x, y, border_chars.horizontal, fg, bg, style_attrs},
          {cur_x, y + h - 1, border_chars.horizontal, fg, bg, style_attrs}
        ]
      end
      |> List.flatten()
    else
      []
    end
  end

  defp render_box_vertical_lines(x, y, w, h, border_chars, fg, bg, style_attrs) do
    if h > 1 do
      for cur_y <- (y + 1)..(y + h - 2) do
        [
          {x, cur_y, border_chars.vertical, fg, bg, style_attrs},
          {x + w - 1, cur_y, border_chars.vertical, fg, bg, style_attrs}
        ]
      end
      |> List.flatten()
    else
      []
    end
  end

  # --- Add Table Rendering Logic ---
  defp render_table(x, y, width, _height, attrs, theme) do
    table_data = extract_table_data(attrs)
    table_styles = build_table_styles(attrs, theme)

    render_table_content(x, y, width, table_data, table_styles, theme)
  end

  defp extract_table_data(attrs) do
    %{
      headers: Map.get(attrs, :_headers, []),
      data: Map.get(attrs, :_data, []),
      col_widths: Map.get(attrs, :_col_widths, []),
      component_type: Map.get(attrs, :_component_type, :table)
    }
  end

  defp build_table_styles(attrs, theme) do
    component_type = Map.get(attrs, :_component_type, :table)

    table_base_styles =
      Raxol.UI.Theming.Theme.get_component_style(theme, component_type)

    %{
      header: %{
        fg: Map.get(table_base_styles, :header_fg, :cyan),
        bg: Map.get(table_base_styles, :header_bg, :default)
      },
      separator: %{
        fg: Map.get(table_base_styles, :border, :white),
        bg: Map.get(table_base_styles, :bg, :default)
      },
      data: %{
        fg: Map.get(table_base_styles, :row_fg, :default),
        bg: Map.get(table_base_styles, :row_bg, :default)
      }
    }
  end

  defp render_table_content(x, y, width, table_data, table_styles, theme) do
    current_y = y
    all_cells = []

    # Render headers
    {header_cells, current_y} =
      render_table_headers(x, current_y, table_data, table_styles, width, theme)

    all_cells = all_cells ++ header_cells

    # Render separator
    {separator_cells, current_y} =
      render_table_separator(
        x,
        current_y,
        table_data,
        table_styles,
        width,
        theme
      )

    all_cells = all_cells ++ separator_cells

    # Render data rows
    data_cells =
      render_table_data_rows(
        x,
        current_y,
        table_data,
        table_styles,
        width,
        theme
      )

    all_cells = all_cells ++ data_cells

    all_cells
  end

  defp render_table_headers(
         x,
         y,
         %{headers: headers, col_widths: col_widths},
         table_styles,
         width,
         theme
       ) do
    if headers != [] do
      cells =
        render_table_row(
          x,
          y,
          headers,
          col_widths,
          table_styles.header,
          width,
          theme
        )

      {cells, y + 1}
    else
      {[], y}
    end
  end

  defp render_table_separator(
         x,
         y,
         %{headers: headers},
         table_styles,
         width,
         theme
       ) do
    if headers != [] do
      separator_char = Map.get(table_styles.separator, :char, "─")
      sep_text = String.duplicate(separator_char, width)
      cells = render_text(x, y, sep_text, table_styles.separator, theme)
      {cells, y + 1}
    else
      {[], y}
    end
  end

  defp render_table_data_rows(
         x,
         y,
         %{data: data, col_widths: col_widths},
         table_styles,
         width,
         theme
       ) do
    Enum.flat_map(Enum.with_index(data), fn {row_data, index} ->
      row_y = y + index

      render_table_row(
        x,
        row_y,
        row_data,
        col_widths,
        table_styles.data,
        width,
        theme
      )
    end)
  end

  # Helper to render a single row (header or data)
  defp render_table_row(
         start_x,
         y,
         row_items,
         col_widths,
         style,
         max_width,
         theme
       ) do
    {row_fg, row_bg, row_attrs} = resolve_styles(style, nil, theme)

    render_table_row_cells(
      start_x,
      y,
      row_items,
      col_widths,
      row_fg,
      row_bg,
      row_attrs,
      max_width
    )
  end

  defp render_table_row_cells(
         start_x,
         y,
         row_items,
         col_widths,
         fg,
         bg,
         attrs,
         max_width
       ) do
    context = %{
      start_x: start_x,
      y: y,
      col_widths: col_widths,
      fg: fg,
      bg: bg,
      attrs: attrs,
      max_width: max_width,
      row_items: row_items
    }

    Enum.reduce_while(Enum.with_index(row_items), {start_x, []}, fn {item,
                                                                     col_index},
                                                                    {x, cells} ->
      case process_table_column(item, col_index, x, context) do
        {:continue, new_x, new_cells} -> {:cont, {new_x, cells ++ new_cells}}
        {:stop, final_cells} -> {:halt, {x, cells ++ final_cells}}
      end
    end)
    |> elem(1)
  end

  defp process_table_column(item, col_index, x, context) do
    col_width = Enum.at(context.col_widths, col_index, 0)
    is_last_col = col_index == length(context.row_items) - 1
    projected_width = if is_last_col, do: col_width, else: col_width + 3

    if x + projected_width <= context.max_width do
      item_cells =
        render_table_cell(
          x,
          context.y,
          item,
          col_width,
          context.fg,
          context.bg,
          context.attrs
        )

      new_x = x + col_width

      if is_last_col do
        {:continue, new_x, item_cells}
      else
        separator_cells =
          render_table_separator(
            new_x,
            context.y,
            context.fg,
            context.bg,
            context.attrs
          )

        {:continue, new_x + 3, item_cells ++ separator_cells}
      end
    else
      {:stop, []}
    end
  end

  defp render_table_cell(x, y, item, col_width, fg, bg, attrs) do
    item_text = to_string(item)
    content_width = max(0, col_width - 2)
    display_text = " " <> String.slice(item_text, 0, content_width)
    padded_text = String.pad_trailing(display_text, col_width)

    for {char, index} <- Enum.with_index(String.graphemes(padded_text)) do
      {x + index, y, char, fg, bg, attrs}
    end
  end

  defp render_table_separator(x, y, fg, bg, attrs) do
    [
      {x, y, " ", fg, bg, attrs},
      {x + 1, y, "|", fg, bg, attrs},
      {x + 2, y, " ", fg, bg, attrs}
    ]
  end

  # Helper to get border characters based on style
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

  defp get_component_styles(component_type, theme) do
    if component_type do
      Map.get(theme.component_styles, component_type, %{})
    else
      %{}
    end
  end

  defp resolve_fg_color(attrs, component_styles, theme) do
    cond do
      Map.has_key?(attrs, :fg) -> Map.get(attrs, :fg)
      Map.has_key?(component_styles, :fg) -> Map.get(component_styles, :fg)
      true -> Raxol.Core.ColorSystem.get(theme.id, :foreground) || @default_fg
    end
  end

  defp resolve_bg_color(attrs, component_styles, theme) do
    cond do
      Map.has_key?(attrs, :bg) -> Map.get(attrs, :bg)
      Map.has_key?(component_styles, :bg) -> Map.get(component_styles, :bg)
      true -> Raxol.Core.ColorSystem.get(theme.id, :background) || @default_bg
    end
  end

  defp resolve_style_attrs(attrs, component_styles) do
    explicit_attrs = Map.get(attrs, :style, []) |> ensure_list()
    component_attrs = Map.get(component_styles, :style, []) |> ensure_list()
    (explicit_attrs ++ component_attrs) |> Enum.uniq()
  end

  defp ensure_list(value) when is_list(value), do: value
  defp ensure_list(_), do: []

  # Clause to handle nil theme (fallback to defaults)
  defp resolve_styles(attrs, _component_type, nil) when map?(attrs) do
    fg_color = Map.get(attrs, :fg, @default_fg)
    bg_color = Map.get(attrs, :bg, @default_bg)
    style_attrs = Map.get(attrs, :style, []) |> Enum.uniq()
    {fg_color, bg_color, style_attrs}
  end

  # Catch-all clause for other cases
  defp resolve_styles(attrs, _component_type, _theme) when map?(attrs) do
    fg_color = Map.get(attrs, :fg, @default_fg)
    bg_color = Map.get(attrs, :bg, @default_bg)
    style_attrs = Map.get(attrs, :style, []) |> Enum.uniq()
    {fg_color, bg_color, style_attrs}
  end
end
