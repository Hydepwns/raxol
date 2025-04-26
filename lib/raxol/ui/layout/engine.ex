defmodule Raxol.UI.Layout.Engine do
  @moduledoc """
  Core layout engine that translates the logical view structure into absolute positions.

  This module is responsible for:
  * Calculating element positions based on available space
  * Resolving layout constraints
  * Managing the layout pipeline
  """

  alias Raxol.UI.Layout.{Grid, Panels, Containers}

  @doc """
  Applies layout to a view, calculating absolute positions for all elements.

  ## Parameters

  * `view` - The view to calculate layout for
  * `dimensions` - Terminal dimensions `%{width: w, height: h}`

  ## Returns

  A list of positioned elements with absolute coordinates.
  """
  def apply_layout(view, dimensions) do
    # Start with the full screen as available space
    available_space = %{
      x: 0,
      y: 0,
      width: dimensions.width,
      height: dimensions.height
    }

    # Process the view tree
    process_element(view, available_space, [])
    |> List.flatten()
  end

  @doc """
  Calculates the space taken by an element in the layout.

  ## Parameters

  * `element` - The element to measure
  * `available_space` - The available space for the element

  ## Returns

  The dimensions of the element: %{width: w, height: h}
  """
  def measure_element(element, available_space) do
    case element do
      %{type: :view} ->
        # View takes up all available space
        %{width: available_space.width, height: available_space.height}

      %{type: :panel} ->
        # Delegate to panel-specific measurement
        Panels.measure(element, available_space)

      %{type: :row} ->
        # Delegate to row measurement
        Containers.measure_row(element, available_space)

      %{type: :column} ->
        # Delegate to column measurement
        Containers.measure_column(element, available_space)

      %{type: :grid} ->
        # Delegate to grid measurement
        Grid.measure(element, available_space)

      %{type: element_type} when element_type in [:label, :text] ->
        # Default text element measurement
        %{
          width:
            min(
              String.length(element.attrs.content || ""),
              available_space.width
            ),
          height: 1
        }

      %{type: :button} ->
        # Button measurement
        text = element.attrs.label || "Button"
        %{width: min(String.length(text) + 4, available_space.width), height: 3}

      %{type: :text_input} ->
        # Text input measurement
        value = element.attrs.value || ""
        placeholder = element.attrs.placeholder || ""
        text = if value == "", do: placeholder, else: value

        %{
          width: min(max(String.length(text) + 4, 10), available_space.width),
          height: 3
        }

      %{type: :checkbox} ->
        # Checkbox measurement
        label = element.attrs.label || ""

        %{
          width: min(String.length(label) + 4, available_space.width),
          height: 1
        }

      %{type: :table} ->
        # Table measurement - simplified version, would need more sophistication in practice
        headers = element.attrs.headers || []
        data = element.attrs.data || []
        rows = max(length(data), 0) + if headers != [], do: 2, else: 0
        %{width: available_space.width, height: rows}

      _ ->
        # Default fallback for unknown elements
        %{width: 1, height: 1}
    end
  end

  # Process a view element
  def process_element(%{type: :view, children: children}, space, acc)
      when is_list(children) do
    # Process children with the available space
    process_children(children, space, acc)
  end

  def process_element(%{type: :view, children: children}, space, acc) do
    # Handle case where children is not a list
    process_element(children, space, acc)
  end

  def process_element(%{type: :panel} = panel, space, acc) do
    # Delegate to panel-specific layout processing
    Panels.process(panel, space, acc)
  end

  def process_element(%{type: :row} = row, space, acc) do
    # Delegate to row layout processing
    Containers.process_row(row, space, acc)
  end

  def process_element(%{type: :column} = column, space, acc) do
    # Delegate to column layout processing
    Containers.process_column(column, space, acc)
  end

  def process_element(%{type: :grid} = grid, space, acc) do
    # Delegate to grid layout processing
    Grid.process(grid, space, acc)
  end

  # Process basic text/label
  def process_element(%{type: type, attrs: attrs} = _element, space, acc) when type in [:label, :text] do
    # Create a text element at the given position
    text_element = %{
      type: :text,
      x: space.x,
      y: space.y,
      text: Map.get(attrs, :content, Map.get(attrs, :text, "")),
      # Pass original attributes through, let Renderer handle styling
      attrs: Map.put(attrs, :original_type, type)
    }

    [text_element | acc]
  end

  def process_element(%{type: :button, attrs: attrs} = _element, space, acc) do
    # Create a button element composed of a box and text
    text = Map.get(attrs, :label, "Button")
    # Keep original attributes like :disabled, :focused if present
    component_attrs = Map.put(attrs, :component_type, :button)

    button_elements = [
      # Button box
      %{
        type: :box,
        x: space.x,
        y: space.y,
        width: min(String.length(text) + 4, space.width),
        height: 3,
        # Pass attributes, Renderer will use theme + component_type
        attrs: component_attrs
      },
      # Button text
      %{
        type: :text,
        x: space.x + 2,
        y: space.y + 1,
        text: text,
        # Pass attributes, Renderer will use theme + component_type
        attrs: component_attrs
      }
    ]

    button_elements ++ acc
  end

  def process_element(%{type: :text_input, attrs: attrs} = _element, space, acc) do
    # Create a text input element composed of box and text
    value = Map.get(attrs, :value, "")
    placeholder = Map.get(attrs, :placeholder, "")
    display_text = if value == "", do: placeholder, else: value

    # Add component_type, potentially pass placeholder/value info if Renderer needs it
    component_attrs = Map.put(attrs, :component_type, :text_input)

    text_input_elements = [
      # Input box
      %{
        type: :box,
        x: space.x,
        y: space.y,
        width: min(max(String.length(display_text) + 4, 10), space.width),
        height: 3,
        attrs: component_attrs
      },
      # Input text (or placeholder)
      %{
        type: :text,
        x: space.x + 2,
        y: space.y + 1,
        text: display_text,
        # Pass component_attrs; Renderer can check :value == "" and use placeholder style
        attrs: Map.merge(component_attrs, %{is_placeholder: value == ""})
      }
    ]

    text_input_elements ++ acc
  end

  def process_element(%{type: :checkbox, attrs: attrs} = _element, space, acc) do
    # Create a checkbox element (simple text for now)
    checked = Map.get(attrs, :checked, false)
    label = Map.get(attrs, :label, "")
    component_attrs = Map.put(attrs, :component_type, :checkbox)

    checkbox_text = if checked, do: "[✓]", else: "[ ]"

    checkbox_elements = [
      # Checkbox text (box + label)
      %{
        type: :text,
        x: space.x,
        y: space.y,
        text: "#{checkbox_text} #{label}",
        attrs: component_attrs # Pass attributes for theme styling
      }
    ]

    checkbox_elements ++ acc
  end

  def process_element(%{type: :table, attrs: attrs}, space, acc) do
    # Create a table element
    headers = Map.get(attrs, :headers, [])
    data = Map.get(attrs, :data, [])

    # Calculate table dimensions
    table_width = space.width
    row_height = 1
    header_y = space.y
    # After header and separator
    data_start_y = space.y + 2

    # Create table elements
    header_elements =
      if headers != [] do
        [
          # Header row
          %{
            type: :text,
            x: space.x,
            y: header_y,
            text: Enum.join(headers, " | "),
            attrs: %{fg: :white, bg: :black}
          },
          # Separator line
          %{
            type: :text,
            x: space.x,
            y: header_y + 1,
            text: String.duplicate("-", table_width),
            attrs: %{fg: :white, bg: :black}
          }
        ]
      else
        []
      end

    # Create data rows
    data_elements =
      data
      |> Enum.with_index()
      |> Enum.map(fn {row, index} ->
        %{
          type: :text,
          x: space.x,
          y: data_start_y + index * row_height,
          text: Enum.join(row, " | "),
          attrs: %{fg: :white, bg: :black}
        }
      end)

    header_elements ++ data_elements ++ acc
  end

  # --- Helper Functions ---

  # Process children of a container element
  defp process_children(children, space, acc) when is_list(children) do
    # Placeholder: needs proper handling based on container type (row, col, etc.)
    # For now, just process each child in the same space (will overlap)
    Enum.reduce(children, acc, fn child, current_acc ->
      process_element(child, space, current_acc)
    end)
  end

  # Add other element processing functions here...
  # process_element for table, select_list etc.

  # Catch-all for unknown element types
  def process_element(%{type: type} = element, _space, acc) do
    Logger.warning(
      "LayoutEngine: Unknown or unhandled element type: #{inspect(type)}. Element: #{inspect(element)}"
    )
    acc
  end

  def process_element(other, _space, acc) do
    Logger.warning("LayoutEngine: Received non-element data: #{inspect(other)}")
    acc
  end
end
