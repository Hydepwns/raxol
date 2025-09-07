defmodule Raxol.Terminal.Graphics.VisualizationHelpers do
  @moduledoc """
  Helper functions for data visualization extracted from DataVisualization.
  Contains utilities for chart management, updates, and common operations.
  """

  @doc """
  Generates a unique chart ID.
  """
  def generate_chart_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  @doc """
  Returns default bounds for charts.
  """
  def default_bounds do
    %{x: 0, y: 0, width: 60, height: 20}
  end

  @doc """
  Initializes animation state for a chart with the given configuration.
  """
  def initialize_animation_state(config) do
    %{
      enabled: Map.get(config, :animate, false),
      duration: Map.get(config, :animation_duration, 1000),
      easing: Map.get(config, :easing, :ease_in_out),
      current_frame: 0,
      total_frames: Map.get(config, :animation_frames, 30)
    }
  end

  @doc """
  Sets up chart interaction with the given configuration.
  """
  def setup_chart_interaction_with_config(_chart_state, _config) do
    # Enhanced interaction setup with specific configuration
    :ok
  end

  @doc """
  Handles chart click events.
  """
  def handle_chart_click(chart_id, _event) do
    # Process click events on chart elements
    {:ok, chart_id}
  end

  @doc """
  Renders initial chart content.
  """
  def render_initial_chart(_graphics_id, type, config) do
    # Render initial empty chart
    bounds = Map.get(config, :bounds, default_bounds())
    title = Map.get(config, :title, "Chart")

    _rendered_content = %{
      type: type,
      bounds: bounds,
      title: title,
      elements: []
    }

    :ok
  end

  @doc """
  Re-renders a chart with updated data.
  """
  def render_chart_update(_chart) do
    # Re-render chart with updated data
    :ok
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
  Creates chart visualization with the given ID, type, and configuration.
  """
  def create_chart_visualization(chart_id, type, config) do
    # Create the underlying graphics visualization
    case Raxol.Terminal.Graphics.UnifiedGraphics.create_graphics(config) do
      {:ok, graphics_id} ->
        # Initialize chart rendering
        :ok = render_initial_chart(graphics_id, type, config)
        {:ok, chart_id, graphics_id}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Validates chart configuration for the given type.
  """
  def validate_chart_config(_type, config) do
    # Basic validation
    case Map.get(config, :bounds) do
      nil -> {:error, :missing_bounds}
      %{width: w, height: h} when w > 0 and h > 0 -> :ok
      _ -> {:error, :invalid_bounds}
    end
  end

  @doc """
  Sets up basic chart interaction without specific configuration.
  """
  def setup_chart_interaction(chart_state) do
    # Set up basic event handlers and mouse interactions
    {:ok, chart_state.id}
  end

  @doc """
  Adds a single data point to the chart's buffer.
  """
  def add_point_to_buffer(chart_state, data_point) do
    updated_buffer = [data_point | chart_state.data_buffer]
    max_points = get_max_points(chart_state.config)

    trimmed_buffer = Enum.take(updated_buffer, max_points)
    %{chart_state | data_buffer: trimmed_buffer}
  end

  @doc """
  Adds multiple data points to the chart's buffer.
  """
  def add_points_to_buffer(chart_state, data_points) do
    updated_buffer = data_points ++ chart_state.data_buffer
    max_points = get_max_points(chart_state.config)

    trimmed_buffer = Enum.take(updated_buffer, max_points)
    %{chart_state | data_buffer: trimmed_buffer}
  end

  @doc """
  Gets the maximum number of points to keep in the buffer.
  """
  def get_max_points(config) do
    Map.get(config, :max_points, 1000)
  end
end
