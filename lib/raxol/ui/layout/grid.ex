defmodule Raxol.UI.Layout.Grid do
  @moduledoc """
  Grid layout utility functions.
  """

  @default_columns 1
  @default_gap 1
  @default_span 1
  @min_cell_size 1

  @doc """
  Processes a grid element, calculating layout for it and its children.

  ## Parameters

  * `grid` - The grid element to process
  * `space` - The available space for the grid
  * `acc` - The accumulator for rendered elements

  ## Returns

  A list of positioned elements with absolute coordinates.
  """
  def process(%{type: :grid, attrs: _attrs, children: []}, _space, acc) do
    # Skip if no children
    acc
  end

  def process(%{type: :grid, attrs: attrs, children: children}, space, acc)
      when is_list(children) do
    grid_info = extract_grid_info(attrs, children)
    cell_dims = compute_cell_dims(grid_info, space)

    child_positions =
      children
      |> Enum.with_index()
      |> Enum.map(&position_grid_child(&1, grid_info, cell_dims, space))

    elements =
      Enum.map(child_positions, fn {child, child_space} ->
        Raxol.UI.Layout.Engine.process_element(child, child_space, [])
      end)

    List.flatten(elements) ++ acc
  end

  def process(_, _space, acc), do: acc

  defp extract_grid_info(attrs, children) do
    columns = Map.get(attrs, :columns, @default_columns)

    %{
      columns: columns,
      rows: Map.get(attrs, :rows, ceil(length(children) / columns)),
      gap_x: Map.get(attrs, :gap_x, @default_gap),
      gap_y: Map.get(attrs, :gap_y, @default_gap)
    }
  end

  defp compute_cell_dims(grid_info, space) do
    available_width = space.width - grid_info.gap_x * (grid_info.columns - 1)
    available_height = space.height - grid_info.gap_y * (grid_info.rows - 1)

    %{
      width: div(available_width, grid_info.columns),
      height: div(available_height, grid_info.rows)
    }
  end

  defp position_grid_child({child, index}, grid_info, cell_dims, space) do
    col = rem(index, grid_info.columns)
    row = div(index, grid_info.columns)

    x = space.x + col * (cell_dims.width + grid_info.gap_x)
    y = space.y + row * (cell_dims.height + grid_info.gap_y)

    col_span = Map.get(child, :col_span, @default_span)
    row_span = Map.get(child, :row_span, @default_span)

    span_width = cell_dims.width * col_span + grid_info.gap_x * (col_span - 1)
    span_height = cell_dims.height * row_span + grid_info.gap_y * (row_span - 1)

    {child, %{x: x, y: y, width: span_width, height: span_height}}
  end

  @doc """
  Measures the space needed by a grid element.

  ## Parameters

  * `grid` - The grid element to measure
  * `available_space` - The available space for the grid

  ## Returns

  The dimensions of the grid: %{width: w, height: h}
  """
  def measure_grid(
        %{
          type: :grid,
          attrs: %{width: width, height: height} = _attrs,
          children: _children
        },
        available_space
      ) do
    # Use explicit dimensions
    actual_width = min(width, available_space.width)
    actual_height = min(height, available_space.height)
    %{width: actual_width, height: actual_height}
  end

  def measure_grid(
        %{type: :grid, attrs: attrs, children: children},
        available_space
      ) do
    grid_info = extract_grid_info(attrs, children)

    child_dimensions =
      Enum.map(children, fn child ->
        Raxol.UI.Layout.Engine.measure_element(child, available_space)
      end)

    max_cell = max_child_dimensions(child_dimensions)
    compute_grid_dimensions(grid_info, max_cell, available_space)
  end

  defp max_child_dimensions(child_dimensions) do
    %{
      width:
        Enum.reduce(child_dimensions, 0, fn dim, acc -> max(acc, dim.width) end),
      height:
        Enum.reduce(child_dimensions, 0, fn dim, acc -> max(acc, dim.height) end)
    }
  end

  defp compute_grid_dimensions(grid_info, max_cell, available_space) do
    grid_width =
      min(
        grid_info.columns * max_cell.width +
          grid_info.gap_x * (grid_info.columns - 1),
        available_space.width
      )

    grid_height =
      min(
        grid_info.rows * max_cell.height +
          grid_info.gap_y * (grid_info.rows - 1),
        available_space.height
      )

    %{width: grid_width, height: grid_height}
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
    columns = Map.get(grid_attrs, :columns, @default_columns)
    rows = Map.get(grid_attrs, :rows, @default_columns)
    gap_x = Map.get(grid_attrs, :gap_x, @default_gap)
    gap_y = Map.get(grid_attrs, :gap_y, @default_gap)

    available_width = space.width - gap_x * (columns - 1)
    available_height = space.height - gap_y * (rows - 1)

    cell_width = max(div(available_width, columns), @min_cell_size)
    cell_height = max(div(available_height, rows), @min_cell_size)

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
  def new(opts \\ []) do
    gap = Keyword.get(opts, :gap, 0)

    %{
      type: :grid,
      columns: Keyword.get(opts, :columns, @default_columns),
      rows: Keyword.get(opts, :rows, @default_columns),
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
  def render(grid) do
    # Simple rendering that returns the structure
    {:ok,
     %{
       type: :rendered_grid,
       layout: grid,
       children: position_children(grid)
     }}
  end

  @doc """
  Calculates spacing between grid cells based on gap value.

  Returns a map with calculated spacing values.
  """
  def calculate_spacing(grid) do
    # Use gap_x and gap_y, which are set from gap if not specified
    gap_x = Map.get(grid, :gap_x, grid.gap)
    gap_y = Map.get(grid, :gap_y, grid.gap)

    {:ok,
     %{
       horizontal_spacing: gap_x * (grid.columns - 1),
       vertical_spacing: gap_y * (grid.rows - 1),
       total_gap_width: gap_x * (grid.columns - 1),
       total_gap_height: gap_y * (grid.rows - 1)
     }}
  end

  defp position_children(grid) do
    gap_x = Map.get(grid, :gap_x, grid.gap)
    gap_y = Map.get(grid, :gap_y, grid.gap)
    cell_width = Map.get(grid, :width) || 0
    cell_height = Map.get(grid, :height) || 0

    # Derive per-cell size from total grid dimensions
    col_step = if grid.columns > 0, do: div(cell_width, grid.columns), else: 0
    row_step = if grid.rows > 0, do: div(cell_height, grid.rows), else: 0

    grid.children
    |> Enum.with_index()
    |> Enum.map(fn {child, index} ->
      col = rem(index, grid.columns)
      row = div(index, grid.columns)

      Map.merge(child, %{
        grid_column: col,
        grid_row: row,
        x: col * (col_step + gap_x),
        y: row * (row_step + gap_y)
      })
    end)
  end
end
