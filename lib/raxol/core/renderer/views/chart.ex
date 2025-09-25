defmodule Raxol.Core.Renderer.Views.Chart do
  require Raxol.Core.Renderer.View

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
          color: View.Types.color()
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

  @spec parse_chart_options(keyword()) :: {:ok, any()} | {:error, any()}
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

  @spec build_chart_content(any()) :: any()
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

  @spec build_chart_main_content(
          any(),
          any(),
          any(),
          any(),
          String.t() | integer(),
          pos_integer(),
          any()
        ) :: any()
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

  @spec build_chart_main_content(
          any(),
          any(),
          any(),
          any(),
          String.t() | integer(),
          pos_integer(),
          any()
        ) :: any()
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

  @spec build_chart_main_content(
          any(),
          any(),
          any(),
          any(),
          String.t() | integer(),
          any(),
          any()
        ) :: any()
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

  @spec maybe_add_axes(String.t(), any(), any(), any()) :: any()
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

  @spec maybe_add_axes(String.t(), any(), any(), any()) :: any()
  defp maybe_add_axes(content, _options, _min, _max), do: content

  @spec maybe_add_labels(String.t(), any()) :: any()
  defp maybe_add_labels(content, %{
         show_labels: true,
         series: series,
         width: width,
         height: height
       }) do
    add_labels(content, series, width, height)
  end

  @spec maybe_add_labels(String.t(), any()) :: any()
  defp maybe_add_labels(content, _options), do: content

  @spec maybe_add_legend(String.t(), any()) :: any()
  defp maybe_add_legend(content, %{show_legend: true, series: series}) do
    add_legend(content, series)
  end

  @spec maybe_add_legend(String.t(), any()) :: any()
  defp maybe_add_legend(content, _options), do: content

  # Private Helpers

  @spec calculate_range(any(), any(), any()) :: any()
  defp calculate_range(series, min, max) do
    data = Enum.flat_map(series, & &1.data)
    handle_range_calculation(Enum.empty?(data), data, min, max)
  end

  @spec handle_range_calculation(any(), any(), any(), any()) ::
          {:ok, any()}
          | {:error, any()}
          | {:reply, any(), any()}
          | {:noreply, any()}
  defp handle_range_calculation(true, _data, min, max) do
    # Handle empty data case: return default range
    {min || 0, max || 1}
  end

  @spec handle_range_calculation(any(), any(), any(), any()) ::
          {:ok, any()}
          | {:error, any()}
          | {:reply, any(), any()}
          | {:noreply, any()}
  defp handle_range_calculation(false, data, min, max) do
    # Proceed as before if data is not empty
    {
      min || Enum.min(data),
      max || Enum.max(data)
    }
  end

  @spec create_bar_chart(
          any(),
          any(),
          any(),
          String.t() | integer(),
          pos_integer(),
          any()
        ) :: any()
  defp create_bar_chart(series, min, max, width, height, orientation) do
    case orientation do
      :vertical -> create_bars(series, min, max, width, height, :vertical)
      :horizontal -> create_bars(series, min, max, width, height, :horizontal)
    end
  end

  @spec create_bars(
          any(),
          any(),
          any(),
          String.t() | integer(),
          pos_integer(),
          any()
        ) :: any()
  defp create_bars(series, min, max, width, height, orientation) do
    total_points = Enum.sum(Enum.map(series, &length(&1.data)))

    create_bars_with_points(
      total_points == 0,
      series,
      min,
      max,
      width,
      height,
      orientation,
      total_points
    )
  end

  @spec create_bars_with_points(
          any(),
          any(),
          any(),
          any(),
          String.t() | integer(),
          any(),
          any(),
          any()
        ) :: any()
  defp create_bars_with_points(
         true,
         _series,
         _min,
         _max,
         _width,
         _height,
         orientation,
         _total_points
       ) do
    empty_bars_flex(orientation)
  end

  @spec create_bars_with_points(
          any(),
          any(),
          any(),
          any(),
          String.t() | integer(),
          pos_integer(),
          any(),
          any()
        ) :: any()
  defp create_bars_with_points(
         false,
         series,
         min,
         max,
         width,
         height,
         orientation,
         total_points
       ) do
    config = bar_config(orientation, min, max, width, height, total_points)
    bars = create_bars_for_series(series, config)

    View.flex direction: config.direction do
      bars
    end
  end

  @spec empty_bars_flex(any()) :: any()
  defp empty_bars_flex(:vertical) do
    View.flex direction: :row do
      []
    end
  end

  @spec empty_bars_flex(any()) :: any()
  defp empty_bars_flex(:horizontal) do
    View.flex direction: :column do
      []
    end
  end

  @spec create_bars_for_series(any(), map()) :: any()
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

  @spec bar_config(
          any(),
          any(),
          any(),
          String.t() | integer(),
          pos_integer(),
          any()
        ) :: any()
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

  @spec bar_config(
          any(),
          any(),
          any(),
          String.t() | integer(),
          pos_integer(),
          any()
        ) :: any()
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

  @spec create_line_chart(
          any(),
          any(),
          any(),
          String.t() | integer(),
          pos_integer()
        ) :: any()
  defp create_line_chart(series, min, max, width, height) do
    lines =
      series
      |> Enum.map(fn %{data: data, color: color} ->
        points = generate_line_points(data, min, max, width, height)
        render_line_canvas(points, width, height, color)
      end)

    View.box(children: lines)
  end

  @spec generate_line_points(
          any(),
          any(),
          any(),
          String.t() | integer(),
          pos_integer()
        ) :: any()
  defp generate_line_points(data, min, max, width, height) do
    len = length(data)

    Enum.with_index(data)
    |> Enum.map(fn {value, x_idx} ->
      x = calc_line_x(x_idx, len, width)
      y = calc_line_y(value, min, max, height)
      {x, y}
    end)
  end

  @spec calc_line_x(String.t() | integer(), any(), String.t() | integer()) ::
          any()
  defp calc_line_x(x_idx, len, width) when len > 1 do
    Float.floor(x_idx / (len - 1) * (width - 1)) |> trunc()
  end

  # single point case
  @spec calc_line_x(String.t() | integer(), any(), String.t() | integer()) ::
          any()
  defp calc_line_x(_x_idx, _len, _width), do: 0

  @spec calc_line_y(any(), any(), any(), pos_integer()) :: any()
  defp calc_line_y(value, min, max, height) do
    Float.floor(scale_value(value, min, max, 0, height - 1)) |> trunc()
  end

  @spec render_line_canvas(
          any(),
          String.t() | integer(),
          pos_integer(),
          Raxol.Terminal.Color.TrueColor.t()
        ) :: any()
  defp render_line_canvas(points, width, height, color) do
    points
    |> build_line_canvas(width, height)
    |> canvas_to_view_cells(color)
  end

  @spec build_line_canvas(any(), String.t() | integer(), pos_integer()) :: any()
  defp build_line_canvas(points, width, height) do
    canvas = blank_canvas(width, height)
    draw_lines_on_canvas(canvas, points)
  end

  @spec draw_lines_on_canvas(any(), any()) :: any()
  defp draw_lines_on_canvas(canvas, points) do
    Enum.chunk_every(points, 2, 1, :discard)
    |> Enum.reduce(canvas, fn [start_point, end_point], acc ->
      mark_line_points(acc, start_point, end_point)
    end)
  end

  @spec mark_line_points(any(), any(), any()) :: any()
  defp mark_line_points(canvas, {x1, y1}, {x2, y2}) do
    # Bresenham's line algorithm
    dx = abs(x2 - x1)
    dy = -abs(y2 - y1)

    sx =
      case x1 < x2 do
        true -> 1
        false -> -1
      end

    sy =
      case y1 < y2 do
        true -> 1
        false -> -1
      end

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

  @spec draw_bresenham(any()) :: any()
  defp draw_bresenham(params) do
    draw_bresenham_with_params(params)
  end

  @spec draw_bresenham_with_params(any()) :: any()
  defp draw_bresenham_with_params(%{canvas: canvas, depth: depth} = _params)
       when depth > 10_000,
       do: canvas

  @spec draw_bresenham_with_params(any()) :: any()
  defp draw_bresenham_with_params(%{canvas: canvas} = params) do
    case {out_of_bounds?(canvas, params), reached_end?(params)} do
      {true, _} -> canvas
      {false, true} -> mark_point(canvas, params)
      {false, false} -> draw_bresenham_step(params)
    end
  end

  @spec out_of_bounds?(any(), any()) :: boolean()
  defp out_of_bounds?(canvas, %{x: x, y: y}) do
    x < 0 or y < 0 or is_nil(Enum.at(canvas, y)) or
      is_nil(Enum.at(Enum.at(canvas, y), x))
  end

  @spec reached_end?(any()) :: boolean()
  defp reached_end?(%{x: x, y: y, x2: x2, y2: y2}) do
    x == x2 and y == y2
  end

  @spec mark_point(any(), any()) :: any()
  defp mark_point(canvas, %{x: x, y: y}) do
    put_in(canvas, [Access.at(y), Access.at(x)], "•")
  end

  @spec draw_bresenham_step(any()) :: any()
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

  @spec calculate_next_position(
          non_neg_integer(),
          non_neg_integer(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any()
        ) :: any()
  defp calculate_next_position(x, y, sx, sy, err, dx, dy, e2) do
    {next_x, _next_err_x} = calculate_next_x(e2 >= dy, x, sx, err, dy)
    {next_y, next_err_y} = calculate_next_y(e2 <= dx, y, sy, err, dx)
    {next_x, next_y, next_err_y}
  end

  @spec calculate_next_x(any(), non_neg_integer(), any(), any(), any()) :: any()
  defp calculate_next_x(true, x, sx, err, dy), do: {x + sx, err + dy}
  @spec calculate_next_x(any(), non_neg_integer(), any(), any(), any()) :: any()
  defp calculate_next_x(false, x, _sx, err, _dy), do: {x, err}

  @spec calculate_next_y(any(), non_neg_integer(), any(), any(), any()) :: any()
  defp calculate_next_y(true, y, sy, err, dx), do: {y + sy, err + dx}
  @spec calculate_next_y(any(), non_neg_integer(), any(), any(), any()) :: any()
  defp calculate_next_y(false, y, _sy, err, _dx), do: {y, err}

  @spec canvas_to_view_cells(any(), Raxol.Terminal.Color.TrueColor.t()) :: any()
  defp canvas_to_view_cells(canvas, color) do
    for {row, y} <- Enum.with_index(canvas),
        {cell, x} <- Enum.with_index(row),
        cell != nil and cell != " " do
      View.text(cell, position: {x, y}, fg: color)
    end
  end

  @spec create_sparkline(any(), any(), any(), String.t() | integer()) :: any()
  defp create_sparkline([series], min, max, width) do
    %{data: data, color: color} = series
    chars = sparkline_chars(data, min, max)
    fitted_chars = fit_sparkline_chars(chars, width)

    View.text(Enum.join(fitted_chars),
      size: {width, 1},
      fg: color
    )
  end

  @spec sparkline_chars(any(), any(), any()) :: any()
  defp sparkline_chars(data, min, max) do
    data
    |> Enum.map(&scale_sparkline_value(&1, min, max))
    |> Enum.map(&sparkline_char/1)
  end

  @spec scale_sparkline_value(any(), any(), any()) :: any()
  defp scale_sparkline_value(value, min, max) do
    scale_value(value, min, max, 0, 7)
  end

  @spec sparkline_char(any()) :: any()
  defp sparkline_char(scaled_value) do
    Enum.at(@bar_chars, floor(scaled_value))
  end

  @spec fit_sparkline_chars(any(), String.t() | integer()) :: any()
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

  @spec create_vertical_bar(any(), any()) :: any()
  defp create_vertical_bar(bar_height, total_height)
       when is_integer(bar_height) and is_integer(total_height) do
    build_bar_string(bar_height, total_height, :vertical)
  end

  @spec create_horizontal_bar(String.t() | integer(), String.t() | integer()) ::
          any()
  defp create_horizontal_bar(bar_width, total_width)
       when is_integer(bar_width) and is_integer(total_width) do
    build_bar_string(bar_width, total_width, :horizontal)
  end

  @spec build_bar_string(any(), any(), any()) :: any()
  defp build_bar_string(bar_length, total_length, direction) do
    clamped = clamp_bar_length(bar_length, total_length)
    {full_blocks, partial_block} = bar_blocks(clamped)
    padding = bar_padding(total_length, full_blocks, partial_block)
    bar_blocks_string(direction, padding, partial_block, full_blocks)
  end

  @spec bar_padding(any(), any(), any()) :: any()
  defp bar_padding(total_length, full_blocks, partial_block) do
    padding_size = total_length - full_blocks - String.length(partial_block)
    String.duplicate(" ", :erlang.max(0, padding_size))
  end

  @spec bar_blocks_string(any(), any(), any(), any()) :: any()
  defp bar_blocks_string(:vertical, padding, partial_block, full_blocks),
    do: padding <> partial_block <> String.duplicate("█", full_blocks)

  @spec bar_blocks_string(any(), any(), any(), any()) :: any()
  defp bar_blocks_string(:horizontal, padding, partial_block, full_blocks),
    do: String.duplicate("█", full_blocks) <> partial_block <> padding

  @spec clamp_bar_length(any(), any()) :: any()
  defp clamp_bar_length(bar_length, total_length) do
    :erlang.max(0, :erlang.min(bar_length, total_length))
  end

  @spec bar_blocks(any()) :: any()
  defp bar_blocks(clamped_length) do
    full_blocks = div(clamped_length, 8)
    remainder = rem(clamped_length, 8)
    partial_block = get_partial_block(remainder > 0, remainder)
    {full_blocks, partial_block}
  end

  @spec get_partial_block(any(), any()) :: any() | nil
  defp get_partial_block(true, remainder), do: Enum.at(@bar_chars, remainder)
  @spec get_partial_block(any(), any()) :: any() | nil
  defp get_partial_block(false, _remainder), do: ""

  @spec scale_value(any(), any(), any(), any(), any()) :: any()
  defp scale_value(value, min, max, new_min, new_max) do
    # Avoid division by zero if min == max
    scale_value_with_range(max == min, value, min, max, new_min, new_max)
  end

  @spec scale_value_with_range(any(), any(), any(), any(), any(), any()) ::
          any()
  defp scale_value_with_range(true, _value, _min, _max, new_min, _new_max),
    do: new_min

  @spec scale_value_with_range(any(), any(), any(), any(), any(), any()) ::
          any()
  defp scale_value_with_range(false, value, min, max, new_min, new_max) do
    (value - min) / (max - min) * (new_max - new_min) + new_min
  end

  @spec add_axes(
          String.t(),
          any(),
          any(),
          String.t() | integer(),
          pos_integer(),
          any()
        ) :: any()
  defp add_axes(content, _min, _max, width, height, _orientation) do
    axis_y = View.text("|", position: {0, 0}, fg: :bright_black)

    axis_x =
      View.text(String.duplicate("-", width),
        position: {0, height - 1},
        fg: :bright_black
      )

    [axis_y, axis_x | List.wrap(content)]
  end

  @spec add_labels(String.t(), any(), String.t() | integer(), pos_integer()) ::
          any()
  defp add_labels(content, _series, _width, height) do
    min_label = View.text("min", position: {0, height - 1}, fg: :bright_black)
    max_label = View.text("max", position: {0, 0}, fg: :bright_black)
    [min_label, max_label | List.wrap(content)]
  end

  @spec add_legend(String.t(), any()) :: any()
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

  @spec blank_canvas(String.t() | integer(), pos_integer()) :: any()
  defp blank_canvas(width, height) do
    for _y <- 0..(height - 1) do
      for _x <- 0..(width - 1) do
        " "
      end
    end
  end
end
