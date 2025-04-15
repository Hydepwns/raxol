defmodule Raxol.Components.Dashboard.Widgets.TreeMapWidget do
  @moduledoc """
  A dashboard widget that displays a treemap using Raxol.Components.Visualization.TreeMap.
  This module is responsible for holding the treemap's state (data, config)
  and providing a data structure for rendering, rather than rendering directly.
  """

  # alias Raxol.View # <-- Remove unused alias
  # alias Raxol.Components.Visualization.TreeMap # <-- Remove unused alias

  # --- State ---

  defstruct [:id, :config, :data, :component_opts]

  # --- Lifecycle / State Management ---

  def init(opts) do
    widget_config = Keyword.fetch!(opts, :widget_config)

    id = Map.fetch!(widget_config, :id)
    # Extract data and component_opts, providing defaults if missing
    data = Map.get(widget_config, :data, placeholder_data()) # Use placeholder if no data provided
    component_opts = Map.get(widget_config, :component_opts, default_component_opts()) # Use defaults if no opts provided

    # Keep the original config map
    %__MODULE__{
      id: id,
      config: widget_config,
      data: data,
      component_opts: component_opts
    }
  end

  # --- Data Structure for Rendering ---

  def render_data_structure(assigns) do
    %{
      type: :treemap,
      data: assigns.data,
      opts: treemap_opts(assigns.component_opts) # Pass the component_opts map
    }
  end

  # --- Private Helpers ---

  defp treemap_opts(component_opts_map) when is_map(component_opts_map) do
    Keyword.new(component_opts_map)
  end
  defp treemap_opts(component_opts_list) when is_list(component_opts_list) do
    component_opts_list
  end

  defp placeholder_data do
    %{
      name: "N/A",
      value: 1,
      children: []
    }
  end

  defp default_component_opts do
    %{title: "TreeMap (No Config)"}
  end
end
