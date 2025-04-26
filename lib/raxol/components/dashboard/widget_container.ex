defmodule Raxol.Components.Dashboard.WidgetContainer do
  @moduledoc """
  A container component for dashboard widgets.
  Provides a frame, title bar (optional), and potentially drag/resize handles.
  Renders the actual widget content passed to it.
  """

  # Add use Component and placeholders
  use Raxol.UI.Components.Base.Component

  require Logger
  require Raxol.View.Elements # Require Elements
  alias Raxol.View.Elements, as: UI # Use UI alias

  # --- Component Behaviour Placeholders ---

  @impl Raxol.UI.Components.Base.Component
  def init(props), do: props # Simple state passthrough for now

  @impl Raxol.UI.Components.Base.Component
  def update(_msg, state), do: {state, []}

  @impl Raxol.UI.Components.Base.Component
  def handle_event(_event, _props, state), do: {state, []}

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
  @impl Raxol.UI.Components.Base.Component
  def render(state, _props) do # Add props argument, use state instead of props directly
    # Assuming state *is* the props map passed from Dashboard for now
    # This needs refinement if WidgetContainer has its own state
    %{bounds: bounds, widget_config: widget_config, content: content} = state
    title = Map.get(widget_config, :title, "Widget")

    # Use View Elements macros
    UI.box [
      x: bounds.x,
      y: bounds.y,
      width: bounds.width,
      height: bounds.height,
      border: :rounded
    ] do
      [
        # Optional: Title bar
        UI.box [x: 0, y: 0, width: :fill, height: 1, style: %{bg: :blue}] do
           UI.label(content: title, align: :center)
        end,

        # Widget content
        UI.box [x: 0, y: 1, width: :fill, height: :fill] do
           content
        end,

        # Resize handle
        render_resize_handle(bounds)
      ]
    end
  end

  # --- Internal Helpers ---

  # Renders the resize handle at the bottom-right corner if bounds allow.
  defp render_resize_handle(bounds)
       when is_map(bounds) and bounds.width > 0 and bounds.height > 1 do
    handle_x = bounds.width - 1
    handle_y = bounds.height - 1

    # Use UI.box and UI.label
    UI.box [x: handle_x, y: handle_y, width: 1, height: 1] do
      UI.label(content: "\u21F2")
    end
  end

  # Don't render handle if widget is too small
  defp render_resize_handle(_bounds), do: nil
end
