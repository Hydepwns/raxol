defmodule Raxol.Core.Renderer.View.Layout.Grid do
  @moduledoc """
  Handles grid-based layouts for the Raxol view system.
  Provides functionality for creating and managing grid layouts with customizable columns and rows.
  """

  import Raxol.Guards

  @doc """
  Creates a new grid layout.

  ## Options
    * `:columns` - Number of columns or list of column sizes
    * `:rows` - Number of rows or list of row sizes
    * `:gap` - Gap between grid items {x, y}
    * `:align` - Alignment of items within grid cells
    * `:justify` - Justification of items within grid cells
    * `:children` - List of child views to place in the grid

  ## Examples

      Grid.new(columns: 3, rows: 2)
      Grid.new(columns: [1, 2, 1], rows: ["auto", "1fr"])
  """
  def new(opts \\ []) do
    %{
      type: :grid,
      columns: Keyword.get(opts, :columns, 1),
      rows: Keyword.get(opts, :rows, 1),
      gap: Keyword.get(opts, :gap, {0, 0}),
      align: Keyword.get(opts, :align, :start),
      justify: Keyword.get(opts, :justify, :start),
      children: Keyword.get(opts, :children, [])
    }
  end

  @doc """
  Calculates the layout of a grid.
  """
  def calculate_layout(grid, available_size) do
    {width, height} = available_size
    {gap_x, gap_y} = grid.gap

    # Calculate column and row sizes
    column_sizes = calculate_column_sizes(grid.columns, width, gap_x)
    row_sizes = calculate_row_sizes(grid.rows, height, gap_y)

    # Place children in grid cells
    placed_children =
      place_children(grid.children, column_sizes, row_sizes, grid.gap)

    # Apply alignment and justification
    aligned_children =
      apply_alignment(
        placed_children,
        column_sizes,
        row_sizes,
        grid.align,
        grid.justify
      )

    aligned_children
  end

  defp calculate_column_sizes(columns, total_width, gap) do
    case columns do
      n when integer?(n) ->
        calculate_equal_columns(n, total_width, gap)

      sizes when list?(sizes) ->
        calculate_custom_columns(sizes, total_width, gap)
    end
  end

  defp calculate_equal_columns(n, total_width, gap) do
    column_width = (total_width - gap * (n - 1)) / n
    List.duplicate(column_width, n)
  end

  defp calculate_custom_columns(sizes, total_width, gap) do
    total_units = Enum.sum(sizes)
    gap_space = gap * (length(sizes) - 1)

    Enum.map(sizes, fn size ->
      size / total_units * (total_width - gap_space)
    end)
  end

  defp calculate_row_sizes(rows, total_height, gap) do
    case rows do
      n when integer?(n) -> calculate_equal_rows(n, total_height, gap)
      sizes when list?(sizes) -> calculate_custom_rows(sizes, total_height, gap)
    end
  end

  defp calculate_equal_rows(n, total_height, gap) do
    row_height = (total_height - gap * (n - 1)) / n
    List.duplicate(row_height, n)
  end

  defp calculate_custom_rows(sizes, total_height, gap) do
    total_units = Enum.sum(sizes)
    gap_space = gap * (length(sizes) - 1)

    Enum.map(sizes, fn size ->
      size / total_units * (total_height - gap_space)
    end)
  end

  defp place_children(children, column_sizes, row_sizes, {gap_x, gap_y}) do
    # Separate children with explicit positions from those needing auto-placement
    {positioned_children, auto_children} =
      separate_children_by_position(children)

    # Calculate cell boundaries for the grid
    cell_bounds = calculate_cell_bounds(column_sizes, row_sizes, {gap_x, gap_y})

    # Position children with explicit grid positions
    positioned_result =
      position_explicit_children(positioned_children, cell_bounds)

    # Auto-place remaining children
    auto_placed_result =
      auto_place_children(auto_children, cell_bounds, positioned_result)

    positioned_result ++ auto_placed_result
  end

  defp separate_children_by_position(children) do
    Enum.split_with(children, fn child ->
      Map.has_key?(child, :grid_position)
    end)
  end

  defp calculate_cell_bounds(column_sizes, row_sizes, {gap_x, gap_y}) do
    # Calculate cumulative positions for columns and rows
    column_positions = calculate_cumulative_positions(column_sizes, gap_x)
    row_positions = calculate_cumulative_positions(row_sizes, gap_y)

    # Create cell bounds map: {col, row} => {x, y, width, height}
    for {col, col_start} <- Enum.with_index(column_positions),
        {row, row_start} <- Enum.with_index(row_positions),
        col < length(column_sizes) and row < length(row_sizes) do
      {{col, row},
       {
         col_start,
         row_start,
         Enum.at(column_sizes, col),
         Enum.at(row_sizes, row)
       }}
    end
    |> Map.new()
  end

  defp calculate_cumulative_positions(sizes, gap) do
    sizes
    |> Enum.scan(0, fn size, acc -> acc + size + gap end)
    |> List.insert_at(0, 0)
  end

  defp position_explicit_children(children, cell_bounds) do
    Enum.map(children, fn child ->
      {col, row} = child.grid_position

      case Map.get(cell_bounds, {col, row}) do
        {x, y, width, height} ->
          child
          |> Map.put(:position, {x, y})
          |> Map.put(:size, {width, height})

        nil ->
          # Invalid position, use default
          child
          |> Map.put(:position, {0, 0})
          |> Map.put(:size, {100, 100})
      end
    end)
  end

  defp auto_place_children(children, cell_bounds, existing_children) do
    # Get all available positions
    all_positions = Map.keys(cell_bounds)
    used_positions = get_used_positions(existing_children)
    available_positions = all_positions -- used_positions

    # Place children in available positions
    children
    |> Enum.zip(available_positions)
    |> Enum.map(fn {child, {col, row}} ->
      {x, y, width, height} = Map.get(cell_bounds, {col, row})

      child
      |> Map.put(:grid_position, {col, row})
      |> Map.put(:position, {x, y})
      |> Map.put(:size, {width, height})
    end)
  end

  defp get_used_positions(children) do
    children
    |> Enum.map(&Map.get(&1, :grid_position))
    |> Enum.filter(&(&1 != nil))
  end

  defp apply_alignment(children, column_sizes, row_sizes, align, justify) do
    Enum.map(children, fn child ->
      align_child_in_cell(child, column_sizes, row_sizes, align, justify)
    end)
  end

  defp align_child_in_cell(child, column_sizes, row_sizes, align, justify) do
    {col, row} = child.grid_position

    {cell_x, cell_y, cell_width, cell_height} =
      get_cell_bounds(col, row, column_sizes, row_sizes)

    {child_width, child_height} = get_child_size(child)

    # Calculate aligned position within cell
    aligned_x =
      calculate_horizontal_alignment(cell_x, cell_width, child_width, justify)

    aligned_y =
      calculate_vertical_alignment(cell_y, cell_height, child_height, align)

    # Update child with aligned position and size
    child
    |> Map.put(:position, {aligned_x, aligned_y})
    |> Map.put(:size, {child_width, child_height})
  end

  defp get_cell_bounds(col, row, column_sizes, row_sizes) do
    col_width = Enum.at(column_sizes, col, 0)
    row_height = Enum.at(row_sizes, row, 0)

    # Calculate cumulative positions
    col_x = Enum.take(column_sizes, col) |> Enum.sum()
    row_y = Enum.take(row_sizes, row) |> Enum.sum()

    {col_x, row_y, col_width, row_height}
  end

  defp get_child_size(child) do
    case Map.get(child, :size) do
      {width, height} -> {width, height}
      # Default size
      nil -> {100, 100}
    end
  end

  defp calculate_horizontal_alignment(cell_x, cell_width, child_width, justify) do
    case justify do
      :start -> cell_x
      :center -> cell_x + (cell_width - child_width) / 2
      :end -> cell_x + cell_width - child_width
      # Simplified - would need multiple children
      :space_between -> cell_x
      _ -> cell_x
    end
  end

  defp calculate_vertical_alignment(cell_y, cell_height, child_height, align) do
    case align do
      :start -> cell_y
      :center -> cell_y + (cell_height - child_height) / 2
      :end -> cell_y + cell_height - child_height
      # Child height would be adjusted to cell height
      :stretch -> cell_y
      _ -> cell_y
    end
  end

  @doc """
  Adds a child to the grid at the specified position.
  """
  def add_child(grid, child, {col, row}) do
    # Validate position
    valid_col = col >= 0 and col < length(grid.columns)
    valid_row = row >= 0 and row < length(grid.rows)

    if valid_col and valid_row do
      # Add child with position information
      child_with_pos = Map.put(child, :grid_position, {col, row})
      %{grid | children: [child_with_pos | grid.children]}
    else
      grid
    end
  end

  def container(opts) do
    raw_children = Keyword.get(opts, :children)

    processed_children_list =
      cond do
        list?(raw_children) -> raw_children
        # Default to empty list if nil
        nil?(raw_children) -> []
        # Wrap single child in a list
        true -> [raw_children]
      end

    # Rebuild opts with the processed children list
    final_opts = Keyword.put(opts, :children, processed_children_list)

    # Merge all options from final_opts into the base grid map, ensuring :type is :grid
    # Specific grid options like :columns, :rows, :gap will be taken from final_opts if present.
    Map.merge(%{type: :grid}, Map.new(final_opts))
  end

  def validate_children(children) do
    # Validates that children are properly formatted for grid layout
    # Returns :ok if valid, {:error, reason} if invalid

    case validate_children_structure(children) do
      :ok ->
        case validate_grid_positions(children) do
          :ok ->
            validate_no_duplicate_positions(children)

          error ->
            error
        end

      error ->
        error
    end
  end

  defp validate_children_structure(children) when list?(children) do
    invalid_children = Enum.filter(children, &(!valid_child_structure?(&1)))

    if Enum.empty?(invalid_children) do
      :ok
    else
      {:error, "Invalid child structure found: #{inspect(invalid_children)}"}
    end
  end

  defp validate_children_structure(_), do: {:error, "Children must be a list"}

  defp valid_child_structure?(child) do
    map?(child) and Map.has_key?(child, :type)
  end

  defp validate_grid_positions(children) do
    invalid_positions =
      children
      |> Enum.filter(fn child ->
        Map.has_key?(child, :grid_position) and
          (fn ->
             {col, row} = child.grid_position
             !valid_position?(col, row)
           end).()
      end)

    if Enum.empty?(invalid_positions) do
      :ok
    else
      {:error, "Invalid grid positions found: #{inspect(invalid_positions)}"}
    end
  end

  defp valid_position?(col, row) when integer?(col) and integer?(row) do
    col >= 0 and row >= 0
  end

  defp valid_position?(_, _), do: false

  defp validate_no_duplicate_positions(children) do
    positions =
      children
      |> Enum.map(&Map.get(&1, :grid_position))
      |> Enum.filter(&(&1 != nil))

    unique_positions = Enum.uniq(positions)

    if length(positions) == length(unique_positions) do
      :ok
    else
      {:error, "Duplicate grid positions found"}
    end
  end
end
