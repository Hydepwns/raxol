defmodule Raxol.UI.Layout.Panels do
  @moduledoc """
  Handles layout calculations for panel UI elements.

  This module is responsible for:
  * Panel border rendering
  * Panel content layout
  * Panel title positioning
  * Panel-specific spacing and constraints
  """

  alias Raxol.UI.Layout.Engine

  @doc """
  Processes a panel element, calculating layout for it and its children.

  ## Parameters

  * `panel` - The panel element to process
  * `space` - The available space for the panel
  * `acc` - The accumulator for rendered elements

  ## Returns

  A list of positioned elements with absolute coordinates.
  """
  def process(attrs, children, context) do
    styled_children =
      children
      |> Enum.map(&Engine.process_element(&1, context, []))

    # panel = %{type: :panel, attrs: attrs, children: children}, # Unused
    # TODO: Actual panel processing logic - applying styles, layout, etc.
    [%{type: :processed_panel, attrs: attrs, children: styled_children}]
  end

  @doc """
  Measures the space required by a panel element.

  ## Parameters

  * `panel` - The panel element to measure
  * `available_space` - The available space for the panel

  ## Returns

  The dimensions of the panel: %{width: w, height: h}
  """
  def measure_panel(
        %{type: :panel, attrs: attrs, children: children},
        available_space
      ) do
    # Calculate space available for content (inside borders)
    content_available_space = %{
      available_space
      | width: max(0, available_space.width - 2), # 1 cell border left/right
        height: max(0, available_space.height - 2) # 1 cell border top/bottom
    }

    # Measure children content size (treat as a column for measurement)
    # Ensure the map has :attrs for measure_element pattern matching
    column_for_measurement = %{type: :column, attrs: %{}, children: children}
    children_size = Engine.measure_element(column_for_measurement, content_available_space)

    # Determine base width/height from content + borders
    # Add 2 for left/right borders
    content_width = children_size.width + 2
    # Add 2 for top/bottom borders
    content_height = children_size.height + 2

    # Use explicit width/height if provided, otherwise use content size
    explicit_width = Map.get(attrs, :width)
    explicit_height = Map.get(attrs, :height)

    width = explicit_width || content_width
    height = explicit_height || content_height

    # Ensure minimum dimensions (e.g., for borders)
    min_width = 2
    min_height = 2
    width = max(width, min_width)
    height = max(height, min_height)

    # Return dimensions constrained to available space
    %{
      width: min(width, available_space.width),
      height: min(height, available_space.height)
    }
  end

  # Private helpers

  # Unused
  # defp calculate_inner_space(space, attrs) do
  # ...
  # end

  # Unused
  # defp get_border_width(attrs) do
  # ...
  # end

  # Unused
  # defp create_panel_elements(space, attrs) do
  # ...
  # end

  # Unused
  # defp get_border_chars(:none), do: nil
  # defp get_border_chars(style) do
  # ...
  # end
end
