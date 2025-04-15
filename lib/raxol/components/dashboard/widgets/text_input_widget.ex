defmodule Raxol.Components.Dashboard.Widgets.TextInputWidget do
  @moduledoc """
  A widget displaying text input from the application state.
  """
  import Raxol.View

  @doc """
  Renders the text input widget content.

  Requires props:
  - `widget_config`: The configuration map for the widget (%{id: _, type: _, title: _, ...}).
  - `app_text`: The current text value from the main application model.
  """
  def render(props) do
    %{app_text: app_text} = props

    # Return a list of view elements for the content area
    [
      # text(title), # Title is rendered by the container
      text("Input:"),
      text(app_text <> "_") # Display current text with a cursor placeholder
    ]
  end
end
