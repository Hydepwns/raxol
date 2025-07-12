defmodule Raxol.Core.Renderer.Views.Chart do
  require Raxol.Core.Renderer.View
  import Raxol.Guards

  @moduledoc """
  Chart view component for data visualization.

  Supports:
  * Bar charts (vertical and horizontal)
  * Line charts
  * Sparklines
  * Axes and labels
  * Multiple series
  * Custom styling
  """

  alias Raxol.Core.Renderer.View

  @type chart_type :: :bar | :line | :sparkline
  @type orientation :: :vertical | :horizontal
  @type series :: %{
          name: String.t(),
          data: [number()],
          color: View.color()
        }

  @type options :: [
          type: chart_type(),
          orientation: orientation(),
          series: [series()],
          width: non_neg_integer(),
          height: non_neg_integer(),
          show_axes: boolean(),
          show_labels: boolean(),
          show_legend: boolean(),
          min: number() | :auto,
          max: number() | :auto,
          style: View.style()
        ]

  @bar_chars ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

  @doc """
  Creates a new chart view.
  """
  def new(opts) do
    options = parse_chart_options(opts)
    content = build_chart_content(options)
    View.box(style: options.style, children: content)
  end

  defp parse_chart_options(opts) do
    %{
      type: Keyword.get(opts, :type, :bar),
      orientation: Keyword.get(opts, :orientation, :vertical),
      series: Keyword.get(opts, :series, []),
      width: Keyword.get(opts, :width, 40),
      height: Keyword.get(opts, :height, 10),
      show_axes: Keyword.get(opts, :show_axes, true),
      show_labels: Keyword.get(opts, :show_labels, true),
      show_legend: Keyword.get(opts, :show_legend, true),
      style: Keyword.get(opts, :style, []),
      min: Keyword.get(opts, :min, nil),
      max: Keyword.get(opts, :max, nil)
    }
  end

  defp build_chart_content(options) do
    {min, max} = calculate_range(options.series, options.min, options.max)

    content =
      build_chart_main_content(
        options.type,
        options.series,
        min,
        max,
        options.width,
        options.height,
        options.orientation
      )

    content
    |> maybe_add_axes(options, min, max)
    |> maybe_add_labels(options)
    |> maybe_add_legend(options)
  end

  defp build_chart_main_content(
         :bar,
         series,
         min,
         max,
         width,
         height,
         orientation
       ),
       do: create_bar_chart(series, min, max, width, height, orientation)

  defp build_chart_main_content(
         :line,
         series,
         min,
         max,
         width,
         height,
         _orientation
       ),
       do: create_line_chart(series, min, max, width, height)

  defp build_chart_main_content(
         :sparkline,
         series,
         min,
         max,
         width,
         _height,
         _orientation
       ),
       do: create_sparkline(series, min, max, width)

  defp maybe_add_axes(
         content,
         %{
           show_axes: true,
           width: width,
           height: height,
           orientation: orientation
         } = _options,
         min,
         max
       ) do
    add_axes(content, min, max, width, height, orientation)
  end

  defp maybe_add_axes(content, _options, _min, _max), do: content

  defp maybe_add_labels(content, %{
         show_labels: true,
         series: series,
         width: width,
         height: height
       }) do
    add_labels(content, series, width, height)
  end

  defp maybe_add_labels(content, _options), do: content

  defp maybe_add_legend(content, %{show_legend: true, series: series}) do
    add_legend(content, series)
  end

  defp maybe_add_legend(content, _options), do: content

  # Private Helpers

  defp calculate_range(series, min, max) do
    data = Enum.flat_map(series, & &1.data)

    if Enum.empty?(data) do
      # Handle empty data case: return default range
      {min || 0, max || 1}
    else
      # Proceed as before if data is not empty
      {
        min || Enum.min(data),
        max || Enum.max(data)
      }
    end
  end

  defp create_bar_chart(series, min, max, width, height, orientation) do
    case orientation do
      :vertical -> create_bars(series, min, max, width, height, :vertical)
      :horizontal -> create_bars(series, min, max, width, height, :horizontal)
    end
  end

  defp create_bars(series, min, max, width, height, orientation) do
    total_points = Enum.sum(Enum.map(series, &length(&1.data)))

    if total_points == 0 do
      empty_bars_flex(orientation)
    else
      config = bar_config(orientation, min, max, width, height, total_points)
      bars = create_bars_for_series(series, config)

      View.flex direction: config.direction do
        bars
      end
    end
  end

  defp empty_bars_flex(:vertical) do
    View.flex direction: :row do
      []
    end
  end

  defp empty_bars_flex(:horizontal) do
    View.flex direction: :column do
      []
    end
  end

  defp create_bars_for_series(series, config) do
    Enum.flat_map(series, fn %{data: data, color: color} ->
      Enum.map(data, fn value ->
        bar_length = config.scale_fun.(value)
        chars = config.create_bar_fun.(bar_length, config.bar_secondary)

        View.text(chars,
          size: config.size_fun.(config.bar_size, config.bar_secondary),
          fg: color
        )
      end)
    end)
  end

  defp bar_config(:vertical, min, max, width, height, total_points) do
    %{
      bar_primary: width,
      bar_secondary: height,
      scale_fun: fn v -> scale_value(v, min, max, 1, height) |> round() end,
      create_bar_fun: &create_vertical_bar/2,
      bar_size: div(width, total_points),
      size_fun: fn bar_size, bar_secondary -> {bar_size, bar_secondary} end,
      direction: :row
    }
  end

  defp bar_config(:horizontal, min, max, width, height, total_points) do
    %{
      bar_primary: height,
      bar_secondary: width,
      scale_fun: fn v -> scale_value(v, min, max, 1, width) |> round() end,
      create_bar_fun: &create_horizontal_bar/2,
      bar_size: div(height, total_points),
      size_fun: fn bar_secondary, bar_size -> {bar_secondary, bar_size} end,
      direction: :column
    }
  end

  defp create_line_chart(series, min, max, width, height) do
    lines =
      series
      |> Enum.map(fn %{data: data, color: color} ->
        points = generate_line_points(data, min, max, width, height)
        render_line_canvas(points, width, height, color)
      end)

    View.box(children: lines)
  end

  defp generate_line_points(data, min, max, width, height) do
    len = length(data)

    Enum.with_index(data)
    |> Enum.map(fn {value, x_idx} ->
      x = calc_line_x(x_idx, len, width)
      y = calc_line_y(value, min, max, height)
      {x, y}
    end)
  end

  defp calc_line_x(x_idx, len, width) when len > 1 do
    Float.floor(x_idx / (len - 1) * (width - 1)) |> trunc()
  end

  # single point case
  defp calc_line_x(_x_idx, _len, _width), do: 0

  defp calc_line_y(value, min, max, height) do
    Float.floor(scale_value(value, min, max, 0, height - 1)) |> trunc()
  end

  defp render_line_canvas(points, width, height, color) do
    points
    |> build_line_canvas(width, height)
    |> canvas_to_view_cells(color)
  end

  defp build_line_canvas(points, width, height) do
    canvas = blank_canvas(width, height)
    draw_lines_on_canvas(canvas, points)
  end

  defp draw_lines_on_canvas(canvas, points) do
    Enum.chunk_every(points, 2, 1, :discard)
    |> Enum.reduce(canvas, fn [start_point, end_point], acc ->
      mark_line_points(acc, start_point, end_point)
    end)
  end

  defp mark_line_points(canvas, {x1, y1}, {x2, y2}) do
    # Bresenham's line algorithm
    dx = abs(x2 - x1)
    dy = -abs(y2 - y1)
    sx = if x1 < x2, do: 1, else: -1
    sy = if y1 < y2, do: 1, else: -1
    err = dx + dy

    %{
      canvas: canvas,
      x: x1,
      y: y1,
      x2: x2,
      y2: y2,
      sx: sx,
      sy: sy,
      err: err,
      dx: dx,
      dy: dy,
      depth: 0
    }
    |> draw_bresenham()
  end

  defp draw_bresenham(params) do
    draw_bresenham_with_params(params)
  end

  defp draw_bresenham_with_params(%{canvas: canvas, depth: depth} = params) do
    cond do
      depth > 10_000 -> canvas
      out_of_bounds?(canvas, params) -> canvas
      reached_end?(params) -> mark_point(canvas, params)
      true -> draw_bresenham_step(params)
    end
  end

  defp out_of_bounds?(canvas, %{x: x, y: y}) do
    x < 0 or y < 0 or nil?(Enum.at(canvas, y)) or
      nil?(Enum.at(Enum.at(canvas, y), x))
  end

  defp reached_end?(%{x: x, y: y, x2: x2, y2: y2}) do
    x == x2 and y == y2
  end

  defp mark_point(canvas, %{x: x, y: y}) do
    put_in(canvas, [Access.at(y), Access.at(x)], "•")
  end

  defp draw_bresenham_step(%{
         canvas: canvas,
         x: x,
         y: y,
         x2: x2,
         y2: y2,
         sx: sx,
         sy: sy,
         err: err,
         dx: dx,
         dy: dy,
         depth: depth
       }) do
    canvas = mark_point(canvas, %{x: x, y: y})
    e2 = 2 * err

    {next_x, next_y, next_err} =
      calculate_next_position(x, y, sx, sy, err, dx, dy, e2)

    next_params = %{
      canvas: canvas,
      x: next_x,
      y: next_y,
      x2: x2,
      y2: y2,
      sx: sx,
      sy: sy,
      err: next_err,
      dx: dx,
      dy: dy,
      depth: depth + 1
    }

    draw_bresenham_with_params(next_params)
  end

  defp calculate_next_position(x, y, sx, sy, err, dx, dy, e2) do
    {next_x, _next_err_x} =
      if e2 >= dy, do: {x + sx, err + dy}, else: {x, err}

    {next_y, next_err_y} =
      if e2 <= dx, do: {y + sy, err + dx}, else: {y, err}

    {next_x, next_y, next_err_y}
  end

  defp canvas_to_view_cells(canvas, color) do
    for {row, y} <- Enum.with_index(canvas),
        {cell, x} <- Enum.with_index(row),
        cell != nil and cell != " " do
      View.text(cell, position: {x, y}, fg: color)
    end
  end

  defp create_sparkline([series], min, max, width) do
    %{data: data, color: color} = series
    chars = sparkline_chars(data, min, max)
    fitted_chars = fit_sparkline_chars(chars, width)

    View.text(Enum.join(fitted_chars),
      size: {width, 1},
      fg: color
    )
  end

  defp sparkline_chars(data, min, max) do
    data
    |> Enum.map(&scale_sparkline_value(&1, min, max))
    |> Enum.map(&sparkline_char/1)
  end

  defp scale_sparkline_value(value, min, max) do
    scale_value(value, min, max, 0, 7)
  end

  defp sparkline_char(scaled_value) do
    Enum.at(@bar_chars, floor(scaled_value))
  end

  defp fit_sparkline_chars(chars, width) do
    char_count = length(chars)

    cond do
      char_count < width ->
        # Pad with spaces if not enough chars
        chars ++ List.duplicate(" ", width - char_count)

      char_count > width ->
        # Truncate if too many chars
        Enum.take(chars, width)

      true ->
        # Return as-is if just right
        chars
    end
  end

  defp create_vertical_bar(bar_height, total_height)
       when integer?(bar_height) and integer?(total_height) do
    build_bar_string(bar_height, total_height, :vertical)
  end

  defp create_horizontal_bar(bar_width, total_width)
       when integer?(bar_width) and integer?(total_width) do
    build_bar_string(bar_width, total_width, :horizontal)
  end

  defp build_bar_string(bar_length, total_length, direction) do
    clamped = clamp_bar_length(bar_length, total_length)
    {full_blocks, partial_block} = bar_blocks(clamped)
    padding = bar_padding(total_length, full_blocks, partial_block)
    bar_blocks_string(direction, padding, partial_block, full_blocks)
  end

  defp bar_padding(total_length, full_blocks, partial_block) do
    padding_size = total_length - full_blocks - String.length(partial_block)
    String.duplicate(" ", :erlang.max(0, padding_size))
  end

  defp bar_blocks_string(:vertical, padding, partial_block, full_blocks),
    do: padding <> partial_block <> String.duplicate("█", full_blocks)

  defp bar_blocks_string(:horizontal, padding, partial_block, full_blocks),
    do: String.duplicate("█", full_blocks) <> partial_block <> padding

  defp clamp_bar_length(bar_length, total_length) do
    :erlang.max(0, :erlang.min(bar_length, total_length))
  end

  defp bar_blocks(clamped_length) do
    full_blocks = div(clamped_length, 8)
    remainder = rem(clamped_length, 8)

    partial_block =
      if remainder > 0, do: Enum.at(@bar_chars, remainder), else: ""

    {full_blocks, partial_block}
  end

  defp scale_value(value, min, max, new_min, new_max) do
    # Avoid division by zero if min == max
    if max == min do
      new_min
    else
      (value - min) / (max - min) * (new_max - new_min) + new_min
    end
  end

  defp add_axes(content, _min, _max, width, height, _orientation) do
    axis_y = View.text("|", position: {0, 0}, fg: :bright_black)

    axis_x =
      View.text(String.duplicate("-", width),
        position: {0, height - 1},
        fg: :bright_black
      )

    [axis_y, axis_x | List.wrap(content)]
  end

  defp add_labels(content, _series, _width, height) do
    min_label = View.text("min", position: {0, height - 1}, fg: :bright_black)
    max_label = View.text("max", position: {0, 0}, fg: :bright_black)
    [min_label, max_label | List.wrap(content)]
  end

  defp add_legend(content, series) do
    legend =
      series
      |> Enum.with_index()
      |> Enum.map(fn {series_data, idx} ->
        name = Map.get(series_data, :name, "Series #{idx + 1}")
        color = Map.get(series_data, :color, :white)
        View.text("■ #{name}", position: {idx * 10, 0}, fg: color)
      end)

    legend ++ List.wrap(content)
  end

  defp blank_canvas(width, height) do
    for _y <- 0..(height - 1) do
      for _x <- 0..(width - 1) do
        " "
      end
    end
  end
end
