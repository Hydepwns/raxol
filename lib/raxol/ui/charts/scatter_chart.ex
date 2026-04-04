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
    plot = ChartUtils.compute_plot_region(x, y, w, h, show_axes, show_legend)
    {normalized, x_range, y_range} = normalize_series(series, opts)

    chart_cells = render_scatter_cells(normalized, plot, x_range, y_range)

    axes_cells =
      render_optional_axes(show_axes, x, y, plot.axes_w, plot.h, y_range)

    legend_cells =
      render_optional_legend(show_legend, x, y + plot.h, normalized)

    axes_cells ++ chart_cells ++ legend_cells
  end

  defp normalize_series(series, opts) do
    normalized =
      Enum.map(series, fn s ->
        %{s | data: ChartUtils.normalize_data_2d(s.data)}
      end)

    all_points = Enum.flat_map(normalized, & &1.data)
    {x_range, y_range} = resolve_ranges(all_points, opts)
    {normalized, x_range, y_range}
  end

  defp render_scatter_cells(normalized, plot, x_range, y_range) do
    canvas = BrailleCanvas.new(plot.w, plot.h)
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

    BrailleCanvas.to_cells_multicolor(canvas, {plot.x, plot.y}, color_map)
  end

  defp render_optional_axes(false, _x, _y, _w, _h, _y_range), do: []

  defp render_optional_axes(true, x, y, w, h, y_range),
    do: ChartUtils.render_axes({x, y, w, h}, y_range)

  defp render_optional_legend(false, _x, _y, _normalized), do: []

  defp render_optional_legend(true, x, y, normalized),
    do: ChartUtils.render_legend(x, y, normalized)

  # -- Private --

  defp resolve_ranges([], opts) do
    {
      resolve_or_auto(Keyword.get(opts, :x_range, :auto), {0.0, 1.0}),
      resolve_or_auto(Keyword.get(opts, :y_range, :auto), {0.0, 1.0})
    }
  end

  defp resolve_ranges(points, opts) do
    {auto_x, auto_y} = ChartUtils.auto_range_2d(points)

    {
      resolve_or_auto(Keyword.get(opts, :x_range, :auto), auto_x),
      resolve_or_auto(Keyword.get(opts, :y_range, :auto), auto_y)
    }
  end

  defp resolve_or_auto(:auto, computed), do: computed
  defp resolve_or_auto(explicit, _computed), do: explicit

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
