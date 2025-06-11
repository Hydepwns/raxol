defmodule Raxol.UI.Renderer do
  @moduledoc """
  Translates a positioned element tree into a flat list of renderable cells.

  Takes the output of the Layout Engine and converts UI primitives (text, boxes, etc.)
  into styled characters at specific coordinates.
  """

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
  def render_to_cells(elements, theme) when is_list(elements) do
    Enum.flat_map(elements, &render_element(&1, theme))
  end

  # Clause for single element
  def render_to_cells(element, theme) when is_map(element) do
    render_element(element, theme)
  end

  # --- Private Element Rendering Functions ---

  defp render_element(nil, _theme) do
    # If the element itself is nil, render nothing
    []
  end

  defp render_element(element, theme) when is_map(element) do
    # Dispatch based on element type found in the layout engine output
    case element do
      # Element type :text - expect :text, :x, :y. attrs is optional.
      %{type: :text, text: text_content, x: x, y: y} = text_element ->
        # Use element's style map as attrs
        attrs = Map.get(text_element, :style, %{})
        render_text(x, y, text_content, attrs, theme)

      # Element type :box - expect :x, :y, :w, :h. attrs is optional.
      %{type: :box, x: x, y: y, width: w, height: h} = box_element ->
        # Use element's style map as attrs
        attrs = Map.get(box_element, :style, %{})
        render_box(x, y, w, h, attrs, theme)

      # Element type :table
      %{type: :table, x: x, y: y} = table_element ->
        # Default width if not specified
        width = Map.get(table_element, :width, 80)
        # Default height if not specified
        height = Map.get(table_element, :height, 24)

        attrs = %{
          _headers: Map.get(table_element, :headers, []),
          _data: Map.get(table_element, :data, []),
          _col_widths: Map.get(table_element, :col_widths, []),
          _component_type: :table,
          # Pass style from element
          style: Map.get(table_element, :style, %{})
        }

        render_table(x, y, width, height, attrs, theme)

      # Match necessary keys for panel rendering. attrs is optional.
      %{type: :panel, x: x, y: y, width: w, height: h} = panel_element ->
        # Use element's style map as attrs for the panel's box
        attrs = Map.get(panel_element, :style, %{})
        # Render the panel's background/border as a box
        panel_box_cells =
          render_box(x, y, w, h, attrs, theme)

        # Render children
        children = Map.get(panel_element, :children)

        children_cells =
          Enum.flat_map(children || [], &render_element(&1, theme))

        # Render children on top of the panel box
        panel_box_cells ++ children_cells

      # TODO: Add cases for other element types (:button, :input, etc.)
      # These might be decomposed into :text and :box primitives by the layout engine,
      # or we might need to handle them directly here, applying component-specific styles.

      _other ->
        Raxol.Core.Runtime.Log.warning(
          "[#{__MODULE__}] Unknown or unhandled element type for rendering: #{inspect(Map.get(element, :type))} - Element: #{inspect(element)}"
        )

        []
    end
  end

  defp render_text(x, y, text, attrs, theme) when is_binary(text) do
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
    # Determine component type from attrs
    component_type =
      Map.get(attrs, :component_type) || Map.get(attrs, :original_type)

    # Resolve styles using component-specific theme styles
    {fg, bg, style_attrs} = resolve_styles(attrs, component_type, theme)

    # Get border style from component styles or attrs
    border_style =
      Map.get(attrs, :border) ||
        Map.get(theme.component_styles[component_type] || %{}, :border, :none)

    # Draw background first
    background_cells =
      if w > 0 and h > 0 do
        for cur_y <- y..(y + h - 1), cur_x <- x..(x + w - 1) do
          {cur_x, cur_y, " ", fg, bg, style_attrs}
        end
      else
        []
      end

    # Draw border if style is not :none and dimensions allow
    border_cells =
      if border_style != :none and w > 0 and h > 0 do
        border_chars = get_border_chars(border_style)

        # Draw corners
        corner_cells = [
          # Top-left
          {x, y, border_chars.top_left, fg, bg, style_attrs},
          # Top-right
          {x + w - 1, y, border_chars.top_right, fg, bg, style_attrs},
          # Bottom-left
          {x, y + h - 1, border_chars.bottom_left, fg, bg, style_attrs},
          # Bottom-right
          {x + w - 1, y + h - 1, border_chars.bottom_right, fg, bg, style_attrs}
        ]

        # Draw horizontal lines (if width > 1)
        horizontal_cells =
          if w > 1 do
            for cur_x <- (x + 1)..(x + w - 2) do
              [
                # Top line
                {cur_x, y, border_chars.horizontal, fg, bg, style_attrs},
                # Bottom line
                {cur_x, y + h - 1, border_chars.horizontal, fg, bg, style_attrs}
              ]
            end
            |> List.flatten()
          else
            []
          end

        # Draw vertical lines (if height > 1)
        vertical_cells =
          if h > 1 do
            for cur_y <- (y + 1)..(y + h - 2) do
              [
                # Left line
                {x, cur_y, border_chars.vertical, fg, bg, style_attrs},
                # Right line
                {x + w - 1, cur_y, border_chars.vertical, fg, bg, style_attrs}
              ]
            end
            |> List.flatten()
          else
            []
          end

        corner_cells ++ horizontal_cells ++ vertical_cells
      else
        []
      end

    # Combine background and border cells
    background_cells ++ border_cells
  end

  # --- Add Table Rendering Logic ---
  defp render_table(x, y, width, _height, attrs, theme) do
    headers = Map.get(attrs, :_headers, [])
    data = Map.get(attrs, :_data, [])
    col_widths = Map.get(attrs, :_col_widths, [])
    component_type = Map.get(attrs, :_component_type, :table)

    # Get base style for the table
    {_fg, _bg, _style_attrs} = resolve_styles(attrs, component_type, theme)

    # Get specific styles for header, separator, data rows from theme
    table_base_styles =
      Raxol.UI.Theming.Theme.get_component_style(theme, component_type)

    header_style = %{
      fg: Map.get(table_base_styles, :header_fg, :cyan),
      bg: Map.get(table_base_styles, :header_bg, :default)
      # Add other header-specific attributes if needed
    }

    separator_style = %{
      # Use border color for separator
      fg: Map.get(table_base_styles, :border, :white),
      # Use base table bg
      bg: Map.get(table_base_styles, :bg, :default)
      # Add other separator-specific attributes if needed
    }

    data_style = %{
      fg: Map.get(table_base_styles, :row_fg, :default),
      bg: Map.get(table_base_styles, :row_bg, :default)
      # TODO: Handle alternate_row_bg here or in render_table_row
    }

    # TODO: Alternate row styling?

    # Collect all cells here
    all_cells = []

    # --- Logging ---
    Raxol.Core.Runtime.Log.debug(
      "[Renderer.render_table] Rendering table at (#{x},#{y}) W=#{width}. Headers: #{inspect(headers)}, DataRows: #{length(data)}, ColWidths: #{inspect(col_widths)}"
    )

    # ---------------

    current_y = y

    # --- Render Headers ---
    header_cells =
      if headers != [] do
        render_table_row(
          x,
          current_y,
          headers,
          col_widths,
          header_style,
          width,
          theme
        )
      else
        []
      end

    all_cells = all_cells ++ header_cells
    current_y = if headers != [], do: current_y + 1, else: current_y

    # --- Render Separator ---
    separator_cells =
      if headers != [] do
        # Create a separator line using box drawing characters or simple dashes
        # Use col_widths to generate the line with appropriate separators
        # Default to simple line
        separator_char = Map.get(separator_style, :char, "─")
        # Simple full-width separator for now
        sep_text = String.duplicate(separator_char, width)
        render_text(x, current_y, sep_text, separator_style, theme)
        # TODO: Make separator respect column widths using junction characters?
      else
        []
      end

    all_cells = all_cells ++ separator_cells
    current_y = if headers != [], do: current_y + 1, else: current_y

    # --- Render Data Rows ---
    data_cells =
      Enum.flat_map(Enum.with_index(data), fn {row_data, index} ->
        row_y = current_y + index
        # Alternate styling could be applied here based on index
        render_table_row(
          x,
          row_y,
          row_data,
          col_widths,
          data_style,
          width,
          theme
        )
      end)

    all_cells = all_cells ++ data_cells

    all_cells
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

    # {current_x, cells}
    initial_acc = {start_x, []}

    # Use reduce_while to generate cells and handle early termination
    # Rename lambda vars to avoid shadowing warnings
    {_final_x, cells} =
      Enum.reduce_while(Enum.with_index(row_items), initial_acc, fn {item,
                                                                     col_index},
                                                                    {iter_x,
                                                                     iter_cells} ->
        col_width = Enum.at(col_widths, col_index, 0)
        item_text = to_string(item)

        # Check if adding this column exceeds max_width BEFORE processing
        # Separator width needs to be considered too
        is_last_col = col_index == length(row_items) - 1
        # +3 for " | "
        projected_width = if is_last_col, do: col_width, else: col_width + 3

        if iter_x + projected_width <= start_x + max_width do
          # Truncate or pad text
          content_width = max(0, col_width - 2)
          display_text = " " <> String.slice(item_text, 0, content_width)
          padded_text = String.pad_trailing(display_text, col_width)

          # Generate item cells
          item_cells =
            for {char, char_index} <-
                  Enum.with_index(String.graphemes(padded_text)) do
              {iter_x + char_index, y, char, row_fg, row_bg, row_attrs}
            end

          new_cells_acc = iter_cells ++ item_cells
          new_x = iter_x + col_width

          # Add separator if not the last column
          if !is_last_col do
            sep_x = new_x

            separator_cells = [
              {sep_x, y, " ", row_fg, row_bg, row_attrs},
              {sep_x + 1, y, "|", row_fg, row_bg, row_attrs},
              {sep_x + 2, y, " ", row_fg, row_bg, row_attrs}
            ]

            {:cont, {new_x + 3, new_cells_acc ++ separator_cells}}
          else
            {:cont, {new_x, new_cells_acc}}
          end
        else
          # Stop rendering this row
          {:halt, {iter_x, iter_cells}}
        end
      end)

    cells
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
    # Theme ID is needed for ColorSystem
    theme_id = theme.id

    # Fetch component styles from theme if component_type is known
    component_styles =
      if component_type do
        Map.get(theme.component_styles, component_type, %{})
      else
        %{}
      end

    # Determine fg color
    fg_color =
      cond do
        Map.has_key?(attrs, :fg) -> Map.get(attrs, :fg)
        Map.has_key?(component_styles, :fg) -> Map.get(component_styles, :fg)
        # Use ColorSystem for semantic lookup
        true -> Raxol.Core.ColorSystem.get(theme_id, :foreground) || @default_fg
      end

    # Determine bg color
    bg_color =
      cond do
        Map.has_key?(attrs, :bg) -> Map.get(attrs, :bg)
        Map.has_key?(component_styles, :bg) -> Map.get(component_styles, :bg)
        # Use ColorSystem for semantic lookup
        true -> Raxol.Core.ColorSystem.get(theme_id, :background) || @default_bg
      end

    # Determine style attributes (bold, underline, etc.)
    # Priority: explicit attrs -> component styles
    raw_explicit_style = Map.get(attrs, :style, [])

    explicit_style_attrs =
      if is_list(raw_explicit_style), do: raw_explicit_style, else: []

    raw_component_style = Map.get(component_styles, :style, [])

    component_style_attrs =
      if is_list(raw_component_style), do: raw_component_style, else: []

    # Merge: explicit attrs take precedence (simple list concatenation for now)
    # A proper merge might be needed depending on how styles are defined
    final_style_attrs =
      (explicit_style_attrs ++ component_style_attrs) |> Enum.uniq()

    {fg_color, bg_color, final_style_attrs}
  end

  # Clause to handle nil theme (fallback to defaults)
  defp resolve_styles(attrs, _component_type, nil) do
    fg_color = Map.get(attrs, :fg, @default_fg)
    bg_color = Map.get(attrs, :bg, @default_bg)
    style_attrs = Map.get(attrs, :style, []) |> Enum.uniq()
    {fg_color, bg_color, style_attrs}
  end

  # Clause to handle when attrs is a map with style attributes
  defp resolve_styles(%{fg: fg, bg: bg, style: style}, _component_type, theme) do
    resolve_styles(%{fg: fg, bg: bg, style: style}, nil, theme)
  end

  # Clause to handle when attrs is a map with just fg and bg
  defp resolve_styles(%{fg: fg, bg: bg}, _component_type, theme) do
    resolve_styles(%{fg: fg, bg: bg, style: []}, nil, theme)
  end

  # Clause to handle when attrs is a map with just style
  defp resolve_styles(%{style: style}, _component_type, theme) do
    resolve_styles(
      %{fg: @default_fg, bg: @default_bg, style: style},
      nil,
      theme
    )
  end
end
