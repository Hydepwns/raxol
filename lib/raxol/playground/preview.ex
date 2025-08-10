defmodule Raxol.Playground.Preview do
  @moduledoc """
  Live preview generation for Raxol components.

  This module handles rendering components with their current props and state,
  generating terminal output that shows how the component will appear.
  """

  # Remove unused aliases

  @doc """
  Generates a preview of a component with given props and state.
  """
  def generate(component, props \\ %{}, state \\ %{}, opts \\ []) do
    theme = Keyword.get(opts, :theme, :default)
    _force_refresh = Keyword.get(opts, :force_refresh, false)

    # Apply theme
    themed_props = apply_theme(props, theme)

    # Generate preview content
    try do
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
    rescue
      error ->
        render_error(component, error)
    end
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

    if level <= 2 do
      underline =
        String.duplicate(
          if(level == 1, do: "=", else: "-"),
          String.length(content) + String.length(prefix)
        )

      "#{styled_content}\n#{underline}"
    else
      styled_content
    end
  end

  defp render_label(props) do
    text = Map.get(props, :text, "")
    required = Map.get(props, :required, false)

    label_text =
      if required do
        "#{text} #{IO.ANSI.red()}*#{IO.ANSI.reset()}"
      else
        text
      end

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
      if String.length(value) == 0 and String.length(placeholder) > 0 do
        "#{IO.ANSI.light_black()}#{placeholder}#{IO.ANSI.reset()}"
      else
        # Show cursor position
        {before, after_cursor} = String.split_at(value, cursor_pos)

        cursor =
          if disabled, do: "", else: "#{IO.ANSI.reverse()} #{IO.ANSI.reset()}"

        "#{before}#{cursor}#{after_cursor}"
      end

    padding = max(0, width - String.length(value))

    border_style =
      if disabled do
        IO.ANSI.light_black()
      else
        IO.ANSI.white()
      end

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

    lines =
      if String.length(value) == 0 and String.length(placeholder) > 0 do
        [IO.ANSI.light_black() <> placeholder <> IO.ANSI.reset()]
      else
        String.split(value, "\n")
      end

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
    arrow = if is_open, do: "▲", else: "▼"

    main_line = "│ #{display_value} #{arrow} │"
    width = String.length(main_line) - 4

    top_border = "┌" <> String.duplicate("─", width + 2) <> "┐"
    bottom_border = "└" <> String.duplicate("─", width + 2) <> "┘"

    result = [top_border, main_line, bottom_border]

    if is_open and length(options) > 0 do
      option_lines =
        Enum.with_index(options, fn option, _idx ->
          marker =
            if option == selected,
              do: "#{IO.ANSI.bright()}► #{IO.ANSI.reset()}",
              else: "  "

          "│ #{marker}#{option}#{String.duplicate(" ", width - String.length("#{marker}#{option}"))} │"
        end)

      result ++ option_lines ++ [bottom_border]
    else
      result
    end
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

    checkbox =
      if checked do
        if disabled do
          "#{IO.ANSI.light_black()}☑#{IO.ANSI.reset()}"
        else
          "#{IO.ANSI.green()}☑#{IO.ANSI.reset()}"
        end
      else
        if disabled do
          "#{IO.ANSI.light_black()}☐#{IO.ANSI.reset()}"
        else
          "☐"
        end
      end

    label_style =
      if disabled do
        IO.ANSI.light_black() <> label <> IO.ANSI.reset()
      else
        label
      end

    "#{checkbox} #{label_style}"
  end

  defp render_radio_group(props, state) do
    options = Map.get(props, :options, [])
    selected = Map.get(state, :selected, Map.get(props, :selected))

    Enum.map(options, fn option ->
      radio =
        if option == selected do
          "#{IO.ANSI.green()}◉#{IO.ANSI.reset()}"
        else
          "○"
        end

      "#{radio} #{option}"
    end)
    |> Enum.join("\n")
  end

  defp render_toggle(props, state) do
    label = Map.get(props, :label, "")
    enabled = Map.get(state, :enabled, Map.get(props, :enabled, false))

    switch =
      if enabled do
        "#{IO.ANSI.green_background()} ON #{IO.ANSI.reset()}"
      else
        "#{IO.ANSI.light_black_background()} OFF #{IO.ANSI.reset()}"
      end

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
      if title do
        title_length = String.length(title)
        left_padding = div(content_width - title_length - 2, 2)
        right_padding = content_width - title_length - 2 - left_padding

        "#{top_left}#{String.duplicate(horizontal, left_padding)} #{title} #{String.duplicate(horizontal, right_padding)}#{top_right}"
      else
        "#{top_left}#{String.duplicate(horizontal, content_width)}#{top_right}"
      end

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

    if direction == :horizontal do
      Enum.join(placeholder_items, String.duplicate(" ", gap))
    else
      Enum.join(placeholder_items, String.duplicate("\n", gap))
    end
  end

  defp render_grid(props) do
    columns = Map.get(props, :columns, 3)
    rows = Map.get(props, :rows, 2)
    gap = Map.get(props, :gap, 1)

    total_items = if rows, do: columns * rows, else: 6

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
        if tab.id == active_tab do
          "#{IO.ANSI.bright()}#{IO.ANSI.underline()}#{tab.label}#{IO.ANSI.reset()}"
        else
          tab.label
        end
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

    if !border do
      # Simple table without borders
      header_line = Enum.join(headers, " | ")
      separator = String.duplicate("-", String.length(header_line))
      row_lines = Enum.map(rows, &Enum.join(&1, " | "))

      ([header_line, separator] ++ row_lines)
      |> Enum.join("\n")
    else
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

    if ordered do
      items
      |> Enum.with_index(1)
      |> Enum.map(fn {item, index} -> "#{index}. #{item}" end)
      |> Enum.join("\n")
    else
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

    if show_percentage do
      "#{bar} #{percentage}%"
    else
      bar
    end
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

    unless visible do
      "(Modal is hidden)"
    else
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
        [top_border, title_line, separator] ++ content_lines ++ [bottom_border]

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

    unless visible do
      ""
    else
      bubble =
        "#{IO.ANSI.black_background()}#{IO.ANSI.white()} #{text} #{IO.ANSI.reset()}"

      case position do
        :top ->
          """
          #{bubble}
           ▼
          """

        :bottom ->
          """
           ▲
          #{bubble}
          """

        :left ->
          "#{bubble} ►"

        :right ->
          "◄ #{bubble}"

        _ ->
          bubble
      end
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
end
