defmodule Raxol.Plugins.Visualization.ImageRenderer do
  @moduledoc """
  Handles rendering logic for image placeholders within the VisualizationPlugin.
  Currently provides a text placeholder, but intended for protocols like sixel or kitty.
  """

  require Logger
  alias Raxol.Terminal.Cell
  alias Raxol.Plugins.Visualization.DrawingUtils
  alias Raxol.Style

  @doc """
  Public entry point for rendering image content.
  Handles bounds checking and calls the internal drawing logic.
  Expects bounds map: %{width: w, height: h}.
  """
  def render_image_content(
        data,
        opts,
        %{width: width, height: height} = bounds,
        _state
      ) do
    title = Map.get(opts, :title, "Image")

    # Basic validation
    if width < 1 or height < 1 do
      Logger.warning(
        "[ImageRenderer] Bounds too small for image rendering: #{inspect(bounds)}"
      )

      # Return empty grid if bounds are zero/negative
      []
    else
      try do
        # TODO: Implement actual image rendering (sixel/kitty)
        # For now, draw a placeholder box
        draw_placeholder(data, title, bounds)
      rescue
        e ->
          stacktrace = __STACKTRACE__

          Logger.error(
            "[ImageRenderer] Error rendering image: #{inspect(e)}\nStacktrace: #{inspect(stacktrace)}"
          )

          DrawingUtils.draw_box_with_text("[Render Error]", bounds)
      end
    end
  end

  # --- Private Image Drawing Logic ---

  @doc false
  # Draws a placeholder box indicating where the image would be.
  defp draw_placeholder(data, title, %{width: width, height: height} = _bounds) do
    grid = List.duplicate(List.duplicate(Cell.new(" "), width), height)
    grid_with_title = DrawingUtils.draw_text_centered(grid, 0, title)

    grid_with_box =
      DrawingUtils.draw_box_borders(
        grid_with_title,
        1,
        1,
        width - 2,
        height - 2,
        Style.new(fg: :dark_gray)
      )

    # Add text indicating data source (e.g., file path)
    data_info =
      case data do
        path when is_binary(path) -> "Src: #{path}"
        _ -> "Data: #{inspect(data, limit: 20)}"
      end

    DrawingUtils.draw_text_centered(grid_with_box, div(height, 2), data_info)
  end

  # TODO: Add functions for specific image protocols
  # defp render_sixel(image_data, bounds) do ... end
  # defp render_kitty(image_data, bounds) do ... end
end
