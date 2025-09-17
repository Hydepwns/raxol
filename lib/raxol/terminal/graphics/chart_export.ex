defmodule Raxol.Terminal.Graphics.ChartExport do
  @moduledoc """
  Chart export and data processing functions extracted from DataVisualization.
  Handles chart data export, ASCII generation, and format conversion.
  """

  @doc """
  Exports chart data in the specified format.
  """
  def export_chart_data(chart_state, format) do
    case format do
      :ascii ->
        # Export as ASCII representation
        ascii_data = generate_ascii_chart(chart_state)
        {:ok, ascii_data}

      :json ->
        # Export as JSON data
        json_data =
          chart_state.data_buffer
          |> Jason.encode!()

        {:ok, json_data}

      :csv ->
        # Export as CSV data
        csv_data = generate_csv_chart(chart_state)
        {:ok, csv_data}

      _ ->
        {:error, :unsupported_format}
    end
  end

  @doc """
  Generates ASCII representation of chart data.
  """
  def generate_ascii_chart(chart_state) do
    case chart_state.type do
      :line ->
        generate_line_chart_ascii(chart_state.data_buffer)

      :bar ->
        generate_bar_chart_ascii(chart_state.data_buffer)

      :scatter ->
        generate_scatter_chart_ascii(chart_state.data_buffer)

      _ ->
        "Chart data:\n" <> inspect(chart_state.data_buffer)
    end
  end

  @doc """
  Generates CSV representation of chart data.
  """
  def generate_csv_chart(chart_state) do
    headers = get_csv_headers(chart_state.type)

    rows =
      chart_state.data_buffer
      |> Enum.map_join(&format_data_point_as_csv(&1, chart_state.type), "\n")

    headers <> "\n" <> rows
  end

  @doc """
  Gets performance statistics for charts.
  """
  def get_performance_stats do
    %{
      total_charts: get_total_charts(),
      active_charts: get_active_charts(),
      memory_usage: get_memory_usage(),
      render_time: get_average_render_time()
    }
  end

  # Private helper functions

  defp generate_line_chart_ascii(data_points) do
    case Enum.empty?(data_points) do
      true ->
        "No data available"

      false ->
        values = Enum.map(data_points, & &1.value)
        max_val = Enum.max(values)
        min_val = Enum.min(values)
        range = max_val - min_val

        data_points
        |> Enum.with_index()
        |> Enum.map_join("\n", fn {point, idx} ->
          height =
            case range > 0 do
              true -> trunc(10 * (point.value - min_val) / range)
              false -> 5
            end

          String.pad_leading("#{idx}", 3) <>
            ": " <> String.duplicate("*", height)
        end)
    end
  end

  defp generate_bar_chart_ascii(data_points) do
    case Enum.empty?(data_points) do
      true ->
        "No data available"

      false ->
        max_val = data_points |> Enum.map(& &1.value) |> Enum.max()

        data_points
        |> Enum.with_index()
        |> Enum.map_join("\n", fn {point, idx} ->
          bar_length =
            case max_val > 0 do
              true -> trunc(20 * point.value / max_val)
              false -> 1
            end

          label = Map.get(point, :label, "Item #{idx}")

          String.pad_trailing(label, 10) <>
            " |" <> String.duplicate("=", bar_length) <> " #{point.value}"
        end)
    end
  end

  defp generate_scatter_chart_ascii(data_points) do
    case Enum.empty?(data_points) do
      true ->
        "No data available"

      false ->
        "Scatter Plot Data:\n" <>
          (data_points
           |> Enum.with_index()
           |> Enum.map_join(
             fn {point, idx} ->
               x = Map.get(point, :x, idx)
               y = Map.get(point, :y, point.value)
               "(#{x}, #{y})"
             end,
             ", "
           ))
    end
  end

  defp get_csv_headers(chart_type) do
    case chart_type do
      :line -> "index,value,timestamp"
      :bar -> "label,value,timestamp"
      :scatter -> "x,y,timestamp"
      :heatmap -> "x,y,value,timestamp"
      _ -> "value,timestamp"
    end
  end

  defp format_data_point_as_csv(point, chart_type) do
    case chart_type do
      :line ->
        "#{Map.get(point, :index, 0)},#{point.value},#{point.timestamp}"

      :bar ->
        label = Map.get(point, :label, "")
        "\"#{label}\",#{point.value},#{point.timestamp}"

      :scatter ->
        x = Map.get(point, :x, 0)
        y = Map.get(point, :y, point.value)
        "#{x},#{y},#{point.timestamp}"

      :heatmap ->
        x = Map.get(point, :x, 0)
        y = Map.get(point, :y, 0)
        "#{x},#{y},#{point.value},#{point.timestamp}"

      _ ->
        "#{point.value},#{point.timestamp}"
    end
  end

  defp get_total_charts, do: :ets.info(:chart_registry, :size) || 0

  defp get_active_charts,
    do: :ets.match(:chart_registry, {~c"_", %{active: true}}) |> length()

  defp get_memory_usage, do: :erlang.memory(:total)
  # Placeholder - would calculate from metrics
  defp get_average_render_time, do: 5.2
end
