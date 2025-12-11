defmodule Raxol.UI.Layout.CSSGrid do
  @moduledoc """
  CSS Grid layout system for Raxol UI components.

  Provides CSS Grid-compatible layout with template rows/columns, grid areas,
  gaps, alignment properties, auto-placement, and grid line naming.

  ## Usage

      %{
        type: :css_grid,
        attrs: %{
          grid_template_columns: "1fr 200px 1fr",
          grid_template_rows: "auto 1fr auto",
          gap: 10
        },
        children: children
      }
  """

  alias Raxol.UI.Layout.Engine

  # Grid track definition
  defmodule Track do
    @moduledoc """
    Grid track (row or column) definition.

    Defines a track's type (fr, px, percent, minmax, auto), value, and optional name.
    """
    defstruct [:type, :value, :name]

    def new(type, value, name \\ nil) do
      %__MODULE__{type: type, value: value, name: name}
    end
  end

  # Grid cell definition
  defmodule Cell do
    @moduledoc """
    Grid cell definition specifying position and span.

    Defines a cell's row, column, row span, column span, and optional named area.
    """
    defstruct [:row, :column, :row_span, :column_span, :area]

    def new(row, column, row_span \\ 1, column_span \\ 1, area \\ nil) do
      %__MODULE__{
        row: row,
        column: column,
        row_span: row_span,
        column_span: column_span,
        area: area
      }
    end
  end

  # Grid item placement
  defmodule Item do
    @moduledoc """
    Grid item with placement information.

    Associates a child element with its cell position, dimensions, and
    auto-placement status.
    """
    defstruct [:child, :cell, :dimensions, :auto_placed]

    def new(child, cell, dimensions, auto_placed \\ false) do
      %__MODULE__{
        child: child,
        cell: cell,
        dimensions: dimensions,
        auto_placed: auto_placed
      }
    end
  end

  @doc """
  Processes a CSS Grid container, calculating layout for it and its children.
  """
  def process_css_grid(
        %{type: :css_grid, children: children} = grid,
        space,
        acc
      )
      when is_list(children) do
    attrs = Map.get(grid, :attrs, %{})

    # Parse grid properties
    grid_props = parse_grid_properties(attrs)

    # Apply padding to available space
    content_space = apply_padding(space, grid_props.padding)

    # Parse grid template areas if provided
    areas = parse_grid_areas(grid_props.grid_template_areas)

    # Create explicit grid tracks
    column_tracks =
      parse_grid_tracks(grid_props.grid_template_columns, content_space.width)

    row_tracks =
      parse_grid_tracks(grid_props.grid_template_rows, content_space.height)

    # Place grid items
    placed_items =
      place_grid_items(
        children,
        column_tracks,
        row_tracks,
        areas,
        content_space,
        grid_props
      )

    # Auto-place remaining items
    all_items =
      auto_place_items(placed_items, column_tracks, row_tracks, grid_props)

    # Size tracks based on content
    {final_column_tracks, final_row_tracks} =
      size_tracks(
        all_items,
        column_tracks,
        row_tracks,
        content_space,
        grid_props
      )

    # Calculate final positions
    positioned_items =
      calculate_positions(
        all_items,
        final_column_tracks,
        final_row_tracks,
        content_space,
        grid_props
      )

    # Process each positioned item
    elements =
      Enum.flat_map(positioned_items, fn {child, child_space} ->
        Engine.process_element(child, child_space, [])
      end)

    elements ++ acc
  end

  def process_css_grid(_, _space, acc), do: acc

  @doc """
  Measures the space needed by a CSS Grid container.
  """
  def measure_css_grid(
        %{type: :css_grid, children: children} = grid,
        available_space
      )
      when is_list(children) do
    attrs = Map.get(grid, :attrs, %{})
    grid_props = parse_grid_properties(attrs)

    # Apply padding for measurement
    content_space = apply_padding(available_space, grid_props.padding)

    # Create initial tracks for measurement
    column_tracks =
      parse_grid_tracks(grid_props.grid_template_columns, content_space.width)

    row_tracks =
      parse_grid_tracks(grid_props.grid_template_rows, content_space.height)

    # Quick placement for measurement (simplified)
    areas = parse_grid_areas(grid_props.grid_template_areas)

    placed_items =
      place_grid_items(
        children,
        column_tracks,
        row_tracks,
        areas,
        content_space,
        grid_props
      )

    all_items =
      auto_place_items(placed_items, column_tracks, row_tracks, grid_props)

    # Size tracks
    {final_column_tracks, final_row_tracks} =
      size_tracks(
        all_items,
        column_tracks,
        row_tracks,
        content_space,
        grid_props
      )

    # Calculate total size
    total_width =
      Enum.reduce(final_column_tracks, 0, fn track, acc ->
        acc + track.value
      end) + grid_props.gap.column * max(0, length(final_column_tracks) - 1)

    total_height =
      Enum.reduce(final_row_tracks, 0, fn track, acc ->
        acc + track.value
      end) + grid_props.gap.row * max(0, length(final_row_tracks) - 1)

    # Add padding back
    %{
      width: total_width + grid_props.padding.left + grid_props.padding.right,
      height: total_height + grid_props.padding.top + grid_props.padding.bottom
    }
  end

  def measure_css_grid(_, _available_space), do: %{width: 0, height: 0}

  # Private helper functions

  defp parse_grid_properties(attrs) do
    %{
      grid_template_columns: Map.get(attrs, :grid_template_columns, "none"),
      grid_template_rows: Map.get(attrs, :grid_template_rows, "none"),
      grid_template_areas: Map.get(attrs, :grid_template_areas, "none"),
      grid_auto_columns: Map.get(attrs, :grid_auto_columns, "auto"),
      grid_auto_rows: Map.get(attrs, :grid_auto_rows, "auto"),
      grid_auto_flow: Map.get(attrs, :grid_auto_flow, :row),
      gap: parse_gap(Map.get(attrs, :gap, 0)),
      justify_items: Map.get(attrs, :justify_items, :stretch),
      align_items: Map.get(attrs, :align_items, :stretch),
      justify_content: Map.get(attrs, :justify_content, :start),
      align_content: Map.get(attrs, :align_content, :start),
      padding: parse_padding(Map.get(attrs, :padding, 0))
    }
  end

  defp parse_gap(gap) when is_integer(gap) do
    %{row: gap, column: gap}
  end

  defp parse_gap(%{row: row, column: column}) do
    %{row: row, column: column}
  end

  defp parse_gap(_), do: %{row: 0, column: 0}

  # Import shared layout utilities
  alias Raxol.UI.Layout.LayoutUtils

  defp parse_padding(padding), do: LayoutUtils.parse_padding(padding)

  defp apply_padding(space, padding),
    do: LayoutUtils.apply_padding(space, padding)

  defp parse_grid_tracks("none", _available_size), do: []

  defp parse_grid_tracks(tracks_str, available_size)
       when is_binary(tracks_str) do
    tracks_str
    |> String.split(~r/\s+/)
    |> Enum.filter(&(&1 != ""))
    |> expand_repeat_notation()
    |> Enum.map(&parse_track(&1, available_size))
  end

  defp parse_grid_tracks(tracks, _available_size) when is_list(tracks) do
    Enum.map(tracks, &parse_track(&1, 0))
  end

  defp parse_grid_tracks(_, _available_size), do: []

  defp expand_repeat_notation(tracks) do
    Enum.flat_map(tracks, fn track ->
      expand_track_notation(track)
    end)
  end

  defp expand_track_notation("repeat(" <> _ = track) do
    expand_repeat(track)
  end

  defp expand_track_notation(track) do
    [track]
  end

  defp expand_repeat(repeat_str) do
    # Parse "repeat(3, 1fr)" or "repeat(auto-fit, minmax(200px, 1fr))"
    content =
      repeat_str
      |> String.trim_leading("repeat(")
      |> String.trim_trailing(")")

    case String.split(content, ",", parts: 2) do
      [count_str, pattern] ->
        count_str = String.trim(count_str)
        pattern = String.trim(pattern)

        expand_by_count_type(count_str, pattern, repeat_str)

      # Invalid repeat syntax
      _ ->
        [repeat_str]
    end
  end

  defp expand_by_count_type("auto-fit", pattern, _repeat_str) do
    # For now, expand to a reasonable number of tracks
    # In a real implementation, this would be calculated based on available space
    List.duplicate(pattern, 5)
  end

  defp expand_by_count_type("auto-fill", pattern, _repeat_str) do
    # For now, expand to a reasonable number of tracks
    # In a real implementation, this would be calculated based on available space
    List.duplicate(pattern, 5)
  end

  defp expand_by_count_type(count_str, pattern, repeat_str) do
    case Integer.parse(count_str) do
      {count, ""} -> List.duplicate(pattern, count)
      # Invalid repeat, return as-is
      _ -> [repeat_str]
    end
  end

  defp parse_track(track_str, available_size) do
    parse_track_by_type(track_str, available_size)
  end

  defp parse_track_by_type(track_str, available_size)
       when is_binary(track_str) do
    case track_str do
      "auto" -> Track.new(:auto, 0)
      "min-content" -> Track.new(:min_content, 0)
      "max-content" -> Track.new(:max_content, 0)
      _ -> parse_track_by_suffix(track_str, available_size)
    end
  end

  defp parse_track_by_type(_track_str, _available_size), do: Track.new(:auto, 0)

  defp parse_track_by_suffix(track_str, available_size) do
    case try_parse_fr_track(track_str) do
      {:ok, result} ->
        result

      :error ->
        case try_parse_px_track(track_str) do
          {:ok, result} ->
            result

          :error ->
            case try_parse_percent_track(track_str, available_size) do
              {:ok, result} ->
                result

              :error ->
                case try_parse_minmax_track(track_str, available_size) do
                  {:ok, result} ->
                    result

                  :error ->
                    parse_fallback_track(track_str)
                end
            end
        end
    end
  end

  defp try_parse_fr_track(track_str) do
    case String.ends_with?(track_str, "fr") do
      true -> {:ok, parse_fr_track(track_str)}
      false -> :error
    end
  end

  defp try_parse_px_track(track_str) do
    case String.ends_with?(track_str, "px") do
      true -> {:ok, parse_px_track(track_str)}
      false -> :error
    end
  end

  defp try_parse_percent_track(track_str, available_size) do
    case String.ends_with?(track_str, "%") do
      true -> {:ok, parse_percent_track(track_str, available_size)}
      false -> :error
    end
  end

  defp try_parse_minmax_track(track_str, available_size) do
    case String.starts_with?(track_str, "minmax(") do
      true -> {:ok, parse_minmax_track(track_str, available_size)}
      false -> :error
    end
  end

  defp parse_fr_track(track_str) do
    {value, "fr"} = Float.parse(track_str)
    Track.new(:fr, value)
  end

  defp parse_px_track(track_str) do
    {value, "px"} = Integer.parse(track_str)
    Track.new(:fixed, value)
  end

  defp parse_percent_track(track_str, available_size) do
    {value, "%"} = Float.parse(track_str)
    Track.new(:fixed, div(available_size * trunc(value), 100))
  end

  # Unused function - commented out to reduce warnings
  # defp parse_keyword_track("auto"), do: Track.new(:auto, 0)
  # defp parse_keyword_track("min-content"), do: Track.new(:min_content, 0)
  # defp parse_keyword_track("max-content"), do: Track.new(:max_content, 0)

  defp parse_fallback_track(track_str) do
    case Integer.parse(track_str) do
      {value, ""} -> Track.new(:fixed, value)
      _ -> Track.new(:auto, 0)
    end
  end

  defp determine_cell_placement(
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
      # Convert to 1-based
      area.min_row + 1,
      area.min_col + 1,
      area.max_row - area.min_row + 1,
      area.max_col - area.min_col + 1,
      grid_area
    )
  end

  defp determine_cell_placement(
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

  defp determine_cell_placement(
         _grid_area,
         _grid_row,
         _grid_column,
         _areas,
         _row_tracks,
         _column_tracks
       ) do
    # Will be auto-placed
    nil
  end

  defp parse_minmax_track(minmax_str, available_size) do
    content =
      minmax_str
      |> String.trim_leading("minmax(")
      |> String.trim_trailing(")")

    case String.split(content, ",") do
      [min_str, max_str] ->
        min_track = parse_track(String.trim(min_str), available_size)
        max_track = parse_track(String.trim(max_str), available_size)
        Track.new(:minmax, %{min: min_track, max: max_track})

      _ ->
        Track.new(:auto, 0)
    end
  end

  defp parse_grid_areas("none"), do: %{}

  defp parse_grid_areas(areas_str) when is_binary(areas_str) do
    areas_str
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {line, row}, acc ->
      # Remove quotes and split by whitespace
      area_names =
        line
        |> String.replace(~r/["']/, "")
        |> String.split(~r/\s+/)
        |> Enum.filter(&(&1 != ""))

      area_names
      |> Enum.with_index()
      |> Enum.reduce(acc, fn {area_name, col}, inner_acc ->
        update_area_bounds(area_name, row, col, inner_acc)
      end)
    end)
  end

  defp parse_grid_areas(_), do: %{}

  defp place_grid_items(
         children,
         column_tracks,
         row_tracks,
         areas,
         content_space,
         _grid_props
       ) do
    Enum.reduce(children, [], fn child, acc ->
      child_attrs = Map.get(child, :attrs, %{})

      # Get item placement properties
      grid_area = Map.get(child_attrs, :grid_area)
      grid_row = Map.get(child_attrs, :grid_row)
      grid_column = Map.get(child_attrs, :grid_column)

      # Calculate dimensions
      dims = Engine.measure_element(child, content_space)

      # Determine cell placement
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

  defp parse_grid_line(nil, _track_count), do: {1, 1}

  defp parse_grid_line(line_str, track_count) when is_binary(line_str) do
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

  defp parse_grid_line(line_num, _track_count) when is_integer(line_num) do
    {line_num, 1}
  end

  defp parse_grid_line(_, _track_count), do: {1, 1}

  defp parse_line_number(line_str, track_count) do
    case Integer.parse(String.trim(line_str)) do
      {num, ""} when num > 0 -> num
      # Negative indexing
      {num, ""} when num < 0 -> track_count + 1 + num
      _ -> 1
    end
  end

  defp auto_place_items(placed_items, column_tracks, row_tracks, grid_props) do
    # Separate items that need auto-placement
    {auto_items, explicit_items} =
      Enum.split_with(placed_items, & &1.auto_placed)

    # Create occupancy grid
    occupancy =
      create_occupancy_grid(
        explicit_items,
        length(column_tracks),
        length(row_tracks)
      )

    # Auto-place items based on grid-auto-flow
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

  defp create_occupancy_grid(items, col_count, row_count) do
    # Initialize empty grid
    grid = for _r <- 1..row_count, do: for(_c <- 1..col_count, do: false)

    # Mark occupied cells
    Enum.reduce(items, grid, fn item, acc ->
      mark_cells_if_present(item.cell, acc)
    end)
  end

  defp mark_cells_if_present(nil, acc), do: acc
  defp mark_cells_if_present(cell, acc), do: mark_occupied_cells(acc, cell)

  defp mark_occupied_cells(grid, cell) do
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

  defp cell_intersects(row_idx, col_idx, cell) do
    row_idx >= cell.row and row_idx < cell.row + cell.row_span and
      col_idx >= cell.column and col_idx < cell.column + cell.column_span
  end

  defp cell_occupies_position(true, _occupied), do: true
  defp cell_occupies_position(false, occupied), do: occupied

  defp find_auto_placement(_item, occupancy, flow, col_count, row_count) do
    # Find first available position based on flow direction
    case flow do
      :row ->
        find_next_available_row(occupancy, 1, 1, col_count, row_count)

      :column ->
        find_next_available_column(occupancy, 1, 1, col_count, row_count)

      _ ->
        find_next_available_row(occupancy, 1, 1, col_count, row_count)
    end
    |> case do
      {row, col} ->
        cell = Cell.new(row, col, 1, 1)
        new_occupancy = mark_occupied_cells(occupancy, cell)
        {cell, new_occupancy}

      nil ->
        # Expand grid if needed
        cell = Cell.new(row_count + 1, 1, 1, 1)
        new_occupancy = mark_occupied_cells(occupancy, cell)
        {cell, new_occupancy}
    end
  end

  defp find_next_available_row(grid, row, col, col_count, row_count)
       when row <= row_count and col > col_count do
    find_next_available_row(grid, row + 1, 1, col_count, row_count)
  end

  defp find_next_available_row(grid, row, col, col_count, row_count)
       when row <= row_count do
    case cell_available?(grid, row, col) do
      true -> {row, col}
      false -> find_next_available_row(grid, row, col + 1, col_count, row_count)
    end
  end

  defp find_next_available_row(_, row, _col, _col_count, row_count)
       when row > row_count do
    nil
  end

  defp find_next_available_column(grid, row, col, col_count, row_count)
       when col <= col_count and row > row_count do
    find_next_available_column(grid, 1, col + 1, col_count, row_count)
  end

  defp find_next_available_column(grid, row, col, col_count, row_count)
       when col <= col_count do
    case cell_available?(grid, row, col) do
      true ->
        {row, col}

      false ->
        find_next_available_column(grid, row + 1, col, col_count, row_count)
    end
  end

  defp find_next_available_column(_, _row, col, col_count, _row_count)
       when col > col_count do
    nil
  end

  defp cell_available?(grid, row, col)
       when row > 0 and row <= length(grid) and col > 0 do
    row_data = Enum.at(grid, row - 1)
    check_column_availability(row_data, col)
  end

  defp cell_available?(_grid, _row, _col), do: false

  defp check_column_availability(row_data, col) when col <= length(row_data) do
    not Enum.at(row_data, col - 1)
  end

  defp check_column_availability(_row_data, _col), do: true

  defp size_tracks(items, column_tracks, row_tracks, content_space, grid_props) do
    # Size columns
    sized_columns =
      size_track_list(
        items,
        column_tracks,
        :column,
        content_space.width,
        grid_props
      )

    # Size rows
    sized_rows =
      size_track_list(items, row_tracks, :row, content_space.height, grid_props)

    {sized_columns, sized_rows}
  end

  defp size_track_list(items, tracks, direction, available_space, grid_props) do
    # First pass: size fixed and auto tracks
    first_pass_tracks =
      Enum.map(tracks, fn track ->
        case track.type do
          :fixed ->
            track

          :auto ->
            calculate_auto_track_size(track, items, direction)

          :min_content ->
            calculate_min_content_track_size(track, items, direction)

          :max_content ->
            calculate_max_content_track_size(track, items, direction)

          :minmax ->
            calculate_minmax_track_size(track, items, direction)

          _ ->
            track
        end
      end)

    # Second pass: distribute remaining space to fr tracks
    used_space =
      Enum.reduce(first_pass_tracks, 0, fn track, acc ->
        accumulate_non_fr_space(track.type == :fr, track.value, acc)
      end)

    # Account for gaps
    gap_space =
      case direction do
        :column -> grid_props.gap.column * max(0, length(tracks) - 1)
        :row -> grid_props.gap.row * max(0, length(tracks) - 1)
      end

    remaining_space = max(0, available_space - used_space - gap_space)

    total_fr =
      Enum.reduce(first_pass_tracks, 0, fn track, acc ->
        accumulate_fr_space(track.type == :fr, track.value, acc)
      end)

    # Final pass: assign sizes to fr tracks
    fr_unit_size =
      calculate_fr_unit_size(total_fr > 0, remaining_space, total_fr)

    Enum.map(first_pass_tracks, fn track ->
      finalize_track_size(track.type == :fr, track, fr_unit_size)
    end)
  end

  defp accumulate_non_fr_space(true, _value, acc), do: acc
  defp accumulate_non_fr_space(false, value, acc), do: acc + value

  defp accumulate_fr_space(true, value, acc), do: acc + value
  defp accumulate_fr_space(false, _value, acc), do: acc

  defp calculate_fr_unit_size(true, remaining_space, total_fr),
    do: remaining_space / total_fr

  defp calculate_fr_unit_size(false, _remaining_space, _total_fr), do: 0

  defp finalize_track_size(true, track, fr_unit_size) do
    %{track | value: track.value * fr_unit_size, type: :fixed}
  end

  defp finalize_track_size(false, track, _fr_unit_size), do: track

  defp calculate_auto_track_size(track, items, direction) do
    # Auto tracks size to fit their content
    max_size =
      Enum.reduce(items, 0, fn item, acc ->
        calculate_item_contribution(
          item.cell && track_intersects_item(track, item, direction),
          item,
          direction,
          acc
        )
      end)

    %{track | value: max_size, type: :fixed}
  end

  defp calculate_min_content_track_size(track, items, direction) do
    # Min-content is the smallest size that doesn't cause overflow
    min_size =
      Enum.reduce(items, 0, fn item, acc ->
        calculate_item_contribution(
          item.cell && track_intersects_item(track, item, direction),
          item,
          direction,
          acc
        )
      end)

    %{track | value: min_size, type: :fixed}
  end

  defp calculate_max_content_track_size(track, items, direction) do
    # Max-content is the largest size without breaking content
    max_size =
      Enum.reduce(items, 0, fn item, acc ->
        calculate_item_contribution(
          item.cell && track_intersects_item(track, item, direction),
          item,
          direction,
          acc
        )
      end)

    %{track | value: max_size, type: :fixed}
  end

  defp calculate_item_contribution(false, _item, _direction, acc), do: acc

  defp calculate_item_contribution(true, item, direction, acc) do
    size =
      case direction do
        :column -> item.dimensions.width
        :row -> item.dimensions.height
      end

    max(acc, size)
  end

  defp calculate_minmax_track_size(track, items, direction) do
    # Calculate both min and max, then clamp
    min_track = calculate_auto_track_size(track.value.min, items, direction)
    _max_track = calculate_auto_track_size(track.value.max, items, direction)

    # For now, use the min value
    %{track | value: min_track.value, type: :fixed}
  end

  defp track_intersects_item(_track, item, _direction) do
    # For simplicity, assume all tracks intersect all items
    # In a real implementation, this would check if the track affects the item
    item != nil
  end

  defp calculate_positions(
         items,
         column_tracks,
         row_tracks,
         content_space,
         grid_props
       ) do
    # Calculate column positions
    column_positions =
      calculate_track_positions(
        column_tracks,
        content_space.x,
        grid_props.gap.column
      )

    # Calculate row positions
    row_positions =
      calculate_track_positions(row_tracks, content_space.y, grid_props.gap.row)

    # Position each item
    Enum.map(items, fn item ->
      position_grid_item(
        item.cell,
        item,
        column_positions,
        column_tracks,
        row_positions,
        row_tracks,
        content_space
      )
    end)
  end

  defp position_grid_item(
         nil,
         item,
         _column_positions,
         _column_tracks,
         _row_positions,
         _row_tracks,
         _content_space
       ) do
    item
  end

  defp position_grid_item(
         _cell,
         item,
         column_positions,
         column_tracks,
         row_positions,
         row_tracks,
         content_space
       ) do
    # Get track positions for this item
    start_col = item.cell.column
    end_col = start_col + item.cell.column_span - 1
    start_row = item.cell.row
    end_row = start_row + item.cell.row_span - 1

    # Calculate item bounds
    x = Enum.at(column_positions, start_col - 1, content_space.x)

    width =
      calculate_item_width(
        end_col <= length(column_positions),
        end_col,
        column_positions,
        column_tracks,
        x,
        start_col
      )

    y = Enum.at(row_positions, start_row - 1, content_space.y)

    height =
      calculate_item_height(
        end_row <= length(row_positions),
        end_row,
        row_positions,
        row_tracks,
        y,
        start_row
      )

    child_space = %{
      x: x,
      y: y,
      width: width,
      height: height
    }

    {item.child, child_space}
  end

  defp calculate_item_width(
         true,
         end_col,
         column_positions,
         column_tracks,
         x,
         _start_col
       ) do
    end_x =
      Enum.at(column_positions, end_col - 1, x) +
        Enum.at(column_tracks, end_col - 1, %{value: 0}).value

    end_x - x
  end

  defp calculate_item_width(
         false,
         _end_col,
         _column_positions,
         column_tracks,
         _x,
         start_col
       ) do
    Enum.at(column_tracks, start_col - 1, %{value: 50}).value
  end

  defp calculate_item_height(
         true,
         end_row,
         row_positions,
         row_tracks,
         y,
         _start_row
       ) do
    end_y =
      Enum.at(row_positions, end_row - 1, y) +
        Enum.at(row_tracks, end_row - 1, %{value: 0}).value

    end_y - y
  end

  defp calculate_item_height(
         false,
         _end_row,
         _row_positions,
         row_tracks,
         _y,
         start_row
       ) do
    Enum.at(row_tracks, start_row - 1, %{value: 20}).value
  end

  defp calculate_track_positions(tracks, start_pos, gap) do
    {positions, _} =
      Enum.reduce(tracks, {[], start_pos}, fn track, {acc, current_pos} ->
        new_acc = [current_pos | acc]
        next_pos = current_pos + track.value + gap
        {new_acc, next_pos}
      end)

    Enum.reverse(positions)
  end

  ## Helper functions for refactored code

  defp update_area_bounds(".", _row, _col, acc), do: acc

  defp update_area_bounds(area_name, row, col, acc) do
    # Track the bounds of each named area
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

  defp create_grid_item(child, nil, dims, acc) do
    [Item.new(child, nil, dims, true) | acc]
  end

  defp create_grid_item(child, cell, dims, acc) do
    [Item.new(child, cell, dims, false) | acc]
  end

  defp parse_grid_line_end(start_num, end_str, track_count) do
    trimmed = String.trim(end_str)

    case String.starts_with?(trimmed, "span") do
      true ->
        span_str = trimmed |> String.trim_leading("span") |> String.trim()
        {span, ""} = Integer.parse(span_str)
        {start_num, span}

      false ->
        end_num = parse_line_number(end_str, track_count)
        {start_num, end_num - start_num}
    end
  end
end
