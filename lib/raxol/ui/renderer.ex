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

  # Group all render_to_cells/2 functions together
  def render_to_cells(element, theme) when is_map(element) do
    render_element(element, theme)
  end

  def render_to_cells(element, theme) when is_binary(element) do
    render_text(0, 0, element, %{}, theme)
  end

  def render_to_cells([], _theme), do: []

  def render_to_cells(nil, _theme), do: []

  def render_to_cells(elements, theme) when is_list(elements) do
    Enum.flat_map(elements, &render_element(&1, theme))
  end

  # Clause for single element
  def render_element(element, theme) when is_map(element) do
    element =
      element
      |> Map.put_new(:style, %{})
      |> Map.put_new(:id, :test_id)
      |> Map.put_new(
        :position,
        {Map.get(element, :x, 0), Map.get(element, :y, 0)}
      )
      |> Map.put_new(:type, :unknown)
      |> Map.put_new(:attrs, %{})
      |> Map.put_new(:children, [])

    rendered_cells =
      case element do
        %{type: :text, text: text_content} = text_element
        when is_map_key(text_element, :type) ->
          x =
            Map.get(
              text_element,
              :x,
              elem(Map.get(text_element, :position, {0, 0}), 0)
            )

          y =
            Map.get(
              text_element,
              :y,
              elem(Map.get(text_element, :position, {0, 0}), 1)
            )

          attrs = Map.get(text_element, :style, %{})
          render_text(x, y, text_content, attrs, theme)

        %{type: :box} = box_element when is_map_key(box_element, :type) ->
          x =
            Map.get(
              box_element,
              :x,
              elem(Map.get(box_element, :position, {0, 0}), 0)
            )

          y =
            Map.get(
              box_element,
              :y,
              elem(Map.get(box_element, :position, {0, 0}), 1)
            )

          w = Map.get(box_element, :width, 1)
          h = Map.get(box_element, :height, 1)
          attrs = Map.get(box_element, :style, %{})
          render_box(x, y, w, h, attrs, theme)

        %{type: :panel} = panel_element when is_map_key(panel_element, :type) ->
          x =
            Map.get(
              panel_element,
              :x,
              elem(Map.get(panel_element, :position, {0, 0}), 0)
            )

          y =
            Map.get(
              panel_element,
              :y,
              elem(Map.get(panel_element, :position, {0, 0}), 1)
            )

          w = Map.get(panel_element, :width, 1)
          h = Map.get(panel_element, :height, 1)
          attrs = Map.get(panel_element, :style, %{})
          panel_box_cells = render_box(x, y, w, h, attrs, theme)
          children = Map.get(panel_element, :children, nil)

          children_cells =
            Enum.flat_map(children || [], &render_element(&1, theme))

          panel_box_cells ++ children_cells

        %{type: :table} = table_element when is_map_key(table_element, :type) ->
          x =
            Map.get(
              table_element,
              :x,
              elem(Map.get(table_element, :position, {0, 0}), 0)
            )

          y =
            Map.get(
              table_element,
              :y,
              elem(Map.get(table_element, :position, {0, 0}), 1)
            )

          width = Map.get(table_element, :width, 0)
          height = Map.get(table_element, :height, 0)
          attrs = Map.get(table_element, :attrs, %{})
          render_table(x, y, width, height, attrs, theme)

        _other ->
          Raxol.Core.Runtime.Log.warning(
            "[#{__MODULE__}] Unknown or unhandled element type for rendering: #{inspect(if is_map(element), do: Map.get(element, :type), else: inspect(element))} - Element: #{inspect(element)}"
          )

          []
      end

    # IO.inspect({rendered_cells, for_element_type: Map.get(element, :type)}, label: "RENDER_ELEMENT_OUTPUT")
    rendered_cells
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
      fg: Map.get(table_base_styles, :row_fg, @default_fg),
      bg: Map.get(table_base_styles, :row_bg, @default_bg)
    }

    alternate_data_style = %{
      fg: Map.get(table_base_styles, :alternate_row_fg, data_style.fg),
      bg: Map.get(table_base_styles, :alternate_row_bg, data_style.bg)
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
        base_sep_char = Map.get(table_base_styles, :header_separator_char, "─")
        # Or "-" if no border
        left_junction =
          Map.get(table_base_styles, :header_separator_left_junction, "├")

        # Or "-"
        mid_junction =
          Map.get(table_base_styles, :header_separator_mid_junction, "┼")

        # Or "-"
        _right_junction =
          Map.get(table_base_styles, :header_separator_right_junction, "┤")

        # Build the separator string respecting column widths
        _separator_parts =
          Enum.map_join(Enum.with_index(col_widths), fn {col_w, index} ->
            line = String.duplicate(base_sep_char, col_w)

            cond do
              # Single column case (no junctions, or special handling if width allows bookends)
              length(col_widths) == 1 ->
                line

              # First column
              index == 0 ->
                # Actually, should be line <> mid_junction if we think of it as col + separator
                line <> left_junction

              # Last column
              index == length(col_widths) - 1 ->
                # The mid_junction from previous column effectively serves as left junction for this one
                line

              # Middle columns
              true ->
                line <> mid_junction
            end
          end)

        # This logic above is a bit complex for cell-based rendering.
        # Simpler: render line segments and junctions as individual cells.
        separator_line_cells = []
        current_sep_x = x

        Enum.with_index(col_widths)
        |> Enum.reduce(separator_line_cells, fn {col_w, idx}, acc_cells ->
          # Draw line for the column width
          line_cells =
            for i <- 0..(col_w - 1) do
              {current_sep_x + i, current_y, base_sep_char, separator_style.fg,
               separator_style.bg, []}
            end

          _current_sep_x = current_sep_x + col_w

          # Draw junction if not the last column
          junction_cells =
            if idx < length(col_widths) - 1 do
              # Junction char needs to be determined based on theme & border style
              # For now, use mid_junction for space of 3: " X "
              # This assumes separator between columns takes 3 cells for " | " in render_table_row
              # This needs to be themed properly
              junction_char = mid_junction

              [
                {current_sep_x, current_y, " ", separator_style.fg,
                 separator_style.bg, []},
                {current_sep_x + 1, current_y, junction_char,
                 separator_style.fg, separator_style.bg, []},
                {current_sep_x + 2, current_y, " ", separator_style.fg,
                 separator_style.bg, []}
              ]
            else
              []
            end

          _current_sep_x =
            current_sep_x + if idx < length(col_widths) - 1, do: 3, else: 0

          acc_cells ++ line_cells ++ junction_cells
        end)

        # Ensure total length matches overall table width, adjust if necessary (truncation or padding)
        # The above logic should naturally fill up to the sum of col_widths + (num_cols - 1) * 3
        # This might not perfectly align with `width` if col_widths don't sum up correctly.
        # For now, we assume col_widths + separators sum to `width`.
        # If not, the table rendering logic in general has an issue.

        # The render_text approach is simpler if we can construct the exact string.
        # Let's try to build the string carefully.

        _constructed_sep_string =
          Enum.map_join(Enum.with_index(col_widths), fn {col_w, idx} ->
            line_segment = String.duplicate(base_sep_char, col_w)

            if idx < length(col_widths) - 1 do
              # Using mid_junction, assuming " | " from row rendering
              line_segment <> " " <> mid_junction <> " "
            else
              line_segment
            end
          end)

        # Truncate or pad to fit table_width
        # Ensure the final string is exactly `width` characters long.
        # The sum of col_widths and separators ( (length(col_widths) - 1) * 3 ) should be `width`.
        # If not, the `col_widths` were not calculated correctly by the layout engine.
        # We will trust `width` and `col_widths` are consistent.
        # final_sep_text = String.slice(constructed_sep_string, 0, width)
        # No, this isn't right, `render_text` will handle individual chars.
        # We should use the cell-based approach directly.

        # Reverting to a more direct cell generation for the separator:
        current_render_x = x

        final_separator_cells =
          Enum.flat_map(Enum.with_index(col_widths), fn {col_w, idx} ->
            # Segment for the column data
            segment_cells =
              for i <- 0..(col_w - 1) do
                {current_render_x + i, current_y, base_sep_char,
                 separator_style.fg, separator_style.bg, []}
              end

            _current_render_x = current_render_x + col_w

            # Separator/junction after the column (if not the last)
            junction_cells =
              if idx < length(col_widths) - 1 do
                # Default to | as per row rendering
                jc =
                  Map.get(table_base_styles, :header_column_separator_char, "|")

                # Allow themed junction fg
                js_fg =
                  Map.get(separator_style, :junction_fg, separator_style.fg)

                # Allow themed junction bg
                js_bg =
                  Map.get(separator_style, :junction_bg, separator_style.bg)

                # Mimic the " | " structure from render_table_row
                js = [
                  {current_render_x, current_y, " ", js_fg, js_bg, []},
                  {current_render_x + 1, current_y, jc, js_fg, js_bg, []},
                  {current_render_x + 2, current_y, " ", js_fg, js_bg, []}
                ]

                _current_render_x = current_render_x + 3
                js
              else
                []
              end

            segment_cells ++ junction_cells
          end)

        final_separator_cells
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
        current_style =
          if rem(index, 2) == 1 && Map.keys(alternate_data_style) != [:fg, :bg] do
            # Only use alternate if it's actually different from base data_style due to specific theme settings
            # (Map.keys check is a proxy, could be more robust by comparing values if defaults are same)
            # A more robust check: if alternate_data_style.fg != data_style.fg or alternate_data_style.bg != data_style.bg
            if alternate_data_style.fg != data_style.fg or
                 alternate_data_style.bg != data_style.bg do
              alternate_data_style
            else
              data_style
            end
          else
            data_style
          end

        render_table_row(
          x,
          row_y,
          row_data,
          col_widths,
          # Pass the determined style
          current_style,
          width,
          theme
          # No longer passing index explicitly here, style is pre-selected
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
         # Style is now passed directly (could be base or alternate)
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
          # Truncate or pad text to fit the column width
          # Content should be left-aligned within the column.
          display_text = String.slice(item_text, 0, col_width)
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
    theme_name = theme.name

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
        Map.has_key?(attrs, :fg) ->
          Map.get(attrs, :fg)

        Map.has_key?(component_styles, :fg) ->
          Map.get(component_styles, :fg)

        # Use ColorSystem for semantic lookup
        true ->
          Raxol.Core.ColorSystem.get(theme_name, :foreground) || @default_fg
      end

    # Determine bg color
    bg_color =
      cond do
        Map.has_key?(attrs, :bg) ->
          Map.get(attrs, :bg)

        Map.has_key?(component_styles, :bg) ->
          Map.get(component_styles, :bg)

        # Use ColorSystem for semantic lookup
        true ->
          Raxol.Core.ColorSystem.get(theme_name, :background) || @default_bg
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
