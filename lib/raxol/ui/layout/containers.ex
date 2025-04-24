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
  def process_row(%{type: :row, attrs: attrs, children: children}, space, acc)
      when is_list(children) do
    # Calculate spacing between items
    gap = Map.get(attrs, :gap, 1)
    justify = Map.get(attrs, :justify, :start)
    align = Map.get(attrs, :align, :start)

    # Skip if no children
    if children == [] do
      acc
    else
      # Calculate the space each child needs
      child_dimensions =
        Enum.map(children, fn child ->
          Engine.measure_element(child, space)
        end)

      # Total width used by children
      total_width = Enum.reduce(child_dimensions, 0, fn dim, acc ->
        acc + dim.width
      end)

      # Space needed for gaps
      gaps_width = gap * (length(children) - 1)

      # Total width including gaps
      total_content_width = total_width + gaps_width

      # Calculate starting x position based on justification
      start_x = case justify do
        :start -> space.x
        :center -> space.x + div(space.width - total_content_width, 2)
        :end -> space.x + space.width - total_content_width
        :space_between ->
          # With space_between, we'll recalculate the gap
          space.x
      end

      # If we're using space_between, recalculate the gap
      effective_gap = if justify == :space_between and length(children) > 1 do
        remaining_space = space.width - total_width
        div(remaining_space, length(children) - 1)
      else
        gap
      end

      # Position each child
      {_, elements} =
        Enum.zip(children, child_dimensions)
        |> Enum.reduce({start_x, []}, fn {child, dims}, {current_x, elements} ->
          # Calculate y position based on alignment
          child_y = case align do
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

          # Process child element
          child_elements = Engine.process_element(child, child_space, [])

          # Return new x position and accumulated elements
          {current_x + dims.width + effective_gap, [child_elements | elements]}
        end)

      # Flatten and add to accumulator
      List.flatten(elements) ++ acc
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
  def process_column(%{type: :column, attrs: attrs, children: children}, space, acc)
      when is_list(children) do
    # Calculate spacing between items
    gap = Map.get(attrs, :gap, 1)
    justify = Map.get(attrs, :justify, :start)
    align = Map.get(attrs, :align, :start)

    # Skip if no children
    if children == [] do
      acc
    else
      # Calculate the space each child needs
      child_dimensions =
        Enum.map(children, fn child ->
          Engine.measure_element(child, space)
        end)

      # Total height used by children
      total_height = Enum.reduce(child_dimensions, 0, fn dim, acc ->
        acc + dim.height
      end)

      # Space needed for gaps
      gaps_height = gap * (length(children) - 1)

      # Total height including gaps
      total_content_height = total_height + gaps_height

      # Calculate starting y position based on justification
      start_y = case justify do
        :start -> space.y
        :center -> space.y + div(space.height - total_content_height, 2)
        :end -> space.y + space.height - total_content_height
        :space_between ->
          # With space_between, we'll recalculate the gap
          space.y
      end

      # If we're using space_between, recalculate the gap
      effective_gap = if justify == :space_between and length(children) > 1 do
        remaining_space = space.height - total_height
        div(remaining_space, length(children) - 1)
      else
        gap
      end

      # Position each child
      {_, elements} =
        Enum.zip(children, child_dimensions)
        |> Enum.reduce({start_y, []}, fn {child, dims}, {current_y, elements} ->
          # Calculate x position based on alignment
          child_x = case align do
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

          # Process child element
          child_elements = Engine.process_element(child, child_space, [])

          # Return new y position and accumulated elements
          {current_y + dims.height + effective_gap, [child_elements | elements]}
        end)

      # Flatten and add to accumulator
      List.flatten(elements) ++ acc
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
  def measure_row(%{type: :row, attrs: _attrs, children: children}, available_space)
      when is_list(children) do
    # Skip if no children
    if children == [] do
      %{width: 0, height: 0}
    else
      # Calculate the space each child needs
      child_dimensions =
        Enum.map(children, fn child ->
          Engine.measure_element(child, available_space)
        end)

      # Row width is sum of children's width
      row_width = Enum.reduce(child_dimensions, 0, fn dim, acc ->
        acc + dim.width
      end)

      # Row height is the maximum child height
      row_height = Enum.reduce(child_dimensions, 0, fn dim, acc ->
        max(acc, dim.height)
      end)

      # Return dimensions constrained to available space
      %{
        width: min(row_width, available_space.width),
        height: min(row_height, available_space.height)
      }
    end
  end

  def measure_row(_, available_space), do: %{width: 0, height: 0}

  @doc """
  Measures the space needed by a column element.

  ## Parameters

  * `column` - The column element to measure
  * `available_space` - The available space for the column

  ## Returns

  The dimensions of the column: %{width: w, height: h}
  """
  def measure_column(%{type: :column, attrs: _attrs, children: children}, available_space)
      when is_list(children) do
    # Skip if no children
    if children == [] do
      %{width: 0, height: 0}
    else
      # Calculate the space each child needs
      child_dimensions =
        Enum.map(children, fn child ->
          Engine.measure_element(child, available_space)
        end)

      # Column height is sum of children's height
      column_height = Enum.reduce(child_dimensions, 0, fn dim, acc ->
        acc + dim.height
      end)

      # Column width is the maximum child width
      column_width = Enum.reduce(child_dimensions, 0, fn dim, acc ->
        max(acc, dim.width)
      end)

      # Return dimensions constrained to available space
      %{
        width: min(column_width, available_space.width),
        height: min(column_height, available_space.height)
      }
    end
  end

  def measure_column(_, available_space), do: %{width: 0, height: 0}
end
