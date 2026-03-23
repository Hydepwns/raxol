defmodule Raxol.UI.Layout.Engine do
  @moduledoc """
  Core layout engine that translates the logical view structure into absolute positions.

  This module is responsible for:
  * Calculating element positions based on available space
  * Resolving layout constraints
  * Managing the layout pipeline
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.UI.Layout.{
    Containers,
    CSSGrid,
    Elements,
    Flexbox,
    Grid,
    Inputs,
    Panels,
    Responsive,
    SplitPane,
    Table
  }

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
    result =
      process_element(view, available_space, [])
      |> List.flatten()

    result
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

  def process_element(%{type: :flex} = flex, space, acc) do
    # Delegate to flexbox layout processing
    Flexbox.process_flex(flex, space, acc)
  end

  def process_element(%{type: :css_grid} = css_grid, space, acc) do
    # Delegate to CSS Grid layout processing
    CSSGrid.process_css_grid(css_grid, space, acc)
  end

  def process_element(%{type: :responsive} = responsive, space, acc) do
    # Delegate to responsive layout processing
    Responsive.process_responsive(responsive, space, acc)
  end

  def process_element(%{type: :responsive_grid} = responsive_grid, space, acc) do
    # Delegate to responsive grid layout processing
    Responsive.process_responsive_grid(responsive_grid, space, acc)
  end

  # Process basic text/label (old format with :attrs)
  def process_element(%{type: type, attrs: attrs} = _element, space, acc)
      when type in [:label, :text] do
    # Convert keyword list to map if needed
    attrs_map = convert_attrs_to_map(attrs)

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

  # Process text elements in new widget format (flat map with :content)
  def process_element(%{type: :text, content: content} = element, space, acc)
      when is_binary(content) do
    text_element = %{
      type: :text,
      x: space.x,
      y: space.y,
      text: content,
      attrs: %{
        style: Map.get(element, :style, %{}),
        id: Map.get(element, :id),
        original_type: :text
      }
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
    display_text = get_display_text(value, placeholder)

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
        attrs: Map.merge(component_attrs, %{placeholder: value == ""})
      }
    ]

    text_input_elements ++ acc
  end

  def process_element(%{type: :checkbox, attrs: attrs} = _element, space, acc) do
    # Create a checkbox element (simple text for now)
    checked = Map.get(attrs, :checked, false)
    label = Map.get(attrs, :label, "")
    component_attrs = Map.put(attrs, :component_type, :checkbox)

    checkbox_text = get_checkbox_text(checked)

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

  # Process box elements in new View DSL format (no :attrs key)
  def process_element(%{type: :box, children: %{} = child} = box, space, acc) do
    process_element(%{box | children: [child]}, space, acc)
  end

  def process_element(%{type: :box, children: children} = box, space, acc)
      when is_list(children) do
    padding = Map.get(box, :padding, 0)
    border = Map.get(box, :border, :none)

    # Calculate inner space accounting for border and padding
    border_offset = if border == :none, do: 0, else: 1
    pad = if is_integer(padding), do: padding, else: 0

    inner_space = %{
      x: space.x + border_offset + pad,
      y: space.y + border_offset + pad,
      width: max(0, space.width - 2 * (border_offset + pad)),
      height: max(0, space.height - 2 * (border_offset + pad))
    }

    # Add box frame element
    box_element = %{
      type: :box,
      x: space.x,
      y: space.y,
      width: space.width,
      height: space.height,
      attrs: %{
        border: border,
        padding: padding,
        style: Map.get(box, :style, %{})
      }
    }

    # Process children in inner space
    children_acc = process_children(children, inner_space, [])
    [box_element | children_acc] ++ acc
  end

  # Process button elements in new View DSL format (no :attrs key)
  def process_element(%{type: :button, text: text} = button, space, acc)
      when is_binary(text) do
    component_attrs = %{
      component_type: :button,
      label: text,
      on_click: Map.get(button, :on_click),
      style: Map.get(button, :style, %{})
    }

    button_elements = [
      %{
        type: :box,
        x: space.x,
        y: space.y,
        width: min(String.length(text) + 4, space.width),
        height: 3,
        attrs: component_attrs
      },
      %{
        type: :text,
        x: space.x + 2,
        y: space.y + 1,
        text: text,
        attrs: component_attrs
      }
    ]

    button_elements ++ acc
  end

  def process_element(%{type: :split_pane} = split, space, acc) do
    SplitPane.process(split, space, acc)
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
    # Process each child with proper delegation to container-specific modules
    Enum.reduce(children, acc, fn child, current_acc ->
      case child do
        %{type: :row} = row ->
          Containers.process_row(row, space, current_acc)

        %{type: :column} = column ->
          Containers.process_column(column, space, current_acc)

        %{type: :panel} = panel ->
          Panels.process(panel, space, current_acc)

        %{type: :grid} = grid ->
          Grid.process(grid, space, current_acc)

        %{type: :flex} = flex ->
          Flexbox.process_flex(flex, space, current_acc)

        %{type: :css_grid} = css_grid ->
          CSSGrid.process_css_grid(css_grid, space, current_acc)

        %{type: :responsive} = responsive ->
          Responsive.process_responsive(responsive, space, current_acc)

        %{type: :responsive_grid} = responsive_grid ->
          Responsive.process_responsive_grid(
            responsive_grid,
            space,
            current_acc
          )

        %{type: :split_pane} = split ->
          SplitPane.process(split, space, current_acc)

        _ ->
          # For non-container elements, process in the same space
          process_element(child, space, current_acc)
      end
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
    attrs_map = convert_attrs_to_map(attrs)
    measure_element_by_type(type, element, attrs_map, available_space)
  end

  # Handles new widget format (flat maps with :content/:children, no :attrs)
  def measure_element(%{type: :text, content: content}, _available_space)
      when is_binary(content) do
    lines = String.split(content, "\n")
    width = lines |> Enum.map(&String.length/1) |> Enum.max(fn -> 0 end)
    %{width: width, height: length(lines)}
  end

  # Button with top-level :text key (new View DSL format)
  def measure_element(%{type: :button, text: text} = _element, available_space) do
    label = text || "Button"
    Inputs.measure(:button, %{label: label}, available_space)
  end

  # Checkbox with top-level :label key (new View DSL format)
  def measure_element(
        %{type: :checkbox, label: label} = _element,
        _available_space
      ) do
    Elements.measure(:checkbox, %{label: label || ""})
  end

  # TextInput with top-level :value/:placeholder keys (new View DSL format)
  def measure_element(%{type: :text_input} = element, available_space) do
    attrs_map = %{
      value: Map.get(element, :value, ""),
      placeholder: Map.get(element, :placeholder, "")
    }

    Inputs.measure(:text_input, attrs_map, available_space)
  end

  # Box with top-level properties (new View DSL format from Box.new/1)
  def measure_element(
        %{type: :box, children: children} = element,
        available_space
      )
      when is_list(children) do
    attrs_map = %{
      width: Map.get(element, :width) || Map.get(element, :size),
      height: Map.get(element, :height)
    }

    # If explicit dimensions, use them; otherwise measure as container
    case {attrs_map.width, attrs_map.height} do
      {w, h} when is_integer(w) and is_integer(h) ->
        %{width: w, height: h}

      _ ->
        measure_container_element(
          :column,
          %{type: :column, children: children},
          available_space
        )
    end
  end

  # Flex with top-level properties (new View DSL format from Flex.row/1 etc.)
  def measure_element(
        %{type: :flex, children: children} = element,
        available_space
      )
      when is_list(children) do
    # Build attrs map from top-level keys so parse_flex_properties works
    attrs = %{
      flex_direction: Map.get(element, :direction, :row),
      justify_content: Map.get(element, :justify, :flex_start),
      align_items: Map.get(element, :align, :stretch),
      gap: Map.get(element, :gap, 0),
      padding: Map.get(element, :padding, 0)
    }

    enriched = Map.put(element, :attrs, attrs)
    Flexbox.measure_flex(enriched, available_space)
  end

  def measure_element(
        %{type: container_type, children: children} = element,
        available_space
      )
      when container_type in [:row, :column, :view] and is_list(children) do
    measure_element_by_type(container_type, element, %{}, available_space)
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

      type
      when type in [
             :row,
             :column,
             :panel,
             :grid,
             :view,
             :flex,
             :css_grid,
             :responsive,
             :responsive_grid,
             :split_pane
           ] ->
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

  defp measure_container_element(:flex, element, available_space),
    do: Flexbox.measure_flex(element, available_space)

  defp measure_container_element(:css_grid, element, available_space),
    do: CSSGrid.measure_css_grid(element, available_space)

  defp measure_container_element(:responsive, element, available_space),
    do: Responsive.measure_responsive(element, available_space)

  defp measure_container_element(:responsive_grid, element, available_space),
    do: Responsive.measure_responsive(element, available_space)

  defp measure_container_element(:split_pane, element, available_space),
    do: SplitPane.measure_split_pane(element, available_space)

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

  # --- Helper Functions ---

  defp convert_attrs_to_map(attrs) when is_list(attrs), do: Map.new(attrs)
  defp convert_attrs_to_map(attrs), do: attrs

  defp get_display_text("", placeholder), do: placeholder
  defp get_display_text(value, _placeholder), do: value

  defp get_checkbox_text(true), do: "[[OK]]"
  defp get_checkbox_text(false), do: "[ ]"

  # --- End Measurement Logic ---
end
