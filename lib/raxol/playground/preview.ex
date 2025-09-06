defmodule Raxol.Playground.Preview do
  @moduledoc """
  Live preview generation for Raxol components.

  This module handles rendering components with their current props and state,
  generating terminal output that shows how the component will appear.
  """

  @doc """
  Generates a preview of a component with given props and state.
  """
  def generate(component, props \\ %{}, state \\ %{}, opts \\ []) do
    theme = Keyword.get(opts, :theme, :default)
    _force_refresh = Keyword.get(opts, :force_refresh, false)

    # Apply theme
    themed_props = apply_theme(props, theme)

    # Generate preview content safely
    case render_component(component, themed_props, state) do
      {:ok, content} -> content
      {:error, error} -> render_error(component, error)
    end
  end

  defp render_component(component, themed_props, state) do
    Raxol.Core.ErrorHandling.safe_call(fn ->
      case component.module do
        # Text Components
        Raxol.UI.Text ->
          render_text(themed_props)

        Raxol.UI.Heading ->
          render_heading(themed_props)

        Raxol.UI.Label ->
          render_label(themed_props)

        # Input Components
        Raxol.UI.TextInput ->
          render_text_input(themed_props, state)

        Raxol.UI.TextArea ->
          render_text_area(themed_props, state)

        Raxol.UI.Select ->
          render_select(themed_props, state)

        # Interactive Components
        Raxol.UI.Button ->
          render_button(themed_props)

        Raxol.UI.Checkbox ->
          render_checkbox(themed_props, state)

        Raxol.UI.RadioGroup ->
          render_radio_group(themed_props, state)

        Raxol.UI.Toggle ->
          render_toggle(themed_props, state)

        # Layout Components
        Raxol.UI.Box ->
          render_box(themed_props)

        Raxol.UI.Flex ->
          render_flex(themed_props)

        Raxol.UI.Grid ->
          render_grid(themed_props)

        Raxol.UI.Tabs ->
          render_tabs(themed_props, state)

        # Data Display Components
        Raxol.UI.Table ->
          render_table(themed_props)

        Raxol.UI.List ->
          render_list(themed_props)

        Raxol.UI.ProgressBar ->
          render_progress_bar(themed_props)

        Raxol.UI.Spinner ->
          render_spinner(themed_props)

        # Special Components
        Raxol.UI.Modal ->
          render_modal(themed_props)

        Raxol.UI.Tooltip ->
          render_tooltip(themed_props)

        _ ->
          render_generic(component, themed_props, state)
      end
    end)
  end

  # Text Component Renderers

  defp render_text(props) do
    content = Map.get(props, :content, "")
    style = Map.get(props, :style, %{})

    apply_text_styles(content, style)
  end

  defp render_heading(props) do
    content = Map.get(props, :content, "")
    level = Map.get(props, :level, 1)

    prefix =
      case level do
        1 -> "# "
        2 -> "## "
        3 -> "### "
        _ -> "#### "
      end

    styled_content = "#{IO.ANSI.bright()}#{prefix}#{content}#{IO.ANSI.reset()}"

    add_underline_if_needed(styled_content, level, content, prefix)
  end

  defp render_label(props) do
    text = Map.get(props, :text, "")
    required = Map.get(props, :required, false)

    label_text = format_required_label(text, required)

    "#{IO.ANSI.bright()}#{label_text}#{IO.ANSI.reset()}"
  end

  # Input Component Renderers

  defp render_text_input(props, state) do
    value = Map.get(state, :value, Map.get(props, :value, ""))
    placeholder = Map.get(props, :placeholder, "")
    width = Map.get(props, :width, 30)
    disabled = Map.get(props, :disabled, false)
    cursor_pos = Map.get(state, :cursor_position, String.length(value))

    display_text =
      format_input_display(value, placeholder, cursor_pos, disabled)

    padding = max(0, width - String.length(value))

    border_style = get_border_style(disabled)

    """
    #{border_style}┌#{"─" |> String.duplicate(width + 2)}┐#{IO.ANSI.reset()}
    #{border_style}│ #{display_text}#{String.duplicate(" ", padding)} │#{IO.ANSI.reset()}
    #{border_style}└#{"─" |> String.duplicate(width + 2)}┘#{IO.ANSI.reset()}
    """
  end

  defp render_text_area(props, state) do
    value = Map.get(state, :value, Map.get(props, :value, ""))
    placeholder = Map.get(props, :placeholder, "")
    rows = Map.get(props, :rows, 5)
    cols = Map.get(props, :cols, 40)

    lines = format_text_area_lines(value, placeholder)

    # Pad lines to fill rows
    padded_lines = lines ++ List.duplicate("", max(0, rows - length(lines)))

    top_border = "┌" <> String.duplicate("─", cols + 2) <> "┐"
    bottom_border = "└" <> String.duplicate("─", cols + 2) <> "┘"

    content_lines =
      Enum.map(padded_lines, fn line ->
        trimmed = String.slice(line, 0, cols)
        padding = String.duplicate(" ", cols - String.length(trimmed))
        "│ #{trimmed}#{padding} │"
      end)

    ([top_border] ++ content_lines ++ [bottom_border])
    |> Enum.join("\n")
  end

  defp render_select(props, state) do
    options = Map.get(props, :options, [])
    selected = Map.get(state, :selected, Map.get(props, :selected))
    placeholder = Map.get(props, :placeholder, "Choose an option")
    is_open = Map.get(state, :is_open, false)

    display_value = selected || placeholder
    arrow = get_select_arrow(is_open)

    main_line = "│ #{display_value} #{arrow} │"
    width = String.length(main_line) - 4

    top_border = "┌" <> String.duplicate("─", width + 2) <> "┐"
    bottom_border = "└" <> String.duplicate("─", width + 2) <> "┘"

    result = [top_border, main_line, bottom_border]

    append_option_lines_if_open(
      result,
      is_open,
      options,
      selected,
      width,
      bottom_border
    )
    |> Enum.join("\n")
  end

  # Interactive Component Renderers

  defp render_button(props) do
    label = Map.get(props, :label, "Button")
    variant = Map.get(props, :variant, :primary)
    disabled = Map.get(props, :disabled, false)

    {bg_color, text_color} =
      case {variant, disabled} do
        {_, true} -> {IO.ANSI.light_black(), IO.ANSI.black()}
        {:primary, _} -> {IO.ANSI.blue_background(), IO.ANSI.white()}
        {:secondary, _} -> {IO.ANSI.white_background(), IO.ANSI.black()}
        {:danger, _} -> {IO.ANSI.red_background(), IO.ANSI.white()}
        _ -> {IO.ANSI.cyan_background(), IO.ANSI.white()}
      end

    "#{bg_color}#{text_color} #{label} #{IO.ANSI.reset()}"
  end

  defp render_checkbox(props, state) do
    label = Map.get(props, :label, "")
    checked = Map.get(state, :checked, Map.get(props, :checked, false))
    disabled = Map.get(props, :disabled, false)

    checkbox = format_checkbox_display(checked, disabled)

    label_style = style_disabled_label(label, disabled)

    "#{checkbox} #{label_style}"
  end

  defp render_radio_group(props, state) do
    options = Map.get(props, :options, [])
    selected = Map.get(state, :selected, Map.get(props, :selected))

    Enum.map(options, fn option ->
      radio = format_radio_icon(option, selected)

      "#{radio} #{option}"
    end)
    |> Enum.join("\n")
  end

  defp render_toggle(props, state) do
    label = Map.get(props, :label, "")
    enabled = Map.get(state, :enabled, Map.get(props, :enabled, false))

    switch = format_toggle_switch(enabled)

    "#{label} #{switch}"
  end

  # Layout Component Renderers

  defp render_box(props) do
    title = Map.get(props, :title)
    border = Map.get(props, :border, :single)
    _padding = Map.get(props, :padding, 1)
    width = Map.get(props, :width, 30)
    height = Map.get(props, :height, 10)

    {top_left, top_right, bottom_left, bottom_right, horizontal, vertical} =
      case border do
        :single -> {"┌", "┐", "└", "┘", "─", "│"}
        :double -> {"╔", "╗", "╚", "╝", "═", "║"}
        :rounded -> {"╭", "╮", "╰", "╯", "─", "│"}
        :thick -> {"┏", "┓", "┗", "┛", "━", "┃"}
        _ -> {"┌", "┐", "└", "┘", "─", "│"}
      end

    content_width = width - 2

    top_border =
      create_box_top_border(
        title,
        content_width,
        top_left,
        top_right,
        horizontal
      )

    empty_line = "#{vertical}#{String.duplicate(" ", content_width)}#{vertical}"
    content_lines = List.duplicate(empty_line, height - 2)

    bottom_border =
      "#{bottom_left}#{String.duplicate(horizontal, content_width)}#{bottom_right}"

    ([top_border] ++ content_lines ++ [bottom_border])
    |> Enum.join("\n")
  end

  defp render_flex(props) do
    direction = Map.get(props, :direction, :horizontal)
    gap = Map.get(props, :gap, 1)

    placeholder_items = ["Item 1", "Item 2", "Item 3"]

    join_flex_items(placeholder_items, direction, gap)
  end

  defp render_grid(props) do
    columns = Map.get(props, :columns, 3)
    rows = Map.get(props, :rows, 2)
    gap = Map.get(props, :gap, 1)

    total_items = calculate_total_items(rows, columns)

    items = for i <- 1..total_items, do: "Item #{i}"

    items
    |> Enum.chunk_every(columns)
    |> Enum.map(&Enum.join(&1, String.duplicate(" ", gap * 2)))
    |> Enum.join(String.duplicate("\n", gap))
  end

  defp render_tabs(props, state) do
    tabs = Map.get(props, :tabs, [])
    active_tab = Map.get(state, :active_tab, Map.get(props, :active_tab))

    tab_line =
      Enum.map(tabs, fn tab ->
        format_tab_label(tab, active_tab)
      end)
      |> Enum.join(" | ")

    separator = String.duplicate("─", String.length(tab_line))

    "#{tab_line}\n#{separator}\n\nContent for #{active_tab || "selected tab"}"
  end

  # Data Display Component Renderers

  defp render_table(props) do
    headers = Map.get(props, :headers, [])
    rows = Map.get(props, :rows, [])
    border = Map.get(props, :border, true)

    case border do
      false ->
        # Simple table without borders
        header_line = Enum.join(headers, " | ")
        separator = String.duplicate("-", String.length(header_line))
        row_lines = Enum.map(rows, &Enum.join(&1, " | "))

        ([header_line, separator] ++ row_lines)
        |> Enum.join("\n")

      true ->
        # Table with borders
        col_widths = calculate_column_widths(headers, rows)

        top_border = create_table_border(col_widths, "┌", "┬", "┐", "─")
        header_separator = create_table_border(col_widths, "├", "┼", "┤", "─")
        bottom_border = create_table_border(col_widths, "└", "┴", "┘", "─")

        header_line = create_table_row(headers, col_widths)
        row_lines = Enum.map(rows, &create_table_row(&1, col_widths))

        ([top_border, header_line, header_separator] ++
           row_lines ++ [bottom_border])
        |> Enum.join("\n")
    end
  end

  defp render_list(props) do
    items = Map.get(props, :items, [])
    ordered = Map.get(props, :ordered, false)
    marker = Map.get(props, :marker, "•")

    case ordered do
      true ->
        items
        |> Enum.with_index(1)
        |> Enum.map(fn {item, index} -> "#{index}. #{item}" end)
        |> Enum.join("\n")

      false ->
        items
        |> Enum.map(&"#{marker} #{&1}")
        |> Enum.join("\n")
    end
  end

  defp render_progress_bar(props) do
    value = Map.get(props, :value, 0)
    max_value = Map.get(props, :max, 100)
    width = Map.get(props, :width, 30)
    show_percentage = Map.get(props, :show_percentage, true)

    percentage = (value / max_value * 100) |> round()
    filled_width = (value / max_value * width) |> round()
    empty_width = width - filled_width

    filled_bar = String.duplicate("█", filled_width)
    empty_bar = String.duplicate("░", empty_width)

    bar =
      "#{IO.ANSI.green()}#{filled_bar}#{IO.ANSI.light_black()}#{empty_bar}#{IO.ANSI.reset()}"

    format_progress_bar_display(bar, percentage, show_percentage)
  end

  defp render_spinner(props) do
    text = Map.get(props, :text, "Loading...")
    style = Map.get(props, :style, :dots)

    spinner =
      case style do
        :dots -> "●○○"
        :line -> "│"
        :circle -> "◐"
        _ -> "..."
      end

    "#{spinner} #{text}"
  end

  # Special Component Renderers

  defp render_modal(props) do
    title = Map.get(props, :title, "Modal")
    visible = Map.get(props, :visible, true)
    width = Map.get(props, :width, 40)
    height = Map.get(props, :height, 20)

    case visible do
      false ->
        "(Modal is hidden)"

      true ->
        # Create modal overlay effect
        _overlay = String.duplicate("▓", width + 4)

        top_border = "╔" <> String.duplicate("═", width) <> "╗"

        title_line =
          "║ #{title}#{String.duplicate(" ", width - String.length(title) - 1)} ║"

        separator = "╠" <> String.duplicate("═", width) <> "╣"

        content_lines =
          for _ <- 1..(height - 4) do
            "║#{String.duplicate(" ", width)}║"
          end

        bottom_border = "╚" <> String.duplicate("═", width) <> "╝"

        modal_lines =
          [top_border, title_line, separator] ++
            content_lines ++ [bottom_border]

        # Add shadow effect
        modal_with_shadow =
          Enum.map(modal_lines, fn line ->
            "#{line}#{IO.ANSI.light_black()}▓#{IO.ANSI.reset()}"
          end)

        shadow_line =
          "#{IO.ANSI.light_black()}#{String.duplicate("▓", width + 2)}#{IO.ANSI.reset()}"

        (modal_with_shadow ++ [shadow_line])
        |> Enum.join("\n")
    end
  end

  defp render_tooltip(props) do
    text = Map.get(props, :text, "Tooltip")
    position = Map.get(props, :position, :top)
    visible = Map.get(props, :visible, true)

    case visible do
      false ->
        ""

      true ->
        bubble =
          "#{IO.ANSI.black_background()}#{IO.ANSI.white()} #{text} #{IO.ANSI.reset()}"

        format_tooltip_position(bubble, position)
    end
  end

  # Helper Functions

  defp render_generic(component, props, state) do
    """
    #{IO.ANSI.bright()}#{component.name}#{IO.ANSI.reset()}

    Props: #{inspect(props, pretty: true)}
    State: #{inspect(state, pretty: true)}

    (Generic renderer - component-specific rendering not implemented)
    """
  end

  defp render_error(component, error) do
    """
    #{IO.ANSI.red()}Error rendering #{component.name}:#{IO.ANSI.reset()}
    #{Exception.message(error)}

    #{IO.ANSI.light_black()}(stacktrace not available in preview)#{IO.ANSI.reset()}
    """
  end

  defp apply_theme(props, theme) do
    # Apply theme-specific styles
    case theme do
      :dark ->
        props
        |> Map.put_new(:background, :black)
        |> Map.put_new(:color, :white)

      :light ->
        props
        |> Map.put_new(:background, :white)
        |> Map.put_new(:color, :black)

      _ ->
        props
    end
  end

  defp apply_text_styles(content, style) do
    content
    |> apply_color(Map.get(style, :color))
    |> apply_bold(Map.get(style, :bold))
    |> apply_italic(Map.get(style, :italic))
    |> apply_underline(Map.get(style, :underline))
  end

  defp apply_color(content, nil), do: content

  defp apply_color(content, :red),
    do: "#{IO.ANSI.red()}#{content}#{IO.ANSI.reset()}"

  defp apply_color(content, :green),
    do: "#{IO.ANSI.green()}#{content}#{IO.ANSI.reset()}"

  defp apply_color(content, :blue),
    do: "#{IO.ANSI.blue()}#{content}#{IO.ANSI.reset()}"

  defp apply_color(content, :yellow),
    do: "#{IO.ANSI.yellow()}#{content}#{IO.ANSI.reset()}"

  defp apply_color(content, :cyan),
    do: "#{IO.ANSI.cyan()}#{content}#{IO.ANSI.reset()}"

  defp apply_color(content, :magenta),
    do: "#{IO.ANSI.magenta()}#{content}#{IO.ANSI.reset()}"

  defp apply_color(content, _), do: content

  defp apply_bold(content, true),
    do: "#{IO.ANSI.bright()}#{content}#{IO.ANSI.reset()}"

  defp apply_bold(content, _), do: content

  defp apply_italic(content, true),
    do: "#{IO.ANSI.italic()}#{content}#{IO.ANSI.reset()}"

  defp apply_italic(content, _), do: content

  defp apply_underline(content, true),
    do: "#{IO.ANSI.underline()}#{content}#{IO.ANSI.reset()}"

  defp apply_underline(content, _), do: content

  defp calculate_column_widths(headers, rows) do
    all_rows = [headers | rows]
    max_cols = Enum.max(Enum.map(all_rows, &length/1))

    for col <- 0..(max_cols - 1) do
      all_rows
      |> Enum.map(&Enum.at(&1, col, ""))
      |> Enum.map(&String.length/1)
      |> Enum.max()
    end
  end

  defp create_table_border(col_widths, left, middle, right, line) do
    borders = Enum.map(col_widths, &String.duplicate(line, &1 + 2))
    "#{left}#{Enum.join(borders, middle)}#{right}"
  end

  defp create_table_row(cells, col_widths) do
    padded_cells =
      Enum.zip(cells, col_widths)
      |> Enum.map(fn {cell, width} ->
        cell_str = to_string(cell)
        padding = String.duplicate(" ", width - String.length(cell_str))
        " #{cell_str}#{padding} "
      end)

    "│#{Enum.join(padded_cells, "│")}│"
  end

  # Missing helper functions for input components

  defp get_border_style(true), do: IO.ANSI.light_black()
  defp get_border_style(false), do: ""

  defp format_input_display(value, placeholder, cursor_pos, disabled) do
    display_text =
      case value do
        "" -> placeholder
        text -> text
      end

    format_input_text(display_text, value, cursor_pos, disabled)
  end

  defp format_text_area_lines(value, placeholder) do
    split_textarea_content(value, placeholder)
  end

  defp append_option_lines_if_open(
         result,
         false,
         _options,
         _selected,
         _width,
         _bottom_border
       ),
       do: result

  defp append_option_lines_if_open(
         result,
         true,
         options,
         selected,
         width,
         _bottom_border
       ) do
    option_lines =
      Enum.map(options, fn option ->
        prefix = case option == selected do
          true -> "✓"
          false -> " "
        end
        option_str = " #{prefix} #{option}"
        padding = String.duplicate(" ", width - String.length(option_str) + 1)
        "│#{option_str}#{padding}│"
      end)

    # Remove the original bottom border and add options with new bottom border
    result_without_bottom = List.delete_at(result, -1)
    new_bottom = "└" <> String.duplicate("─", width + 2) <> "┘"

    result_without_bottom ++ option_lines ++ [new_bottom]
  end

  defp format_radio_icon(option, selected) do
    format_radio_selected(option == selected)
  end

  defp format_radio_selected(true), do: "#{IO.ANSI.green()}◉#{IO.ANSI.reset()}"
  defp format_radio_selected(false), do: "○"

  defp format_required_label(text, required) do
    add_required_marker(text, required)
  end

  defp add_underline_if_needed(styled_content, level, content, _prefix)
       when level <= 2 do
    underline_char = select_underline_char(level)
    underline = String.duplicate(underline_char, String.length(content))
    "#{styled_content}\n#{underline}"
  end

  defp add_underline_if_needed(styled_content, _level, _content, _prefix),
    do: styled_content

  # Helper functions using pattern matching instead of if statements

  defp select_underline_char(1), do: "═"
  defp select_underline_char(_), do: "─"

  defp get_select_arrow(true), do: "▲"
  defp get_select_arrow(false), do: "▼"

  defp join_flex_items(items, :horizontal, gap),
    do: Enum.join(items, String.duplicate(" ", gap))

  defp join_flex_items(items, _direction, gap),
    do: Enum.join(items, String.duplicate("\n", gap))

  defp calculate_total_items(nil, _columns), do: 6
  defp calculate_total_items(rows, columns), do: columns * rows

  defp format_tab_label(tab, active_tab) when tab.id == active_tab do
    "#{IO.ANSI.bright()}#{IO.ANSI.underline()}#{tab.label}#{IO.ANSI.reset()}"
  end

  defp format_tab_label(tab, _active_tab), do: tab.label

  defp format_progress_bar_display(bar, percentage, true),
    do: "#{bar} #{percentage}%"

  defp format_progress_bar_display(bar, _percentage, false), do: bar

  defp format_input_text(display_text, _value, _cursor_pos, true) do
    "#{IO.ANSI.light_black()}#{display_text}#{IO.ANSI.reset()}"
  end

  defp format_input_text(display_text, value, cursor_pos, false) do
    add_cursor_indicator(display_text, value, cursor_pos)
  end

  defp add_cursor_indicator(display_text, value, cursor_pos) do
    value_length = String.length(value)

    format_cursor_position(
      cursor_pos <= value_length,
      display_text,
      value,
      cursor_pos
    )
  end

  defp format_cursor_position(true, _display_text, value, cursor_pos) do
    {before, after_cursor} = String.split_at(value, cursor_pos)
    "#{before}│#{after_cursor}"
  end

  defp format_cursor_position(false, display_text, _value, _cursor_pos),
    do: "#{display_text}│"

  defp split_textarea_content("", placeholder), do: [placeholder]

  defp split_textarea_content(value, _placeholder),
    do: String.split(value, "\n")

  defp add_required_marker(text, true),
    do: "#{text} #{IO.ANSI.red()}*#{IO.ANSI.reset()}"

  defp add_required_marker(text, false), do: text

  defp style_disabled_label(label, true),
    do: "#{IO.ANSI.light_black()}#{label}#{IO.ANSI.reset()}"

  defp style_disabled_label(label, false), do: label

  defp format_checkbox_display(checked, disabled) do
    icon = get_checkbox_icon(checked)
    apply_checkbox_style(icon, checked, disabled)
  end

  defp get_checkbox_icon(true), do: "✓"
  defp get_checkbox_icon(false), do: " "

  defp apply_checkbox_style(icon, _checked, true) do
    "#{IO.ANSI.light_black()}[#{icon}]#{IO.ANSI.reset()}"
  end

  defp apply_checkbox_style(icon, true, false) do
    "#{IO.ANSI.green()}[#{icon}]#{IO.ANSI.reset()}"
  end

  defp apply_checkbox_style(icon, false, false), do: "[#{icon}]"

  defp format_toggle_switch(true),
    do: "#{IO.ANSI.green_background()} ON #{IO.ANSI.reset()}"

  defp format_toggle_switch(false),
    do: "#{IO.ANSI.light_black_background()} OFF #{IO.ANSI.reset()}"

  defp create_box_top_border(
         nil,
         content_width,
         top_left,
         top_right,
         horizontal
       ) do
    "#{top_left}#{String.duplicate(horizontal, content_width)}#{top_right}"
  end

  defp create_box_top_border(
         title,
         content_width,
         top_left,
         top_right,
         horizontal
       ) do
    title_length = String.length(title)
    left_padding = div(content_width - title_length - 2, 2)
    right_padding = content_width - title_length - 2 - left_padding

    "#{top_left}#{String.duplicate(horizontal, left_padding)} #{title} #{String.duplicate(horizontal, right_padding)}#{top_right}"
  end

  defp format_tooltip_position(bubble, :top) do
    """
    #{bubble}
     ▼
    """
  end

  defp format_tooltip_position(bubble, :bottom) do
    """
     ▲
    #{bubble}
    """
  end

  defp format_tooltip_position(bubble, :left), do: "#{bubble} ►"
  defp format_tooltip_position(bubble, :right), do: "◄ #{bubble}"
  defp format_tooltip_position(bubble, _), do: bubble
end
