defmodule Raxol.Core.Renderer.Views.Chart do
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
    type = Keyword.get(opts, :type, :bar)
    orientation = Keyword.get(opts, :orientation, :vertical)
    series = Keyword.get(opts, :series, [])
    width = Keyword.get(opts, :width, 40)
    height = Keyword.get(opts, :height, 10)
    show_axes = Keyword.get(opts, :show_axes, true)
    show_labels = Keyword.get(opts, :show_labels, true)
    show_legend = Keyword.get(opts, :show_legend, true)
    style = Keyword.get(opts, :style, [])

    # Calculate data range
    {min, max} = calculate_range(series, opts[:min], opts[:max])

    # Create chart content based on type
    content =
      case type do
        :bar -> create_bar_chart(series, min, max, width, height, orientation)
        :line -> create_line_chart(series, min, max, width, height)
        :sparkline -> create_sparkline(series, min, max, width)
      end

    # Add axes if needed
    content =
      if show_axes do
        add_axes(content, min, max, width, height, orientation)
      else
        content
      end

    # Add labels if needed
    content =
      if show_labels do
        add_labels(content, series, width, height)
      else
        content
      end

    # Add legend if needed
    content =
      if show_legend do
        add_legend(content, series)
      else
        content
      end

    View.box([style: style], do: content)
  end

  # Private Helpers

  defp calculate_range(series, min, max) do
    data = Enum.flat_map(series, & &1.data)

    {
      min || Enum.min(data),
      max || Enum.max(data)
    }
  end

  defp create_bar_chart(series, min, max, width, height, orientation) do
    case orientation do
      :vertical -> create_vertical_bars(series, min, max, width, height)
      :horizontal -> create_horizontal_bars(series, min, max, width, height)
    end
  end

  defp create_vertical_bars(series, min, max, width, height) do
    bar_width = div(width, Enum.sum(Enum.map(series, &length(&1.data))))

    bars =
      series
      |> Enum.flat_map(fn %{data: data, color: color} ->
        data
        |> Enum.map(fn value ->
          bar_height = scale_value(value, min, max, 1, height)
          chars = create_vertical_bar(bar_height, height)

          View.text(chars,
            size: {bar_width, height},
            fg: color
          )
        end)
      end)

    View.flex(direction: :row, children: bars)
  end

  defp create_horizontal_bars(series, min, max, width, height) do
    bar_height = div(height, Enum.sum(Enum.map(series, &length(&1.data))))

    bars =
      series
      |> Enum.flat_map(fn %{data: data, color: color} ->
        data
        |> Enum.map(fn value ->
          bar_width = scale_value(value, min, max, 1, width)
          chars = create_horizontal_bar(bar_width, width)

          View.text(chars,
            size: {width, bar_height},
            fg: color
          )
        end)
      end)

    View.flex(direction: :column, children: bars)
  end

  defp create_line_chart(series, min, max, width, height) do
    lines =
      series
      |> Enum.map(fn %{data: data, color: color} ->
        points =
          data
          |> Enum.with_index()
          |> Enum.map(fn {value, x} ->
            y = scale_value(value, min, max, 0, height - 1)
            {x, y}
          end)

        create_line(points, width, height, color)
      end)

    View.box(children: lines)
  end

  defp create_sparkline([series], min, max, width) do
    %{data: data, color: color} = series
    values = Enum.map(data, &scale_value(&1, min, max, 0, 7))
    chars = Enum.map(values, &Enum.at(@bar_chars, floor(&1)))

    View.text(Enum.join(chars),
      size: {width, 1},
      fg: color
    )
  end

  defp create_vertical_bar(height, total_height) do
    full = div(height, 1)
    remainder = height - full

    full_blocks = String.duplicate("█", full)

    partial_block =
      if remainder > 0 do
        index = floor(remainder * 8)
        Enum.at(@bar_chars, index)
      else
        ""
      end

    padding = String.duplicate(" ", total_height - full - 1)

    padding <> partial_block <> full_blocks
  end

  defp create_horizontal_bar(width, total_width) do
    full = div(width, 1)
    remainder = width - full

    full_blocks = String.duplicate("█", full)

    partial_block =
      if remainder > 0 do
        index = floor(remainder * 8)
        Enum.at(@bar_chars, index)
      else
        ""
      end

    padding = String.duplicate(" ", total_width - full - 1)

    full_blocks <> partial_block <> padding
  end

  defp create_line(points, width, height, color) do
    # Create a blank canvas
    canvas =
      for _y <- 0..(height - 1) do
        for _x <- 0..(width - 1) do
          " "
        end
      end

    # Draw lines between points
    canvas =
      Enum.chunk_every(points, 2, 1, :discard)
      |> Enum.reduce(canvas, fn [{x1, y1}, {x2, y2}], acc ->
        draw_line(acc, {x1, y1}, {x2, y2})
      end)

    # Convert to view cells
    canvas
    |> Enum.with_index()
    |> Enum.map(fn {row, y} ->
      row
      |> Enum.with_index()
      |> Enum.map(fn {cell, x} ->
        if cell do
          View.text(cell,
            position: {x, y},
            fg: color
          )
        end
      end)
      |> Enum.reject(&is_nil/1)
    end)
    |> List.flatten()
  end

  defp draw_line(canvas, {x1, y1}, {x2, y2}) do
    dx = abs(x2 - x1)
    _dy = abs(y2 - y1)
    _error = div(dx, 2)
    _ystep = if y1 < y2, do: 1, else: -1

    Enum.reduce(x1..x2, canvas, fn x, acc ->
      pos = {x, y1}
      put_in(acc, pos_to_path(pos), "•")
    end)
  end

  defp pos_to_path({x, y}) do
    [Access.at(y), Access.at(x)]
  end

  defp scale_value(value, min, max, out_min, out_max) do
    ratio = (value - min) / (max - min)
    out_min + ratio * (out_max - out_min)
  end

  defp add_axes(content, min, max, width, height, _orientation) do
    y_axis = create_y_axis(min, max, height)
    x_axis = create_x_axis(width)

    View.box(
      children: [
        View.box(
          children: [
            y_axis,
            content
          ]
        ),
        x_axis
      ]
    )
  end

  defp create_y_axis(min, max, height) do
    labels =
      for i <- 0..(height - 1) do
        value = min + i * ((max - min) / (height - 1))

        View.text(
          "#{Float.round(value, 1)} │",
          position: {0, height - i - 1}
        )
      end

    View.box(children: labels)
  end

  defp create_x_axis(width) do
    View.text(String.duplicate("─", width))
  end

  defp add_labels(content, _series, _width, _height) do
    # Add x-axis labels
    content
  end

  defp add_legend(content, series) do
    legend_items =
      series
      |> Enum.map(fn %{name: name, color: color} ->
        View.flex(
          direction: :row,
          children: [
            View.text("█ ", fg: color),
            View.text(name)
          ]
        )
      end)

    View.box(
      children: [
        content,
        View.flex(
          direction: :column,
          children: legend_items
        )
      ]
    )
  end
end
