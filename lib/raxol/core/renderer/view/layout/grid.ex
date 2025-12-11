defmodule Raxol.Core.Renderer.View.Layout.Grid do
  @moduledoc """
  Handles grid-based layouts for the Raxol view system.
  Provides functionality for creating and managing grid layouts with customizable columns and rows.
  """

  alias Raxol.Core.Runtime.Log

  defp validate_columns(columns) when is_integer(columns) and columns < 1 do
    raise ArgumentError, "Grid must have at least 1 column"
  end

  defp validate_columns(_), do: :ok

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
    columns = Keyword.get(opts, :columns, 1)
    children = Keyword.get(opts, :children, [])
    provided_rows = Keyword.get(opts, :rows)

    # Validate columns
    validate_columns(columns)

    # Calculate required rows if not provided
    rows =
      case provided_rows do
        nil ->
          num_children = length(children)
          required_rows = ceil(num_children / columns)
          max(1, required_rows)

        val ->
          val
      end

    %{
      type: :grid,
      columns: columns,
      rows: rows,
      gap: Keyword.get(opts, :gap, {0, 0}),
      align: Keyword.get(opts, :align, :start),
      justify: Keyword.get(opts, :justify, :start),
      children: children
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
      n when is_integer(n) ->
        calculate_equal_columns(n, total_width, gap)

      sizes when is_list(sizes) ->
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
      n when is_integer(n) ->
        calculate_equal_rows(n, total_height, gap)

      sizes when is_list(sizes) ->
        calculate_custom_rows(sizes, total_height, gap)
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

    final_result = positioned_result ++ auto_placed_result

    final_result
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

    # Create cell bounds map: {col_index, row_index} => {x, y, width, height}
    for {col_start, col_index} <- Enum.with_index(column_positions),
        {row_start, row_index} <- Enum.with_index(row_positions),
        col_index < length(column_sizes) and row_index < length(row_sizes) do
      {{col_index, row_index},
       {
         col_start,
         row_start,
         Enum.at(column_sizes, col_index),
         Enum.at(row_sizes, row_index)
       }}
    end
    |> Map.new()
  end

  defp calculate_simple_cell_bounds(bounds, columns, rows) do
    {x, y, width, height} = bounds

    # Calculate cell dimensions
    cell_width = width / columns
    cell_height = height / rows

    # Create cell bounds map: {row_index, col_index} => {x, y, width, height}
    for row <- 0..(rows - 1),
        col <- 0..(columns - 1) do
      cell_x = x + col * cell_width
      cell_y = y + row * cell_height

      {{row, col}, {cell_x, cell_y, cell_width, cell_height}}
    end
    |> Map.new()
  end

  defp calculate_cumulative_positions(sizes, gap) do
    Enum.reduce(sizes, {[], 0}, fn size, {acc, pos} ->
      {[pos | acc], pos + size + gap}
    end)
    |> elem(0)
    |> Enum.reverse()
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

    # Place children in available positions, row by row
    children
    |> Enum.zip(available_positions)
    |> Enum.map(fn {child, {row, col}} ->
      {x, y, width, height} = Map.get(cell_bounds, {row, col})

      child
      |> Map.put(:grid_position, {row, col})
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

    case {valid_col, valid_row} do
      {true, true} ->
        # Add child with position information
        child_with_pos = Map.put(child, :grid_position, {col, row})
        %{grid | children: [child_with_pos | grid.children]}

      _ ->
        grid
    end
  end

  def container(opts) do
    raw_children = Keyword.get(opts, :children)

    processed_children_list =
      case raw_children do
        children when is_list(children) -> children
        # Default to empty list if nil
        nil -> []
        # Wrap single child in a list
        single_child -> [single_child]
      end

    columns = Keyword.get(opts, :columns, 1)

    rows =
      case Keyword.get(opts, :rows) do
        nil ->
          child_count = length(processed_children_list)
          # ceil(child_count / columns)
          div(child_count + columns - 1, columns)

        val ->
          val
      end

    # Rebuild opts with the processed children list and calculated rows
    final_opts =
      opts
      |> Keyword.put(:children, processed_children_list)
      |> Keyword.put(:rows, rows)

    # Merge all options from final_opts into the base grid map, ensuring :type is :grid
    Map.merge(
      %{
        type: :grid,
        align: Keyword.get(opts, :align, :start),
        justify: Keyword.get(opts, :justify, :start)
      },
      Map.new(final_opts)
    )
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

  defp validate_children_structure(children) when is_list(children) do
    invalid_children = Enum.filter(children, &(!valid_child_structure?(&1)))

    case Enum.empty?(invalid_children) do
      true ->
        :ok

      false ->
        {:error, "Invalid child structure found: #{inspect(invalid_children)}"}
    end
  end

  defp validate_children_structure(_), do: {:error, "Children must be a list"}

  defp valid_child_structure?(child) do
    is_map(child) and Map.has_key?(child, :type)
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

    case Enum.empty?(invalid_positions) do
      true ->
        :ok

      false ->
        {:error, "Invalid grid positions found: #{inspect(invalid_positions)}"}
    end
  end

  defp valid_position?(col, row) when is_integer(col) and is_integer(row) do
    col >= 0 and row >= 0
  end

  defp valid_position?(_, _), do: false

  defp validate_no_duplicate_positions(children) do
    positions =
      children
      |> Enum.map(&Map.get(&1, :grid_position))
      |> Enum.filter(&(&1 != nil))

    unique_positions = Enum.uniq(positions)

    case length(positions) == length(unique_positions) do
      true -> :ok
      false -> {:error, "Duplicate grid positions found"}
    end
  end

  defp calculate_grid_dimensions(children, columns, rows) do
    num_children = length(children)

    # Ensure we have enough rows for all children
    required_rows = ceil(num_children / columns)

    # Use the maximum of provided rows and required rows
    final_rows = max(rows || 1, required_rows)

    {columns, final_rows}
  end

  def grid(children, columns: columns, rows: rows, bounds: bounds) do
    {final_columns, final_rows} =
      calculate_grid_dimensions(children, columns, rows)

    cell_bounds =
      calculate_simple_cell_bounds(bounds, final_columns, final_rows)

    children
    |> Enum.with_index()
    |> Enum.map(fn {child, index} ->
      {row, col} = {div(index, final_columns), rem(index, final_columns)}
      cell_key = {row, col}

      case Map.get(cell_bounds, cell_key) do
        nil ->
          child

        cell_bounds ->
          Log.info(
            "Positioning child #{index} at #{inspect(cell_key)} with bounds #{inspect(cell_bounds)}"
          )

          %{child | bounds: cell_bounds}
      end
    end)
  end
end
