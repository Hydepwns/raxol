defmodule Raxol.UI.Layout.Panels do
  @moduledoc """
  Handles layout calculations for panel UI elements.

  This module is responsible for:
  * Panel border rendering
  * Panel content layout
  * Panel title positioning
  * Panel-specific spacing and constraints
  """

  import Raxol.Guards
  import Kernel, except: [nil?: 1]
  alias Raxol.UI.Theming.Theme
  alias Raxol.UI.Layout.Engine
  require Raxol.Core.Runtime.Log

  @doc """
  Processes a panel element, calculating layout for it and its children.

  ## Parameters

  * `panel` - The panel element to process
  * `space` - The available space for the panel
  * `acc` - The accumulator for rendered elements

  ## Returns

  A list of positioned elements with absolute coordinates.
  """
  def process(
        %{type: :panel, attrs: attrs, children: children_input} = panel_element,
        space,
        acc
      ) do
    # Measure the panel first to get its actual dimensions
    panel_dimensions = measure_panel(panel_element, space)

    # Original attributes from the panel element
    panel_input_attrs = attrs
    actual_border_style = Map.get(panel_input_attrs, :border, :single)

    # Construct final attributes for the panel's box representation
    final_box_attrs =
      panel_input_attrs
      # Ensure border_style is correctly set
      |> Map.put(:border_style, actual_border_style)
      |> then(fn current_attrs ->
        if actual_border_style == :none do
          # For test: attrs.border should be nil for :none style
          Map.put(current_attrs, :border, nil)
        else
          # For other styles, ensure :border attribute also reflects the style
          Map.put(current_attrs, :border, actual_border_style)
        end
      end)

    # Create the main panel box element
    panel_box = %{
      type: :box,
      x: space.x,
      y: space.y,
      width: panel_dimensions.width,
      height: panel_dimensions.height,
      # Use the constructed attributes
      attrs: final_box_attrs
    }

    elements = [panel_box]

    # Create title element if present
    title_elements =
      case Map.get(attrs, :title) do
        nil ->
          []

        "" ->
          []

        title_text ->
          [
            %{
              type: :text,
              # Position inside left border, after a space
              x: space.x + 2,
              # On the top border line
              y: space.y,
              # Add padding around title
              text: " #{title_text} ",
              # Allow styling title
              attrs: Map.get(attrs, :title_attrs, %{})
            }
          ]
      end

    # Define inner space for children (inside borders)
    inner_space = %{
      x: space.x + 1,
      y: space.y + 1,
      width: max(0, panel_dimensions.width - 2),
      height: max(0, panel_dimensions.height - 2)
    }

    # Ensure children_input is a list for Enum.map
    children_to_process =
      case children_input do
        nil ->
          []

        c when list?(c) ->
          c

        # Wrap single child map in a list
        c when map?(c) ->
          [c]

        _ ->
          # Should not happen based on Panel definition if type specs are followed
          # but good to be defensive.
          Raxol.Core.Runtime.Log.warning(
            "Panels.process received unexpected children format: #{inspect(children_input)}",
            []
          )

          []
      end

    # Process children by calling Engine.process_element for each one
    processed_children_elements =
      children_to_process
      |> Enum.map(fn child_element ->
        # Pass an empty accumulator for each child, as process_element appends to it.
        Engine.process_element(child_element, inner_space, [])
      end)
      |> List.flatten()

    # Combine all elements and add to accumulator
    elements ++ title_elements ++ processed_children_elements ++ acc
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
      | # 1 cell border left/right
        width: max(0, available_space.width - 2),
        # 1 cell border top/bottom
        height: max(0, available_space.height - 2)
    }

    # Measure children content size (treat as a column for measurement)
    # Ensure the map has :attrs for measure_element pattern matching
    column_for_measurement = %{type: :column, attrs: %{}, children: children}

    children_size =
      Engine.measure_element(column_for_measurement, content_available_space)

    # Determine base width/height from content + borders
    # Add 2 for left/right borders
    content_width = children_size.width + 2
    # Add 2 for top/bottom borders
    content_height = children_size.height + 2

    # Use explicit width/height if provided, otherwise use content size or available if no content
    explicit_width = Map.get(attrs, :width)
    explicit_height = Map.get(attrs, :height)

    # Default to available space if no explicit size and no (or zero-sized) children
    base_width =
      if children_size.width == 0 and nil?(explicit_width) do
        available_space.width
      else
        content_width
      end

    base_height =
      if children_size.height == 0 and nil?(explicit_height) do
        available_space.height
      else
        content_height
      end

    width = explicit_width || base_width
    height = explicit_height || base_height

    # Ensure minimum dimensions (e.g., for borders and minimal content)
    min_width = 4
    min_height = 3
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
