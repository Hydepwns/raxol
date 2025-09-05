defmodule Raxol.UI.Layout.Panels do
  @moduledoc """
  Handles layout calculations for panel UI elements.

  This module is responsible for:
  * Panel border rendering
  * Panel content layout
  * Panel title positioning
  * Panel-specific spacing and constraints
  """

  # All Kernel functions are now available

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
    panel_dimensions = measure_panel(panel_element, space)
    panel_box = create_panel_box(attrs, space, panel_dimensions)
    title_elements = create_title_elements(attrs, space)
    inner_space = calculate_inner_space(space, panel_dimensions)

    children_to_process = normalize_children(children_input)
    processed_children = process_children(children_to_process, inner_space)

    [panel_box] ++ title_elements ++ processed_children ++ acc
  end

  defp create_panel_box(attrs, space, panel_dimensions) do
    border_style = Map.get(attrs, :border, :single)

    final_attrs =
      attrs
      |> Map.put(:border_style, border_style)
      |> adjust_border_attrs(border_style)

    %{
      type: :box,
      x: space.x,
      y: space.y,
      width: panel_dimensions.width,
      height: panel_dimensions.height,
      attrs: final_attrs
    }
  end

  defp adjust_border_attrs(attrs, :none), do: Map.put(attrs, :border, nil)

  defp adjust_border_attrs(attrs, border_style),
    do: Map.put(attrs, :border, border_style)

  defp create_title_elements(attrs, space) do
    case Map.get(attrs, :title) do
      title when title in [nil, ""] -> []
      title_text -> [create_title_element(title_text, attrs, space)]
    end
  end

  defp create_title_element(title_text, attrs, space) do
    %{
      type: :text,
      x: space.x + 2,
      y: space.y,
      text: " #{title_text} ",
      attrs: Map.get(attrs, :title_attrs, %{})
    }
  end

  defp calculate_inner_space(space, panel_dimensions) do
    %{
      x: space.x + 1,
      y: space.y + 1,
      width: max(0, panel_dimensions.width - 2),
      height: max(0, panel_dimensions.height - 2)
    }
  end

  defp normalize_children(children_input) do
    case children_input do
      nil ->
        []

      c when is_list(c) ->
        c

      c when is_map(c) ->
        [c]

      _ ->
        log_unexpected_children_format(children_input)
        []
    end
  end

  defp log_unexpected_children_format(children_input) do
    Raxol.Core.Runtime.Log.warning(
      "Panels.process received unexpected children format: #{inspect(children_input)}",
      []
    )
  end

  defp process_children(children, inner_space) do
    children
    |> Enum.map(&Engine.process_element(&1, inner_space, []))
    |> List.flatten()
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
    content_space = calculate_content_space(available_space)
    children_size = measure_children_size(children, content_space)

    base_dimensions =
      calculate_base_dimensions(children_size, available_space, attrs)

    final_dimensions = apply_constraints(base_dimensions, available_space)

    final_dimensions
  end

  defp calculate_content_space(available_space) do
    %{
      available_space
      | width: max(0, available_space.width - 2),
        height: max(0, available_space.height - 2)
    }
  end

  defp measure_children_size(children, content_space) do
    column_for_measurement = %{type: :column, attrs: %{}, children: children}
    Engine.measure_element(column_for_measurement, content_space)
  end

  defp calculate_base_dimensions(children_size, available_space, attrs) do
    explicit_width = Map.get(attrs, :width)
    explicit_height = Map.get(attrs, :height)

    base_width =
      determine_base_width(children_size, available_space, explicit_width)

    base_height =
      determine_base_height(children_size, available_space, explicit_height)

    %{
      width: explicit_width || base_width,
      height: explicit_height || base_height
    }
  end

  defp determine_base_width(%{width: 0}, available_space, nil) do
    available_space.width
  end

  defp determine_base_width(children_size, _available_space, _explicit_width) do
    # Add borders
    children_size.width + 2
  end

  defp determine_base_height(%{height: 0}, available_space, nil) do
    available_space.height
  end

  defp determine_base_height(children_size, _available_space, _explicit_height) do
    # Add borders
    children_size.height + 2
  end

  defp apply_constraints(dimensions, available_space) do
    min_width = 4
    min_height = 3

    %{
      width: dimensions.width |> max(min_width) |> min(available_space.width),
      height:
        dimensions.height |> max(min_height) |> min(available_space.height)
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
