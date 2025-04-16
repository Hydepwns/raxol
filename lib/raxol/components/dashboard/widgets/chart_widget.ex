defmodule Raxol.Components.Dashboard.Widgets.ChartWidget do
  @moduledoc """
  A dashboard widget that displays a chart using Raxol.Components.Visualization.Chart.
  This module is responsible for holding the chart's state (data, config)
  and providing a data structure for rendering, rather than rendering directly.
  """

  # alias Raxol.View # <-- Remove unused alias
  # alias Raxol.Components.Visualization.Chart # <-- Remove unused alias

  # --- State ---

  defstruct [:id, :config, :data, :component_opts]

  # --- Lifecycle / State Management ---

  def init(opts) do
    widget_config = Keyword.fetch!(opts, :widget_config)

    id = Map.fetch!(widget_config, :id)
    # Extract data and component_opts, providing defaults if missing
    # Use placeholder if no data provided
    data = Map.get(widget_config, :data, placeholder_data())
    # Use defaults if no opts provided
    component_opts =
      Map.get(widget_config, :component_opts, default_component_opts())

    # Keep the original config map for potential future use (e.g., title in WidgetContainer)
    %__MODULE__{
      id: id,
      # Store the whole original config
      config: widget_config,
      data: data,
      component_opts: component_opts
    }
  end

  # --- Data Structure for Rendering ---

  def render_data_structure(assigns) do
    %{
      type: :chart,
      data: assigns.data,
      # Pass the component_opts map
      opts: chart_opts(assigns.component_opts)
    }
  end

  # --- Private Helpers ---

  defp chart_opts(component_opts_map) when is_map(component_opts_map) do
    Keyword.new(component_opts_map)
  end

  defp chart_opts(component_opts_list) when is_list(component_opts_list) do
    component_opts_list
  end

  defp placeholder_data do
    [
      {"N/A", 0}
    ]
  end

  defp default_component_opts do
    %{type: :bar, title: "Chart (No Config)"}
  end
end
