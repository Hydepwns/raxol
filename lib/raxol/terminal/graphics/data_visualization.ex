defmodule Raxol.Terminal.Graphics.DataVisualization do
  @moduledoc """
  Advanced data visualization component library for terminal graphics.

  This module extends the existing chart capabilities with:
  - Real-time data streaming visualizations
  - Interactive data exploration tools
  - Advanced chart types (heatmaps, scatter plots, histograms, etc.)
  - Multi-dimensional data visualization
  - Export capabilities for graphics
  - Performance-optimized rendering for large datasets

  Built on top of existing Raxol visualization infrastructure, this module
  provides enterprise-grade data visualization capabilities.

  ## Features

  ### Advanced Chart Types
  - Heatmaps with customizable color scales
  - Scatter plots with clustering visualization
  - Histograms and distribution plots
  - Multi-series time-series charts
  - Bubble charts with size/color encoding
  - Treemaps for hierarchical data

  ### Real-time Capabilities
  - Streaming data visualization with configurable buffers
  - Live updates with smooth animations
  - Automatic scaling and zooming
  - Performance monitoring and throttling
  - Memory-efficient data windowing

  ### Interactive Features
  - Mouse-driven zoom and pan
  - Data point selection and highlighting
  - Dynamic filtering and grouping
  - Tooltip information on hover
  - Click-to-drill-down functionality

  ## Usage

      # Create a real-time line chart
      {:ok, chart} = DataVisualization.create_streaming_chart(:line, %{
        title: "CPU Usage",
        max_points: 100,
        update_interval: 1000,  # 1 second
        auto_scale: true
      })

      # Stream data points
      DataVisualization.add_data_point(chart, %{
        timestamp: System.system_time(:millisecond),
        value: 75.5,
        series: "cpu_usage"
      })

      # Create interactive heatmap
      {:ok, heatmap} = DataVisualization.create_heatmap(data, %{
        width: 80, height: 24,
        color_scale: :viridis,
        interactive: true
      })
  """

  use Raxol.Core.Behaviours.BaseManager
  require Logger

  alias Raxol.Terminal.Graphics.ChartRenderers
  alias Raxol.Terminal.Graphics.VisualizationHelpers
  alias Raxol.Terminal.Graphics.ChartOperations
  alias Raxol.Terminal.Graphics.ChartExport
  alias Raxol.Terminal.Graphics.StreamingManager

  @type chart_id :: String.t()
  @type data_point :: %{
          timestamp: non_neg_integer(),
          value: number(),
          series: String.t(),
          metadata: map()
        }
  @type streaming_config :: %{
          max_points: non_neg_integer(),
          update_interval: non_neg_integer(),
          auto_scale: boolean(),
          buffer_size: non_neg_integer(),
          animation_enabled: boolean()
        }
  @type visualization_type ::
          :line
          | :bar
          | :scatter
          | :heatmap
          | :histogram
          | :bubble
          | :treemap
          | :sparkline
  @type chart_state :: %{
          id: chart_id(),
          type: visualization_type(),
          config: map(),
          data_buffer: [data_point()],
          bounds: map(),
          graphics_id: non_neg_integer(),
          last_update: non_neg_integer(),
          interactive: boolean(),
          animation_state: map()
        }

  defstruct [
    :active_charts,
    :streaming_charts,
    :performance_metrics,
    :config
  ]

  # Public API

  @doc """
  Starts the data visualization manager.
  """

  #  def start_link(opts \\ []) do
  #    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  #  end

  @doc """
  Creates a real-time streaming chart.

  ## Parameters

  - `type` - Chart type (:line, :bar, :scatter, etc.)
  - `config` - Chart configuration including streaming settings

  ## Returns

  - `{:ok, chart_id}` - Successfully created streaming chart
  - `{:error, reason}` - Failed to create chart

  ## Examples

      {:ok, chart_id} = DataVisualization.create_streaming_chart(:line, %{
        title: "Network Throughput",
        max_points: 200,
        update_interval: 500,  # 500ms updates
        series: ["download", "upload"],
        bounds: %{x: 0, y: 0, width: 80, height: 20},
        auto_scale: true,
        animation: %{enabled: true, duration: 300}
      })
  """
  @spec create_streaming_chart(visualization_type(), map()) ::
          {:ok, chart_id()} | {:error, term()}
  def create_streaming_chart(type, config) do
    GenServer.call(__MODULE__, {:create_streaming_chart, type, config})
  end

  @doc """
  Adds a data point to a streaming chart.

  ## Examples

      DataVisualization.add_data_point(chart_id, %{
        timestamp: System.system_time(:millisecond),
        value: 85.2,
        series: "cpu_usage",
        metadata: %{core: 0, temperature: 65}
      })
  """
  @spec add_data_point(chart_id(), data_point()) :: :ok | {:error, term()}
  def add_data_point(chart_id, data_point) do
    GenServer.cast(__MODULE__, {:add_data_point, chart_id, data_point})
  end

  @doc """
  Adds multiple data points efficiently.

  ## Examples

      points = [
        %{timestamp: t1, value: 10, series: "cpu"},
        %{timestamp: t2, value: 20, series: "cpu"},
        %{timestamp: t3, value: 15, series: "memory"}
      ]
      
      DataVisualization.add_data_points(chart_id, points)
  """
  @spec add_data_points(chart_id(), [data_point()]) :: :ok | {:error, term()}
  def add_data_points(chart_id, data_points) do
    GenServer.cast(__MODULE__, {:add_data_points, chart_id, data_points})
  end

  @doc """
  Creates an interactive heatmap visualization.

  ## Parameters

  - `data` - 2D array of numerical data
  - `config` - Heatmap configuration

  ## Examples

      # Create temperature heatmap
      data = generate_2d_temperature_data(24, 60)  # 24 hours x 60 minutes
      
      {:ok, heatmap_id} = DataVisualization.create_heatmap(data, %{
        title: "Temperature Over Time",
        x_labels: hour_labels,
        y_labels: minute_labels,
        color_scale: :thermal,
        bounds: %{x: 5, y: 5, width: 70, height: 20},
        interactive: true,
        tooltip_enabled: true
      })
  """
  @spec create_heatmap([[number()]], map()) ::
          {:ok, chart_id()} | {:error, term()}
  def create_heatmap(data, config) do
    GenServer.call(__MODULE__, {:create_heatmap, data, config})
  end

  @doc """
  Creates a scatter plot with optional clustering visualization.

  ## Examples

      points = [
        %{x: 10, y: 20, size: 5, color: :blue, cluster: 1},
        %{x: 15, y: 25, size: 8, color: :red, cluster: 2}
      ]
      
      {:ok, scatter_id} = DataVisualization.create_scatter_plot(points, %{
        title: "Data Clustering",
        show_clusters: true,
        cluster_colors: [:blue, :red, :green],
        interactive: true
      })
  """
  @spec create_scatter_plot([map()], map()) ::
          {:ok, chart_id()} | {:error, term()}
  def create_scatter_plot(points, config) do
    GenServer.call(__MODULE__, {:create_scatter_plot, points, config})
  end

  @doc """
  Creates a histogram from data values.

  ## Examples

      values = [1.2, 1.5, 1.8, 2.1, 2.3, 2.8, 3.1, 3.5]
      
      {:ok, hist_id} = DataVisualization.create_histogram(values, %{
        title: "Value Distribution",
        bins: 10,
        show_statistics: true,
        bounds: %{x: 0, y: 0, width: 60, height: 15}
      })
  """
  @spec create_histogram([number()], map()) ::
          {:ok, chart_id()} | {:error, term()}
  def create_histogram(values, config) do
    GenServer.call(__MODULE__, {:create_histogram, values, config})
  end

  @doc """
  Enables interactive features for a chart.

  ## Examples

      DataVisualization.enable_interaction(chart_id, %{
        zoom: true,
        pan: true,
        select: true,
        hover_tooltip: true
      })
  """
  @spec enable_interaction(chart_id(), map()) :: :ok | {:error, term()}
  def enable_interaction(chart_id, interaction_config) do
    GenServer.call(
      __MODULE__,
      {:enable_interaction, chart_id, interaction_config}
    )
  end

  @doc """
  Exports a chart to various formats.

  ## Examples

      # Export as ASCII art
      {:ok, ascii_data} = DataVisualization.export_chart(chart_id, :ascii)
      
      # Export as JSON data
      {:ok, json_data} = DataVisualization.export_chart(chart_id, :json)
      
      # Export as SVG (if supported)
      {:ok, svg_data} = DataVisualization.export_chart(chart_id, :svg)
  """
  @spec export_chart(chart_id(), :ascii | :json | :svg | :png) ::
          {:ok, binary()} | {:error, term()}
  def export_chart(chart_id, format) do
    GenServer.call(__MODULE__, {:export_chart, chart_id, format})
  end

  @doc """
  Gets performance statistics for visualization operations.
  """
  @spec get_performance_stats() :: map()
  def get_performance_stats do
    GenServer.call(__MODULE__, :get_performance_stats)
  end

  # GenServer Implementation

  @impl true
  def init_manager(opts) do
    initial_state = StreamingManager.create_initial_state(opts)
    StreamingManager.schedule_streaming_updates()
    {:ok, initial_state}
  end

  @impl true
  def handle_manager_call({:create_streaming_chart, type, config}, _from, state) do
    case StreamingManager.handle_chart_creation(
           type,
           config,
           state,
           fn chart_id, chart_type, cfg ->
             VisualizationHelpers.create_chart_visualization(
               chart_id,
               chart_type,
               cfg
             )
           end
         ) do
      {:reply, {:ok, chart_id}, updated_state} ->
        chart_state = Map.get(updated_state.active_charts, chart_id)

        new_streaming =
          Map.put(updated_state.streaming_charts, chart_id, chart_state)

        {:reply, {:ok, chart_id},
         %{updated_state | streaming_charts: new_streaming}}

      result ->
        result
    end
  end

  @impl true
  def handle_manager_call({:create_heatmap, data, config}, _from, state) do
    StreamingManager.handle_chart_creation(
      :heatmap,
      config,
      state,
      fn _chart_id, _type, cfg ->
        ChartRenderers.create_heatmap_visualization(data, cfg)
      end
    )
  end

  @impl true
  def handle_manager_call({:create_scatter_plot, points, config}, _from, state) do
    StreamingManager.handle_chart_creation(
      :scatter,
      config,
      state,
      fn _chart_id, _type, cfg ->
        ChartRenderers.create_scatter_visualization(points, cfg)
      end
    )
  end

  @impl true
  def handle_manager_call({:create_histogram, values, config}, _from, state) do
    StreamingManager.handle_chart_creation(
      :histogram,
      config,
      state,
      fn _chart_id, _type, cfg ->
        ChartRenderers.create_histogram_visualization(values, cfg)
      end
    )
  end

  @impl true
  def handle_manager_call(
        {:enable_interaction, chart_id, interaction_config},
        _from,
        state
      ) do
    case Map.get(state.active_charts, chart_id) do
      nil ->
        {:reply, {:error, :chart_not_found}, state}

      chart_state ->
        :ok =
          VisualizationHelpers.setup_chart_interaction_with_config(
            chart_state,
            interaction_config
          )

        updated_chart = %{chart_state | interactive: true}
        new_active = Map.put(state.active_charts, chart_id, updated_chart)
        {:reply, :ok, %{state | active_charts: new_active}}
    end
  end

  @impl true
  def handle_manager_call({:export_chart, chart_id, format}, _from, state) do
    case Map.get(state.active_charts, chart_id) do
      nil ->
        {:reply, {:error, :chart_not_found}, state}

      chart_state ->
        case ChartExport.export_chart_data(chart_state, format) do
          {:ok, exported_data} ->
            {:reply, {:ok, exported_data}, state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_manager_call(:get_performance_stats, _from, state) do
    stats = StreamingManager.calculate_performance_stats(state)
    {:reply, stats, state}
  end

  @impl true
  def handle_manager_cast({:add_data_point, chart_id, data_point}, state) do
    case Map.get(state.streaming_charts, chart_id) do
      nil ->
        {:noreply, state}

      chart_state ->
        updated_chart =
          VisualizationHelpers.add_point_to_buffer(chart_state, data_point)

        new_streaming = Map.put(state.streaming_charts, chart_id, updated_chart)
        {:noreply, %{state | streaming_charts: new_streaming}}
    end
  end

  @impl true
  def handle_manager_cast({:add_data_points, chart_id, data_points}, state) do
    case Map.get(state.streaming_charts, chart_id) do
      nil ->
        {:noreply, state}

      chart_state ->
        updated_chart =
          VisualizationHelpers.add_points_to_buffer(chart_state, data_points)

        new_streaming = Map.put(state.streaming_charts, chart_id, updated_chart)
        {:noreply, %{state | streaming_charts: new_streaming}}
    end
  end

  @impl true
  def handle_manager_info(:update_streaming_charts, state) do
    new_state = ChartOperations.update_all_streaming_charts(state)
    StreamingManager.schedule_streaming_updates()
    {:noreply, new_state}
  end

  # All helper functions have been moved to specialized modules:
  # - ChartRenderers: Chart-specific rendering functions  
  # - VisualizationHelpers: Chart utilities and configuration
  # - ChartOperations: Chart updates and streaming operations
  # - ChartExport: Data export and ASCII generation
  # - StreamingManager: State management and streaming coordination
end
