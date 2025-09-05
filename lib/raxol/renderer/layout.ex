defmodule Raxol.Renderer.Layout do
  import Kernel, except: [to_string: 1]
  require Raxol.Core.Renderer.View

  @moduledoc """
  Handles layout calculations for UI elements.

  This module translates the logical layout (panels, rows, columns)
  into absolute positions for rendering.

  ## Architecture

  This module delegates to specialized sub-modules:
  - `Raxol.Renderer.Layout.Flex` - Flex layout algorithms
  - `Raxol.Renderer.Layout.Scroll` - Scroll handling and scrollbars
  - `Raxol.Renderer.Layout.Elements` - Element-specific processing
  - `Raxol.Renderer.Layout.Utils` - Utility functions
  """

  # Define element processors map
  @element_processors %{
    view: :process_view_element,
    panel: :process_panel_element,
    label: :process_label_element,
    button: :process_button_element,
    text_input: :process_text_input_element,
    checkbox: :process_checkbox_element,
    table: :process_table_element,
    scroll: :process_scroll_element,
    shadow_wrapper: :process_shadow_wrapper_element,
    box: :process_box_element,
    flex: :process_flex_element,
    text: :process_text_element,
    border: :process_border_element,
    grid: :process_grid_element
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
    available_space = %{
      x: 0,
      y: 0,
      width: dimensions.width,
      height: dimensions.height
    }

    normalized_view =
      normalize_view_for_layout(view, available_space, dimensions)

    result = process_element(normalized_view, available_space, [])
    flatten_result(result)
  end

  defp normalize_view_for_layout(view, available_space, dimensions) do
    normalized_views =
      Raxol.Renderer.Layout.Utils.deep_normalize_child(
        view,
        available_space,
        :box,
        true
      )

    case normalized_views do
      [single_view] -> single_view
      [first_view | _rest] -> first_view
      [] -> Raxol.Renderer.Layout.Utils.create_default_view(dimensions)
      single_map when is_map(single_map) -> single_map
      _other -> Raxol.Renderer.Layout.Utils.create_default_view(dimensions)
    end
  end

  defp flatten_result(result) do
    flat = List.flatten(result) |> Enum.reject(&is_nil/1)

    case flat do
      [single_map] when is_map(single_map) -> single_map
      _ -> flat
    end
  end

  # Process element functions - simplified main function
  def process_element(element, space, acc) do
    case element do
      %{type: type} = el ->
        process_function = @element_processors[type]

        case process_function do
          nil -> acc
          func -> apply(__MODULE__, func, [el, space, acc])
        end

      _ ->
        acc
    end
  end

  # Delegate element processing to specialized modules
  defdelegate process_view_element(element, space, acc),
    to: Raxol.Renderer.Layout.Elements

  defdelegate process_panel_element(element, space, acc),
    to: Raxol.Renderer.Layout.Elements

  defdelegate process_label_element(element, space, acc),
    to: Raxol.Renderer.Layout.Elements

  defdelegate process_button_element(element, space, acc),
    to: Raxol.Renderer.Layout.Elements

  defdelegate process_text_input_element(element, space, acc),
    to: Raxol.Renderer.Layout.Elements

  defdelegate process_checkbox_element(element, space, acc),
    to: Raxol.Renderer.Layout.Elements

  defdelegate process_table_element(element, space, acc),
    to: Raxol.Renderer.Layout.Elements

  defdelegate process_shadow_wrapper_element(element, space, acc),
    to: Raxol.Renderer.Layout.Elements

  defdelegate process_box_element(element, space, acc),
    to: Raxol.Renderer.Layout.Elements

  defdelegate process_text_element(element, space, acc),
    to: Raxol.Renderer.Layout.Elements

  defdelegate process_border_element(element, space, acc),
    to: Raxol.Renderer.Layout.Elements

  defdelegate process_grid_element(element, space, acc),
    to: Raxol.Renderer.Layout.Elements

  # Delegate flex processing to Flex module
  defdelegate process_flex_element(element, space, acc),
    to: Raxol.Renderer.Layout.Flex

  # Delegate scroll processing to Scroll module
  defdelegate process_scroll_element(element, space, acc),
    to: Raxol.Renderer.Layout.Scroll

  # Delegate utility functions to Utils module
  defdelegate calculate_size(size, space), to: Raxol.Renderer.Layout.Utils

  defdelegate ensure_required_keys(child, space, default_type),
    to: Raxol.Renderer.Layout.Utils

  defdelegate create_default_view(dimensions), to: Raxol.Renderer.Layout.Utils
  defdelegate apply_panel_layout(space, attrs), to: Raxol.Renderer.Layout.Utils

  defdelegate create_panel_elements(space, attrs),
    to: Raxol.Renderer.Layout.Utils

  # Process children functions
  def process_children(children, space, acc) when is_list(children) do
    new_child_elements =
      Enum.flat_map(children, fn child_node ->
        normalized_child = normalize_child_node(child_node, space)

        # Pass empty acc, collect this child's elements
        process_element(normalized_child, space, [])
      end)

    # Add all new child elements to the parent's accumulator
    new_child_elements ++ acc
  end

  def process_children(child, space, acc) when is_map(child) do
    normalized_child =
      case Map.has_key?(child, :type) and Map.has_key?(child, :position) and
           Map.has_key?(child, :size) do
        true -> child
        false -> ensure_required_keys(child, space, :box)
      end

    process_element(normalized_child, space, acc)
  end

  def process_children(_other, _space, acc), do: acc

  # Helper to normalize child nodes
  defp normalize_child_node(child_node, space) when is_map(child_node) do
    case Map.has_key?(child_node, :type) and Map.has_key?(child_node, :position) and
         Map.has_key?(child_node, :size) do
      true -> child_node
      false -> ensure_required_keys(child_node, space, :box)
    end
  end

  defp normalize_child_node(child_node, space) when is_list(child_node) do
    process_children(child_node, space, [])
  end

  defp normalize_child_node(child_node, space) do
    ensure_required_keys(child_node, space, :box)
  end
end
