defmodule Raxol.Metrics.Visualizer do
  @moduledoc """
  Provides visualization capabilities for Raxol performance metrics.
  Uses Contex to generate charts and graphs for various performance indicators.
  """

  alias Contex.{Plot, BarChart, Dataset, Point, PointPlot}

  @doc """
  Creates a bar chart visualization for event processing times.
  
  ## Parameters
    * data - List of {event_type, processing_time} tuples
    * options - Optional configuration for the chart
  """
  def create_event_timing_chart(data, options \\ []) do
    dataset = Dataset.new(data, ["Event Type", "Processing Time (ms)"])
    
    BarChart.new(dataset)
    |> BarChart.titles("Event Processing Times", "Event Types")
    |> Plot.new(options[:width] || 600, options[:height] || 400)
    |> Plot.to_svg()
  end

  @doc """
  Creates a scatter plot for event throughput over time.
  
  ## Parameters
    * data - List of {timestamp, events_per_second} tuples
    * options - Optional configuration for the chart
  """
  def create_throughput_plot(data, options \\ []) do
    dataset = Dataset.new(data, ["Time", "Events/sec"])
    
    PointPlot.new(dataset)
    |> PointPlot.titles("Event Throughput", "Time")
    |> Plot.new(options[:width] || 600, options[:height] || 400)
    |> Plot.to_svg()
  end

  @doc """
  Creates a line chart for memory usage trends.
  
  ## Parameters
    * data - List of {timestamp, memory_usage} tuples
    * options - Optional configuration for the chart
  """
  def create_memory_usage_chart(data, options \\ []) do
    dataset = Dataset.new(data, ["Time", "Memory Usage (MB)"])
    
    LinePlot.new(dataset)
    |> LinePlot.titles("Memory Usage Over Time", "Time")
    |> Plot.new(options[:width] || 600, options[:height] || 400)
    |> Plot.to_svg()
  end
end 