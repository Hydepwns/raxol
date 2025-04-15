defmodule Raxol.Plugins.VisualizationPlugin do
  @moduledoc """
  Plugin responsible for rendering visualization components like charts and treemaps.
  It receives data structures from the view rendering pipeline and outputs
  actual terminal cells.
  """
  @behaviour Raxol.Plugins.Plugin

  require Logger

  defstruct name: "visualization",
            version: "0.1.0",
            description: "Renders chart and treemap visualizations.",
            enabled: true,
            config: %{},
            dependencies: [],
            api_version: "1.0.0" # Match manager API

  @impl true
  def init(config \\ %{}) do
    plugin_state = struct(__MODULE__, config)
    {:ok, plugin_state}
  end

  @impl true
  def handle_cells(%__MODULE__{} = plugin_state, cells) do
    # This plugin hook doesn't have bounds info, so we pass cells through.
    # Rendering will be triggered by Runtime.process_view_element.
    {plugin_state, cells, [], nil}
  end

  # --- Private Helpers ---

  # Remove process_visualization_elements
  # defp process_visualization_elements(elements) do ... end

  # Keep rendering functions to be called by Runtime
  def render_chart_to_cells(_data, opts, bounds) do
    # TODO: Implement actual chart rendering within bounds
    title = Map.get(opts, :title, "Chart")
    placeholder_text = "[Chart: #{title}]"
    # Simple placeholder: Draw a box with the text
    draw_placeholder_box(placeholder_text, bounds)
  end

  def render_treemap_to_cells(_data, opts, bounds) do
    # TODO: Implement actual treemap rendering within bounds
    title = Map.get(opts, :title, "TreeMap")
    placeholder_text = "[TreeMap: #{title}]"
    # Simple placeholder: Draw a box with the text
    draw_placeholder_box(placeholder_text, bounds)
  end

  # Helper to draw a simple box with text (example)
  defp draw_placeholder_box(text, bounds) do
    width = bounds.width
    height = bounds.height
    x_start = bounds.x
    y_start = bounds.y

    if width < 2 or height < 2 do
      [] # Too small to draw box
    else
      # Top/Bottom borders
      top_bottom = for x <- x_start..(x_start + width - 1), do: %{x: x, y: y_start, char: ?-, fg: 7, bg: 0}
      bottom = for %{x: _} = cell <- top_bottom, do: %{cell | y: y_start + height - 1} # Ignore x
      # Side borders
      sides = for y <- (y_start + 1)..(y_start + height - 2) do
        [
           %{x: x_start, y: y, char: ?|, fg: 7, bg: 0},
           %{x: x_start + width - 1, y: y, char: ?|, fg: 7, bg: 0}
        ]
      end
      # Text (centered-ish)
      text_cells =
        if height > 2 and String.length(text) <= width - 2 do
          text_y = y_start + div(height - 1, 2)
          text_x = x_start + max(1, div(width - String.length(text), 2))
          text
          |> String.graphemes()
          |> Enum.with_index()
          |> Enum.map(fn {grapheme, i} ->
            [char_code | _] = String.to_charlist(grapheme)
            %{x: text_x + i, y: text_y, char: char_code, fg: 7, bg: 0}
          end)
        else
          []
        end

      top_bottom ++ bottom ++ List.flatten(sides) ++ text_cells
    end
  end

  # Other callbacks (can be minimal for now)
  @impl true
  def handle_input(state, _input), do: {:ok, state}
  @impl true
  def handle_output(state, output), do: {:ok, state, output} # Pass output through
  @impl true
  def handle_mouse(state, _event, _rendered_cells), do: {:ok, state, :propagate}
  @impl true
  def handle_resize(state, _w, _h), do: {:ok, state}
  @impl true
  def cleanup(state), do: {:ok, state}
  @impl true
  def get_api_version, do: "1.0.0"
  @impl true
  def get_dependencies, do: []

end
