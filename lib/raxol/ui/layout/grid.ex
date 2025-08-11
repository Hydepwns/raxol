defmodule Raxol.UI.Layout.Grid do
  @moduledoc """
  Grid layout utility functions.
  """

  @doc """
  Processes a grid element, calculating layout for it and its children.

  ## Parameters

  * `grid` - The grid element to process
  * `space` - The available space for the grid
  * `acc` - The accumulator for rendered elements

  ## Returns

  A list of positioned elements with absolute coordinates.
  """
  def process(%{type: :grid, attrs: attrs, children: children}, space, acc)
      when is_list(children) do
    # Skip if no children
    if children == [] do
      acc
    else
      # Get grid configuration
      columns = Map.get(attrs, :columns, 1)
      rows = Map.get(attrs, :rows, ceil(length(children) / columns))
      gap_x = Map.get(attrs, :gap_x, 1)
      gap_y = Map.get(attrs, :gap_y, 1)

      # Calculate cell dimensions
      available_width = space.width - gap_x * (columns - 1)
      available_height = space.height - gap_y * (rows - 1)
      cell_width = div(available_width, columns)
      cell_height = div(available_height, rows)

      # Calculate positions for each child
      child_positions =
        children
        |> Enum.with_index()
        |> Enum.map(fn {child, index} ->
          # Get column and row from index
          col = rem(index, columns)
          row = div(index, columns)

          # Calculate child position
          x = space.x + col * (cell_width + gap_x)
          y = space.y + row * (cell_height + gap_y)

          # Account for column and row spans if specified
          col_span = Map.get(child, :col_span, 1)
          row_span = Map.get(child, :row_span, 1)

          # Calculate width and height with spans
          span_width = cell_width * col_span + gap_x * (col_span - 1)
          span_height = cell_height * row_span + gap_y * (row_span - 1)

          {child, %{x: x, y: y, width: span_width, height: span_height}}
        end)

      # Process each child with its calculated space
      elements =
        Enum.map(child_positions, fn {child, child_space} ->
          Raxol.UI.Layout.Engine.process_element(child, child_space, [])
        end)

      # Flatten and add to accumulator
      List.flatten(elements) ++ acc
    end
  end

  def process(_, _space, acc), do: acc

  @doc """
  Measures the space needed by a grid element.

  ## Parameters

  * `grid` - The grid element to measure
  * `available_space` - The available space for the grid

  ## Returns

  The dimensions of the grid: %{width: w, height: h}
  """
  def measure_grid(
        %{type: :grid, attrs: attrs, children: children},
        available_space
      ) do
    # Get grid dimensions from attributes or calculate based on children
    if Map.has_key?(attrs, :width) and Map.has_key?(attrs, :height) do
      # Use explicit dimensions
      width = min(Map.get(attrs, :width), available_space.width)
      height = min(Map.get(attrs, :height), available_space.height)
      %{width: width, height: height}
    else
      # Calculate dimensions based on children
      columns = Map.get(attrs, :columns, 1)
      rows = Map.get(attrs, :rows, ceil(length(children) / columns))
      gap_x = Map.get(attrs, :gap_x, 1)
      gap_y = Map.get(attrs, :gap_y, 1)

      # Get child dimensions
      child_dimensions =
        Enum.map(children, fn child ->
          Raxol.UI.Layout.Engine.measure_element(child, available_space)
        end)

      # Find the largest cell
      max_cell_width =
        Enum.reduce(child_dimensions, 0, fn dim, acc ->
          max(acc, dim.width)
        end)

      max_cell_height =
        Enum.reduce(child_dimensions, 0, fn dim, acc ->
          max(acc, dim.height)
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
  * `space` - The base space for the grid

  ## Returns

  A space map with x, y, width, and height for the cell.
  """
  def cell_position(col, row, grid_cells, space) do
    x = space.x + col * (grid_cells.cell_width + grid_cells.gap_x)
    y = space.y + row * (grid_cells.cell_height + grid_cells.gap_y)

    %{
      x: x,
      y: y,
      width: grid_cells.cell_width,
      height: grid_cells.cell_height
    }
  end

  @doc """
  Creates a new grid layout with the given options.
  
  ## Options
  - `:columns` - number of columns
  - `:rows` - number of rows
  - `:gap` - gap between cells
  - `:children` - child elements
  - `:width` - grid width
  - `:height` - grid height
  """
  @spec new(keyword()) :: map()
  def new(opts \\ []) do
    gap = Keyword.get(opts, :gap, 0)
    
    %{
      type: :grid,
      columns: Keyword.get(opts, :columns, 1),
      rows: Keyword.get(opts, :rows, 1),
      gap: gap,
      gap_x: Keyword.get(opts, :gap_x, gap),
      gap_y: Keyword.get(opts, :gap_y, gap),
      children: Keyword.get(opts, :children, []),
      width: Keyword.get(opts, :width),
      height: Keyword.get(opts, :height)
    }
  end

  @doc """
  Renders the grid layout.
  
  Returns the layout with calculated positions for all children.
  """
  @spec render(map()) :: {:ok, map()}
  def render(grid) do
    # Simple rendering that returns the structure
    {:ok, %{
      type: :rendered_grid,
      layout: grid,
      children: position_children(grid)
    }}
  end

  @doc """
  Calculates spacing between grid cells based on gap value.
  
  Returns a map with calculated spacing values.
  """
  @spec calculate_spacing(map()) :: {:ok, map()}
  def calculate_spacing(grid) do
    # Use gap_x and gap_y, which are set from gap if not specified
    gap_x = Map.get(grid, :gap_x, grid.gap)
    gap_y = Map.get(grid, :gap_y, grid.gap)
    
    {:ok, %{
      horizontal_spacing: gap_x * (grid.columns - 1),
      vertical_spacing: gap_y * (grid.rows - 1),
      total_gap_width: gap_x * (grid.columns - 1),
      total_gap_height: gap_y * (grid.rows - 1)
    }}
  end

  defp position_children(grid) do
    grid.children
    |> Enum.with_index()
    |> Enum.map(fn {child, index} ->
      col = rem(index, grid.columns)
      row = div(index, grid.columns)
      
      Map.merge(child, %{
        grid_column: col,
        grid_row: row,
        x: col * 10,  # Simplified positioning
        y: row * 10   # Simplified positioning
      })
    end)
  end
end
