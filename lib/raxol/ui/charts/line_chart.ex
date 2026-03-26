defmodule Raxol.UI.Charts.LineChart do
  @moduledoc """
  Braille-resolution line chart with multicolor multi-series support.

  Renders data as connected lines using Bresenham's algorithm at braille
  dot resolution (2x width, 4x height), producing cell tuples compatible
  with the HUD rendering pattern.
  """

  alias Raxol.UI.Charts.{BrailleCanvas, ChartUtils}

  @type cell :: ChartUtils.cell()

  @type series :: %{
          name: String.t(),
          data: list() | struct(),
          color: atom()
        }

  @doc """
  Renders a line chart into cell tuples.

  ## Options
  - `show_axes` -- render Y-axis labels and line (default: false)
  - `show_legend` -- render series legend below chart (default: false)
  - `min` -- Y-axis minimum (default: `:auto`)
  - `max` -- Y-axis maximum (default: `:auto`)
  """
  @spec render(
          {non_neg_integer(), non_neg_integer(), pos_integer(), pos_integer()},
          [series()],
          keyword()
        ) :: [cell()]
  def render({x, y, w, h}, series, opts \\ []) do
    show_axes = Keyword.get(opts, :show_axes, false)
    show_legend = Keyword.get(opts, :show_legend, false)

    # Reserve space for axes and legend
    axes_width = if show_axes, do: 7, else: 0
    legend_height = if show_legend, do: 1, else: 0
    plot_w = max(w - axes_width, 1)
    plot_h = max(h - legend_height, 1)
    plot_x = x + axes_width
    plot_y = y

    # Normalize and compute range
    normalized =
      Enum.map(series, fn s ->
        %{s | data: ChartUtils.normalize_data(s.data)}
      end)

    all_values = Enum.flat_map(normalized, & &1.data)

    {y_min, y_max} = ChartUtils.resolve_range(all_values, opts)

    # Build braille canvas
    canvas = BrailleCanvas.new(plot_w, plot_h)
    {dot_w, dot_h} = BrailleCanvas.get_dimensions(canvas)

    canvas =
      normalized
      |> Enum.with_index()
      |> Enum.reduce(canvas, fn {%{data: data}, layer_id}, acc ->
        draw_series_line(acc, data, layer_id, y_min, y_max, dot_w, dot_h)
      end)

    # Build color map
    color_map =
      normalized
      |> Enum.with_index()
      |> Map.new(fn {%{color: color}, idx} -> {idx, color} end)

    chart_cells =
      BrailleCanvas.to_cells_multicolor(canvas, {plot_x, plot_y}, color_map)

    # Optional decorations
    axes_cells =
      if show_axes,
        do: ChartUtils.render_axes({x, y, axes_width, plot_h}, {y_min, y_max}),
        else: []

    legend_cells =
      if show_legend,
        do: ChartUtils.render_legend(x, y + plot_h, normalized),
        else: []

    axes_cells ++ chart_cells ++ legend_cells
  end

  # -- Private --

  defp draw_series_line(canvas, [], _layer_id, _y_min, _y_max, _dot_w, _dot_h),
    do: canvas

  defp draw_series_line(canvas, [_], _layer_id, _y_min, _y_max, _dot_w, _dot_h),
    do: canvas

  defp draw_series_line(canvas, data, layer_id, y_min, y_max, dot_w, dot_h) do
    len = length(data)

    points =
      data
      |> Enum.with_index()
      |> Enum.map(fn {value, idx} ->
        px = scale_x(idx, len, dot_w)
        py = scale_y(value, y_min, y_max, dot_h)
        {px, py}
      end)

    points
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce(canvas, fn [{x1, y1}, {x2, y2}], acc ->
      bresenham(acc, x1, y1, x2, y2, layer_id)
    end)
  end

  defp scale_x(idx, len, dot_w) when len > 1 do
    round(idx / (len - 1) * (dot_w - 1))
    |> ChartUtils.clamp(0, dot_w - 1)
  end

  defp scale_x(_idx, _len, _dot_w), do: 0

  defp scale_y(value, y_min, y_max, dot_h) do
    # Invert Y: high values at top (low dot_y)
    scaled = ChartUtils.scale_value(value, y_min, y_max, 0, dot_h - 1)
    (dot_h - 1 - round(scaled)) |> ChartUtils.clamp(0, dot_h - 1)
  end

  # Tail-recursive Bresenham line drawing
  defp bresenham(canvas, x1, y1, x2, y2, layer_id) do
    dx = abs(x2 - x1)
    dy = -abs(y2 - y1)
    sx = if x1 < x2, do: 1, else: -1
    sy = if y1 < y2, do: 1, else: -1
    err = dx + dy

    do_bresenham(canvas, x1, y1, x2, y2, sx, sy, err, dx, dy, layer_id)
  end

  defp do_bresenham(canvas, x, y, x2, y2, sx, sy, err, dx, dy, layer_id) do
    canvas = BrailleCanvas.put_dot(canvas, x, y, layer_id)

    if x == x2 and y == y2 do
      canvas
    else
      e2 = 2 * err

      {next_x, next_err} =
        if e2 >= dy, do: {x + sx, err + dy}, else: {x, err}

      {next_y, next_err} =
        if e2 <= dx, do: {y + sy, next_err + dx}, else: {y, next_err}

      do_bresenham(
        canvas,
        next_x,
        next_y,
        x2,
        y2,
        sx,
        sy,
        next_err,
        dx,
        dy,
        layer_id
      )
    end
  end
end
