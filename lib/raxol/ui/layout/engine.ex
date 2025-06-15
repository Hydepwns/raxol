defmodule Raxol.UI.Layout.Engine do
  @moduledoc """
  Core layout engine that translates the logical view structure into absolute positions.

  This module is responsible for:
  * Calculating element positions based on available space
  * Resolving layout constraints
  * Managing the layout pipeline
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.UI.Layout.{Grid, Panels, Containers, Table, Elements, Inputs}

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
    # Convert keyword list to map if needed
    attrs_map = if is_list(attrs), do: Map.new(attrs), else: attrs

    # Create a text element at the given position
    text_element = %{
      type: :text,
      x: space.x,
      y: space.y,
      text: Map.get(attrs_map, :content, Map.get(attrs_map, :text, "")),
      # Pass original attributes through, let Renderer handle styling
      attrs: Map.put(attrs_map, :original_type, type)
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
    Raxol.Core.Runtime.Log.warning_with_context(
      "LayoutEngine: Unknown or unhandled element type: #{inspect(type)}. Element: #{inspect(element)}",
      %{}
    )

    acc
  end

  def process_element(other, _space, acc) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "LayoutEngine: Received non-element data: #{inspect(other)}",
      %{}
    )

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

  # Handles valid elements (maps with :type and :attrs)
  def measure_element(%{type: type, attrs: attrs} = element, available_space)
      when is_atom(type) do
    # Convert keyword list to map if needed
    attrs_map = if is_list(attrs), do: Map.new(attrs), else: attrs
    measure_element_by_type(type, element, attrs_map, available_space)
  end

  # Catch-all for unknown element types
  def measure_element(other, _available_space) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "LayoutEngine: Cannot measure unknown element type: #{inspect(other)}",
      %{}
    )

    %{width: 0, height: 0}
  end

  defp measure_element_by_type(type, element, attrs_map, available_space) do
    case type do
      type when type in [:text, :label, :box, :checkbox] ->
        Elements.measure(type, attrs_map)

      type when type in [:button, :text_input] ->
        Inputs.measure(type, attrs_map, available_space)

      type when type in [:row, :column, :panel, :grid, :view] ->
        measure_container_element(type, element, available_space)

      :table ->
        Table.measure(attrs_map, available_space)

      _ ->
        handle_unknown_element(type)
    end
  end

  defp measure_container_element(:row, element, available_space),
    do: Containers.measure_row(element, available_space)

  defp measure_container_element(:column, element, available_space),
    do: Containers.measure_column(element, available_space)

  defp measure_container_element(:panel, element, available_space),
    do: Panels.measure_panel(element, available_space)

  defp measure_container_element(:grid, element, available_space),
    do: Grid.measure_grid(element, available_space)

  defp measure_container_element(:view, element, available_space),
    do: measure_view(element, available_space)

  defp measure_view(element, available_space) do
    %{type: :column, children: Map.get(element, :children, [])}
    |> __MODULE__.measure_element(available_space)
  end

  defp handle_unknown_element(type) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "LayoutEngine: Cannot measure element type: #{inspect(type)}",
      %{}
    )

    %{width: 0, height: 0}
  end

  # --- End Measurement Logic ---
end
