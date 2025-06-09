defmodule Raxol.UI.Layout.Containers do
  @moduledoc """
  Handles layout calculations for container elements like rows and columns.

  This module is responsible for:
  * Row layout calculations
  * Column layout calculations
  * Flexbox-like distribution of space
  * Gap and alignment handling
  """

  alias Raxol.UI.Layout.Engine

  @doc """
  Processes a row element, calculating layout for it and its children.

  ## Parameters

  * `row` - The row element to process
  * `space` - The available space for the row
  * `acc` - The accumulator for rendered elements

  ## Returns

  A list of positioned elements with absolute coordinates.
  """
  def process_row(%{type: :row, attrs: attrs} = row, space, acc) do
    children = Map.get(row, :children, [])
    children = if is_list(children), do: children, else: []
    # Calculate spacing between items
    gap = Map.get(attrs, :gap, 1)
    justify = Map.get(attrs, :justify, :start)
    align = Map.get(attrs, :align, :start)

    # Skip if no children
    if Enum.empty?(children) do
      acc
    else
      # Calculate the space each child needs
      child_dimensions =
        Enum.map(children, fn child ->
          Engine.measure_element(child, space)
        end)

      # Total width used by children
      total_width =
        Enum.reduce(child_dimensions, 0, fn dim, acc ->
          acc + extract_dim(dim, :width, 0, 0)
        end)

      # Space needed for gaps
      gaps_width = gap * (length(children) - 1)

      # Total width including gaps
      total_content_width = total_width + gaps_width

      # Calculate starting x position based on justification
      start_x =
        case justify do
          :start ->
            space.x

          :center ->
            space.x + div(space.width - total_content_width, 2)

          :end ->
            space.x + space.width - total_content_width

          :space_between ->
            # With space_between, we'll recalculate the gap
            space.x
        end

      # If we're using space_between, recalculate the gap
      effective_gap =
        if justify == :space_between and length(children) > 1 do
          remaining_space = space.width - total_width
          div(remaining_space, length(children) - 1)
        else
          gap
        end

      # Position each child
      {_final_x, child_generated_elements_reversed} =
        Enum.zip(children, child_dimensions)
        |> Enum.reduce({start_x, []}, fn {child, dims},
                                         {current_x, elements_acc_for_reduce} ->
          # Calculate y position based on alignment
          child_y =
            case align do
              :start -> space.y
              :center -> space.y + div(space.height - dims.height, 2)
              :end -> space.y + space.height - dims.height
            end

          # Create child space
          child_space = %{
            x: current_x,
            y: child_y,
            width: dims.width,
            height: dims.height
          }

          # Process child element, passing empty accumulator for this child's own processing
          processed_elements_for_this_child =
            Engine.process_element(child, child_space, [])

          # Return new x position and accumulated elements (reversed order)
          {current_x + dims.width + effective_gap,
           processed_elements_for_this_child ++ elements_acc_for_reduce}
        end)

      final_child_elements =
        List.flatten(child_generated_elements_reversed) |> Enum.reverse()

      # Append to the original accumulator from caller
      all_elements = final_child_elements ++ acc
      all_elements
    end
  end

  def process_row(_, _space, acc), do: acc

  @doc """
  Processes a column element, calculating layout for it and its children.

  ## Parameters

  * `column` - The column element to process
  * `space` - The available space for the column
  * `acc` - The accumulator for rendered elements

  ## Returns

  A list of positioned elements with absolute coordinates.
  """
  def process_column(%{type: :column, attrs: attrs} = column, space, acc) do
    IO.inspect({column, space, acc},
      label: "Containers.process_column ENTRY",
      limit: :infinity
    )

    children = Map.get(column, :children, [])
    children = if is_list(children), do: children, else: []
    # Calculate spacing between items
    gap = Map.get(attrs, :gap, 1)
    justify = Map.get(attrs, :justify, :start)
    align = Map.get(attrs, :align, :start)

    # Skip if no children
    if Enum.empty?(children) do
      acc
    else
      # Calculate the space each child needs
      child_dimensions =
        Enum.map(children, fn child ->
          Engine.measure_element(child, space)
        end)

      # Total height used by children
      total_height =
        Enum.reduce(child_dimensions, 0, fn dim, acc ->
          acc + extract_dim(dim, :height, 1, 0)
        end)

      # Space needed for gaps
      gaps_height = gap * (length(children) - 1)

      # Total height including gaps
      total_content_height = total_height + gaps_height

      # Calculate starting y position based on justification
      start_y =
        case justify do
          :start ->
            space.y

          :center ->
            space.y + div(space.height - total_content_height, 2)

          :end ->
            space.y + space.height - total_content_height

          :space_between ->
            # With space_between, we'll recalculate the gap
            space.y
        end

      # If we're using space_between, recalculate the gap
      effective_gap =
        if justify == :space_between and length(children) > 1 do
          remaining_space = space.height - total_height
          div(remaining_space, length(children) - 1)
        else
          gap
        end

      # Position each child
      {_final_y, child_generated_elements_reversed} =
        Enum.zip(children, child_dimensions)
        |> Enum.reduce({start_y, []}, fn {child, dims},
                                         {current_y, elements_acc_for_reduce} ->
          IO.inspect(child,
            label: "Containers.process_column PROCESSING CHILD FOR ENGINE"
          )

          child_x =
            case align do
              :start -> space.x
              :center -> space.x + div(space.width - dims.width, 2)
              :end -> space.x + space.width - dims.width
            end

          # Create child space
          child_space = %{
            x: child_x,
            y: current_y,
            width: dims.width,
            height: dims.height
          }

          # Process child element, passing empty accumulator for this child's own processing
          processed_elements_for_this_child =
            Engine.process_element(child, child_space, [])

          {current_y + dims.height + effective_gap,
           processed_elements_for_this_child ++ elements_acc_for_reduce}
        end)

      final_child_elements =
        List.flatten(child_generated_elements_reversed) |> Enum.reverse()

      all_elements = final_child_elements ++ acc

      IO.inspect(all_elements,
        label: "Containers.process_column RETURNED TO ENGINE"
      )

      all_elements
    end
  end

  def process_column(_, _space, acc), do: acc

  @doc """
  Measures the space needed by a row element.

  ## Parameters

  * `row` - The row element to measure
  * `available_space` - The available space for the row

  ## Returns

  The dimensions of the row: %{width: w, height: h}
  """
  def measure_row(%{type: :row} = row, available_space) do
    children = Map.get(row, :children, [])
    children = if is_list(children), do: children, else: []
    # Skip if no children
    if Enum.empty?(children) do
      %{width: 0, height: 0}
    else
      # Calculate the space each child needs
      child_dimensions =
        Enum.map(children, fn child ->
          Engine.measure_element(child, available_space)
        end)

      # Row width is sum of children's width
      row_width =
        Enum.reduce(child_dimensions, 0, fn dim, acc ->
          acc + extract_dim(dim, :width, 0, 0)
        end)

      # Row height is the maximum child height
      row_height =
        Enum.reduce(child_dimensions, 0, fn dim, acc ->
          max(acc, extract_dim(dim, :height, 1, 0))
        end)

      # Return dimensions constrained to available space
      %{
        width: min(row_width, available_space.width),
        height: min(row_height, available_space.height)
      }
    end
  end

  def measure_row(_, _available_space), do: %{width: 0, height: 0}

  @doc """
  Measures the space needed by a column element.

  ## Parameters

  * `column` - The column element to measure
  * `available_space` - The available space for the column

  ## Returns

  The dimensions of the column: %{width: w, height: h}
  """
  def measure_column(%{type: :column} = column, available_space) do
    children = Map.get(column, :children, [])
    children = if is_list(children), do: children, else: []
    # Skip if no children
    if Enum.empty?(children) do
      %{width: 0, height: 0}
    else
      # Calculate the space each child needs
      child_dimensions =
        Enum.map(children, fn child ->
          Engine.measure_element(child, available_space)
        end)

      # Column height is sum of children's height
      column_height =
        Enum.reduce(child_dimensions, 0, fn dim, acc ->
          acc + extract_dim(dim, :height, 1, 0)
        end)

      # Column width is the maximum child width
      column_width =
        Enum.reduce(child_dimensions, 0, fn dim, acc ->
          max(acc, extract_dim(dim, :width, 0, 0))
        end)

      # Return dimensions constrained to available space
      %{
        width:
          min(column_width, Map.get(available_space, :width, column_width)),
        height:
          min(column_height, Map.get(available_space, :height, column_height))
      }
    end
  end

  def measure_column(_, _available_space), do: %{width: 0, height: 0}

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
end
