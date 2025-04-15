defmodule Raxol.Components.Dashboard.Widgets.InfoWidget do
  @moduledoc """
  A simple widget displaying static informational text.
  """
  import Raxol.View

  @doc """
  Renders the info widget content.

  Requires props:
  - `widget_config`: The configuration map for the widget (%{id: _, type: _, title: _, ...}).
  """
  def render(_props) do
    # We don't use the title from config here, as the WidgetContainer shows it.
    # %{widget_config: widget_config} = props
    # title = Map.get(widget_config, :title, "Info")

    # Return a list of view elements for the content area
    [
      # text(title), # Title is rendered by the container
      text("This is static info."),
      text("Rendered by InfoWidget.")
    ]
  end
end
