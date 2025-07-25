defmodule RaxolWeb.UIComponentView do
  use RaxolWeb, :view

  @moduledoc """
  A view for rendering UI components in the web interface.

  This module provides functions for rendering various UI components
  including charts, visualizations, and other interactive elements
  that can be displayed in web templates.
  """

  alias Raxol.Plugins.Visualization.ChartRenderer
  alias Raxol.Core.Metrics.Visualizer

  @color_map %{
    black: "#000000",
    red: "#ff0000",
    green: "#00ff00",
    yellow: "#ffff00",
    blue: "#0000ff",
    magenta: "#ff00ff",
    cyan: "#00ffff",
    white: "#ffffff",
    dark_gray: "#404040"
  }

  @doc """
  Renders a chart component for web display.

  ## Parameters
    * `chart_data` - The data to display in the chart
    * `opts` - Chart options including type, title, dimensions, etc.

  ## Options
    * `:type` - Chart type (:bar, :line, :sparkline)
    * `:title` - Chart title
    * `:width` - Chart width in pixels
    * `:height` - Chart height in pixels
    * `:series` - List of data series
    * `:show_axes` - Whether to show axes (default: true)
    * `:show_labels` - Whether to show labels (default: true)
    * `:show_legend` - Whether to show legend (default: true)
    * `:orientation` - Chart orientation (:vertical, :horizontal)
    * `:style` - Additional styling options

  ## Returns
    HTML-safe string containing the chart markup
  """
  def render_chart(chart_data, opts \\ []) do
    chart_opts = build_chart_options(chart_data, opts)
    generate_chart_html(chart_opts[:title], chart_opts, opts)
  end

  @doc """
  Renders a metrics visualization chart.

  ## Parameters
    * `metrics` - Metrics data to visualize
    * `chart_type` - Type of chart (:line, :bar, :gauge, :histogram)
    * `opts` - Additional options for the visualization

  ## Returns
    HTML-safe string containing the metrics chart markup
  """
  def render_metrics_chart(metrics, chart_type \\ :line, opts \\ []) do
    title = Keyword.get(opts, :title, "Metrics Visualization")
    width = Keyword.get(opts, :width, 600)
    height = Keyword.get(opts, :height, 400)

    chart_options = %{
      type: chart_type,
      title: title,
      width: width,
      height: height,
      color: Keyword.get(opts, :color, "#4A90E2"),
      show_legend: Keyword.get(opts, :show_legend, true),
      show_grid: Keyword.get(opts, :show_grid, true),
      time_range: Keyword.get(opts, :time_range)
    }

    case Visualizer.create_chart(metrics, chart_options) do
      {:ok, _chart_id, chart_data} ->
        generate_metrics_chart_html(chart_data, chart_options)

      {:error, reason} ->
        generate_error_html(
          "Failed to create metrics chart: #{inspect(reason)}"
        )
    end
  end

  @doc """
  Renders a simple bar chart using terminal-style rendering.

  ## Parameters
    * `data` - List of {label, value} tuples or maps with :label and :value keys
    * `opts` - Chart options

  ## Returns
    HTML-safe string containing the terminal-style chart markup
  """
  def render_terminal_chart(data, opts \\ []) do
    title = Keyword.get(opts, :title, "Chart")
    width = Keyword.get(opts, :width, 80)
    height = Keyword.get(opts, :height, 24)

    bounds = %{width: width, height: height}
    chart_opts = %{title: title}

    # Use the terminal chart renderer
    rendered_chart =
      ChartRenderer.render_chart_content(data, chart_opts, bounds, %{})

    # Convert terminal cells to HTML
    convert_terminal_chart_to_html(rendered_chart, title, opts)
  end

  @doc """
  Renders a dashboard widget container.

  ## Parameters
    * `widget_data` - Widget configuration and data
    * `opts` - Rendering options

  ## Returns
    HTML-safe string containing the widget markup
  """
  def render_widget(widget_data, opts \\ []) do
    widget_type = Map.get(widget_data, :type, :info)
    render_widget_by_type(widget_type, widget_data, opts)
  end

  # Private helper functions

  defp build_chart_options(chart_data, opts) do
    series = prepare_chart_series(chart_data, opts)

    [
      type: Keyword.get(opts, :type, :bar),
      series: series,
      width: Keyword.get(opts, :width, 400),
      height: Keyword.get(opts, :height, 300),
      show_axes: Keyword.get(opts, :show_axes, true),
      show_labels: Keyword.get(opts, :show_labels, true),
      show_legend: Keyword.get(opts, :show_legend, true),
      orientation: Keyword.get(opts, :orientation, :vertical),
      style: Keyword.get(opts, :style, [])
    ]
  end

  defp prepare_chart_series(chart_data, opts) do
    case chart_data do
      data when is_list(data) ->
        # Handle list of {label, value} tuples
        [
          %{
            name: Keyword.get(opts, :series_name, "Data"),
            data: Enum.map(data, fn {_label, value} -> value end),
            color: Keyword.get(opts, :color, :blue)
          }
        ]

      %{series: series} when is_list(series) ->
        # Handle pre-formatted series data
        series

      _ ->
        # Default empty series
        []
    end
  end

  defp generate_chart_html(title, chart_opts, _opts) do
    chart_id = generate_chart_id()

    # Create canvas element for the chart
    canvas_html = """
    <canvas id="#{chart_id}" width="#{chart_opts[:width]}" height="#{chart_opts[:height]}" class="chart-canvas"></canvas>
    """

    # Create container with title
    """
    <div class="chart-card" data-chart-type="#{chart_opts[:type]}" data-chart-data='#{Jason.encode!(chart_opts)}'>
      <h3 class="chart-title">#{title}</h3>
      <div class="chart-container">
        #{canvas_html}
      </div>
    </div>
    """
  end

  defp generate_metrics_chart_html(chart_data, chart_options) do
    chart_id = generate_chart_id()

    # Create canvas for metrics chart
    canvas_html = """
    <canvas id="#{chart_id}" width="#{chart_options.width}" height="#{chart_options.height}" class="metrics-chart-canvas"></canvas>
    """

    # Create container
    """
    <div class="metrics-chart-card" data-chart-data='#{Jason.encode!(chart_data)}'>
      <h3 class="metrics-chart-title">#{chart_options.title}</h3>
      <div class="metrics-chart-container">
        #{canvas_html}
      </div>
    </div>
    """
  end

  defp convert_terminal_chart_to_html(rendered_chart, title, opts) do
    chart_rows = build_chart_rows(rendered_chart, opts[:width] || 80)

    """
    <div class="terminal-chart-card">
      <h3 class="terminal-chart-title">#{title}</h3>
      <div class="terminal-chart-content">
        #{chart_rows}
      </div>
    </div>
    """
  end

  defp build_chart_rows(rendered_chart, width) do
    rendered_chart
    |> Enum.map(&build_chart_cell/1)
    |> Enum.chunk_every(width)
    |> Enum.map(&build_chart_row/1)
  end

  defp build_chart_cell(cell) do
    style = build_cell_style(cell)
    style_attr = Enum.map_join(style, "; ", fn {k, v} -> "#{k}: #{v}" end)
    "<span style=\"#{style_attr}\">#{cell.char}</span>"
  end

  defp build_chart_row(row_cells) do
    "<div class=\"chart-row\">#{Enum.join(row_cells, "")}</div>"
  end

  defp build_cell_style(cell) do
    []
    |> maybe_add_color("color", cell.fg)
    |> maybe_add_color("background-color", cell.bg)
    |> maybe_add_styles(cell.style)
  end

  defp maybe_add_color(style_list, _property, nil), do: style_list
  defp maybe_add_color(style_list, _property, :default), do: style_list

  defp maybe_add_color(style_list, property, color) do
    [{property, color_to_css(color)} | style_list]
  end

  defp maybe_add_styles(style_list, nil), do: style_list

  defp maybe_add_styles(style_list, styles),
    do: apply_text_styles(styles, style_list)

  defp color_to_css(color) when is_atom(color) do
    Map.get(@color_map, color, "#000000")
  end

  defp color_to_css(color) when is_integer(color) do
    # Handle 256-color codes
    ("#" <> Integer.to_string(color, 16)) |> String.pad_leading(6, "0")
  end

  defp color_to_css(_), do: "#000000"

  defp apply_text_styles(styles, style_list) when is_list(styles) do
    Enum.reduce(styles, style_list, fn style, acc ->
      case style do
        :bold -> [{"font-weight", "bold"} | acc]
        :underline -> [{"text-decoration", "underline"} | acc]
        :italic -> [{"font-style", "italic"} | acc]
        _ -> acc
      end
    end)
  end

  defp apply_text_styles(_styles, style_list), do: style_list

  defp render_chart_widget(widget_data, _opts) do
    data = Map.get(widget_data, :data, [])
    component_opts = Map.get(widget_data, :component_opts, %{})

    chart_opts = [
      type: Map.get(component_opts, :type, :bar),
      title: Map.get(widget_data, :title, "Chart"),
      series: data
    ]

    render_chart(data, chart_opts)
  end

  defp render_treemap_widget(widget_data, _opts) do
    title = Map.get(widget_data, :title, "TreeMap")
    _data = Map.get(widget_data, :data, [])

    """
    <div class="treemap-widget">
      <h3 class="treemap-title">#{title}</h3>
      <div class="treemap-placeholder">TreeMap visualization</div>
    </div>
    """
  end

  defp render_info_widget(title, content, _opts) do
    """
    <div class="info-widget">
      <h3 class="info-widget-title">#{title}</h3>
      <div class="info-widget-content">#{content}</div>
    </div>
    """
  end

  defp render_generic_widget(widget_data, _opts) do
    title = Map.get(widget_data, :title, "Widget")
    content = Map.get(widget_data, :content, "Generic widget content")

    """
    <div class="generic-widget">
      <h3 class="generic-widget-title">#{title}</h3>
      <div class="generic-widget-content">#{content}</div>
    </div>
    """
  end

  defp generate_error_html(message) do
    """
    <div class="error-widget">
      <h3 class="error-title">Error</h3>
      <div class="error-message">#{message}</div>
    </div>
    """
  end

  defp generate_chart_id do
    "chart_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end

  defp render_widget_by_type(:chart, widget_data, opts) do
    render_chart_widget(widget_data, opts)
  end

  defp render_widget_by_type(:treemap, widget_data, opts) do
    render_treemap_widget(widget_data, opts)
  end

  defp render_widget_by_type(:info, widget_data, opts) do
    title = Map.get(widget_data, :title, "Widget")
    content = Map.get(widget_data, :content, "")
    render_info_widget(title, content, opts)
  end

  defp render_widget_by_type(_type, widget_data, opts) do
    render_generic_widget(widget_data, opts)
  end
end
