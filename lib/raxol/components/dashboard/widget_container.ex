defmodule Raxol.Components.Dashboard.WidgetContainer do
  @moduledoc """
  A container component for dashboard widgets.
  Provides a frame, title bar (optional), and potentially drag/resize handles.
  Renders the actual widget content passed to it.
  """
  import Raxol.View
  require Logger

  # --- Render Function ---
  # This component might not need its own Model/update if it's purely presentational,
  # but it could be added later if needed (e.g., for internal state like focus).

  @doc """
  Renders the widget container frame and its content.

  Requires props:
  - `bounds`: %{x, y, width, height} - The absolute bounds calculated by GridContainer.
  - `widget_config`: The configuration map for the widget being rendered.
                     Used for title, etc. (%{id: _, type: _, title: _, ...}).
  - `content`: The actual View element(s) representing the widget's content.
  """
  def render(props) do
    %{bounds: bounds, widget_config: widget_config, content: content} = props
    title = Map.get(widget_config, :title, "Widget")

    # Use a box for the main frame
    box(
      [
        x: bounds.x,
        y: bounds.y,
        width: bounds.width,
        height: bounds.height,
        border: :rounded
      ],
      do: [
        # Optional: Render a title bar within the frame
        box([x: 0, y: 0, width: :fill, height: 1, style: %{bg: :blue}],
          do: text(title, align: :center)
        ),

        # Render the actual widget content, offset below the title bar
        box([x: 0, y: 1, width: :fill, height: :fill], do: content),

        # Render resize handle (placeholder character)
        render_resize_handle(bounds)
      ]
    )
  end

  # --- Internal Helpers ---

  # Renders the resize handle at the bottom-right corner if bounds allow.
  defp render_resize_handle(bounds)
       when is_map(bounds) and bounds.width > 0 and bounds.height > 1 do
    # Relative X within the container box
    handle_x = bounds.width - 1
    # Relative Y
    handle_y = bounds.height - 1

    # Position the handle character using View.at or similar DSL primitive if available
    # For now, using a nested box as a simple positioning mechanism
    # Corner arrow
    box([x: handle_x, y: handle_y, width: 1, height: 1], do: text("\u21F2"))
  end

  # Don't render handle if widget is too small
  defp render_resize_handle(_bounds), do: nil
end
