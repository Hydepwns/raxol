defmodule Raxol.UI.Charts.ScatterChart do
  @moduledoc """
  Braille-resolution scatter plot for 2D `{x, y}` data.

  Each data point becomes a single braille dot. Multiple series are
  rendered as separate layers with independent colors. Points that
  fall outside the display range are silently clipped.
  """

  alias Raxol.UI.Charts.{BrailleCanvas, ChartUtils}

  @type cell :: ChartUtils.cell()

  @type series :: %{
          name: String.t(),
          data: [{number(), number()}] | struct(),
          color: atom()
        }

  @doc """
  Renders a scatter chart into cell tuples.

  ## Options
  - `show_axes` -- render Y-axis labels and line (default: false)
  - `show_legend` -- render series legend below chart (default: false)
  - `x_range` -- `{min, max}` or `:auto` (default: `:auto`)
  - `y_range` -- `{min, max}` or `:auto` (default: `:auto`)
  """
  @spec render(
          {non_neg_integer(), non_neg_integer(), pos_integer(), pos_integer()},
          [series()],
          keyword()
        ) :: [cell()]
  def render({x, y, w, h}, series, opts \\ []) do
    show_axes = Keyword.get(opts, :show_axes, false)
    show_legend = Keyword.get(opts, :show_legend, false)

    axes_width = if show_axes, do: 7, else: 0
    legend_height = if show_legend, do: 1, else: 0
    plot_w = max(w - axes_width, 1)
    plot_h = max(h - legend_height, 1)
    plot_x = x + axes_width
    plot_y = y

    normalized =
      Enum.map(series, fn s ->
        %{s | data: ChartUtils.normalize_data_2d(s.data)}
      end)

    all_points = Enum.flat_map(normalized, & &1.data)
    {x_range, y_range} = resolve_ranges(all_points, opts)

    canvas = BrailleCanvas.new(plot_w, plot_h)
    {dot_w, dot_h} = BrailleCanvas.get_dimensions(canvas)

    canvas =
      normalized
      |> Enum.with_index()
      |> Enum.reduce(canvas, fn {%{data: data}, layer_id}, acc ->
        place_dots(acc, data, layer_id, x_range, y_range, dot_w, dot_h)
      end)

    color_map =
      normalized
      |> Enum.with_index()
      |> Map.new(fn {%{color: color}, idx} -> {idx, color} end)

    chart_cells =
      BrailleCanvas.to_cells_multicolor(canvas, {plot_x, plot_y}, color_map)

    axes_cells =
      if show_axes,
        do: ChartUtils.render_axes({x, y, axes_width, plot_h}, y_range),
        else: []

    legend_cells =
      if show_legend,
        do: ChartUtils.render_legend(x, y + plot_h, normalized),
        else: []

    axes_cells ++ chart_cells ++ legend_cells
  end

  # -- Private --

  defp resolve_ranges([], opts) do
    x_range = Keyword.get(opts, :x_range, :auto)
    y_range = Keyword.get(opts, :y_range, :auto)

    {
      if(x_range == :auto, do: {0.0, 1.0}, else: x_range),
      if(y_range == :auto, do: {0.0, 1.0}, else: y_range)
    }
  end

  defp resolve_ranges(points, opts) do
    {auto_x, auto_y} = ChartUtils.auto_range_2d(points)
    x_range = Keyword.get(opts, :x_range, :auto)
    y_range = Keyword.get(opts, :y_range, :auto)

    {
      if(x_range == :auto, do: auto_x, else: x_range),
      if(y_range == :auto, do: auto_y, else: y_range)
    }
  end

  defp place_dots(
         canvas,
         data,
         layer_id,
         {x_min, x_max},
         {y_min, y_max},
         dot_w,
         dot_h
       ) do
    Enum.reduce(data, canvas, fn {px, py}, acc ->
      dx = round(ChartUtils.scale_value(px, x_min, x_max, 0, dot_w - 1))
      # Invert Y: high values at top
      dy =
        dot_h - 1 -
          round(ChartUtils.scale_value(py, y_min, y_max, 0, dot_h - 1))

      BrailleCanvas.put_dot(acc, dx, dy, layer_id)
    end)
  end
end
