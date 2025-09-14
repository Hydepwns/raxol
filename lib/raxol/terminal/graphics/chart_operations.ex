defmodule Raxol.Terminal.Graphics.ChartOperations do
  @moduledoc """
  Chart operations and management functions extracted from DataVisualization.
  Contains streaming updates, data processing, and chart maintenance functions.
  """

  require Logger
  alias Raxol.Terminal.Graphics.ChartDataUtils

  @doc """
  Updates all streaming charts in the given state.
  """
  def update_all_streaming_charts(state) do
    updated_charts =
      state.active_charts
      |> Enum.map(fn {chart_id, chart} ->
        case should_update_chart?(chart) do
          true ->
            updated_chart = update_chart_visualization(chart)
            {chart_id, updated_chart}

          false ->
            {chart_id, chart}
        end
      end)
      |> Enum.into(%{})

    %{state | active_charts: updated_charts}
  end

  @doc """
  Updates chart visualization with new data.
  """
  def update_chart_visualization(chart) do
    # Update the chart with new data
    :ok = render_chart_update(chart)
    %{chart | last_update: System.system_time(:millisecond)}
  end

  @doc """
  Checks if a chart needs to be updated based on its update interval.
  """
  def should_update_chart?(chart) do
    update_interval = Map.get(chart.config, :update_interval, 1000)
    now = System.system_time(:millisecond)
    now - chart.last_update >= update_interval
  end

  @doc """
  Handles chart click events.
  """
  def handle_chart_click(chart_id, _event) do
    Logger.debug("Chart clicked: #{chart_id}")
  end

  @doc """
  Handles chart hover events.
  """
  def handle_chart_hover(chart_id, _event) do
    Logger.debug("Chart hover: #{chart_id}")
  end

  @doc """
  Re-renders a chart with updated data.
  """
  def render_chart_update(_chart) do
    # Re-render chart with updated data
    :ok
  end

  @doc """
  Flattens 2D heatmap data into a list of data points.
  """
  def flatten_heatmap_data(data) do
    ChartDataUtils.flatten_heatmap_data(data)
  end

  @doc """
  Converts histogram values into data points with binning.
  """
  def histogram_data_points(values, config) do
    ChartDataUtils.histogram_data_points(values, config)
  end

  @doc """
  Gets data points for scatter plot visualization from the chart state.
  """
  def get_scatter_points(chart_state) do
    chart_state.data_buffer
    # Limit points for performance
    |> Enum.take(1000)
    |> Enum.map(fn point ->
      %{
        x: Map.get(point, :x, 0),
        y: Map.get(point, :y, 0),
        timestamp: Map.get(point, :timestamp, System.system_time(:millisecond))
      }
    end)
  end

  @doc """
  Processes chart data points for real-time updates.
  """
  def process_chart_data_points(chart_state, new_data_points) do
    updated_buffer = new_data_points ++ chart_state.data_buffer
    max_points = Map.get(chart_state.config, :max_points, 1000)

    trimmed_buffer = Enum.take(updated_buffer, max_points)

    %{
      chart_state
      | data_buffer: trimmed_buffer,
        last_update: System.system_time(:millisecond)
    }
  end

  @doc """
  Sets up streaming data connection for a chart.
  """
  def setup_streaming_connection(chart_id, stream_config) do
    # Setup streaming data connection
    Logger.info("Setting up streaming for chart #{chart_id}")

    {:ok,
     %{
       chart_id: chart_id,
       stream_type: Map.get(stream_config, :type, :websocket),
       buffer_size: Map.get(stream_config, :buffer_size, 1000),
       update_interval: Map.get(stream_config, :update_interval, 100),
       connected: true
     }}
  end
end
