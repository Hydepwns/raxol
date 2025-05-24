defmodule Raxol.UI.Components.Dashboard.Widgets.TreeMapWidget do
  @moduledoc """
  A dashboard widget that displays a treemap using Raxol.UI.Components.Visualization.TreeMap.
  This module is responsible for holding the treemap's state (data, config)
  and providing a data structure for rendering, rather than rendering directly.
  """

  # --- State ---

  defstruct [:id, :config, :data, :component_opts]

  # --- Lifecycle / State Management ---

  @spec init(keyword()) :: map()
  def init(opts) do
    widget_config = Keyword.fetch!(opts, :widget_config)

    id =
      case Map.get(widget_config, :id) do
        nil ->
          raise ArgumentError,
                "TreeMapWidget requires an :id in widget_config, got: #{inspect(widget_config)}"

        value ->
          value
      end

    # Extract data and component_opts, providing defaults if missing
    # Use placeholder if no data provided
    data = Map.get(widget_config, :data, placeholder_data())
    # Use defaults if no opts provided
    component_opts =
      Map.get(widget_config, :component_opts, default_component_opts())

    # Keep the original config map
    %__MODULE__{
      id: id,
      config: widget_config,
      data: data,
      component_opts: component_opts
    }
  end

  # --- Data Structure for Rendering ---

  @spec render_data_structure(map()) :: map()
  def render_data_structure(assigns) do
    %{
      type: :treemap,
      data: assigns.data,
      # Pass the component_opts map
      opts: treemap_opts(assigns.component_opts)
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
