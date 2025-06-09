defmodule Raxol.UI.Layout.Grid do
  @moduledoc """
  Handles layout calculations for grid UI elements.

  This module is responsible for:
  * Grid-based layout calculations
  * Cell sizing and positioning
  * Column and row spanning elements
  * Grid-specific spacing and constraints
  """

  alias Raxol.UI.Layout.Engine

  @doc """
  Processes a grid element, calculating layout for it and its children.

  ## Parameters

  * `grid` - The grid element to process
  * `space` - The available space for the grid
  * `acc` - The accumulator for rendered elements

  ## Returns

  A list of positioned elements with absolute coordinates.
  """
  def process_grid(%{type: :grid, attrs: attrs} = grid, space, acc) do
    children = Map.get(grid, :children, [])
    children = if is_list(children), do: children, else: []
    # Calculate grid parameters
    columns = Map.get(attrs, :columns, 1)
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

      # Calculate cell size
      cell_width = div(space.width - gap * (columns - 1), columns)

      cell_height =
        div(
          space.height - gap * div(length(children) - 1, columns),
          div(length(children) - 1, columns) + 1
        )

      # Position each child
      child_generated_elements =
        Enum.with_index(children)
        |> Enum.map(fn {child, index} ->
          row = div(index, columns)
          col = rem(index, columns)

          # Calculate cell position
          cell_x = space.x + col * (cell_width + gap)
          cell_y = space.y + row * (cell_height + gap)

          # Calculate child position within cell based on alignment
          child_x =
            case justify do
              :start ->
                cell_x

              :center ->
                cell_x + div(cell_width - child_dimensions[index].width, 2)

              :end ->
                cell_x + cell_width - child_dimensions[index].width
            end

          child_y =
            case align do
              :start ->
                cell_y

              :center ->
                cell_y + div(cell_height - child_dimensions[index].height, 2)

              :end ->
                cell_y + cell_height - child_dimensions[index].height
            end

          # Create child space
          child_space = %{
            x: child_x,
            y: child_y,
            width: child_dimensions[index].width,
            height: child_dimensions[index].height
          }

          # Process child element
          Engine.process_element(child, child_space, [])
        end)

      # Append to the original accumulator from caller
      all_elements = List.flatten(child_generated_elements) ++ acc
      all_elements
    end
  end

  def process_grid(_, _space, acc), do: acc

  @doc """
  Measures the space needed by a grid element.

  ## Parameters

  * `grid` - The grid element to measure
  * `available_space` - The available space for the grid

  ## Returns

  The dimensions of the grid: %{width: w, height: h}
  """
  def measure_grid(%{type: :grid, attrs: attrs} = grid, available_space) do
    children = Map.get(grid, :children, [])
    children = if is_list(children), do: children, else: []
    # Get grid dimensions from attributes or calculate based on children
    if (is_map(attrs) and Map.has_key?(attrs, :width) and
          Map.has_key?(attrs, :height)) or
         (is_tuple(attrs) and tuple_size(attrs) >= 2) do
      width =
        extract_dim(attrs, :width, 0, safe_map_get(available_space, :width, 80))

      height =
        extract_dim(
          attrs,
          :height,
          1,
          safe_map_get(available_space, :height, 24)
        )

      %{
        width: min(width, safe_map_get(available_space, :width, 80)),
        height: min(height, safe_map_get(available_space, :height, 24))
      }
    else
      # Calculate dimensions based on children
      columns = Map.get(attrs, :columns, 1)
      rows = Map.get(attrs, :rows, ceil(length(children) / columns))
      gap_x = Map.get(attrs, :gap_x, 1)
      gap_y = Map.get(attrs, :gap_y, 1)

      # Get child dimensions
      child_dimensions =
        Enum.map(children, fn child ->
          Engine.measure_element(child, available_space)
        end)

      # Find the largest cell
      max_cell_width =
        Enum.reduce(child_dimensions, 0, fn dim, acc ->
          max(acc, extract_dim(dim, :width, 0, 0))
        end)

      max_cell_height =
        Enum.reduce(child_dimensions, 0, fn dim, acc ->
          max(acc, extract_dim(dim, :height, 1, 0))
        end)

      # Calculate grid dimensions
      grid_width =
        min(
          columns * max_cell_width + gap_x * (columns - 1),
          available_space.width
        )

      grid_height =
        min(rows * max_cell_height + gap_y * (rows - 1), available_space.height)

      %{width: grid_width, height: grid_height}
    end
  end

  # Helper functions for grid layout

  @doc """
  Creates grid cell information for a grid layout.

  ## Parameters

  * `grid_attrs` - The grid attributes
  * `space` - The available space

  ## Returns

  A map containing cell dimensions and grid information.
  """
  def calculate_grid_cells(grid_attrs, space) do
    # Get grid configuration
    columns = Map.get(grid_attrs, :columns, 1)
    rows = Map.get(grid_attrs, :rows, 1)
    gap_x = Map.get(grid_attrs, :gap_x, 1)
    gap_y = Map.get(grid_attrs, :gap_y, 1)

    # Available space accounting for gaps
    available_width = space.width - gap_x * (columns - 1)
    available_height = space.height - gap_y * (rows - 1)

    # Cell dimensions
    cell_width = max(div(available_width, columns), 1)
    cell_height = max(div(available_height, rows), 1)

    # Return grid cell information
    %{
      columns: columns,
      rows: rows,
      gap_x: gap_x,
      gap_y: gap_y,
      cell_width: cell_width,
      cell_height: cell_height
    }
  end

  @doc """
  Calculates the position for a cell in the grid.

  ## Parameters

  * `col` - The column index (0-based)
  * `row` - The row index (0-based)
  * `grid_cells` - The grid cell information from `calculate_grid_cells/2`

  ## Returns

  The position for the cell in the grid.
  """
  def calculate_cell_position(col, row, grid_cells) do
    %{
      x: grid_cells.cell_width * col + grid_cells.gap_x * col,
      y: grid_cells.cell_height * row + grid_cells.gap_y * row
    }
  end

  # Helper function to safely get a value from a map with a default
  defp safe_map_get(map, key, default) do
    if is_map(map), do: Map.get(map, key, default), else: default
  end

  # Helper function to extract dimensions from attributes
  defp extract_dim(attrs, key, default, _opts) do
    cond do
      is_map(attrs) and Map.has_key?(attrs, key) -> Map.get(attrs, key)
      true -> default
    end
  end
end
