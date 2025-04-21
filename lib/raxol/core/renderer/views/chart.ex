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

    View.box(style: style, children: content)
  end

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
      :vertical -> create_vertical_bars(series, min, max, width, height)
      :horizontal -> create_horizontal_bars(series, min, max, width, height)
    end
  end

  defp create_vertical_bars(series, min, max, width, height) do
    # Calculate total data points only if series is not empty
    total_points = Enum.sum(Enum.map(series, &length(&1.data)))

    # Handle empty data case
    if total_points == 0 do
      View.flex direction: :row do
        # Return empty view
        []
      end
    else
      bar_width = div(width, total_points)

      bars =
        series
        |> Enum.flat_map(fn %{data: data, color: color} ->
          data
          |> Enum.map(fn value ->
            bar_height = scale_value(value, min, max, 1, height) |> round()
            chars = create_vertical_bar(bar_height, height)

            View.text(chars,
              size: {bar_width, height},
              fg: color
            )
          end)
        end)

      View.flex direction: :row do
        bars
      end
    end
  end

  defp create_horizontal_bars(series, min, max, width, height) do
    # Calculate total data points only if series is not empty
    total_points = Enum.sum(Enum.map(series, &length(&1.data)))

    # Handle empty data case
    if total_points == 0 do
      View.flex direction: :column do
        # Return empty view
        []
      end
    else
      bar_height = div(height, total_points)

      bars =
        series
        |> Enum.flat_map(fn %{data: data, color: color} ->
          data
          |> Enum.map(fn value ->
            bar_width = scale_value(value, min, max, 1, width) |> round()
            chars = create_horizontal_bar(bar_width, width)

            View.text(chars,
              size: {width, bar_height},
              fg: color
            )
          end)
        end)

      View.flex direction: :column do
        bars
      end
    end
  end

  defp create_line_chart(series, min, max, width, height) do
    lines =
      series
      |> Enum.map(fn %{data: data, color: color} ->
        points =
          data
          |> Enum.with_index()
          |> Enum.map(fn {value, x_idx} ->
            # Scale x based on index and width
            x = floor(x_idx / (length(data) - 1) * (width - 1))
            # Scale y based on value and height, then floor
            y = floor(scale_value(value, min, max, 0, height - 1))
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

    # Pad the character list with spaces if it's shorter than the width
    padded_chars =
      if length(chars) < width do
        chars ++ List.duplicate(" ", width - length(chars))
      else
        # Optionally truncate if longer? For now, let View.text handle it.
        chars
      end

    View.text(Enum.join(padded_chars),
      size: {width, 1},
      fg: color
    )
  end

  defp create_vertical_bar(bar_height, total_height)
       when is_integer(bar_height) and is_integer(total_height) do
    # Clamp height to valid range
    clamped_height = :erlang.max(0, :erlang.min(bar_height, total_height))

    # Each char represents 8 levels
    full = div(clamped_height, 8)
    remainder = rem(clamped_height, 8)

    full_blocks = String.duplicate("█", full)

    partial_block =
      if remainder > 0 do
        Enum.at(@bar_chars, remainder)
      else
        ""
      end

    # Calculate needed padding from the top
    padding_size = total_height - full - String.length(partial_block)
    padding = String.duplicate(" ", :erlang.max(0, padding_size))

    # Build bar from top down
    padding <> partial_block <> full_blocks
  end

  defp create_horizontal_bar(bar_width, total_width)
       when is_integer(bar_width) and is_integer(total_width) do
    # Clamp width to valid range
    clamped_width = :erlang.max(0, :erlang.min(bar_width, total_width))

    # Each char represents 8 levels
    full = div(clamped_width, 8)
    remainder = rem(clamped_width, 8)

    full_blocks = String.duplicate("█", full)

    partial_block =
      if remainder > 0 do
        Enum.at(@bar_chars, remainder)
      else
        ""
      end

    # Calculate needed padding from the right
    padding_size = total_width - full - String.length(partial_block)
    padding = String.duplicate(" ", :erlang.max(0, padding_size))

    # Build bar from left to right
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
    # Basic Bresenham's line algorithm (simplified for now)
    # TODO: Implement a proper Bresenham or similar algorithm
    # For now, just mark the start and end points
    canvas = put_in(canvas, [Access.at(y1), Access.at(x1)], "•")
    put_in(canvas, [Access.at(y2), Access.at(x2)], "•")
  end

  defp scale_value(value, min, max, new_min, new_max) do
    # Avoid division by zero if min == max
    if max == min do
      new_min
    else
      (value - min) / (max - min) * (new_max - new_min) + new_min
    end
  end

  defp add_axes(content, _min, _max, _width, _height, _orientation) do
    # TODO: Refactor to use a more structured approach for drawing axes
    # Consider using a dedicated drawing library or module for better separation
    # Placeholder implementation
    content
  end

  defp add_labels(content, _series, _width, _height) do
    # TODO: Implement label drawing logic
    content
  end

  defp add_legend(content, _series) do
    # TODO: Implement legend drawing logic
    content
  end
end
