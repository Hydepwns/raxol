defmodule Raxol.UI.Layout.CSSGrid.Positioning do
  @moduledoc """
  Calculates final pixel positions for placed grid items given sized tracks.
  """

  @doc "Calculate {child, child_space} pairs for all placed items."
  def calculate_positions(
        items,
        column_tracks,
        row_tracks,
        content_space,
        grid_props
      ) do
    column_positions =
      calculate_track_positions(
        column_tracks,
        content_space.x,
        grid_props.gap.column
      )

    row_positions =
      calculate_track_positions(row_tracks, content_space.y, grid_props.gap.row)

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

  def position_grid_item(
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

  def position_grid_item(
        _cell,
        item,
        column_positions,
        column_tracks,
        row_positions,
        row_tracks,
        content_space
      ) do
    start_col = item.cell.column
    end_col = start_col + item.cell.column_span - 1
    start_row = item.cell.row
    end_row = start_row + item.cell.row_span - 1

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

    child_space = %{x: x, y: y, width: width, height: height}
    {item.child, child_space}
  end

  def calculate_item_width(
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

  def calculate_item_width(
        false,
        _end_col,
        _column_positions,
        column_tracks,
        _x,
        start_col
      ) do
    Enum.at(column_tracks, start_col - 1, %{value: 50}).value
  end

  def calculate_item_height(
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

  def calculate_item_height(
        false,
        _end_row,
        _row_positions,
        row_tracks,
        _y,
        start_row
      ) do
    Enum.at(row_tracks, start_row - 1, %{value: 20}).value
  end

  def calculate_track_positions(tracks, start_pos, gap) do
    {positions, _} =
      Enum.reduce(tracks, {[], start_pos}, fn track, {acc, current_pos} ->
        new_acc = [current_pos | acc]
        next_pos = current_pos + track.value + gap
        {new_acc, next_pos}
      end)

    Enum.reverse(positions)
  end
end
