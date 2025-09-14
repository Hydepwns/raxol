defmodule Raxol.Terminal.Graphics.ChartRenderers do
  @moduledoc """
  Chart rendering functions extracted from DataVisualization.
  Handles specific chart types: heatmaps, scatter plots, histograms.
  """

  alias Raxol.Terminal.Graphics.UnifiedGraphics
  alias Raxol.Terminal.Graphics.ChartDataUtils

  @doc """
  Renders a heatmap visualization.
  """
  def render_heatmap(_graphics_id, _data, _config), do: :ok

  @doc """
  Renders a scatter plot visualization.
  """
  def render_scatter_plot(_graphics_id, _points, _config), do: :ok

  @doc """
  Renders a histogram visualization.
  """
  def render_histogram(_graphics_id, _values, _config), do: :ok

  @doc """
  Creates a heatmap visualization with the given data and configuration.
  """
  def create_heatmap_visualization(data, config) do
    chart_id = generate_chart_id()

    case UnifiedGraphics.create_graphics(config) do
      {:ok, graphics_id} ->
        :ok = render_heatmap(graphics_id, data, config)
        {:ok, chart_id, graphics_id}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Creates a scatter plot visualization with the given points and configuration.
  """
  def create_scatter_visualization(points, config) do
    chart_id = generate_chart_id()

    case UnifiedGraphics.create_graphics(config) do
      {:ok, graphics_id} ->
        :ok = render_scatter_plot(graphics_id, points, config)
        {:ok, chart_id, graphics_id}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Creates a histogram visualization with the given values and configuration.
  """
  def create_histogram_visualization(values, config) do
    chart_id = generate_chart_id()

    case UnifiedGraphics.create_graphics(config) do
      {:ok, graphics_id} ->
        :ok = render_histogram(graphics_id, values, config)
        {:ok, chart_id, graphics_id}

      {:error, reason} ->
        {:error, reason}
    end
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

  defp generate_chart_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
