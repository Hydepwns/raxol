defmodule Raxol.UI.Layout.CSSGrid.Sizing do
  @moduledoc """
  Track sizing for CSS Grid: resolves auto, fr, min-content, max-content, and
  minmax() tracks based on item content and available space.
  """

  @doc "Size both column and row track lists, returning {columns, rows}."
  def size_tracks(items, column_tracks, row_tracks, content_space, grid_props) do
    sized_columns =
      size_track_list(
        items,
        column_tracks,
        :column,
        content_space.width,
        grid_props
      )

    sized_rows =
      size_track_list(items, row_tracks, :row, content_space.height, grid_props)

    {sized_columns, sized_rows}
  end

  def size_track_list(items, tracks, direction, available_space, grid_props) do
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

    used_space =
      Enum.reduce(first_pass_tracks, 0, fn track, acc ->
        accumulate_non_fr_space(track.type == :fr, track.value, acc)
      end)

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

    fr_unit_size =
      calculate_fr_unit_size(total_fr > 0, remaining_space, total_fr)

    Enum.map(first_pass_tracks, fn track ->
      finalize_track_size(track.type == :fr, track, fr_unit_size)
    end)
  end

  # ---------------------------------------------------------------------------
  # Track size helpers
  # ---------------------------------------------------------------------------

  def accumulate_non_fr_space(true, _value, acc), do: acc
  def accumulate_non_fr_space(false, value, acc), do: acc + value

  def accumulate_fr_space(true, value, acc), do: acc + value
  def accumulate_fr_space(false, _value, acc), do: acc

  def calculate_fr_unit_size(true, remaining_space, total_fr),
    do: remaining_space / total_fr

  def calculate_fr_unit_size(false, _remaining_space, _total_fr), do: 0

  def finalize_track_size(true, track, fr_unit_size) do
    %{track | value: track.value * fr_unit_size, type: :fixed}
  end

  def finalize_track_size(false, track, _fr_unit_size), do: track

  def calculate_auto_track_size(track, items, direction) do
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

  def calculate_min_content_track_size(track, items, direction) do
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

  def calculate_max_content_track_size(track, items, direction) do
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

  def calculate_item_contribution(false, _item, _direction, acc), do: acc

  def calculate_item_contribution(true, item, direction, acc) do
    size =
      case direction do
        :column -> item.dimensions.width
        :row -> item.dimensions.height
      end

    max(acc, size)
  end

  def calculate_minmax_track_size(track, items, direction) do
    min_track = calculate_auto_track_size(track.value.min, items, direction)
    _max_track = calculate_auto_track_size(track.value.max, items, direction)
    %{track | value: min_track.value, type: :fixed}
  end

  def track_intersects_item(_track, item, _direction), do: item != nil
end
