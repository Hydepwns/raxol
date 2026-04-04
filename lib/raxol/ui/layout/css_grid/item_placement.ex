defmodule Raxol.UI.Layout.CSSGrid.ItemPlacement do
  @moduledoc """
  Handles grid item placement: explicit placement via grid-area / grid-row /
  grid-column, occupancy-grid construction, and auto-placement (grid-auto-flow).
  """

  @compile {:no_warn_undefined, Raxol.UI.Layout.CSSGrid.Cell}
  @compile {:no_warn_undefined, Raxol.UI.Layout.CSSGrid.Item}

  alias Raxol.UI.Layout.CSSGrid.{Cell, Item}
  alias Raxol.UI.Layout.Engine

  # ---------------------------------------------------------------------------
  # Grid areas
  # ---------------------------------------------------------------------------

  @doc "Parse grid-template-areas string into a map of area_name -> bounds."
  def parse_grid_areas("none"), do: %{}

  def parse_grid_areas(areas_str) when is_binary(areas_str) do
    areas_str
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
    |> Enum.with_index()
    |> Enum.reduce(%{}, &parse_area_line/2)
  end

  def parse_grid_areas(_), do: %{}

  defp parse_area_line({line, row}, acc) do
    line
    |> String.replace(~r/["']/, "")
    |> String.split(~r/\s+/)
    |> Enum.filter(&(&1 != ""))
    |> Enum.with_index()
    |> Enum.reduce(acc, fn {area_name, col}, inner_acc ->
      update_area_bounds(area_name, row, col, inner_acc)
    end)
  end

  # ---------------------------------------------------------------------------
  # Explicit item placement
  # ---------------------------------------------------------------------------

  @doc "Place children that have explicit grid-area / grid-row / grid-column."
  def place_grid_items(
        children,
        column_tracks,
        row_tracks,
        areas,
        content_space,
        _grid_props
      ) do
    children
    |> Enum.reduce([], fn child, acc ->
      child_attrs = Map.get(child, :attrs, %{})
      grid_area = Map.get(child_attrs, :grid_area)
      grid_row = Map.get(child_attrs, :grid_row)
      grid_column = Map.get(child_attrs, :grid_column)

      dims = Engine.measure_element(child, content_space)

      cell =
        determine_cell_placement(
          grid_area,
          grid_row,
          grid_column,
          areas,
          row_tracks,
          column_tracks
        )

      create_grid_item(child, cell, dims, acc)
    end)
    |> Enum.reverse()
  end

  def determine_cell_placement(
        grid_area,
        _grid_row,
        _grid_column,
        areas,
        _row_tracks,
        _column_tracks
      )
      when not is_nil(grid_area) and is_map_key(areas, grid_area) do
    area = areas[grid_area]

    Cell.new(
      area.min_row + 1,
      area.min_col + 1,
      area.max_row - area.min_row + 1,
      area.max_col - area.min_col + 1,
      grid_area
    )
  end

  def determine_cell_placement(
        _grid_area,
        grid_row,
        grid_column,
        _areas,
        row_tracks,
        column_tracks
      )
      when not is_nil(grid_row) or not is_nil(grid_column) do
    {row, row_span} = parse_grid_line(grid_row, length(row_tracks))
    {col, col_span} = parse_grid_line(grid_column, length(column_tracks))
    Cell.new(row, col, row_span, col_span)
  end

  def determine_cell_placement(
        _grid_area,
        _grid_row,
        _grid_column,
        _areas,
        _row_tracks,
        _column_tracks
      ) do
    nil
  end

  # ---------------------------------------------------------------------------
  # Grid line parsing
  # ---------------------------------------------------------------------------

  def parse_grid_line(nil, _track_count), do: {1, 1}

  def parse_grid_line(line_str, track_count) when is_binary(line_str) do
    case String.split(line_str, "/") do
      [start_str] ->
        {parse_line_number(start_str, track_count), 1}

      [start_str, end_str] ->
        start_num = parse_line_number(start_str, track_count)
        parse_grid_line_end(start_num, end_str, track_count)

      _ ->
        {1, 1}
    end
  end

  def parse_grid_line(line_num, _track_count) when is_integer(line_num),
    do: {line_num, 1}

  def parse_grid_line(_, _track_count), do: {1, 1}

  def parse_line_number(line_str, track_count) do
    case Integer.parse(String.trim(line_str)) do
      {num, ""} when num > 0 -> num
      {num, ""} when num < 0 -> track_count + 1 + num
      _ -> 1
    end
  end

  def parse_grid_line_end(start_num, end_str, track_count) do
    trimmed = String.trim(end_str)

    if String.starts_with?(trimmed, "span") do
      span_str = trimmed |> String.trim_leading("span") |> String.trim()
      {span, ""} = Integer.parse(span_str)
      {start_num, span}
    else
      end_num = parse_line_number(end_str, track_count)
      {start_num, end_num - start_num}
    end
  end

  # ---------------------------------------------------------------------------
  # Auto placement
  # ---------------------------------------------------------------------------

  @doc "Auto-place items that have no explicit cell."
  def auto_place_items(placed_items, column_tracks, row_tracks, grid_props) do
    {auto_items, explicit_items} =
      Enum.split_with(placed_items, & &1.auto_placed)

    occupancy =
      create_occupancy_grid(
        explicit_items,
        length(column_tracks),
        length(row_tracks)
      )

    {final_auto_items, _} =
      Enum.reduce(auto_items, {[], occupancy}, fn item, {acc, occ} ->
        {new_cell, new_occ} =
          find_auto_placement(
            item,
            occ,
            grid_props.grid_auto_flow,
            length(column_tracks),
            length(row_tracks)
          )

        new_item = %{item | cell: new_cell, auto_placed: true}
        {[new_item | acc], new_occ}
      end)

    explicit_items ++ Enum.reverse(final_auto_items)
  end

  # ---------------------------------------------------------------------------
  # Occupancy grid
  # ---------------------------------------------------------------------------

  def create_occupancy_grid(items, col_count, row_count) do
    grid = for _r <- 1..row_count, do: for(_c <- 1..col_count, do: false)

    Enum.reduce(items, grid, fn item, acc ->
      mark_cells_if_present(item.cell, acc)
    end)
  end

  def mark_cells_if_present(nil, acc), do: acc
  def mark_cells_if_present(cell, acc), do: mark_occupied_cells(acc, cell)

  def mark_occupied_cells(grid, cell) do
    for {row, r} <- Enum.with_index(grid) do
      for {occupied, c} <- Enum.with_index(row) do
        row_idx = r + 1
        col_idx = c + 1

        cell_occupies_position(
          cell_intersects(row_idx, col_idx, cell),
          occupied
        )
      end
    end
  end

  def cell_intersects(row_idx, col_idx, cell) do
    row_idx >= cell.row and row_idx < cell.row + cell.row_span and
      col_idx >= cell.column and col_idx < cell.column + cell.column_span
  end

  def cell_occupies_position(true, _occupied), do: true
  def cell_occupies_position(false, occupied), do: occupied

  def find_auto_placement(_item, occupancy, flow, col_count, row_count) do
    result =
      case flow do
        :row ->
          find_next_available_row(occupancy, 1, 1, col_count, row_count)

        :column ->
          find_next_available_column(occupancy, 1, 1, col_count, row_count)

        _ ->
          find_next_available_row(occupancy, 1, 1, col_count, row_count)
      end

    case result do
      {row, col} ->
        cell = Cell.new(row, col, 1, 1)
        new_occupancy = mark_occupied_cells(occupancy, cell)
        {cell, new_occupancy}

      nil ->
        cell = Cell.new(row_count + 1, 1, 1, 1)
        new_occupancy = mark_occupied_cells(occupancy, cell)
        {cell, new_occupancy}
    end
  end

  def find_next_available_row(grid, row, col, col_count, row_count)
      when row <= row_count and col > col_count do
    find_next_available_row(grid, row + 1, 1, col_count, row_count)
  end

  def find_next_available_row(grid, row, col, col_count, row_count)
      when row <= row_count do
    if cell_available?(grid, row, col),
      do: {row, col},
      else: find_next_available_row(grid, row, col + 1, col_count, row_count)
  end

  def find_next_available_row(_, row, _col, _col_count, row_count)
      when row > row_count, do: nil

  def find_next_available_column(grid, row, col, col_count, row_count)
      when col <= col_count and row > row_count do
    find_next_available_column(grid, 1, col + 1, col_count, row_count)
  end

  def find_next_available_column(grid, row, col, col_count, row_count)
      when col <= col_count do
    if cell_available?(grid, row, col),
      do: {row, col},
      else: find_next_available_column(grid, row + 1, col, col_count, row_count)
  end

  def find_next_available_column(_, _row, col, col_count, _row_count)
      when col > col_count, do: nil

  def cell_available?(grid, row, col)
      when row > 0 and row <= length(grid) and col > 0 do
    row_data = Enum.at(grid, row - 1)
    check_column_availability(row_data, col)
  end

  def cell_available?(_grid, _row, _col), do: false

  def check_column_availability(row_data, col) when col <= length(row_data) do
    not Enum.at(row_data, col - 1)
  end

  def check_column_availability(_row_data, _col), do: true

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def update_area_bounds(".", _row, _col, acc), do: acc

  def update_area_bounds(area_name, row, col, acc) do
    current =
      Map.get(acc, area_name, %{
        min_row: row,
        max_row: row,
        min_col: col,
        max_col: col
      })

    updated = %{
      min_row: min(current.min_row, row),
      max_row: max(current.max_row, row),
      min_col: min(current.min_col, col),
      max_col: max(current.max_col, col)
    }

    Map.put(acc, area_name, updated)
  end

  def create_grid_item(child, nil, dims, acc) do
    [Item.new(child, nil, dims, true) | acc]
  end

  def create_grid_item(child, cell, dims, acc) do
    [Item.new(child, cell, dims, false) | acc]
  end
end
