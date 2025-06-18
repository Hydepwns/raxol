defmodule Raxol.Plugins.Visualization.ChartRenderer do
  @moduledoc """
  Handles rendering logic for chart visualizations within the VisualizationPlugin.
  """

  require Raxol.Core.Runtime.Log
  alias Raxol.Terminal.Cell
  alias Raxol.Plugins.Visualization.DrawingUtils
  alias Raxol.Style

  # Define module attributes for thresholds previously in the plugin
  @max_chart_data_points 100

  @doc """
  Public entry point for rendering chart content.
  Handles bounds checking, error handling, and calls the internal drawing logic.
  Expects bounds to be a map like %{width: w, height: h}.
  """
  def render_chart_content(
        data,
        opts,
        %{width: width, height: height} = bounds,
        _state
      ) do
    title = Map.get(opts, :title, "Chart")

    if width < 5 or height < 3 do
      Raxol.Core.Runtime.Log.warning_with_context(
        "[ChartRenderer] Bounds too small for chart rendering: #{inspect(bounds)}",
        %{}
      )

      DrawingUtils.draw_box_with_text("!", bounds)
    else
      try do
        # First, sample the data if it's too large
        sampled_data = sample_chart_data(data)
        # Log if sampling occurred
        log_sampling(data, sampled_data)

        # Draw the chart with sampled data
        draw_tui_bar_chart(sampled_data, title, bounds)
      rescue
        e ->
          stacktrace = __STACKTRACE__

          Raxol.Core.Runtime.Log.error(
            "[ChartRenderer] Error rendering chart: #{inspect(e)}\nStacktrace: #{inspect(stacktrace)}"
          )

          DrawingUtils.draw_box_with_text("[Render Error]", bounds)
      end
    end
  end

  # --- Private Chart Drawing Logic ---

  @doc false
  # Draws a simple text-based bar chart within the given bounds.
  # Assumes data is a list of {label, value} tuples or maps with :label and :value keys.
  defp draw_tui_bar_chart(data, title, %{width: width, height: height} = bounds) do
    if is_list(data) and width > 4 and height > 4 do
      {max_value, min_value} = calculate_value_bounds(data)
      {chart_height, chart_width} = calculate_chart_dimensions(width, height)
      grid = initialize_grid(width, height, title, max_value, min_value)

      draw_chart_content(
        grid,
        data,
        max_value,
        min_value,
        chart_height,
        chart_width,
        height,
        width
      )
    else
      DrawingUtils.draw_box_with_text(
        if(data == [], do: "[No Data]", else: "!"),
        bounds
      )
    end
  end

  defp calculate_value_bounds(data) do
    values =
      Enum.map(data, fn
        {_label, value} -> value
        %{value: value} -> value
        _ -> 0
      end)

    max_value = Enum.max_by(data, &elem(&1, 1), fn -> {nil, 0} end) |> elem(1)
    min_value = Enum.min([0 | values])
    {max_value, min_value}
  end

  defp calculate_chart_dimensions(width, height) do
    chart_height = max(1, height - 2)
    chart_width = max(1, width - 4)
    {chart_height, chart_width}
  end

  defp initialize_grid(width, height, title, max_value, min_value) do
    grid = List.duplicate(List.duplicate(Cell.new(" "), width), height)
    grid = DrawingUtils.draw_text_centered(grid, 0, title)
    grid = DrawingUtils.draw_text(grid, 1, 0, Integer.to_string(max_value))

    grid =
      DrawingUtils.draw_text(grid, height - 2, 0, Integer.to_string(min_value))

    draw_y_axis(grid, height)
  end

  defp draw_y_axis(grid, height) do
    Enum.reduce(1..(height - 2), grid, fn y, acc_grid ->
      axis_style = Style.new(fg: :dark_gray)

      DrawingUtils.put_cell(acc_grid, y, 3, %{Cell.new("|") | style: axis_style})
    end)
  end

  defp draw_chart_content(
         grid,
         data,
         max_value,
         min_value,
         chart_height,
         chart_width,
         height,
         _width
       ) do
    num_bars = Enum.count(data)
    total_bar_area_width = max(1, chart_width - (num_bars - 1))
    bar_width = max(1, div(total_bar_area_width, num_bars))
    spacing = if num_bars > 1, do: 1, else: 0

    Enum.reduce(Enum.with_index(data), {grid, 4}, fn {{label, value}, _index},
                                                     {acc_grid, current_x} ->
      bar_height =
        calculate_bar_height(value, max_value, min_value, chart_height)

      bar_start_y = height - 2 - bar_height
      new_grid = draw_bar(acc_grid, bar_width, bar_start_y, height, current_x)

      draw_label_and_advance(
        new_grid,
        label,
        bar_width,
        height,
        current_x,
        spacing
      )
    end)
    |> elem(0)
  end

  defp calculate_bar_height(value, max_value, min_value, chart_height) do
    if max_value == 0 do
      0
    else
      round(chart_height * (value - min_value) / max(1, max_value - min_value))
    end
  end

  defp draw_bar(grid, bar_width, bar_start_y, height, current_x) do
    Enum.reduce(0..(bar_width - 1), grid, fn w_offset, inner_grid ->
      draw_bar_column(inner_grid, bar_start_y, height, current_x + w_offset)
    end)
  end

  defp draw_bar_column(grid, bar_start_y, height, x) do
    Enum.reduce(bar_start_y..(height - 2), grid, fn y, acc_grid ->
      style = Style.new(bg: :blue, fg: :blue)
      cell = %{Cell.new("█") | style: style}
      DrawingUtils.put_cell(acc_grid, y, x, cell)
    end)
  end

  defp draw_label_and_advance(
         grid,
         label,
         bar_width,
         height,
         current_x,
         spacing
       ) do
    label_str = format_label(label, bar_width)
    final_grid = DrawingUtils.draw_text(grid, height - 1, current_x, label_str)
    next_x = current_x + bar_width + spacing
    {final_grid, next_x}
  end

  defp format_label(label, bar_width) do
    case label do
      l when is_binary(l) -> l
      l -> inspect(l)
    end
    |> String.slice(0, bar_width)
  end

  # --- Private Data Handling ---

  @doc false
  # Sample data if it exceeds the threshold using simple interval sampling.
  defp sample_chart_data(data) when is_list(data) do
    data_length = length(data)

    if data_length <= @max_chart_data_points do
      # No sampling needed
      data
    else
      # Calculate sampling interval
      interval = ceil(data_length / @max_chart_data_points)
      # Take every nth element
      data
      |> Enum.with_index()
      |> Enum.filter(fn {_item, index} -> rem(index, interval) == 0 end)
      |> Enum.map(fn {item, _index} -> item end)
    end
  end

  # Return non-lists as is
  defp sample_chart_data(other), do: other

  defp log_sampling(original_data, sampled_data) do
    data_length = if is_list(original_data), do: length(original_data), else: 0
    sampled_length = if is_list(sampled_data), do: length(sampled_data), else: 0

    if data_length != sampled_length and data_length > 0 do
      Raxol.Core.Runtime.Log.debug(
        "[ChartRenderer] Data sampled for chart: #{data_length} -> #{sampled_length} points"
      )
    end
  end
end
