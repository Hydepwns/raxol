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
  def process(panel = %{type: :panel, attrs: attrs, children: children}, space, acc) do
    # Calculate inner space for panel contents
    inner_space = calculate_inner_space(space, attrs)

    # Create panel border elements
    panel_elements = create_panel_elements(space, attrs)

    # Process panel children with the inner space
    inner_elements =
      if is_list(children) do
        Enum.reduce(children, [], fn child, acc ->
          Engine.process_element(child, inner_space, acc)
        end)
      else
        Engine.process_element(children, inner_space, [])
      end

    [panel_elements, inner_elements | acc]
  end

  @doc """
  Measures the space required by a panel element.

  ## Parameters

  * `panel` - The panel element to measure
  * `available_space` - The available space for the panel

  ## Returns

  The dimensions of the panel: %{width: w, height: h}
  """
  def measure(panel = %{type: :panel, attrs: attrs, children: children}, available_space) do
    # Default to using all available space unless specifically constrained
    width = Map.get(attrs, :width, available_space.width)
    height = Map.get(attrs, :height, available_space.height)

    # Enforce minimum sizes
    min_width = max(width, 4) # Minimum width to accommodate borders
    min_height = max(height, 3) # Minimum height to accommodate borders and title

    # Return dimensions constrained to available space
    %{
      width: min(min_width, available_space.width),
      height: min(min_height, available_space.height)
    }
  end

  # Private helpers

  # Calculate the inner space available for panel contents (accounting for borders)
  defp calculate_inner_space(space, attrs) do
    border_width = get_border_width(attrs)

    %{
      x: space.x + border_width,
      y: space.y + border_width,
      width: max(space.width - (border_width * 2), 0),
      height: max(space.height - (border_width * 2), 0)
    }
  end

  # Get the border width based on panel attributes
  defp get_border_width(attrs) do
    border_style = Map.get(attrs, :border, :single)

    case border_style do
      :none -> 0
      :single -> 1
      :double -> 1
      :thick -> 1
      _ -> 1  # Default to single border
    end
  end

  # Create the panel border elements
  defp create_panel_elements(space, attrs) do
    title = Map.get(attrs, :title, "")
    border_style = Map.get(attrs, :border, :single)
    border_chars = get_border_chars(border_style)

    # Panel box element
    box = %{
      type: :box,
      x: space.x,
      y: space.y,
      width: space.width,
      height: space.height,
      attrs: %{
        fg: Map.get(attrs, :fg, :white),
        bg: Map.get(attrs, :bg, :black),
        border: border_chars
      }
    }

    # Panel title element (if title is provided)
    title_element =
      if title != "" do
        %{
          type: :text,
          x: space.x + 2,
          y: space.y,
          text: " #{title} ",
          attrs: %{
            fg: Map.get(attrs, :title_fg, :white),
            bg: Map.get(attrs, :title_bg, :black)
          }
        }
      else
        nil
      end

    if title_element, do: [box, title_element], else: [box]
  end

  # Get appropriate border characters for the specified border style
  defp get_border_chars(:none), do: nil

  defp get_border_chars(:single) do
    %{
      top_left: "┌",
      top_right: "┐",
      bottom_left: "└",
      bottom_right: "┘",
      horizontal: "─",
      vertical: "│"
    }
  end

  defp get_border_chars(:double) do
    %{
      top_left: "╔",
      top_right: "╗",
      bottom_left: "╚",
      bottom_right: "╝",
      horizontal: "═",
      vertical: "║"
    }
  end

  defp get_border_chars(:thick) do
    %{
      top_left: "┏",
      top_right: "┓",
      bottom_left: "┗",
      bottom_right: "┛",
      horizontal: "━",
      vertical: "┃"
    }
  end

  defp get_border_chars(_) do
    # Default to single border
    get_border_chars(:single)
  end
end
