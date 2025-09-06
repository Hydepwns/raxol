defmodule Raxol.Terminal.Graphics.StreamingManager do
  @moduledoc """
  Streaming chart management and state utilities extracted from DataVisualization.
  Handles streaming updates, scheduling, and chart state management.
  """

  @doc """
  Schedules streaming updates for charts.
  """
  def schedule_streaming_updates do
    Process.send_after(self(), :update_streaming_charts, 1000)
  end

  @doc """
  Initializes metrics for chart tracking.
  """
  def initialize_metrics do
    %{
      charts_created: 0,
      data_points_processed: 0,
      updates_rendered: 0,
      interactions_handled: 0,
      exports_performed: 0,
      started_at: System.system_time(:millisecond)
    }
  end

  @doc """
  Calculates performance statistics for the given state.
  """
  def calculate_performance_stats(state) do
    %{
      active_charts: map_size(state.active_charts),
      streaming_charts: map_size(state.streaming_charts),
      performance_metrics: state.performance_metrics,
      uptime: System.system_time(:millisecond) - state.performance_metrics.started_at
    }
  end

  @doc """
  Updates chart state with new data point.
  """
  def update_chart_with_data_point(chart_state, data_point) do
    updated_buffer = [data_point | chart_state.data_buffer]
    max_points = Map.get(chart_state.config, :max_points, 1000)
    trimmed_buffer = Enum.take(updated_buffer, max_points)
    
    %{chart_state | 
      data_buffer: trimmed_buffer,
      last_update: System.system_time(:millisecond)
    }
  end

  @doc """
  Updates chart state with multiple data points.
  """
  def update_chart_with_data_points(chart_state, data_points) do
    updated_buffer = data_points ++ chart_state.data_buffer
    max_points = Map.get(chart_state.config, :max_points, 1000)
    trimmed_buffer = Enum.take(updated_buffer, max_points)
    
    %{chart_state | 
      data_buffer: trimmed_buffer,
      last_update: System.system_time(:millisecond)
    }
  end

  @doc """
  Creates initial state for the DataVisualization GenServer.
  """
  def create_initial_state(opts) do
    %{
      active_charts: %{},
      streaming_charts: %{},
      performance_metrics: initialize_metrics(),
      config: Map.new(opts)
    }
  end

  @doc """
  Cleans up expired charts from state.
  """
  def cleanup_expired_charts(state) do
    current_time = System.system_time(:millisecond)
    expiry_time = 24 * 60 * 60 * 1000  # 24 hours in milliseconds

    active_charts = state.active_charts
    |> Enum.reject(fn {_id, chart} ->
      current_time - chart.last_update > expiry_time
    end)
    |> Enum.into(%{})

    streaming_charts = state.streaming_charts
    |> Enum.reject(fn {_id, chart} ->
      current_time - chart.last_update > expiry_time
    end)
    |> Enum.into(%{})

    %{state | 
      active_charts: active_charts,
      streaming_charts: streaming_charts
    }
  end

  @doc """
  Updates performance metrics after an operation.
  """
  def update_metrics(state, operation) do
    updated_metrics = case operation do
      :chart_created ->
        %{state.performance_metrics | charts_created: state.performance_metrics.charts_created + 1}
      :data_point_processed ->
        %{state.performance_metrics | data_points_processed: state.performance_metrics.data_points_processed + 1}
      :update_rendered ->
        %{state.performance_metrics | updates_rendered: state.performance_metrics.updates_rendered + 1}
      :interaction_handled ->
        %{state.performance_metrics | interactions_handled: state.performance_metrics.interactions_handled + 1}
      :export_performed ->
        %{state.performance_metrics | exports_performed: state.performance_metrics.exports_performed + 1}
      _ ->
        state.performance_metrics
    end

    %{state | performance_metrics: updated_metrics}
  end

  @doc """
  Creates a chart state structure with common fields.
  """
  def create_chart_state(chart_id, type, config, graphics_id) do
    %{
      id: chart_id,
      type: type,
      config: config,
      data_buffer: [],
      bounds: Map.get(config, :bounds, default_bounds()),
      graphics_id: graphics_id,
      last_update: 0,
      interactive: Map.get(config, :interactive, false),
      animation_state: initialize_animation_state(config)
    }
  end

  @doc """
  Handles common chart creation logic.
  """
  def handle_chart_creation(type, config, state, chart_creation_fn) do
    case validate_chart_config(type, config) do
      :ok ->
        chart_id = generate_chart_id()
        case chart_creation_fn.(chart_id, type, config) do
          {:ok, chart_id, graphics_id} ->
            chart_state = create_chart_state(chart_id, type, config, graphics_id)
            setup_chart_if_interactive(chart_state)
            
            new_active = Map.put(state.active_charts, chart_id, chart_state)
            updated_state = update_metrics(%{state | active_charts: new_active}, :chart_created)
            
            {:reply, {:ok, chart_id}, updated_state}
            
          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  # Private helper functions
  defp default_bounds, do: %{x: 0, y: 0, width: 60, height: 20}
  defp generate_chart_id, do: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  defp validate_chart_config(_type, config) do
    case Map.get(config, :bounds) do
      nil -> {:error, :missing_bounds}
      %{width: w, height: h} when w > 0 and h > 0 -> :ok
      _ -> {:error, :invalid_bounds}
    end
  end
  
  defp initialize_animation_state(config) do
    case Map.get(config, :animation, %{}) do
      %{enabled: true} = anim_config ->
        %{
          enabled: true,
          duration: Map.get(anim_config, :duration, 300),
          easing: Map.get(anim_config, :easing, :ease_out),
          active: false
        }
      _ ->
        %{enabled: false}
    end
  end
  
  defp setup_chart_if_interactive(chart_state) do
    case chart_state.interactive do
      true -> setup_chart_interaction(chart_state)
      false -> :ok
    end
  end
  
  defp setup_chart_interaction(_chart_state) do
    # Would call MouseInteraction.register_interactive_element/2
    :ok  # Simplified for extraction
  end
end