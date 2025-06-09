defmodule Raxol.UI.Layout.Engine do
  @moduledoc """
  Core layout engine that translates the logical view structure into absolute positions.

  This module is responsible for:
  * Calculating element positions based on available space
  * Resolving layout constraints
  * Managing the layout pipeline
  """

  require Raxol.Core.Runtime.Log

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
    result_before_flatten = process_element(view, available_space, [])

    result_before_flatten
    |> List.flatten()
  end

  # Main entry point for element processing
  def process_element(element, space, acc) do
    # More robust check for element structure before delegating
    unless is_map(element) and Map.has_key?(element, :type) do
      Raxol.Core.Runtime.Log.warning_with_context(
        "LayoutEngine: process_element called with invalid element structure. Element: #{inspect(element)}",
        %{space: space, acc: acc}
      )

      acc
    end

    # Ensure :attrs and :children keys are always present and safe
    element =
      element
      |> Map.put_new(:attrs, %{})
      |> Map.put_new(:children, [])

    do_process_element(element, space, acc)
  end

  # Internal processing function with specific clauses
  defp do_process_element(%{type: :view} = element, space, acc)
       when is_map_key(element, :type) do
    children_nodes = Map.get(element, :children, [])
    children_nodes = if is_list(children_nodes), do: children_nodes, else: []

    elements_from_children = process_children(children_nodes, space)

    elements_from_children ++ acc
  end

  defp do_process_element(%{type: :panel} = panel, space, acc)
       when is_map_key(panel, :type) do
    children = Map.get(panel, :children, [])
    children = if is_list(children), do: children, else: []
    panel = Map.put(panel, :children, children)
    Panels.process(panel, space, acc)
  end

  defp do_process_element(%{type: :row} = row_orig, space, acc)
       when is_map_key(row_orig, :type) do
    children = Map.get(row_orig, :children, [])
    attrs = Map.get(row_orig, :attrs, %{})
    row = %{row_orig | children: children, attrs: attrs}
    Containers.process_row(row, space, acc)
  end

  defp do_process_element(%{type: :column} = column_orig, space, acc)
       when is_map_key(column_orig, :type) do
    children = Map.get(column_orig, :children, [])
    attrs = Map.get(column_orig, :attrs, %{})
    column = %{column_orig | children: children, attrs: attrs}
    Containers.process_column(column, space, acc)
  end

  defp do_process_element(%{type: :grid} = grid_orig, space, acc)
       when is_map_key(grid_orig, :type) do
    children = Map.get(grid_orig, :children, [])
    attrs = Map.get(grid_orig, :attrs, %{})
    grid = %{grid_orig | children: children, attrs: attrs}
    Grid.process_grid(grid, space, acc)
  end

  # Process basic text/label
  defp do_process_element(
         %{type: type, attrs: attrs_orig_param} = element_data_orig,
         space,
         acc
       )
       when is_map(element_data_orig) and type in [:label, :text] do
    # Step 1: Normalize element_data based on attrs_orig_param
    element_data_normalized =
      if is_list(attrs_orig_param) do
        %{element_data_orig | attrs: Map.new(attrs_orig_param)}
      else
        # Use original if attrs wasn't a list
        element_data_orig
      end

    # Step 2: Ensure current_attrs is a map, derived from normalized element_data.attrs
    # This step is crucial. If element_data_normalized does not have an :attrs key, this line will fail.
    # However, the function clause pattern requires element_data_orig to have :attrs.
    current_attrs =
      cond do
        is_map(element_data_normalized.attrs) ->
          element_data_normalized.attrs

        # Handle case where original attrs was nil
        is_nil(element_data_normalized.attrs) ->
          %{}

        true ->
          Raxol.Core.Runtime.Log.warning_with_context(
            "LayoutEngine: Unexpected attrs type for :label/:text after normalization: #{inspect(element_data_normalized.attrs)}",
            %{element_data_orig: element_data_orig, space: space}
          )

          # Default to empty map
          %{}
      end

    # Original logic for creating the text element
    text_content =
      Map.get(current_attrs, :content, Map.get(current_attrs, :text, ""))

    final_attrs = Map.put(current_attrs, :original_type, type)

    text_element = %{
      type: :text,
      x: space.x,
      y: space.y,
      text: text_content,
      # final_attrs is guaranteed to be a map here
      attrs: final_attrs
    }

    [text_element | acc]
  end

  defp do_process_element(
         %{type: :button, attrs: attrs_orig_param} = element,
         space,
         acc
       )
       when is_map_key(element, :type) do
    attrs_orig = attrs_orig_param || %{}

    attrs =
      case attrs_orig do
        list when is_list(list) -> Map.new(list)
        map when is_map(map) -> map
        _ -> %{}
      end

    text = safe_access_get(attrs, :label, "Button")
    component_attrs = Map.put(attrs, :component_type, :button)

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

  defp do_process_element(
         %{type: :text_input, attrs: attrs_orig_param} = element,
         space,
         acc
       )
       when is_map_key(element, :type) do
    attrs_orig = attrs_orig_param || %{}

    attrs =
      case attrs_orig do
        list when is_list(list) -> Map.new(list)
        map when is_map(map) -> map
        _ -> %{}
      end

    value = safe_access_get(attrs, :value, "")
    placeholder = safe_access_get(attrs, :placeholder, "")
    display_text = if value == "", do: placeholder, else: value
    component_attrs = Map.put(attrs, :component_type, :text_input)

    text_input_elements = [
      %{
        type: :box,
        x: space.x,
        y: space.y,
        width: min(String.length(display_text) + 4, space.width),
        height: 3,
        attrs: component_attrs
      },
      %{
        type: :text,
        x: space.x + 2,
        y: space.y + 1,
        text: display_text,
        attrs: Map.merge(component_attrs, %{is_placeholder: value == ""})
      }
    ]

    text_input_elements ++ acc
  end

  defp do_process_element(
         %{type: :checkbox, attrs: attrs_orig_param} = element,
         space,
         acc
       )
       when is_map_key(element, :type) do
    attrs_orig = attrs_orig_param || %{}

    attrs =
      case attrs_orig do
        list when is_list(list) -> Map.new(list)
        map when is_map(map) -> map
        _ -> %{}
      end

    checked = safe_access_get(attrs, :checked, false)
    label = safe_access_get(attrs, :label, "")
    component_attrs = Map.put(attrs, :component_type, :checkbox)
    checkbox_text = if checked, do: "[✓]", else: "[ ]"

    checkbox_elements = [
      %{
        type: :text,
        x: space.x,
        y: space.y,
        text: "#{checkbox_text} #{label}",
        attrs: component_attrs
      }
    ]

    checkbox_elements ++ acc
  end

  defp do_process_element(%{type: :table} = table_element, space, acc)
       when is_map_key(table_element, :type) do
    # Delegate table measurement and positioning to the dedicated module
    Table.measure_and_position(table_element, space, acc)
  end

  # Catch-all for unknown element types
  defp do_process_element(%{type: type} = element, _space, acc)
       when is_map_key(element, :type) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "LayoutEngine: Unknown or unhandled element type: #{inspect(type)}. Element: #{inspect(element)}",
      %{}
    )

    acc
  end

  defp do_process_element(other, _space, acc) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "LayoutEngine: Received non-element data: #{inspect(other)}",
      %{}
    )

    acc
  end

  # Process children of a container element (Helper)
  defp process_children(children_list, space) when is_list(children_list) do
    result =
      Enum.flat_map(children_list, fn child_node ->
        # Recursive call with empty acc
        process_element(child_node, space, [])
      end)

    result
  end

  # --- End Element Processing ---

  # --- Element Measurement Logic ---

  defp safe_access_get(data, key, default) when is_map(data),
    do: Access.get(data, key, default)

  defp safe_access_get(data, key, default)
       when is_list(data) and (data == [] or is_tuple(hd(data))),
       do: Keyword.get(data, key, default)

  defp safe_access_get(data, key, default) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "LayoutEngine: safe_access_get called with non-map/keyword data for key '#{key}'. Data: #{inspect(data)}",
      %{}
    )

    # Return default if data is not a map or keyword list
    default
  end

  defp extract_dim(attrs, key, tuple_index, default) do
    cond do
      is_map(attrs) and Map.has_key?(attrs, key) ->
        Map.get(attrs, key)

      is_tuple(attrs) and tuple_size(attrs) > tuple_index ->
        elem(attrs, tuple_index)

      true ->
        default
    end
  end

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
  def measure_element(
        %{type: type, attrs: attrs_orig_param} = element,
        available_space
      )
      when is_map_key(element, :type) and is_atom(type) do
    attrs_orig = attrs_orig_param || %{}

    attrs =
      case attrs_orig do
        list when is_list(list) -> Map.new(list)
        map when is_map(map) -> map
        _ -> %{}
      end

    case type do
      :text ->
        text = safe_access_get(attrs, :text, "")
        %{width: String.length(text), height: 1}

      :label ->
        text = safe_access_get(attrs, :content, "")
        %{width: String.length(text), height: 1}

      :box ->
        width = extract_dim(attrs, :width, 0, 1)
        height = extract_dim(attrs, :height, 1, 1)
        %{width: width, height: height}

      :button ->
        text = safe_access_get(attrs, :label, "Button")
        padding = 4

        width =
          min(
            String.length(text) + padding,
            extract_dim(available_space, :width, 0, 80)
          )

        height = 3
        %{width: width, height: height}

      :text_input ->
        value = safe_access_get(attrs, :value, "")
        placeholder = safe_access_get(attrs, :placeholder, "")
        display_text = if value == "", do: placeholder, else: value
        padding = 4

        width =
          min(
            String.length(display_text) + padding,
            extract_dim(available_space, :width, 0, 80)
          )

        height = 3
        %{width: width, height: height}

      :checkbox ->
        label = safe_access_get(attrs, :label, "")
        width = 4 + String.length(label)
        height = 1
        %{width: width, height: height}

      :row ->
        Containers.measure_row(element, available_space)

      :column ->
        Containers.measure_column(element, available_space)

      :panel ->
        Panels.measure_panel(element, available_space)

      :grid ->
        %{type: :column, children: safe_access_get(element, :children, [])}
        |> __MODULE__.measure_element(available_space)

      :view ->
        %{type: :column, children: safe_access_get(element, :children, [])}
        |> __MODULE__.measure_element(available_space)

      :table ->
        headers = safe_access_get(attrs, :headers, [])
        data = safe_access_get(attrs, :data, [])

        header_width =
          if headers == [],
            do: 0,
            else: String.length(Enum.join(headers, " | "))

        max_data_width =
          data
          |> Enum.map(fn row -> String.length(Enum.join(row, " | ")) end)
          |> Enum.max(fn -> 0 end)

        width = max(header_width, max_data_width)
        header_height = if headers == [], do: 0, else: 2
        data_height = length(data)
        height = header_height + data_height

        %{
          width: min(width, extract_dim(available_space, :width, 0, 80)),
          height: min(height, extract_dim(available_space, :height, 1, 24))
        }

      _ ->
        # Fallback for unknown or unmeasurable elements
        Raxol.Core.Runtime.Log.warning_with_context(
          "LayoutEngine: Cannot measure element type: #{inspect(type)}",
          %{}
        )

        %{width: 0, height: 0}
    end
  end

  # Catch-all for non-element data or invalid elements
  def measure_element(other, _available_space) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "LayoutEngine: Cannot measure non-element or invalid element: #{inspect(other)}",
      %{}
    )

    %{width: 0, height: 0}
  end
end
