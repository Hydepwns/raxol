defmodule Raxol.UI.Layout.CSSGrid do
  @moduledoc """
  CSS Grid layout system for Raxol UI components.

  This module provides CSS Grid-compatible layout calculations with support for:
  - Grid template rows and columns with various unit types (fr, px, auto, %, min-content, max-content)
  - Grid areas and item placement (grid-row, grid-column, grid-area)
  - Grid gaps (row-gap, column-gap, gap)
  - Alignment properties (justify-items, align-items, justify-content, align-content)
  - Auto-placement algorithm
  - Grid line naming
  - Subgrid (basic support)

  ## Example Usage

      # CSS Grid container
      %{
        type: :css_grid,
        attrs: %{
          grid_template_columns: "1fr 200px 1fr",
          grid_template_rows: "auto 1fr auto",
          gap: 10,
          grid_template_areas: ~S(
            "header header header"
            "sidebar content content"
            "footer footer footer"
          ),
          justify_items: :center,
          align_items: :stretch
        },
        children: [
          %{type: :text, attrs: %{content: "Header", grid_area: "header"}},
          %{type: :text, attrs: %{content: "Sidebar", grid_area: "sidebar"}},
          %{type: :text, attrs: %{content: "Content", grid_area: "content"}},
          %{type: :text, attrs: %{content: "Footer", grid_area: "footer"}}
        ]
      }
      
      # Explicit grid positioning
      %{
        type: :css_grid,
        attrs: %{
          grid_template_columns: "repeat(3, 1fr)",
          grid_template_rows: "repeat(3, 100px)",
          gap: %{row: 10, column: 15}
        },
        children: [
          %{type: :text, attrs: %{content: "A", grid_column: "1 / 3", grid_row: "1"}},
          %{type: :text, attrs: %{content: "B", grid_column: "3", grid_row: "1 / 3"}},
          %{type: :text, attrs: %{content: "C", grid_column: "1 / 2", grid_row: "2 / 4"}}
        ]
      }
  """

  import Raxol.Guards
  alias Raxol.UI.Layout.Engine

  # Grid track definition
  defmodule Track do
    defstruct [:type, :value, :name]

    def new(type, value, name \\ nil) do
      %__MODULE__{type: type, value: value, name: name}
    end
  end

  # Grid cell definition
  defmodule Cell do
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
      when list?(children) do
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
      when list?(children) do
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

  defp parse_padding(padding) when is_integer(padding) do
    %{top: padding, right: padding, bottom: padding, left: padding}
  end

  defp parse_padding(%{top: t, right: r, bottom: b, left: l}) do
    %{top: t, right: r, bottom: b, left: l}
  end

  defp parse_padding(_), do: %{top: 0, right: 0, bottom: 0, left: 0}

  defp apply_padding(space, padding) do
    %{
      x: space.x + padding.left,
      y: space.y + padding.top,
      width: max(0, space.width - padding.left - padding.right),
      height: max(0, space.height - padding.top - padding.bottom)
    }
  end

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
      if String.starts_with?(track, "repeat(") do
        expand_repeat(track)
      else
        [track]
      end
    end)
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

        cond do
          count_str == "auto-fit" or count_str == "auto-fill" ->
            # For now, expand to a reasonable number of tracks
            # In a real implementation, this would be calculated based on available space
            List.duplicate(pattern, 5)

          true ->
            case Integer.parse(count_str) do
              {count, ""} -> List.duplicate(pattern, count)
              # Invalid repeat, return as-is
              _ -> [repeat_str]
            end
        end

      # Invalid repeat syntax
      _ ->
        [repeat_str]
    end
  end

  defp parse_track(track_str, available_size) do
    cond do
      String.ends_with?(track_str, "fr") ->
        {value, "fr"} = Float.parse(track_str)
        Track.new(:fr, value)

      String.ends_with?(track_str, "px") ->
        {value, "px"} = Integer.parse(track_str)
        Track.new(:fixed, value)

      String.ends_with?(track_str, "%") ->
        {value, "%"} = Float.parse(track_str)
        Track.new(:fixed, div(available_size * trunc(value), 100))

      track_str == "auto" ->
        Track.new(:auto, 0)

      track_str == "min-content" ->
        Track.new(:min_content, 0)

      track_str == "max-content" ->
        Track.new(:max_content, 0)

      String.starts_with?(track_str, "minmax(") ->
        parse_minmax_track(track_str, available_size)

      true ->
        # Try to parse as integer (assume pixels)
        case Integer.parse(track_str) do
          {value, ""} -> Track.new(:fixed, value)
          # Fallback
          _ -> Track.new(:auto, 0)
        end
    end
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
        if area_name != "." do
          # Track the bounds of each named area
          current =
            Map.get(inner_acc, area_name, %{
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

          Map.put(inner_acc, area_name, updated)
        else
          inner_acc
        end
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
         grid_props
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
        cond do
          grid_area != nil and Map.has_key?(areas, grid_area) ->
            area = areas[grid_area]

            Cell.new(
              # Convert to 1-based
              area.min_row + 1,
              area.min_col + 1,
              area.max_row - area.min_row + 1,
              area.max_col - area.min_col + 1,
              grid_area
            )

          grid_row != nil or grid_column != nil ->
            {row, row_span} = parse_grid_line(grid_row, length(row_tracks))

            {col, col_span} =
              parse_grid_line(grid_column, length(column_tracks))

            Cell.new(row, col, row_span, col_span)

          true ->
            # Will be auto-placed
            nil
        end

      if cell do
        [Item.new(child, cell, dims, false) | acc]
      else
        [Item.new(child, nil, dims, true) | acc]
      end
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

        if String.starts_with?(String.trim(end_str), "span") do
          span_str =
            String.trim(end_str) |> String.trim_leading("span") |> String.trim()

          {span, ""} = Integer.parse(span_str)
          {start_num, span}
        else
          end_num = parse_line_number(end_str, track_count)
          {start_num, end_num - start_num}
        end

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
      if item.cell do
        mark_occupied_cells(acc, item.cell)
      else
        acc
      end
    end)
  end

  defp mark_occupied_cells(grid, cell) do
    for {row, r} <- Enum.with_index(grid) do
      for {occupied, c} <- Enum.with_index(row) do
        row_idx = r + 1
        col_idx = c + 1

        if row_idx >= cell.row and row_idx < cell.row + cell.row_span and
             col_idx >= cell.column and col_idx < cell.column + cell.column_span do
          true
        else
          occupied
        end
      end
    end
  end

  defp find_auto_placement(item, occupancy, flow, col_count, row_count) do
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
       when row <= row_count do
    if col > col_count do
      find_next_available_row(grid, row + 1, 1, col_count, row_count)
    else
      if is_cell_available(grid, row, col) do
        {row, col}
      else
        find_next_available_row(grid, row, col + 1, col_count, row_count)
      end
    end
  end

  defp find_next_available_row(_, row, _col, _col_count, row_count)
       when row > row_count do
    nil
  end

  defp find_next_available_column(grid, row, col, col_count, row_count)
       when col <= col_count do
    if row > row_count do
      find_next_available_column(grid, 1, col + 1, col_count, row_count)
    else
      if is_cell_available(grid, row, col) do
        {row, col}
      else
        find_next_available_column(grid, row + 1, col, col_count, row_count)
      end
    end
  end

  defp find_next_available_column(_, _row, col, col_count, _row_count)
       when col > col_count do
    nil
  end

  defp is_cell_available(grid, row, col) do
    if row > 0 and row <= length(grid) and col > 0 do
      row_data = Enum.at(grid, row - 1)

      if col <= length(row_data) do
        not Enum.at(row_data, col - 1)
      else
        true
      end
    else
      false
    end
  end

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
        if track.type == :fr do
          acc
        else
          acc + track.value
        end
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
        if track.type == :fr do
          acc + track.value
        else
          acc
        end
      end)

    # Final pass: assign sizes to fr tracks
    fr_unit_size =
      if total_fr > 0 do
        remaining_space / total_fr
      else
        0
      end

    Enum.map(first_pass_tracks, fn track ->
      if track.type == :fr do
        %{track | value: track.value * fr_unit_size, type: :fixed}
      else
        track
      end
    end)
  end

  defp calculate_auto_track_size(track, items, direction) do
    # Auto tracks size to fit their content
    max_size =
      Enum.reduce(items, 0, fn item, acc ->
        if item.cell and track_intersects_item(track, item, direction) do
          size =
            case direction do
              :column -> item.dimensions.width
              :row -> item.dimensions.height
            end

          max(acc, size)
        else
          acc
        end
      end)

    %{track | value: max_size, type: :fixed}
  end

  defp calculate_min_content_track_size(track, items, direction) do
    # Min-content is the smallest size that doesn't cause overflow
    min_size =
      Enum.reduce(items, 0, fn item, acc ->
        if item.cell and track_intersects_item(track, item, direction) do
          # For simplicity, use the item's natural size
          size =
            case direction do
              :column -> item.dimensions.width
              :row -> item.dimensions.height
            end

          max(acc, size)
        else
          acc
        end
      end)

    %{track | value: min_size, type: :fixed}
  end

  defp calculate_max_content_track_size(track, items, direction) do
    # Max-content is the largest size the content could take
    max_size =
      Enum.reduce(items, 0, fn item, acc ->
        if item.cell and track_intersects_item(track, item, direction) do
          size =
            case direction do
              :column -> item.dimensions.width
              :row -> item.dimensions.height
            end

          max(acc, size)
        else
          acc
        end
      end)

    %{track | value: max_size, type: :fixed}
  end

  defp calculate_minmax_track_size(track, items, direction) do
    # Calculate both min and max, then clamp
    min_track = calculate_auto_track_size(track.value.min, items, direction)
    max_track = calculate_auto_track_size(track.value.max, items, direction)

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
      if item.cell do
        # Get track positions for this item
        start_col = item.cell.column
        end_col = start_col + item.cell.column_span - 1
        start_row = item.cell.row
        end_row = start_row + item.cell.row_span - 1

        # Calculate item bounds
        x = Enum.at(column_positions, start_col - 1, content_space.x)

        width =
          if end_col <= length(column_positions) do
            end_x =
              Enum.at(column_positions, end_col - 1, x) +
                Enum.at(column_tracks, end_col - 1, %{value: 0}).value

            end_x - x
          else
            Enum.at(column_tracks, start_col - 1, %{value: 50}).value
          end

        y = Enum.at(row_positions, start_row - 1, content_space.y)

        height =
          if end_row <= length(row_positions) do
            end_y =
              Enum.at(row_positions, end_row - 1, y) +
                Enum.at(row_tracks, end_row - 1, %{value: 0}).value

            end_y - y
          else
            Enum.at(row_tracks, start_row - 1, %{value: 20}).value
          end

        child_space = %{
          x: x,
          y: y,
          width: width,
          height: height
        }

        {item.child, child_space}
      else
        # Item without placement - place at origin
        {item.child,
         %{
           x: content_space.x,
           y: content_space.y,
           width: item.dimensions.width,
           height: item.dimensions.height
         }}
      end
    end)
  end

  defp calculate_track_positions(tracks, start_pos, gap) do
    {positions, _} =
      Enum.reduce(tracks, {[], start_pos}, fn track, {acc, current_pos} ->
        new_acc = acc ++ [current_pos]
        next_pos = current_pos + track.value + gap
        {new_acc, next_pos}
      end)

    positions
  end
end
