defmodule Raxol.UI.Layout.Engine do
  @moduledoc """
  Core layout engine that translates the logical view structure into absolute positions.

  This module is responsible for:
  * Calculating element positions based on available space
  * Resolving layout constraints
  * Managing the layout pipeline
  """

  require Logger

  alias Raxol.UI.Layout.{Grid, Panels, Containers}
  alias Raxol.UI.Layout.Table

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

  # --- Element Processing Logic ---
  # Moved all process_element/3 definitions here for grouping

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
  def process_element(%{type: type, attrs: attrs} = _element, space, acc)
      when type in [:label, :text] do
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
        width: min(String.length(display_text) + 4, space.width),
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
        # Pass attributes for theme styling
        attrs: component_attrs
      }
    ]

    checkbox_elements ++ acc
  end

  def process_element(%{type: :table} = table_element, space, acc) do
    # Delegate table measurement and positioning to the dedicated module
    Table.measure_and_position(table_element, space, acc)
  end

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

  # Process children of a container element (Helper)
  defp process_children(children, space, acc) when is_list(children) do
    # Placeholder: needs proper handling based on container type (row, col, etc.)
    # For now, just process each child in the same space (will overlap)
    Enum.reduce(children, acc, fn child, current_acc ->
      process_element(child, space, current_acc)
    end)
  end

  # --- End Element Processing ---

  # --- Element Measurement Logic ---
  # Function Header for multi-clause function with defaults
  @doc """
  Calculates the intrinsic dimensions (width, height) of an element.

  This function determines the natural size of an element before layout constraints
  are applied. For containers, it might recursively measure children.

  ## Parameters

  * `element` - The element map to measure.
  * `available_space` - Map providing context (e.g., max width).
  - Defaults to an empty map.

  ## Returns

  A map representing the dimensions: `%{width: integer(), height: integer()}`.
  """
  def measure_element(element, available_space \\ %{})

  # The clauses below starting from the one matching %{type: type, attrs: attrs} are the main implementation
  # --- Measurement Logic ---

  # Handles valid elements (maps with :type and :attrs)
  def measure_element(%{type: type, attrs: attrs} = element, available_space)
      when is_atom(type) and is_map(attrs) do
    case type do
      :text ->
        text = Map.get(attrs, :text, "")
        %{width: String.length(text), height: 1}

      :label ->
        # Alias for text in measurement
        text = Map.get(attrs, :content, "")
        %{width: String.length(text), height: 1}

      :box ->
        # Simple box takes explicit size or minimal size
        width = Map.get(attrs, :width, 1)
        height = Map.get(attrs, :height, 1)
        %{width: width, height: height}

      :button ->
        text = Map.get(attrs, :label, "Button")
        # Box: [ Text ]
        padding = 4
        width = min(String.length(text) + padding, available_space.width)
        # Fixed height for button
        height = 3
        %{width: width, height: height}

      :text_input ->
        value = Map.get(attrs, :value, "")
        placeholder = Map.get(attrs, :placeholder, "")
        display_text = if value == "", do: placeholder, else: value
        # Box: [ Text ]
        padding = 4
        # min_width = 10 # Remove min_width constraint for now
        # Calculate width based on text + padding, constrained by available space
        width =
          min(String.length(display_text) + padding, available_space.width)

        # Fixed height for text input
        height = 3
        %{width: width, height: height}

      :checkbox ->
        label = Map.get(attrs, :label, "")
        # "[ ] " or "[✓] " prefix
        width = 4 + String.length(label)
        height = 1
        %{width: width, height: height}

      # Container types delegate to helper measurement functions
      :row ->
        Containers.measure_row(element, available_space)

      :column ->
        Containers.measure_column(element, available_space)

      :panel ->
        # Assuming Panel takes full available space unless constrained
        # TODO: Implement Panels.measure_panel if needed
        # %{width: available_space.width, height: available_space.height}
        # Delegate to Panels module for measurement
        Panels.measure_panel(element, available_space)

      :grid ->
        # TODO: Implement Grid.measure_grid if needed
        # %{width: available_space.width, height: available_space.height} # Placeholder
        # Delegate to Grid module for measurement
        Grid.measure_grid(element, available_space)

      :view ->
        # View takes full available space or measures children if needed
        # For now, assume it takes available space. A different approach might be needed.
        # %{width: available_space.width, height: available_space.height} # Placeholder
        # Measure view based on its children (treat as a column)
        %{type: :column, children: Map.get(element, :children, [])}
        |> __MODULE__.measure_element(available_space)

      :table ->
        # Basic table measurement (consider headers, widest row)
        headers = Map.get(attrs, :headers, [])
        data = Map.get(attrs, :data, [])

        header_width =
          if headers == [],
            do: 0,
            else: String.length(Enum.join(headers, " | "))

        max_data_width =
          data
          |> Enum.map(fn row -> String.length(Enum.join(row, " | ")) end)
          |> Enum.max(fn -> 0 end)

        width = max(header_width, max_data_width)
        # Header + separator
        header_height = if headers == [], do: 0, else: 2
        data_height = length(data)
        height = header_height + data_height

        %{
          width: min(width, available_space.width),
          height: min(height, available_space.height)
        }

      _ ->
        # Fallback for unknown or unmeasurable elements
        Logger.warning(
          "LayoutEngine: Cannot measure element type: #{inspect(type)}"
        )

        %{width: 0, height: 0}
    end
  end

  # Catch-all for non-element data or invalid elements
  def measure_element(other, _available_space) do
    Logger.warning(
      "LayoutEngine: Cannot measure non-element or invalid element: #{inspect(other)}"
    )

    %{width: 0, height: 0}
  end

  # --- End Measurement Logic ---
end
