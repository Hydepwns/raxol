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
    # Basic validation
    unless is_list(data) and width > 4 and height > 4 do
      DrawingUtils.draw_box_with_text(
        if(data == [], do: "[No Data]", else: "!"),
        bounds
      )
    else
      # Extract values for scaling
      values =
        Enum.map(data, fn item ->
          case item do
            {_label, value} -> value
            %{value: value} -> value
            # Default for invalid items
            _ -> 0
          end
        end)

      max_value = Enum.max_by(data, &elem(&1, 1), fn -> {nil, 0} end) |> elem(1)
      # Ensure min_value is at most 0
      min_value = Enum.min([0 | values])

      # Calculate chart area (leave space for title, axes/labels)
      # Top title, bottom labels
      chart_height = max(1, height - 2)
      # Left axis, right padding
      chart_width = max(1, width - 4)

      # Create empty grid (rows of columns)
      grid = List.duplicate(List.duplicate(Cell.new(" "), width), height)

      # Draw Title
      grid = DrawingUtils.draw_text_centered(grid, 0, title)

      # Draw Y-axis (simple min/max for now)
      grid = DrawingUtils.draw_text(grid, 1, 0, Integer.to_string(max_value))

      grid =
        DrawingUtils.draw_text(
          grid,
          height - 2,
          0,
          Integer.to_string(min_value)
        )

      # Draw simple Y-axis line
      grid =
        Enum.reduce(1..(height - 2), grid, fn y, acc_grid ->
          axis_style = Style.new(fg: :dark_gray)

          DrawingUtils.put_cell(acc_grid, y, 3, %{
            Cell.new("|")
            | style: axis_style
          })
        end)

      # Determine bar width and spacing
      num_bars = Enum.count(data)

      # Calculate widths, accounting for spacing
      # Subtract potential spacing. Fixed typo.
      total_bar_area_width = max(1, chart_width - (num_bars - 1))
      bar_width = max(1, div(total_bar_area_width, num_bars))

      # spacing = if num_bars > 1, do: max(0, div(chart_width - bar_width * num_bars, num_bars - 1)), else: 0
      # Simplified spacing
      spacing = if num_bars > 1, do: 1, else: 0

      # Draw Bars and X-axis labels
      Enum.reduce(Enum.with_index(data), {grid, 4}, fn {{label, value}, _index},
                                                       {acc_grid, current_x} ->
        # Normalize value to chart height
        bar_height =
          if max_value == 0 do
            # Avoid division by zero
            0
          else
            round(
              chart_height * (value - min_value) / max(1, max_value - min_value)
            )
          end

        bar_start_y = height - 2 - bar_height

        # Draw the bar
        new_grid =
          Enum.reduce(0..(bar_width - 1), acc_grid, fn w_offset, inner_grid ->
            Enum.reduce(bar_start_y..(height - 2), inner_grid, fn y,
                                                                  innermost_grid ->
              # Use correct Style module
              style = Style.new(bg: :blue, fg: :blue)
              # Use block character
              cell = %{Cell.new("█") | style: style}

              DrawingUtils.put_cell(
                innermost_grid,
                y,
                current_x + w_offset,
                cell
              )
            end)
          end)

        # Draw X-axis label (truncated)
        label_str =
          case label do
            l when is_binary(l) -> l
            l -> inspect(l)
          end
          |> String.slice(0, bar_width)

        final_grid =
          DrawingUtils.draw_text(new_grid, height - 1, current_x, label_str)

        # Calculate next bar's starting position
        next_x = current_x + bar_width + spacing

        {final_grid, next_x}
      end)
      # Return just the final grid
      |> elem(0)
    end
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
